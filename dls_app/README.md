# Digital Lesela Sete (DLS) - Flutter App

Current implementation status:

- Sprint 1: Complete (scanner/upload + wardrobe grid)
- Sprint 2: Complete (category tagging + filtering + item detail/edit)
- Sprint 3: Complete (Firebase auth + protected routing)
- Sprint 4: Complete (generator persistence + outfit history retrieval)
- Sprint 5: Complete (event recommendation persistence)
- Sprint 6: Complete (profile analytics + style evolution + demo data seed)
- Sprint 7: Code-based QA complete (physical device phase pending)

Detailed implementation/audit logs:

- `PROJECT_HISTORY.md`
- `AUDIT_TRACKING_PLAN.md`
- `SCREENS.md`
- `IOS_SETUP.md`
- `TOMORROW_TEST_FLOW.md`
- `FEATURE_PLANS.md`
- `PRE_GO_LIVE_CHECKLIST.md`

## Auth + Onboarding Flow (MVP)

On app launch routing now follows:

1. Not authenticated -> Login
2. Authenticated + no Firestore profile -> Onboarding
3. Authenticated + profile exists -> Dashboard

Profile document creation is intentionally delayed until onboarding completion.

## Core Features Implemented

1. Auth
- Email/password sign-up and sign-in
- Google sign-in flow
- Auth-gated navigation

2. Wardrobe
- Camera/gallery upload
- Image compression + storage upload
- Firestore metadata persistence
- Filter chips and item edit/status flow

3. Outfit Generator
- Rule-based generation from live wardrobe
- Persisted generation history (`outfit_history`)
- Recent history retrieval UI
- Optional LLM stylist enhancement (Gemini/DeepSeek) with fallback to rule engine

4. Event Planner
- Event create/list from Firestore
- Persisted recommendation payload per event

5. Profile / Style DNA
- Live metrics from user data (items, outfits, events)
- Derived style score and latest caption insight
- Style evolution log from `audit_events`

6. Dummy Data Seeding
- One-tap "Seed Demo Data" action on Profile screen
- Seeds `clothing_items`, `outfit_history`, `events`, and `audit_events`

## Tech Stack

- Flutter + Provider
- Firebase Core/Auth/Firestore/Storage
- image_picker + flutter_image_compress
- permission_handler
- intl

## Quick Start

1. Install dependencies:

```bash
flutter pub get
```

2. Configure Firebase (project id: `digital-les-sete`):

```bash
flutterfire configure
```

3. Run app:

```bash
flutter run
```

## Optional LLM Stylist Boost (Gemini or DeepSeek)

The generator now supports an optional LLM enhancement pass for better caption and reasoning quality.

No key is hardcoded in source. Configure via runtime `--dart-define` values:

```bash
flutter run \
	--dart-define=DLS_LLM_PROVIDER=gemini \
	--dart-define=DLS_LLM_API_KEY=YOUR_KEY_HERE \
	--dart-define=DLS_LLM_MODEL=gemini-1.5-flash
```

DeepSeek example:

```bash
flutter run \
	--dart-define=DLS_LLM_PROVIDER=deepseek \
	--dart-define=DLS_LLM_API_KEY=YOUR_KEY_HERE \
	--dart-define=DLS_LLM_MODEL=deepseek-chat
```

If `DLS_LLM_API_KEY` is missing or device is offline, app automatically falls back to local rule-based generation.

## Git Exposure and Ignore Hygiene

Current hygiene updates:

1. Added ignore rules for local env files: `.env`, `.env.*` (except `.env.example`).
2. Added ignore rules for ad-hoc local outputs: `*.out`, `*.err`.

Current tracked config files:

1. `android/app/google-services.json`
2. `lib/firebase_options.dart`

These are Firebase client config files (not service-account private keys). If you prefer stricter repo privacy, move to template files and inject real values outside git.

## Physical Device Testing (Android)

The environment has been prepared with:

1. Android cmdline-tools installed in local SDK.
2. Android SDK licenses accepted.
3. Android toolchain verified by `flutter doctor -v`.

If your phone still does not run the app:

1. Enable Developer options + USB debugging on device.
2. Plug in device and accept the RSA trust prompt on the phone.
3. Verify visibility:

```bash
adb devices
flutter devices
```

4. Run on device:

```bash
flutter run -d <device_id>
```

## iOS / iPhone Support

Repository-side iOS support has been prepared with:

1. `ios/Podfile` added for CocoaPods dependency installation.
2. `ios/Runner/Info.plist` updated with:
	- camera permission text
	- photo library permission text
	- Google Sign-In URL scheme
3. iOS Firebase options already present in `lib/firebase_options.dart`.

Important limitation:

1. Final iPhone/iPad validation must be done on macOS with Xcode.
2. `GoogleService-Info.plist` is still required in `ios/Runner/`.
3. Apple signing/provisioning must be configured in Xcode.

Full iOS setup and validation steps are documented in `IOS_SETUP.md`.

## Current Known External Dependencies

1. Google sign-in runtime requires Firebase OAuth/SHA setup in console.
2. Firestore/Storage rules must be configured for your target environment.
3. iOS builds require macOS + Xcode + CocoaPods for final device validation.

## Testing Follow-Up

For tomorrow's physical-device testing flow and next AI phase planning, use:

- `TOMORROW_TEST_FLOW.md`
- `FEATURE_PLANS.md`
- `PRE_GO_LIVE_CHECKLIST.md`

## Preflight Gate (Run Before Web/App Launch)

To reduce breakages after code changes, run the preflight script before `flutter run` or deploy:

```powershell
Set-Location "c:\Users\TshiamoMoloto\Documents\Git Repos\Portfilo\DLS\stitch\dls_app"
pwsh -File .\tooling\preflight_check.ps1
```

This runs:

1. `flutter analyze`
2. `flutter test`
3. `flutter build web --release`

If any step fails, stop and fix before continuing.

## Automated Test Phase (Completed in Code)

Implemented automated tests:

1. `test/services/outfit_bot_service_test.dart`
	- validates empty-clean wardrobe behavior
	- validates valid outfit generation
	- validates category alias normalization (`tshirt`, `jeans`, `shoe`)
2. `test/services/recommendation_service_test.dart`
	- validates sorted deduplicated missing-item recommendations
	- validates empty suggestions for fully covered wardrobe
3. `test/services/caption_service_test.dart`
	- validates template placeholder replacement
	- validates runtime input usage in generated captions

Run the code-based test suite:

```bash
flutter analyze
flutter test
```

## Containerised Builds (Docker)

The release toolchain is pinned in `docker/Dockerfile.dev`, which builds on
`ghcr.io/cirruslabs/flutter:3.41.6`. That tag pins Flutter to **the exact
revision the release candidate was audited on — 3.41.6 / `db50e20168`**, identical
to a developer machine, so a container build cannot silently differ from a local
one. Bump it in lockstep with the team; never switch to `latest`.

Prerequisites: Docker Desktop running (Linux containers mode).

```bash
cd docker

# Build the image once (~25 min first time: Flutter SDK + Android SDK downloads)
docker compose build

# Gate: analyze + full unit test suite
docker compose run --rm test

# Release web bundle  -> build/web/
docker compose run --rm build-web

# Release Android APK -> build/app/outputs/flutter-apk/
docker compose run --rm build-apk

# Interactive shell (codegen, flutter doctor, adb, ...)
docker compose run --rm shell
```

See `docker/README.md` for the volume map and how to extract build artifacts.
Note that `.dockerignore` intentionally stays at the project root, because
BuildKit only reads it from the build-context root.

### What is cached

| Volume | Holds | Why |
|---|---|---|
| `pub-cache` | Dart/Flutter packages | Avoids re-downloading on every run |
| `gradle-cache` | Gradle distribution + deps | The slowest part of a cold APK build |
| `android-sdk` | Platform + build-tools images | ~1 GB of downloads |
| `build-output` | `/app/build` | Keeps generated output off the Windows bind mount |
| `dart-tool` | `/app/.dart_tool` | Same reason: bind mounts are slow for many small files |

The repository itself is bind-mounted at `/app`, so edits on the host are picked
up immediately without rebuilding the image.

### Notes and caveats

- **Signing is not configured.** `build-apk` currently produces an APK signed
  with the debug key and `applicationId = com.example.dls_app`. A real upload
  keystore is required before any store submission.
- **The container runs as root** for simplicity, which avoids permission drift
  across the bind mount. Do not run untrusted code in it.
- `flutter test` inside the container is slower than on the host on Windows
  because of the bind mount. The named volumes above are what keep that
  tolerable.
- The host repo is mounted with the host's line endings. The image sets
  `core.autocrlf=input` to avoid `flutter` tripping over CRLF shell scripts.

## Remaining Phase (Physical Devices)

1. Android physical smoke test on your handset.
2. iPhone physical smoke test on macOS/Xcode (`IOS_SETUP.md`).

