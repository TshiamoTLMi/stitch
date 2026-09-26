# Release evidence contract

Every applicable release gate produces one dated evidence record in the project audit process. The record may be a checklist row, test output reference, screenshot reference, or release-owner note, but it must contain the same fields.

## Required record fields

| Field | Requirement |
|---|---|
| `gateId` | Stable identifier such as `AUTH-RESET-ANDROID` or `WEB-PWA-INSTALL`. |
| `story` | One of the four feature stories or `cross-cutting`. |
| `platform` | `android`, `web`, `firebase-console`, `repository`, `macos-ios`, or `not-applicable`. |
| `environment` | Emulator/device, browser/URL, Firebase project/environment, or local repository context. |
| `buildIdentity` | APK/AAB version, Web deployment/build identifier, or `not-applicable`. |
| `testedAt` | Date/time with timezone. |
| `result` | `pass`, `fail`, `blocked`, or `not-applicable`. |
| `observedBehavior` | What was actually observed, including the tested account/data shape without unnecessary personal data. |
| `evidenceRef` | Safe path, test command/output reference, or screenshot name; never a secret or reset link. |
| `blockerOrRisk` | Empty only when no risk remains; otherwise state the exact limitation. |
| `owner` | Person/team responsible for the follow-up or sign-off. |
| `nextAction` | Required remediation, retest, accepted-risk decision, or `none`. |
| `rollbackOrDisposition` | Previous stable build/disablement path or accepted-risk/expiry note. |

## Required gate groups

| Group | Examples |
|---|---|
| Repository | `flutter pub get`, `flutter analyze`, `flutter test`, targeted story tests. |
| Build | Android debug/release artifact and `flutter build web --release`. |
| Auth/routing | Signed-out route, recovery states, same-account re-login, onboarding/profile preservation. |
| Core smoke | Onboarding, upload/filter/edit, generator/history, events/recommendations, profile, sign-out. |
| Low network | Recovery, event visibility/reminder fallback, generator/history, profile analytics, upload save/unsaved distinction. |
| Firebase configuration | Project identity, Auth providers/OAuth origins, Android SHA keys, deployed Firestore/Storage rules, notification capability. |
| Web release | Production-like URL, hard refresh, OAuth, upload, PWA install flow, browser limitations. |
| Android release | Physical notification permission/fallback, launcher icon foreground/corner/background, force-stop/restart, upgrade installation. |
| Account preservation | Existing UID and profile, wardrobe, outfit history, event, and audit records after upgrade/deployment update. |
| Sign-off | Green applicable gates, accepted risks, external dependencies, rollback artifact, release-owner approval. |

## Recording rules

- A missing device, Chrome target, production URL, Firebase Console access, permission, or deployed environment is `blocked`, not silently skipped.
- Source tests cannot mark production Firebase configuration or physical-device behavior as passed.
- iOS/macOS checks unavailable on Windows are `not-applicable` or `blocked` with the macOS owner/action; they do not count toward Android/Web readiness.
- Do not include passwords, reset tokens/links, API keys, private keys, service-account material, or unnecessary personal data.
- Update `AUDIT_TRACKING_PLAN.md` with the gate result/risk/owner and `PROJECT_HISTORY.md` with the implementation and validation delta. Update `PRE_GO_LIVE_CHECKLIST.md` when a gate changes status.