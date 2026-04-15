# Pre-Go-Live Checklist (Test-Gated)

Use this checklist before release. Do not mark go-live ready until all P0 checks pass.

## A. Code and Build Gates

- [ ] `flutter pub get` succeeds
- [ ] `flutter analyze` reports no issues
- [ ] `flutter test` passes
- [ ] Android debug build succeeds (`flutter build apk --debug`)
- [ ] iOS build path verified on macOS (`pod install`, Xcode build)

## B. Auth and Routing Gates

- [ ] Launch signed-out -> Login screen
- [ ] Login success with no profile -> Onboarding screen
- [ ] Login success with existing profile -> Dashboard
- [ ] Email/password sign-up and sign-in confirmed
- [ ] Google sign-in confirmed
- [ ] Apple sign-in confirmed (if enabled for release)
- [ ] Microsoft sign-in confirmed (if enabled for release)

## C. Onboarding Gates

- [ ] First name required validation
- [ ] Last name required validation
- [ ] Display name / nickname support validation
- [ ] Gender required validation
- [ ] Birth year age range validation (13-100)
- [ ] At least one style preference validation
- [ ] Camera permission denied -> friendly snackbar (no crash)
- [ ] Gallery permission denied -> friendly snackbar (no crash)
- [ ] Profile image compressed (500px, 70%, JPEG)
- [ ] Profile image uploaded to `users/{uid}/profile.jpg`
- [ ] Firestore profile document created after onboarding submit only

## D. Data Integrity Gates

- [ ] `users/{uid}` has expected schema fields
- [ ] `clothing_items` entries scoped to current user
- [ ] `outfit_history` writes and reads successfully
- [ ] `events` writes and recommendation payloads persist
- [ ] `audit_events` entries exist for key user actions

## E. Regression Gates

- [ ] Closet upload still works
- [ ] Closet filters still work
- [ ] Outfit generator still works
- [ ] Event planner still works
- [ ] Profile metrics still work

## F. Security and Config Gates

- [ ] Firestore rules hardened for authenticated access
- [ ] Storage rules hardened for authenticated access
- [ ] OAuth client config correct in Firebase Console
- [ ] Android SHA keys configured for Google sign-in
- [ ] iOS bundle id and `GoogleService-Info.plist` match Firebase app

## G. Physical Device Gates (Manual)

- [ ] Android physical smoke test passed
- [ ] iOS physical smoke test passed (macOS + Xcode)
- [ ] Low-network behavior checked on both platforms
- [ ] No crash observed in core onboarding + dashboard path

## H. Release Decision

- [ ] All P0 gates are green
- [ ] Open risks documented and accepted
- [ ] Rollback plan prepared (previous stable build available)
- [ ] Release owner sign-off complete

## I. Publish/Update Rollout Checklist

- [ ] `pubspec.yaml` version incremented for release
- [ ] Android release artifact generated (`apk`/`aab`) and smoke-tested
- [ ] Internal test rollout completed before broad production rollout
- [ ] Existing install upgrade path tested (install over older app build)
- [ ] Existing users can open app without forced re-signup
- [ ] Email/password login re-validated after upgrade
- [ ] Google login re-validated after upgrade
- [ ] Profile image upload re-validated after upgrade
- [ ] Closet image upload re-validated after upgrade
- [ ] Calendar import re-validated after upgrade

## J. Account Preservation Gates (No Forced Re-Signup)

- [ ] No Firebase Auth user deletion operations performed for release
- [ ] Firebase project id unchanged across builds/environments
- [ ] Android `applicationId` unchanged for upgrade builds
- [ ] iOS bundle id unchanged for upgrade builds
- [ ] Token-expiry behavior confirmed (re-login prompt only when expected)

## K. Web Publish Gates

- [ ] `flutter build web` succeeds
- [ ] Hosting deploy succeeds (`firebase deploy --only hosting`)
- [ ] Browser hard refresh shows latest build assets
- [ ] Web login and upload paths validated on production URL
