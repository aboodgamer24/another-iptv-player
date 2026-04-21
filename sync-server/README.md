# IPTV Sync Server

A self-hosted Node.js backend for syncing playlists, favorites, watch later, continue watching, and settings across devices.

---

## Quick Start (without Docker)

1. Install **PostgreSQL** and create a database:
   ```sql
   CREATE DATABASE iptv_sync;
   ```
2. Copy `.env.example` to `.env` and fill in your values:
   ```bash
   cp .env.example .env
   ```
3. Install dependencies:
   ```bash
   npm install
   ```
4. Run database migrations:
   ```bash
   node src/migrate.js
   ```
5. Start the server:
   ```bash
   npm start
   ```
   The server will be available at `http://localhost:7000`.

---

## Docker Setup (Recommended)

### Prerequisites
- [Docker](https://docs.docker.com/get-docker/) installed
- [Docker Compose](https://docs.docker.com/compose/install/) installed (included with Docker Desktop)

### 1. Configure Environment

Copy the example env file and edit it:

```bash
cp .env.example .env
```

Edit `.env` with your preferred values:

```env
PORT=7000
DB_HOST=db
DB_PORT=5432
DB_NAME=iptv_sync
DB_USER=postgres
DB_PASSWORD=your_secure_password_here
JWT_SECRET=change_this_to_a_long_random_secret
JWT_EXPIRES_IN=30d
```

> **Important:** When using Docker Compose, set `DB_HOST=db` (the service name), not `localhost`.

### 2. Start with Docker Compose

```bash
docker compose up -d
```

This will:
- Pull and start a **PostgreSQL 16** container with persistent data
- Build and start the **sync server** container
- Automatically run database migrations on first start
- Expose the server on port **7000**

### 3. Verify it's Running

```bash
curl http://localhost:7000/health
```

Expected response:
```json
{"status":"ok"}
```

### 4. View Logs

```bash
# All services
docker compose logs -f

# Server only
docker compose logs -f server

# Database only
docker compose logs -f db
```

### 5. Stop the Server

```bash
# Stop containers (keeps data)
docker compose down

# Stop and delete all data (volumes)
docker compose down -v
```

### 6. Rebuild After Code Changes

```bash
docker compose up -d --build
```

---

## Docker Commands Reference

| Command | Description |
|---------|-------------|
| `docker compose up -d` | Start all services in the background |
| `docker compose up -d --build` | Rebuild and start (after code changes) |
| `docker compose down` | Stop all services (preserves data) |
| `docker compose down -v` | Stop and remove all data |
| `docker compose logs -f` | Follow logs from all services |
| `docker compose ps` | Show running containers |
| `docker compose exec db psql -U postgres -d iptv_sync` | Open psql shell |
| `docker compose exec server node src/migrate.js` | Re-run migrations |

---

## API Endpoints

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `GET` | `/health` | No | Health check |
| `POST` | `/auth/register` | No | Register a new account |
| `POST` | `/auth/login` | No | Login and receive JWT token |
| `GET` | `/sync` | Yes | Pull all synced data |
| `PUT` | `/sync` | Yes | Push all data (full replace) |
| `PATCH` | `/sync/:field` | Yes | Update a single field (`playlists`, `favorites`, `watch_later`, `continue_watching`, `settings`) |
| `GET` | `/sync/me` | Yes | Get profile info |
| `PATCH` | `/sync/me` | Yes | Update display name or avatar color |

### Authentication

All protected endpoints require a `Bearer` token in the `Authorization` header:

```
Authorization: Bearer <your_jwt_token>
```

---

## Connecting from the App

1. Open **Settings** → **Sign In / Register**
2. Enter your server URL: `http://<your-server-ip>:7000`
3. Create an account or sign in
4. Your data will sync automatically

> **Tip:** If running Docker on the same machine, use your LAN IP (e.g., `http://192.168.1.100:7000`), not `localhost`, when connecting from a mobile device.
