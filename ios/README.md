# CalSnap — iOS app

SwiftUI app (iOS 18). The Xcode project is generated from `project.yml` with
[xcodegen](https://github.com/yonaskolb/XcodeGen), so it is **not** committed.

## Run it

```bash
brew install xcodegen          # once
cd ios
xcodegen generate             # creates CalSnap.xcodeproj
open CalSnap.xcodeproj         # then ⌘R on a simulator
```

Or build/run headless on a simulator:

```bash
xcodebuild -project CalSnap.xcodeproj -scheme CalSnap \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

## Pointing at the backend

`CalSnap/Config/AppConfig.swift` sets `apiBaseURL`:

- **Simulator** → `http://127.0.0.1:8000` (talks to Django on your Mac). Default.
- **Real device** → change to your Mac's LAN IP, e.g. `http://192.168.1.20:8000`,
  and make sure the phone and Mac are on the same Wi-Fi.

ATS is configured to allow plain-HTTP localhost for the live build. The camera
needs a real device — the simulator falls back to the photo-library picker.

## Layout

- `Config/` — API base URL
- `Models/` — Codable DTOs (snake_case decoding)
- `Networking/` — `Keychain` (JWT) + `APIClient` (async/await)
- `State/` — `AuthStore`, `MealStore` (`@Observable`)
- `Views/` — `Auth`, `Today` (calorie ring), `Camera` (Snap flow), `History`, `Settings`
