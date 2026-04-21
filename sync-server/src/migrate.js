const pool = require('./db');

async function migrate() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS users (
      id SERIAL PRIMARY KEY,
      email TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      display_name TEXT,
      avatar_color TEXT DEFAULT '#01696f',
      created_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS user_sync (
      user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
      playlists JSONB DEFAULT '[]',
      favorites JSONB DEFAULT '[]',
      watch_later JSONB DEFAULT '[]',
      continue_watching JSONB DEFAULT '[]',
      settings JSONB DEFAULT '{}',
      updated_at TIMESTAMPTZ DEFAULT NOW()
    );
  `);
  console.log('[DB] Migration complete');
  await pool.end();
}

migrate().catch(console.error);
