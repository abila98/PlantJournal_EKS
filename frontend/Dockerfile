FROM nginx:alpine

# Remove default nginx page
RUN rm /usr/share/nginx/html/*

# Copy our static site
COPY index.html /usr/share/nginx/html/index.html

# nginx config to proxy /api calls to the backend service
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

