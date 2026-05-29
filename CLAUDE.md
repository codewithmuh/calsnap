# CalSnap — AI Calorie Tracker (Build Spec)

> **Single source of truth for this build.** If code or copy drifts from this, fix it.
> Built live on stream with Claude Code — SwiftUI + Django + Claude vision.

---

## 0. What we're building

**CalSnap** — snap a photo of a meal → Claude vision identifies the food + calories + macros → logs it to a daily tracker in an iOS app, synced to a Django backend.

- **One-liner:** "Snap your meal, AI counts the calories."
- **Hook:** Cal AI clone (Cal AI hit ~$30M ARR). Headline writes itself.
- **The moneyshot:** camera → Claude → calorie number appears. Everything else supports that loop.
- **Everything is powered by Claude** — keep the narrative tight (Claude Code builds it, Claude vision runs it).

---

## 1. Tech Stack (locked)

### iOS
- **Xcode 16**, iOS 18 SDK
- **SwiftUI** only — no UIKit
- **SwiftData** for local cache (offline-first feel)
- **PhotosUI** for camera + image picker
- **URLSession + async/await** for networking
- **Keychain** for JWT token storage
- **Swift Charts** for the history/trends view

### Backend
- **Django 5.x** + **Django REST Framework**
- **PostgreSQL 16** (Docker)
- **Redis 7** (Celery broker — optional, only if time)
- **Celery 5** worker for async Claude calls (OPTIONAL — do sync first)
- **Claude API** — `claude-sonnet-4-6`, vision input for food ID
- **JWT auth** — `djangorestframework-simplejwt`
- **Pillow** for image handling; local media storage for the stream (S3 is a Phase-2 nicety)
- **gunicorn** in the web container

### Infra
- **Docker Compose** for local dev
- Services: `db` (postgres), `redis`, `web` (django+gunicorn), `worker` (celery — optional)

---

## 2. Architecture

```
iOS App (SwiftUI)
    ↓ HTTPS + JWT
Django REST API
    ├── PostgreSQL  (users, meals, daily_totals)
    ├── Claude API  (vision: image → {food, calories, protein, carbs, fat})
    └── local media (meal photos)
```

### Core endpoints
| Method | Path | Purpose |
|---|---|---|
| POST | `/api/auth/register` | create account → JWT |
| POST | `/api/auth/login` | login → JWT (access + refresh) |
| POST | `/api/meals/` | multipart: image (+ optional note) → AI-analyzed meal |
| GET | `/api/meals/?date=YYYY-MM-DD` | meals for a day |
| GET | `/api/stats/weekly` | weekly totals for the dashboard chart |
| DELETE | `/api/meals/{id}/` | remove a meal |

### Data models (Django)
- **User** — use Django auth user (email login). Keep simple.
- **Meal** — `user`, `image`, `food_name`, `calories`, `protein`, `carbs`, `fat`, `note`, `created_at`
- **DailyTotal** — optional; can be computed on the fly from Meal for the stream. Don't over-build.

### Claude vision call (the content-gold moment)
- Send the meal image as a vision input to `claude-sonnet-4-6`.
- Prompt returns **strict JSON**: `{ "food": str, "calories": int, "protein_g": int, "carbs_g": int, "fat_g": int, "confidence": float }`.
- Parse, validate, persist. **Show the prompt on screen during the stream** — viewers love this.
- Keep the prompt in a single, readable file (`backend/meals/claude.py` or similar) so it's easy to show.

---

## 3. iOS Screens

1. **Onboarding** — sign up / log in
2. **Today** — calorie ring (progress vs daily goal), today's meals list, big "Snap meal" button
3. **Camera flow** — capture → "Claude analyzing…" loading → confirm/edit result → save
4. **History** — week/month view with Swift Charts
5. **Settings** — daily calorie goal, log out

The **calorie ring animating up after a meal saves** is the satisfying beat. Make it smooth.

---

## 4. Build Order (matches the live runbook)

Build in this exact order — it's sequenced so there's a demoable thing at each stage, and the wow moment lands mid-stream.

1. **Backend first**
   - Django project + `User` + `Meal` models
   - DRF endpoints + JWT auth (test with curl)
   - Claude vision endpoint: image → food + macros JSON ← *show the prompt*
2. **iOS shell**
   - SwiftUI app, tab bar, 3 main screens
   - Auth flow → token → Keychain
   - Today view: calorie ring + empty state + Snap button
3. **The magic moment**
   - PhotosUI camera capture
   - Upload to Django → Claude → result ← *slow down, this is the moneyshot*
   - Save to log, animate calorie ring
4. **Polish**
   - History screen + weekly chart
   - Loading / error / empty states
   - Run on a real iPhone, snap real food on camera

### Fallbacks if behind (in priority order)
- Skip history chart → simple list
- Skip JWT → simple API key for the demo
- Skip Docker → run Django bare locally
- Skip Celery → synchronous Claude call (this is the default anyway)

---

## 5. Conventions

- **Commit live during the stream** — viewers love watching the repo grow. Small, frequent commits.
- **`.env` for secrets** — `ANTHROPIC_API_KEY`, Django `SECRET_KEY`, DB creds. NEVER commit `.env`. Provide `.env.example`.
- **Sync over async** for the Claude call unless time allows Celery — fewer moving parts on live.
- **Strict JSON from Claude** — always validate the shape before saving; show a clean error path if parsing fails.
- **Keep the prompt readable and in one place** — it's on-screen content.
- **No premature abstraction** — this is a 4-hour live build, not a production codebase. Favor the simplest thing that demos well.

---

## 6. Pre-stream checklist (do BEFORE going live — cold start = death)

- [ ] Xcode 16 installed, Apple Developer account (free tier OK for TestFlight)
- [ ] Anthropic API key with vision access, verified working from a quick script
- [ ] `docker-compose up` tested once end-to-end
- [ ] Empty SwiftUI scaffold + Django repo skeleton already created
- [ ] OBS scenes: full screen + PiP cam + "CalSnap" lower-third
- [ ] Real plate of food ready to photograph (rice + chicken + veg = obvious macros)
- [ ] Landing page deployed (calsnap.app or calsnap.codewithmuh.com) — URL on screen whole stream
- [ ] GitHub repo created, ready to push commits live
- [ ] Pinned chat: "Source code + landing page in description ⤵"
- [ ] 30-sec finished-app demo pre-recorded FIRST (safety net if live fails)

---

## 7. Repo layout (target)

```
calsnap/
├── CLAUDE.md                 # this file
├── docker-compose.yml
├── .env.example
├── backend/
│   ├── manage.py
│   ├── requirements.txt
│   ├── Dockerfile
│   ├── config/               # django project (settings, urls, wsgi)
│   ├── accounts/             # auth, JWT
│   └── meals/                # Meal model, endpoints, claude.py (vision prompt)
└── ios/
    └── CalSnap/              # Xcode project (SwiftUI app)
```

---

## 8. Channel context (codewithmuh)

- Audience: developers + tech-curious people who want to **build with AI**. Show the build, not just talk.
- This extends the **YC clone trilogy** format (proven hit on the channel).
- Narrative: "Claude Code can now build full iOS apps." Keep everything Claude-powered.
- Follow-up planned: "Part 2 — I shipped CalSnap to the App Store."
- Full plan + runbook: `codwithmuh-assitant/output/youtube/2026-05-24-ios-app-claude-code-live/plan.md`
