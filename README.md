# CalSnap — Snap your meal, AI counts the calories 📸🍱

> **A full-stack AI calorie tracker.** Point your iPhone at a plate of food, and Claude vision identifies the meal, estimates calories + macros, and logs it to a daily tracker — all synced to a Django backend.

CalSnap is a **Cal AI clone** built end-to-end with [Claude Code](https://claude.com/claude-code): a native **SwiftUI** iOS app talking to a **Django + DRF** API, with **Claude vision** doing the food recognition. The whole thing was built live, on stream.

<p align="center">
  <em>camera → Claude → calorie number appears → the ring animates up.</em>
</p>

---

## 🎓 Learn to build this (free course)

This repo is the companion code for the full video course:

### ▶️ [Learn to Build an AI Calorie Tracker iOS App with Claude](https://aiseekho.pk/courses/ios-app-with-claude)

**Free on [aiseekho.pk](https://aiseekho.pk/courses/ios-app-with-claude).** Watch the entire app get built from an empty folder — Django models, JWT auth, the Claude vision prompt, the SwiftUI screens, the animated calorie ring, and running it on a real iPhone. No prior iOS experience required.

> 🇵🇰 More free AI & coding courses at **[aiseekho.pk](https://aiseekho.pk)** · 📺 Follow the build on **[@codewithmuh](https://youtube.com/@codewithmuh)**

---

## ✨ Features

- 📷 **Snap a meal** — camera or photo library (PhotosUI)
- 🤖 **Claude vision analysis** — image → `{ food, calories, protein, carbs, fat, confidence }`
- 🔥 **Animated calorie ring** — progress vs. your daily goal, smoothly animates up on save
- 📝 **Daily meal log** — today's meals, tap to delete
- 📊 **History & trends** — 7-day calories bar chart (Swift Charts) with goal line
- 🔐 **JWT auth** — email/password register + login, tokens in the Keychain
- 👤 **Guest mode** — try the app without an account
- ⚙️ **Settings** — edit your daily calorie goal, log out
- 🐳 **Dockerized backend** — Postgres + Redis + Django/gunicorn via Docker Compose

---

## 🏗️ Architecture

```
iOS App (SwiftUI)
    │  HTTPS + JWT
    ▼
Django REST API
    ├── PostgreSQL   users · meals
    ├── Claude API   vision: image → { food, calories, protein_g, carbs_g, fat_g, confidence }
    └── local media  meal photos
```

**The heart of the app** is a single, readable prompt in [`backend/meals/claude.py`](backend/meals/claude.py) — it tells Claude to return strict JSON, which the backend parses, validates, and persists.

### Tech stack

| Layer | Tech |
|---|---|
| **iOS** | Xcode 16 · iOS 18 · SwiftUI · PhotosUI · Swift Charts · URLSession (async/await) · Keychain |
| **Backend** | Django 5.1 · Django REST Framework · SimpleJWT · Pillow |
| **AI** | Claude (`claude-sonnet-4-6`) vision via the official `anthropic` SDK |
| **Data** | PostgreSQL 16 (SQLite fallback for bare-local dev) |
| **Infra** | Docker Compose (`db` · `redis` · `web` + gunicorn) |

---

## 🔌 API

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/api/auth/register` | Create account → JWT |
| `POST` | `/api/auth/login` | Login → access + refresh tokens |
| `POST` | `/api/auth/refresh` | Refresh access token |
| `GET` / `PATCH` | `/api/auth/me` | Current user / update daily goal |
| `POST` | `/api/meals/` | Multipart: image (+ optional note) → AI-analyzed meal |
| `GET` | `/api/meals/?date=YYYY-MM-DD` | Meals for a day |
| `DELETE` | `/api/meals/{id}/` | Remove a meal |
| `GET` | `/api/stats/weekly` | 7-day totals for the history chart |

---

## 🚀 Getting started

### 1. Clone & configure

```bash
git clone https://github.com/codewithmuh/calsnap.git
cd calsnap
cp .env.example .env
```

Open `.env` and set your **`ANTHROPIC_API_KEY`** (get one at [console.anthropic.com](https://console.anthropic.com)). The meal-analysis endpoint returns a 502 until this is set.

### 2a. Run the backend with Docker (recommended)

```bash
docker compose up --build
```

API is now at **http://localhost:8008** (host ports are remapped in `.env` to avoid clashes — Postgres `5544`, Redis `6399`, web `8008`).

### 2b. Or run the backend bare-local (no Docker)

Falls back to SQLite automatically when `POSTGRES_HOST` is unset.

```bash
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python manage.py migrate
python manage.py runserver 127.0.0.1:8000
```

### 3. Run the iOS app

The Xcode project is generated with [xcodegen](https://github.com/yonaskolb/XcodeGen) from `ios/project.yml`:

```bash
cd ios
xcodegen generate
open CalSnap.xcodeproj
```

In [`ios/CalSnap/Config/AppConfig.swift`](ios/CalSnap/Config/AppConfig.swift), set `apiBaseURL`:
- **Simulator:** `http://127.0.0.1:8000` (bare-local) or `http://127.0.0.1:8008` (Docker)
- **Real iPhone:** your Mac's LAN IP, e.g. `http://192.168.1.x:8008`

Then build & run on the iOS 18 simulator or a real device.

---

## 🧠 The Claude vision prompt

The food recognition is one tightly-scoped prompt asking for strict JSON — see [`backend/meals/claude.py`](backend/meals/claude.py):

```jsonc
{
  "food":       "Grilled chicken with rice and broccoli",
  "calories":   620,
  "protein_g":  45,
  "carbs_g":    55,
  "fat_g":      18,
  "confidence": 0.82
}
```

The backend strips stray code fences, validates the shape, clamps values, and persists. If parsing fails, it surfaces a clean error instead of saving garbage.

---

## 📁 Repo layout

```
calsnap/
├── docker-compose.yml
├── .env.example
├── backend/
│   ├── config/        # Django project (settings, urls, wsgi)
│   ├── accounts/      # custom email-login User + JWT auth
│   └── meals/         # Meal model, endpoints, claude.py (vision prompt)
└── ios/
    ├── project.yml    # xcodegen spec
    └── CalSnap/       # SwiftUI app (Views, State stores, Networking, Models)
```

---

## 📚 Course & links

- 🎓 **Course:** [Learn to Build an AI Calorie Tracker iOS App with Claude](https://aiseekho.pk/courses/ios-app-with-claude) — *free on aiseekho.pk*
- 🌐 **More courses:** [aiseekho.pk](https://aiseekho.pk)
- 📺 **YouTube:** [@codewithmuh](https://youtube.com/@codewithmuh)

---

## 📄 License

MIT — see [LICENSE](LICENSE). Built for learning; use it, fork it, ship your own.

> Built with [Claude Code](https://claude.com/claude-code) · Powered by Claude vision.
