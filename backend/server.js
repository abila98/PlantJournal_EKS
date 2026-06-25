const express = require('express');
const { Pool } = require('pg');

const app  = express();
const PORT = 3000;

// ── DB connection pool ──────────────────────────────────────
// Credentials come from environment variables (Docker Compose or K8s Secret)
const useSSL = process.env.DB_SSL === 'true';

const pool = new Pool({
  host:     process.env.DB_HOST,
  port:     parseInt(process.env.DB_PORT) || 5432,
  database: process.env.DB_NAME     || 'plantjournal',
  user:     process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  ssl:      useSSL ? { rejectUnauthorized: false } : false,
});

// ── Health check — K8s liveness/readiness probe ─────────────
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// ── GET /api/plants — return all plants ─────────────────────
app.get('/api/plants', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, name, latin_name, tag, notes, image_url
       FROM plants
       ORDER BY id ASC`
    );
    res.json(result.rows);
  } catch (err) {
    console.error('DB query failed:', err.message);
    res.status(500).json({ error: 'Database error', detail: err.message });
  }
});

// ── Start ───────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`Plant Journal backend running on port ${PORT}`);
  console.log(`DB host: ${process.env.DB_HOST}`);
  console.log(`SSL: ${useSSL}`);
});

