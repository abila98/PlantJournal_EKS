# PlantJournal

A simple 3-tier app to log and browse plants/flowers sent over by friends — upload a photo, add notes, and view the collection. Built as a learning project to practice containerizing a full stack and running it on AWS EKS.

## Architecure Diagram

<img width="1536" height="1024" alt="image" src="https://github.com/user-attachments/assets/ee010a52-3f69-464e-9e14-8e668ec96be9" />

---
## Stack
- Frontend: static HTML served by nginx (proxies `/api/*` to the backend)
- Backend: Node.js / Express, uploads images to S3, reads/writes plant records in PostgreSQL
- Database: PostgreSQL (RDS in AWS, plain Postgres container locally)
- Images: uploaded to an S3 bucket, URL stored in the DB
- Infra (AWS): VPC with public/private subnets, IGW, NAT, ALB (ACM-terminated TLS) in the public subnet, EKS + RDS in the private subnet, ECR for container images, IAM roles (IRSA / pod identity) for pod-level S3 access

---

## 1. Run it locally with Docker Compose

This spins up the frontend, backend, and a Postgres container that stands in for RDS. Good for trying the app out or developing without touching AWS.

### Prerequisites

- Docker
- Docker Compose (v2, i.e. the `docker compose` subcommand — or standalone `docker-compose`)
- An AWS account with an S3 bucket, **if** you want image uploads to actually work locally (see note below)

### Steps

1. **Clone the repo**
   ```bash
   git clone https://github.com/abila98/PlantJournal_EKS.git
   cd PlantJournal_EKS
   ```

2. **Check `docker-compose.yml`** — it already defines three services: `postgres`, `backend`, `frontend`, on a shared bridge network. Postgres auto-seeds from `seed.sql` on first run.

3. **Set your S3 bucket / region** (needed for the upload feature to work)

   Open `docker-compose.yml` and update these under the `backend` service:
   ```yaml
   environment:
     S3_BUCKET:  "your-bucket-name"
     AWS_REGION: "your-region"
   ```

4. **Provide AWS credentials to the backend container**

   The backend uses the AWS SDK's default credential chain (no keys hardcoded). Locally there's no EC2/pod role to fall back to, so pass your own credentials as environment variables, for example:
   ```yaml
   environment:
     AWS_ACCESS_KEY_ID: "your-access-key"
     AWS_SECRET_ACCESS_KEY: "your-secret-key"
   ```
   Or mount your `~/.aws` credentials file into the container instead. Skip this if you only want to test the plant list/DB features without image uploads.
   Or create a EC2 workspace and attach instance_profile role to the ec2 which has good permissions.

6. **Build and start everything**
   ```bash
   docker compose up --build
   ```

7. **Access the app**
   - Frontend: [http://localhost](http://localhost)
   - Backend health check: [http://localhost:3000/health](http://localhost:3000/health)
   - Backend API directly: [http://localhost:3000/api/plants](http://localhost:3000/api/plants)

8. **Stop everything**
   ```bash
   docker compose down
   ```
   Add `-v` if you also want to wipe the Postgres volume (`docker compose down -v`) and start with a fresh seeded DB next time.

### Troubleshooting

- **Backend can't reach Postgres** — don't change `DB_HOST`; it must stay as the service name (`postgres`), since containers resolve each other by service name on the shared Docker network.
- **Image upload fails with "S3 upload failed"** — check `S3_BUCKET`, `AWS_REGION`, and your credentials, and that the IAM user/key has `s3:PutObject` on the bucket.
- **Port already in use** — change the left-hand side of a `ports` mapping, e.g. `"8080:80"` instead of `"80:80"`.

---

## 2. Deploy to AWS EKS

This assumes the VPC, subnets, IGW, NAT, RDS, and S3 bucket are already provisioned (see architecture diagram above), and that you have an EC2 instance to use as a workstation/bastion for running these commands.

> Keep `--region` consistent across every command below. The commands as originally run mixed `us-east-1` (ECR) and `us-west-1` (EKS cluster/OIDC/load balancer) — pick one region for your setup and use it everywhere.

### 2.1 Prep the workstation EC2 instance

```bash
sudo yum install git -y      # or apt install git -y on Ubuntu
git clone https://github.com/abila98/PlantJournal_EKS.git
cd PlantJournal_EKS
chmod +x setup.sh
./setup.sh
```

`setup.sh` installs Docker, Docker Compose, `eksctl`, `kubectl`, `helm`, and the PostgreSQL client. The IAM role/instance profile attached to this EC2 instance needs enough permissions to create and manage: EKS clusters and nodegroups, the underlying EC2/Auto Scaling resources, IAM roles/policies (for OIDC and pod identity), and the ALB (via the Load Balancer Controller). Easiest to use an admin-level role while setting this up, then tighten later.

### 2.2 Create the EKS cluster

```bash
eksctl create cluster \
  --name mycluster \
  --region us-east-1 \
  --version 1.36 \
  --nodegroup-name standard-workers \
  --node-type t3.medium \
  --nodes 1 \
  --nodes-min 1 \
  --nodes-max 1 \
  --managed
```

**Alternative — create it inside your existing VPC/subnets** instead of letting `eksctl` build a new VPC, using `eks/cluster-template.yaml`:

```bash
cd eks
# edit eksnetworking.env with your VPC ID and subnet IDs first
source eksnetworking.env
envsubst < cluster-template.yaml > cluster.yaml
eksctl create cluster -f cluster.yaml
cd ..
```

### 2.3 Set up the IAM OIDC provider (needed for IRSA)

```bash
eksctl utils associate-iam-oidc-provider \
  --cluster mycluster \
  --region us-west-1 \
  --approve
```

### 2.4 Install the AWS Load Balancer Controller

```bash
eksctl create iamserviceaccount \
  --cluster=mycluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=arn:aws:iam::417425906408:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve \
  --region=us-west-1

aws eks describe-cluster \
  --name mycluster \
  --region us-west-1 \
  --query "cluster.resourcesVpcConfig.vpcId" \
  --output text

helm repo add eks https://aws.github.io/eks-charts
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=mycluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=us-west-1 \
  --set vpcId=<<vpcid_from_above>>
```

### 2.5 S3 bucket for plant photos

Bucket: `plantjournal-pictures`

The backend needs `s3:PutObject` on this bucket. Rather than access keys, the pod gets access via **EKS Pod Identity**:

```bash
aws eks create-pod-identity-association \
  --cluster-name mycluster \
  --namespace default \
  --service-account plantjournal-sa \
  --role-arn arn:aws:iam::417425906408:role/PlantJournalS3Role \
  --region us-west-1
```

`PlantJournalS3Role` needs an S3 read/write policy scoped to `plantjournal-pictures`, and a trust policy allowing `pods.eks.amazonaws.com` to assume it. `k8s/serviceaccount.yaml` also annotates the `plantjournal-sa` service account with this role ARN for IRSA as a fallback path.

### 2.6 Build, tag, and push images to ECR

**Backend**
```bash
aws ecr create-repository --repository-name plantjournal-backend --region us-east-1

aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin <<account>>.dkr.ecr.us-east-1.amazonaws.com

docker build -t plantjournal-backend ./backend
docker tag plantjournal-backend:latest <<account>>.dkr.ecr.us-east-1.amazonaws.com/plantjournal-backend:latest
docker push <<account>>.dkr.ecr.us-east-1.amazonaws.com/plantjournal-backend:latest
```

**Frontend**
```bash
aws ecr create-repository --repository-name plantjournal-frontend --region us-east-1

docker build -t plantjournal-frontend ./frontend
docker tag plantjournal-frontend:latest<<account>>.dkr.ecr.us-east-1.amazonaws.com/plantjournal-frontend:latest
docker push <<account>>.dkr.ecr.us-east-1.amazonaws.com/plantjournal-frontend:latest
```

`k8s/deployment.yaml` already points at these two image URIs — update them if your account ID or region differ.

### 2.7 Deploy to the cluster

Update `k8s/configmap.yaml` (RDS endpoint, DB name, S3 bucket, region) and `k8s/secret.yaml` (DB credentials) for your environment, then apply everything:

```bash
kubectl apply -f k8s/
```

This creates the service account (`serviceaccount.yaml`), config/secrets (`configmap.yaml`, `secret.yaml`), both deployments (`deployment.yaml`), both services (`service.yaml`), and the ALB ingress (`ingress.yaml`).

### 2.8 Get the app URL

```bash
kubectl get ingress plantjournal-ingress
```

The `ADDRESS` column gives the ALB's DNS name once the Load Balancer Controller finishes provisioning it (can take a couple of minutes).
