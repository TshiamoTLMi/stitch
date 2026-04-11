# iOS Setup and Validation

This document covers the repository-side iOS support work already completed and the remaining Apple-specific steps required to run Digital Lesela Sete on iPhone and iPad.

## What Is Already Fixed In Repo

1. iOS project now includes a CocoaPods file:
   - `ios/Podfile`
2. iOS permission prompts are defined in `ios/Runner/Info.plist` for:
   - camera
   - photo library read
   - photo library add/save
3. Google Sign-In URL scheme is registered in `ios/Runner/Info.plist`.
4. iOS deployment target is aligned to `13.0`.
5. Firebase iOS options already exist in `lib/firebase_options.dart`.

## Remaining Requirements

These steps must be completed on macOS with Xcode installed.

1. Open the project on a Mac:

```bash
cd dls_app
flutter pub get
cd ios
pod install
open Runner.xcworkspace
```

2. In Xcode, set a real signing team for the `Runner` target.

3. Confirm the bundle identifier in Xcode matches the configured Firebase iOS app:
   - Current bundle id in repo: `com.example.dlsApp`

4. Download `GoogleService-Info.plist` from Firebase Console for the iOS app and add it to:
   - `ios/Runner/GoogleService-Info.plist`

5. For Google Sign-In on iOS, verify Firebase Console and Google Cloud OAuth config are enabled for the same bundle identifier.

## Build and Run on iPhone

1. Connect iPhone to the Mac.
2. Trust the Mac on the device.
3. Select the iPhone target in Xcode or via Flutter CLI.

```bash
flutter devices
flutter run -d <ios_device_id>
```

## Functional Validation Checklist

Run these checks on a physical iPhone:

| Test | Expected Result |
|---|---|
| Launch app | App opens without crash |
| Email sign-up/login | User can authenticate successfully |
| Google sign-in | Sign-in completes and returns to app |
| Camera upload | Camera permission prompt appears, capture works, item uploads |
| Gallery upload | Photo permission prompt appears, selection works, item uploads |
| Closet filters | Tops/Bottoms/Shoes/Accessories filter correctly |
| Seed demo data | Demo items, history, and events appear for current user |
| Outfit generation | Generated outfit appears with score and history entry |
| Event planner | Event saves and recommendation appears |
| Profile metrics | Counts and insight reflect seeded or live data |

## Known iOS-Specific Risks

1. Google Sign-In will fail if `GoogleService-Info.plist` is missing or mismatched.
2. Camera/gallery access will fail if the app is built without the updated `Info.plist` permission strings.
3. iOS code signing and provisioning must be configured in Xcode before installation on a real device.

## Recommendation

The repo is now prepared for iOS. Final validation should be done on a Mac with:

1. `pod install`
2. Xcode signing setup
3. real iPhone smoke test