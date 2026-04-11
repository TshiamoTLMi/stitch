# Digital Lesela Sete (DLS) - Flutter App

Current implementation status:

- Sprint 1: Complete (scanner/upload + wardrobe grid)
- Sprint 2: Complete (category tagging + filtering + item detail/edit)
- Sprint 3: Complete (Firebase auth + protected routing)
- Sprint 4: Complete (generator persistence + outfit history retrieval)
- Sprint 5: Complete (event recommendation persistence)
- Sprint 6: Complete (profile analytics + style evolution + demo data seed)
- Sprint 7: Next

Detailed implementation/audit logs:

- `PROJECT_HISTORY.md`
- `AUDIT_TRACKING_PLAN.md`
- `SCREENS.md`
- `IOS_SETUP.md`

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

