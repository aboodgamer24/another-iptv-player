<div align="center">
  <img width="110" src="https://raw.githubusercontent.com/aboodgamer24/another-iptv-player/main/assets/logo.png" alt="C4TV Player Logo" />
  <h1>C4TV Player</h1>
  <p><strong>Beautiful UI · Multi-Device Sync · Lightning-Fast Streaming · 100% Free & Open Source</strong></p>

</div>

---

**Another IPTV Player** (branded as **C4TV Player**) is a free, open-source IPTV client built with Flutter. It focuses on three core pillars: a **clean, intuitive UI** that feels native on every device, **seamless cross-device synchronization** via a self-hosted backend you fully control, and a **fast, reliable streaming engine** powered by media_kit.

> **⚠️ Disclaimer:** This application is a player only. It does **not** provide IPTV content, subscriptions, or streaming services. You must supply your own legal IPTV provider credentials.

---

## 🎨 Beautiful, Friendly UI

The app is designed to feel natural across all screen sizes — from phones to desktops. Everything is where you'd expect it.

- **Clean home screen** with your playlists, recent content, and quick-access categories
- **Responsive layout** that adapts beautifully from 5-inch phones to 4K desktops
- **Persistent bottom navigation** for instant access to Live TV, Movies, Series, Search, and Settings
- **Category browsing** with search, sorting, and the ability to hide unwanted categories
- **Full metadata display** — cover art, descriptions, ratings, and episode lists for series

---

## 🔄 Cross-Device Synchronization

Your data follows you everywhere. Connect to your own self-hosted sync server and keep the following in sync across all your devices in real time:

| Data                      | Synced |
| ------------------------- | ------ |
| 📋 Playlists              | ✅     |
| ❤️ Favorites              | ✅     |
| ▶️ Continue Watching      | ✅     |
| 🕒 Watch History          | ✅     |
| ⏰ Watch Later            | ✅     |
| ⚙️ Settings & Preferences | ✅     |

The sync server is a lightweight **Node.js + PostgreSQL** backend you host yourself — no third-party cloud, no data sharing, full privacy. See the [Self-Hosting the Sync Server](https://github.com/aboodgamer24/c4tv-player/tree/main/sync-server) section below to get started in minutes.

---

## ⚡ Fast Streaming

Streaming speed and reliability come first.

- **media_kit** — battle-tested, cross-platform video engine (based on libmpv/FFmpeg) handles virtually any stream format
- **Local SQLite cache** — playlist data and metadata are stored locally via Drift/SQLite, meaning the app loads instantly without waiting for network
- **Connectivity-aware** — gracefully handles drops, retries, and reconnects with exponential backoff
- **Wakelock** — prevents screen sleep during long viewing sessions
- **Playlist refresh on demand** — pull fresh M3U data with one tap, without restarting
- **Track switching** — change video quality, audio language, or subtitles mid-stream without buffering
- **Xtream Codes + M3U/M3U8** — supports both major IPTV stream formats natively

---

## ✨ Full Feature List

- Xtream Codes API support (Live, VOD, Series)
- M3U / M3U8 playlist support (URL or local file)
- Continue Watching with automatic resume
- Auto-play next episode
- Global search across all content types
- Watch History per playlist
- Favorites
- Video, audio, and subtitle track selection with memory
- Subtitle customization (font, size, color, position)
- Multi-language UI (10+ languages)
- Sorting options for channels and content

---

## 🖥️ Supported Platforms

| Platform   | Status       |
| ---------- | ------------ |
| 🤖 Android | ✅ Supported |
| 🪟 Windows | ✅ Supported |

---

## 🚀 Getting Started

### Prerequisites

- An IPTV subscription that supports **Xtream Codes API** or **M3U / M3U8 playlists**
- _(Optional)_ A server to self-host the sync backend

### Installation

Download the latest pre-built release for your platform from the [**Releases**](https://github.com/aboodgamer24/another-iptv-player/releases) page.

| Platform | Package                     |
| -------- | --------------------------- |
| Windows  | `.exe` installer            |
| Android  | `.apk`                      |

### Quick Start

1. Install the app for your platform
2. Tap **Add Playlist**
3. Enter your **Xtream Codes** credentials **or** paste an **M3U URL**
4. Wait for the playlist to load — content is cached locally
5. Browse Live TV, Movies, or Series and start watching

---

## 🗄️ Self-Hosting the Sync Server

The sync server is a **Node.js + PostgreSQL** backend that lives in the `sync-server/` directory. Hosting it takes less than 5 minutes with Docker.

### What Gets Synced

Once connected, the app automatically syncs your playlists, favorites, watch history, continue watching progress, watch later list, and settings across all your signed-in devices.

### Requirements

- A machine running Docker and Docker Compose (a VPS, home server, or Raspberry Pi all work)
- Port `7000` accessible from your devices (or proxied behind Nginx/Caddy with HTTPS)

---

### Option A — Docker (Recommended)

**1. Navigate to the sync-server directory:**

```bash
cd sync-server
```

**2. Copy and configure the environment file:**

```bash
cp .env.example .env
```

Edit `.env` with your values:

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

> **Important:** Keep `DB_HOST=db` when using Docker Compose — that's the internal service name.

**3. Start all services:**

```bash
docker compose up -d
```

This pulls **PostgreSQL 16**, builds the sync server, runs database migrations, and starts everything. The server is now running on port `7000`.

**4. Verify it's working:**

```bash
curl http://localhost:7000/health
# Expected: {"status":"ok"}
```

---

### Option B — Without Docker (Manual)

**1. Install PostgreSQL** and create a database:

```sql
CREATE DATABASE iptv_sync;
```

**2. Install dependencies:**

```bash
cd sync-server
cp .env.example .env   # fill in DB credentials and JWT_SECRET
npm install
```

**3. Run migrations and start:**

```bash
node src/migrate.js
npm start
```

The server starts at `http://localhost:7000`.

---

### Docker Commands Reference

| Command                                                | Description                          |
| ------------------------------------------------------ | ------------------------------------ |
| `docker compose up -d`                                 | Start all services in the background |
| `docker compose up -d --build`                         | Rebuild after code changes           |
| `docker compose down`                                  | Stop services (keeps data)           |
| `docker compose down -v`                               | Stop and delete all data             |
| `docker compose logs -f`                               | Follow all logs                      |
| `docker compose logs -f server`                        | Follow server logs only              |
| `docker compose ps`                                    | Show running containers              |
| `docker compose exec db psql -U postgres -d iptv_sync` | Open database shell                  |

---

### Connecting the App to Your Server

1. Open the app → **Settings** → **Sign In / Register**
2. Enter your server URL: `http://<your-server-ip>:7000`
3. Create an account or sign in
4. Sync starts automatically

> **Tip:** If your server runs on the same local network, use your LAN IP (e.g., `http://192.168.1.100:7000`) rather than `localhost` when connecting from a phone or tablet.

---

### API Reference

| Method  | Endpoint         | Auth | Description                                                                                      |
| ------- | ---------------- | ---- | ------------------------------------------------------------------------------------------------ |
| `GET`   | `/health`        | No   | Health check                                                                                     |
| `POST`  | `/auth/register` | No   | Register a new account                                                                           |
| `POST`  | `/auth/login`    | No   | Login and receive JWT token                                                                      |
| `GET`   | `/sync`          | Yes  | Pull all synced data                                                                             |
| `PUT`   | `/sync`          | Yes  | Push all data (full replace)                                                                     |
| `PATCH` | `/sync/:field`   | Yes  | Update a single field (`playlists`, `favorites`, `watch_later`, `continue_watching`, `settings`) |
| `GET`   | `/sync/me`       | Yes  | Get profile info                                                                                 |
| `PATCH` | `/sync/me`       | Yes  | Update display name or avatar color                                                              |

All protected endpoints require a JWT Bearer token in the `Authorization` header.

---

## 🛠️ Build from Source

### Requirements

- [Flutter SDK](https://flutter.dev/docs/get-started/install) `^3.9.2` (Dart SDK `^3.9.2`)
- Platform toolchain (Android Studio, Xcode, etc.)

### Steps

```bash
# Clone the repository
git clone https://github.com/aboodgamer24/another-iptv-player.git
cd another-iptv-player

# Install dependencies
flutter pub get

# Generate Drift DB models and localizations
flutter pub run build_runner build --delete-conflicting-outputs
# Or use the provided script:
bash generate.sh

# Run on your target platform
flutter run                   # default device
flutter run -d windows        # Windows desktop
flutter run -d linux          # Linux desktop
flutter run -d android        # Android
flutter run -d web-server     # Web browser
```

### Windows Installer

Build a Windows installer using [Inno Setup](https://jrsoftware.org/isinfo.php):

```bat
build_installer.bat
```

---

## 🗺️ Roadmap

### Completed ✅

- [x] Xtream Codes API (Live, VOD, Series)
- [x] M3U / M3U8 playlist support
- [x] Watch history, favorites, continue watching
- [x] Global search
- [x] Track selection with memory
- [x] Subtitle customization
- [x] Localization (10+ languages)
- [x] Cross-device sync server

### Planned 🔜

- [ ] Android TV / tvOS interface
- [ ] Linux desktop version
- [ ] macOS version
- [ ] iOS version
- [ ] Web version

---

## 🤝 Contributing

Contributions are welcome — bug reports, feature requests, translations, and pull requests. Please read [CONTRIBUTING.md](CONTRIBUTING.md) before submitting changes.

---

## 📄 License

Licensed under the terms in the [LICENSE](LICENSE) file.

---

## 🙏 Acknowledgements

- Video playback powered by [media_kit](https://github.com/media-kit/media-kit)
- Original project & special thanks to [**@bsogulcan**](https://github.com/bsogulcan) for creating and open-sourcing [another-iptv-player](https://github.com/bsogulcan/another-iptv-player) — the foundation this project is built upon
- Xtream Codes API documentation by [JUL1EN094](https://github.com/JUL1EN094)

---

<div align="center">
  <sub>Built with Flutter · No subscriptions · No tracking · Self-hostable · Open Source</sub>
</div>
