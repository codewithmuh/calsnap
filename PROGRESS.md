# CalSnap — Build Progress (resume state)

Last updated: 2026-05-31. Building per `CLAUDE.md` (single source of truth).

## Status summary
- **Backend: DONE + verified end-to-end.** Committed as `aa32ac4`.
- **iOS: IN PROGRESS.** Core (config/models/keychain/APIClient) written. Stores + screens + Xcode project still TODO. **Nothing iOS committed yet.**

## Backend (complete, in `backend/`)
- Django 5.1 + DRF + simplejwt, custom email-login `User` (accounts) with `daily_calorie_goal`.
- `meals/claude.py` = Claude vision call (`claude-sonnet-4-6`), image→strict JSON `{food,calories,protein_g,carbs_g,fat_g,confidence}`, tolerant parse/validate. The on-screen "moneyshot" prompt lives in `SYSTEM_PROMPT`.
- Endpoints (all verified with curl, return correct status codes):
  - `POST /api/auth/register`, `POST /api/auth/login`, `POST /api/auth/refresh`, `GET/PATCH /api/auth/me`
  - `POST /api/meals/` (multipart image+note→Claude→Meal), `GET /api/meals/?date=YYYY-MM-DD`, `DELETE /api/meals/{id}/`
  - `GET /api/stats/weekly` → `{goal, days:[{date,calories,protein,carbs,fat}] x7}`
- `settings.py`: uses Postgres if `POSTGRES_HOST` set, else **SQLite fallback** for bare-local. CORS open. JWT access lifetime 7d.
- Run bare-local: `cd backend && .venv/bin/python manage.py runserver 127.0.0.1:8000` (venv at `backend/.venv`, deps installed). Migrations applied. Test user: `demo@calsnap.app` / `snap123` (goal 2200).
- `.env.example` at repo root; needs `ANTHROPIC_API_KEY` for real Claude calls (NOT set in env yet — `/api/meals/` POST will 502 until provided).
- Docker: `docker-compose.yml` (db/redis/web) + `backend/Dockerfile` present, not yet tested with `docker compose up`.

## iOS (in `ios/`, Swift/SwiftUI, target iOS 18, bundle `com.codewithmuh.calsnap`)
Scaffolding via **xcodegen** (installed, 2.44.1) — `ios/project.yml` defines target + Info.plist props (camera/photo usage strings, ATS allow-arbitrary-loads for http localhost).

### Files written so far
- `project.yml`, `Assets.xcassets` (AccentColor green, empty AppIcon), `CalSnap/CalSnapApp.swift` (@main, injects `AuthStore` via `.environment`).
- `Config/AppConfig.swift` — `apiBaseURL = http://127.0.0.1:8000` (change to Mac LAN IP for real device).
- `Models/Models.swift` — `AuthUser, Tokens, AuthResponse, Meal, DayStat, WeeklyStats` + ISO8601/date helpers. Decoder uses `.convertFromSnakeCase`.
- `Networking/Keychain.swift` — JWT access/refresh storage.
- `Networking/APIClient.swift` — `APIClient.shared`, async/await: register/login/me/updateGoal/meals(date)/weekly/deleteMeal/createMeal(multipart). Surfaces DRF `{detail}` errors; 401→`.unauthorized`.

### iOS TODO (next steps, in order)
1. **State stores** (use iOS17 `@Observable`, `@MainActor`):
   - `State/AuthStore.swift` — `isAuthenticated`, `currentUser`; `register/login/logout`; on init, if `Keychain.accessToken` exists set authed + fetch `me()`. Save tokens to Keychain on auth.
   - `State/MealStore.swift` — `todayMeals`, `consumedCalories` (sum), `weekly`; `loadToday()` (uses `DateFormatter.todayUTCString()`), `addMeal(Meal)` (insert + recompute), `deleteMeal`, `loadWeekly()`.
2. **Screens** (`Views/`):
   - `RootView.swift` — if `auth.isAuthenticated` → `MainTabView` (Today/History/Settings) else `AuthView`.
   - `Auth/AuthView.swift` — login/register toggle; email/password (+goal on register).
   - `Today/CalorieRing.swift` — animated circular trim ring (consumed vs goal, rotation -90, withAnimation). **The satisfying beat — animate up on save.**
   - `Today/TodayView.swift` — ring + today's meal list + big "Snap meal" button → presents `SnapFlowView` sheet.
   - `Camera/SnapFlowView.swift` — **the magic moment.** PhotosUI `PhotosPicker` (library) + `UIImagePickerController` representable for camera; flow: pick→preview→"Analyze with Claude" (loading)→result card (food/cals/macros/confidence)→Save→`MealStore.addMeal` + dismiss → ring animates. JPEG-compress before `createMeal`.
   - `History/HistoryView.swift` — Swift Charts bar chart of 7-day calories + goal rule line.
   - `Settings/SettingsView.swift` — edit daily goal (PATCH me), logout (clear Keychain).
3. **Generate + build**: `cd ios && xcodegen generate`, then `xcodebuild -project CalSnap.xcodeproj -scheme CalSnap -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build` (or boot sim + install). Fix compile errors. Free-tier signing OK for simulator (no team needed).

## Gotchas / notes
- Tool-output rendering in this session was flaky (delayed/batched, stray "... wait"); outputs DID eventually arrive. If resuming, trust file state.
- Background Django server may still be running (`ps aux | grep runserver`); reuse or restart.
- For the real camera→Claude demo you MUST set `ANTHROPIC_API_KEY` in `.env` (repo root) and restart the server.
- Commit cadence per CLAUDE.md: small/frequent. Backend already committed; commit iOS once it builds.
