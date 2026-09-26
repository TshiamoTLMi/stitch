# Quickstart: Release-readiness validation

This runbook is for the existing Windows development environment and separates reproducible repository checks from Firebase Console, physical-device, production-Web, and macOS-only gates.

## Prerequisites

- Windows with Flutter and Android SDK available on PATH or via the repository's established Flutter installation.
- Repository root: `dls_app/`.
- For runtime checks: a non-production test account and a Firebase project/environment authorized by the release owner.
- For Android checks: an authorized physical device or emulator; physical-device evidence is required for notification, launcher, and upgrade gates.
- For Web checks: Chrome and a production-like deployed URL for OAuth, reset email, PWA, hard refresh, upload, and low-network validation.
- Do not put credentials, reset URLs, tokens, or private keys in commands, screenshots, or evidence.

## Repository checks

Run from the repository root in PowerShell:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter build web --release
```

Expected outcome: dependency resolution succeeds, analysis has no new issues, all unit/widget tests pass, the Android debug artifact builds, and the Web release artifact builds.

Run the existing focused auth smoke test on Chrome:

```powershell
flutter test integration_test/auth_web_android_smoke_test.dart -d chrome
```

Run it on an authorized Android target after checking available devices:

```powershell
flutter devices
flutter test integration_test/auth_web_android_smoke_test.dart -d <android-device-id>
```

The implementation phase should add focused service/widget tests under `test/` and extend the nearby integration smoke coverage for the four stories. Run those targeted files first, then repeat the full commands above.

## Story 1: Account recovery

1. Start signed out and confirm `AppRouter` shows the existing login surface.
2. Open Forgot password with blank and malformed values; confirm no Firebase request is attempted and a correction message remains in the dialog.
3. Submit repeatedly while the first request is active; confirm one request state, disabled submit, and no duplicate completion.
4. With a valid test account on Android and the production-like Web URL, submit a reset request and record neutral success/failure feedback. Never record the reset email or link.
5. Exercise unknown account, offline/low-network, throttled/rejected, expired/used link, and retry paths. Confirm no raw exception, crash, dead-end, or lost email input.
6. Complete the reset externally and sign in again. Confirm the same account UID/profile/data route is used and no onboarding record is recreated.

## Story 2: Event guidance and reminders

1. Use a test account with known wardrobe gaps and create an event for the next local calendar day.
2. Confirm the event card includes name, date, occasion, recommendation reason, and a relevant add/generate action.
3. On Android, test permission granted, denied/revoked, app restart, force-stop, and repeated refresh. Record whether exactly one current reminder is scheduled or a visible fallback is shown. Record the selected one-hour lead time.
4. Edit/date-change/delete a test event and confirm obsolete reminders are cancelled and the current event is authoritative.
5. On Web, reload or revisit the deployed app and confirm the in-app next-day reminder appears. Confirm copy does not claim browser notification delivery.
6. Test covered wardrobe, incomplete occasion/category data, no upcoming events, duplicate imported events, and offline refresh. Confirm covered/unknown/empty states are distinct and actionable.

## Story 3: Analytics and style evolution

1. Seed or create a test account with wardrobe items, outfit history, events, and audit activity using the existing demo-data path where appropriate.
2. Open Profile / Style DNA on Android and Web. Confirm item, outfit, event, and style labels are readable without clipped text or raw abbreviations.
3. Open the style evolution view. Confirm newest-first order, readable dates, mapped activity labels, concise descriptions, and fallbacks for missing optional fields.
4. Repeat with empty and partial accounts. Confirm the UI explains unavailable/empty activity rather than showing failed reads as complete zeroes.
5. Simulate slow/offline access and a permission/data error. Confirm stable loading, stale/cached labeling where data exists, retry action, and preserved navigation.

## Story 4: Release evidence and account preservation

Use the matrix in [contracts/release-evidence.md](contracts/release-evidence.md) and record one row per applicable gate.

1. Run the signed-out route, sign-up/sign-in, onboarding, wardrobe upload/filter/edit, outfit generation/history, event/recommendation, profile metrics/style history, and sign-out flow on Android and Web.
2. Run low-network checks for recovery, event visibility, generator/history, profile analytics, and wardrobe upload. Record completed, pending, failed, stale, or unsaved outcomes explicitly.
3. Verify `web/manifest.json`, install the PWA from the production-like URL, and record browser/version/URL/build identity. A local build is not production deployment evidence.
4. Inspect the Android launcher icon on a physical device and record the device/build identity and foreground/corner/background result.
5. Install the Android candidate over the prior build and update the Web deployment. Confirm an existing test account retains sign-in, profile, wardrobe, outfit history, event, and audit data.
6. Separately verify Firebase project identity, Auth providers/OAuth origins, Android SHA keys, deployed Firestore/Storage rules, hosting deployment, and notification capability. Mark inaccessible gates `blocked`, never `pass`.
7. Record rollback artifact/previous stable build, accepted risks, remaining external dependencies, owner, and release sign-off.

## Windows limitation

iOS build/device validation, CocoaPods, signing, and final Apple Firebase configuration remain macOS-only. Record them as not applicable or blocked for this Windows run; do not count them as Android or Web evidence.

## Repository validation recorded (2026-09-26)

The following checks passed in the Windows workspace:

```text
flutter pub get                 passed
flutter analyze                 passed
flutter test                    passed (42 tests)
flutter build apk --debug       passed
flutter build apk --release     passed
flutter build web --release     passed
focused story tests             passed
```

The reminder convention remains one hour before the event. Android delivery still requires
physical-device permission and scheduling evidence; Web uses the in-app next-day fallback.
Production Firebase configuration, deployed rules, production-like Web behavior, PWA install,
low-network behavior, account preservation, and iOS/macOS validation remain external gates.