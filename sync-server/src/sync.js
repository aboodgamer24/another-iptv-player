const express = require('express');
const jwt = require('jsonwebtoken');
const pool = require('./db');
const router = express.Router();

// Auth middleware
function auth(req, res, next) {
  const header = req.headers.authorization;
  if (!header) return res.status(401).json({ error: 'No token' });
  try {
    const payload = jwt.verify(header.replace('Bearer ', ''), process.env.JWT_SECRET);
    req.userId = payload.userId;
    next();
  } catch {
    res.status(401).json({ error: 'Invalid token' });
  }
}

// GET /sync — pull all user data
router.get('/', auth, async (req, res) => {
  const result = await pool.query('SELECT * FROM user_sync WHERE user_id = $1', [req.userId]);
  if (!result.rows[0]) return res.json({ playlists: [], favorites: [], watch_later: [], continue_watching: [], settings: {} });
  res.json(result.rows[0]);
});

// PUT /sync — push all user data (full replace)
router.put('/', auth, async (req, res) => {
  const { playlists, favorites, watch_later, continue_watching, settings } = req.body;
  await pool.query(`
    INSERT INTO user_sync (user_id, playlists, favorites, watch_later, continue_watching, settings, updated_at)
    VALUES ($1, $2, $3, $4, $5, $6, NOW())
    ON CONFLICT (user_id) DO UPDATE SET
      playlists = EXCLUDED.playlists,
      favorites = EXCLUDED.favorites,
      watch_later = EXCLUDED.watch_later,
      continue_watching = EXCLUDED.continue_watching,
      settings = EXCLUDED.settings,
      updated_at = NOW()
  `, [
    req.userId,
    JSON.stringify(playlists ?? []),
    JSON.stringify(favorites ?? []),
    JSON.stringify(watch_later ?? []),
    JSON.stringify(continue_watching ?? []),
    JSON.stringify(settings ?? {}),
  ]);
  res.json({ success: true });
});

// PATCH /sync/:field — update a single field only (e.g. favorites, settings)
router.patch('/:field', auth, async (req, res) => {
  const allowed = ['playlists', 'favorites', 'watch_later', 'continue_watching', 'settings'];
  const { field } = req.params;
  if (!allowed.includes(field)) return res.status(400).json({ error: 'Invalid field' });
  await pool.query(`
    INSERT INTO user_sync (user_id, ${field}, updated_at)
    VALUES ($1, $2, NOW())
    ON CONFLICT (user_id) DO UPDATE SET ${field} = EXCLUDED.${field}, updated_at = NOW()
  `, [req.userId, JSON.stringify(req.body.data)]);
  res.json({ success: true });
});

// GET /sync/me — get profile info
router.get('/me', auth, async (req, res) => {
  const result = await pool.query('SELECT id, email, display_name, avatar_color, created_at FROM users WHERE id = $1', [req.userId]);
  res.json(result.rows[0]);
});

// PATCH /sync/me — update display name or avatar color
router.patch('/me', auth, async (req, res) => {
  const { displayName, avatarColor } = req.body;
  await pool.query('UPDATE users SET display_name = COALESCE($1, display_name), avatar_color = COALESCE($2, avatar_color) WHERE id = $3',
    [displayName, avatarColor, req.userId]);
  res.json({ success: true });
});

module.exports = { router, auth };
