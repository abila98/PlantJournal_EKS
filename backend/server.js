const express = require('express');
const multer  = require('multer');
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const { Pool } = require('pg');
const path = require('path');

const app  = express();
const PORT = 3000;

app.use(express.json());

// ── PostgreSQL pool ─────────────────────────────────────────
const useSSL = process.env.DB_SSL === 'true';
const pool = new Pool({
  host:     process.env.DB_HOST,
  port:     parseInt(process.env.DB_PORT) || 5432,
  database: process.env.DB_NAME     || 'plantjournal',
  user:     process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  ssl:      useSSL ? { rejectUnauthorized: false } : false,
  max:      10,   // max 10 connections in pool
});

// ── S3 client ───────────────────────────────────────────────
// Uses EC2 instance role automatically — no keys needed!
const s3 = new S3Client({ region: process.env.AWS_REGION || 'ap-south-1' });
const BUCKET = process.env.S3_BUCKET; // e.g. plantjournal-pics

// ── Multer — store file in memory temporarily ───────────────
// File goes: browser → backend memory → S3 (never touches disk)
const upload = multer({
  storage: multer.memoryStorage(),
  limits:  { fileSize: 10 * 1024 * 1024 }, // 10 MB max
  fileFilter: (req, file, cb) => {
    const allowed = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'];
    if (allowed.includes(file.mimetype)) cb(null, true);
    else cb(new Error('Only image files are allowed (jpg, png, webp, gif)'));
  }
});

// ── Health check ────────────────────────────────────────────
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// ── POST /api/upload — upload image to S3 ──────────────────
// Returns the public S3 URL
app.post('/api/upload', upload.single('image'), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No image file provided' });
  }

  if (!BUCKET) {
    return res.status(500).json({ error: 'S3_BUCKET env var not set' });
  }

  // Build a unique filename: timestamp-originalname
  const ext      = path.extname(req.file.originalname).toLowerCase() || '.jpg';
  const filename = `plants/${Date.now()}-${Math.random().toString(36).slice(2)}${ext}`;

  try {
    await s3.send(new PutObjectCommand({
      Bucket:      BUCKET,
      Key:         filename,
      Body:        req.file.buffer,
      ContentType: req.file.mimetype,
    }));

    // Build the public URL
    const region = process.env.AWS_REGION || 'ap-south-1';
    const url = `https://${BUCKET}.s3.${region}.amazonaws.com/${filename}`;

    console.log(`Uploaded to S3: ${url}`);
    res.json({ url });

  } catch (err) {
    console.error('S3 upload failed:', err.message);
    res.status(500).json({ error: 'S3 upload failed', detail: err.message });
  }
});

// ── GET /api/plants ─────────────────────────────────────────
app.get('/api/plants', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, name, latin_name, tag, bloom_seasons, sent_by,
              spotted_at, special_features, water_req, notes, image_url, created_at
       FROM plants ORDER BY created_at DESC`
    );
    res.json(result.rows);
  } catch (err) {
    console.error('GET /api/plants failed:', err.message);
    res.status(500).json({ error: 'Database error', detail: err.message });
  }
});

// ── POST /api/plants ────────────────────────────────────────
app.post('/api/plants', async (req, res) => {
  const {
    name, latin_name, tag, bloom_seasons,
    sent_by, spotted_at, special_features,
    water_req, notes, image_url
  } = req.body;

  if (!name || !tag) {
    return res.status(400).json({ error: 'name and tag are required' });
  }

  try {
    const result = await pool.query(
      `INSERT INTO plants
         (name, latin_name, tag, bloom_seasons, sent_by, spotted_at, special_features, water_req, notes, image_url)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
       RETURNING *`,
      [
        name, latin_name || null, tag,
        bloom_seasons    || [],
        sent_by          || null,
        spotted_at       || null,
        special_features || [],
        water_req        || null,
        notes            || null,
        image_url        || null
      ]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('POST /api/plants failed:', err.message);
    res.status(500).json({ error: 'Database error', detail: err.message });
  }
});

// ── Start ───────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`Plant Journal backend v3 running on port ${PORT}`);
  console.log(`DB host:   ${process.env.DB_HOST}`);
  console.log(`S3 bucket: ${BUCKET}`);
  console.log(`SSL:       ${useSSL}`);
});

