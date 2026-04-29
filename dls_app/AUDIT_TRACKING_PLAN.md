# Digital Les Sete - Audit and Process Tracking Plan

## 1. Purpose

This document is the audit source for delivery tracking, validation evidence, and sprint governance.

Use this file to answer:
- What was planned?
- What was shipped?
- What was validated?
- What is blocked?
- What is next?

## 2. Governance Rules

1. No sprint is marked complete without validation evidence.
2. UI redesign is not allowed unless `SCREENS.md` is updated first.
3. Every sprint update must include:
   - implementation summary
   - validation evidence
   - risk status
   - next action plan
4. Firebase project naming for setup must use:
   - Display name: `digital Les Sete`
   - Project id: `digital-les-sete`

## 3. Baseline Context

- Repository: `stitch`
- Working branch for active delivery: `dev`
- Default branch: `main`
- Flutter app path: `dls_app/`
- Core history log: `PROJECT_HISTORY.md`
- Screen contract: `SCREENS.md`

## 4. Milestone Ledger

### Sprint 1 (Status: Complete)

Scope delivered:
- image capture/pick
- image compression
- Firebase Storage upload
- Firestore metadata write
- wardrobe grid display

Validation evidence:
- static analysis passed (`flutter analyze`)
- Firebase project linked via FlutterFire
- Firestore REST smoke write/delete validated

### Sprint 2 (Status: Complete)

Scope delivered:
- category tagging in upload flow
- functional closet filter chips
- item detail bottom sheet
- item category/status edit + save
- upload error retry feedback
- image load fallback

Validation evidence:
- static analysis passed (`flutter analyze`)
- Firestore update path implemented via `updateClothingItem`

### Sprint 3 (Status: Complete)

Scope delivered:
- email/password sign-up and sign-in
- Google sign-in (web popup + mobile credential)
- auth gate routing at app entry
- authenticated-only Home shell context
- profile upsert on successful auth

Validation evidence:
- static analysis passed (`flutter analyze`)
- dependency integration complete (`google_sign_in`)

Operational dependency:
- Google sign-in requires Firebase console platform setup (SHA fingerprints/OAuth config)

## 5. Requirements Traceability Matrix

| Requirement | Status | Code Reference |
|---|---|---|
| Category tagging during upload | Complete | `lib/views/upload_screen.dart`, `lib/services/firebase_service.dart` |
| Closet chips filter real wardrobe data | Complete | `lib/views/wardrobe_dashboard.dart` |
| Item detail view | Complete | `lib/views/wardrobe_dashboard.dart` |
| Item edit (category/status) | Complete | `lib/views/wardrobe_dashboard.dart`, `lib/services/firebase_service.dart` |
| Upload retry/failure feedback | Complete | `lib/views/upload_screen.dart` |
| Email/password auth | Complete | `lib/views/auth/login_signup_page.dart`, `lib/services/auth_service.dart` |
| Google sign-in | Complete | `lib/services/auth_service.dart` |
| Protected app routing | Complete | `lib/app.dart`, `lib/views/home/home_shell.dart` |
| Generator save to persistent history | Complete | `lib/views/home/outfit_generator_page.dart`, `lib/services/outfit_history_service.dart` |
| Generator history retrieval UI | Complete | `lib/views/home/outfit_generator_page.dart` |
| Event recommendation persistence | Complete | `lib/views/home/event_planner_page.dart`, `lib/models/event_model.dart` |
| Profile metrics from live user data | Complete | `lib/views/home/profile_page.dart` |
| Dummy data generation for validation | Complete | `lib/services/demo_data_service.dart`, `lib/views/home/profile_page.dart` |
| Sprint audit event trail | Complete | `lib/views/home/outfit_generator_page.dart`, `lib/views/home/event_planner_page.dart`, `lib/services/demo_data_service.dart` |

## 6. Validation Checklist Template (Per Sprint)

Use this checklist each sprint closeout.

1. Code quality
   - [ ] `flutter analyze` passes
   - [ ] no unresolved TODOs for sprint scope
2. Runtime validation
   - [ ] in-app flow tested end-to-end
   - [ ] data writes verified in Firestore
   - [ ] storage writes verified in Firebase Storage
3. Documentation
   - [ ] `PROJECT_HISTORY.md` updated
   - [ ] `SCREENS.md` updated (if behavior/contract changed)
   - [ ] this audit file updated
4. Risks
   - [ ] blockers documented with owner/action

## 7. Current Risks and Mitigations

1. Google sign-in runtime failure risk if platform credentials are incomplete.
   - Mitigation: complete Firebase Console SHA/OAuth setup before release.
2. Rules hardening risk if development rules remain permissive.
   - Mitigation: lock Firestore/Storage rules for authenticated access before production.
3. Mobile plugin build prerequisites (Windows symlink/developer mode).
   - Mitigation: enable developer mode on Windows for plugin builds.
4. iOS runtime validation cannot be completed on Windows.
   - Mitigation: finish final iPhone validation on macOS with Xcode, CocoaPods, and Apple signing.

## 8. Forward Process Plan

### Sprint 7 Plan (final pending scope)

1. Physical Android smoke validation (real handset).
2. Physical iOS smoke validation (macOS + Xcode managed hardware).
3. Release hardening after physical test outcomes.

## 9. Audit Update Procedure

At the end of every work session:

1. Append implementation delta to `PROJECT_HISTORY.md`.
2. Update sprint contract/roadmap in `SCREENS.md`.
3. Update this file with:
   - completed items
   - validation evidence
   - remaining risks
   - next action plan

This ensures full traceability for planning, review, and audit.

## 10. Sprint 3 Audit (2026-04-11)

Status: Complete

Implementation summary:
- Auth gate and protected shell flow validated in app routing.
- Email/password and Google sign-in integrations are active.
- Sign-up/login layout overflow regressions were patched and stabilized.

Validation evidence:
- `flutter analyze` -> `No issues found`.
- Runtime regressions previously seen in sign-up page were addressed.

Risk status:
- Google sign-in still depends on Firebase platform OAuth and SHA setup.

Next action plan:
- Continue with Sprint 4 generator-history integration.

## 11. Sprint 4 Audit (2026-04-11)

Status: Complete

Implementation summary:
- Introduced `OutfitHistoryService` for save + stream retrieval.
- Generator now persists caption + metadata + result score through service.
- Added recent outfit history list on the generator page (latest 5 entries).
- Added audit event logging for generated outfits.

Validation evidence:
- `flutter analyze` -> `No issues found`.
- Data path implemented from generator action to `outfit_history` collection and retrieval stream.

Risk status:
- Historical ordering relies on in-memory sort to avoid composite index blockers.

Next action plan:
- Complete event recommendation persistence and retrieval in Sprint 5.

## 12. Sprint 5 Audit (2026-04-11)

Status: Complete

Implementation summary:
- Event model expanded with `recommended_outfits` persistence.
- Event creation now stores generated recommendations at write time.
- Event screen prefers persisted recommendation payload and falls back to live generation.
- Added audit event logging for event creation.

Validation evidence:
- `flutter analyze` -> `No issues found`.
- Event stream query hardened to avoid index-precondition runtime failures.

Risk status:
- Recommendation quality depends on wardrobe data volume and clean status distribution.

Next action plan:
- Wire profile analytics and style insight to real user data in Sprint 6.

## 13. Sprint 6 Audit (2026-04-11)

Status: Complete

Implementation summary:
- Profile page now loads metrics from live Firestore user-scoped data:
   - closet item count
   - outfits logged
   - events planned
   - derived style score
- AI stylist insight now reflects computed top category + latest caption.
- Added style evolution log bottom sheet sourced from `audit_events`.
- Added one-tap demo data seeding (`DemoDataService`) for sprint validation.
- Demo seeding writes fixture data to `clothing_items`, `outfit_history`, `events`, `users`, and `audit_events`.

Validation evidence:
- `flutter analyze` -> `No issues found` after Sprint 6 changes.
- Device readiness verification:
   - Android cmdline-tools installed into local SDK.
   - Android licenses accepted via `sdkmanager --licenses`.
   - `flutter doctor -v` now reports Android toolchain healthy.

Risk status:
- Connected Android device currently appears as `unauthorized` in ADB until on-device RSA prompt is accepted.

Next action plan:
- Start Sprint 7 polish immediately after final device authorization and runtime smoke confirmation.

## 14. iOS Readiness Audit (2026-04-11)

Status: In Progress

Implementation summary:
- Added missing `ios/Podfile` to support CocoaPods dependency installation on macOS.
- Added iOS permission strings for camera and photo library usage in `ios/Runner/Info.plist`.
- Added Google Sign-In URL scheme registration in `ios/Runner/Info.plist`.
- Added iOS setup runbook in `IOS_SETUP.md`.

Validation evidence:
- Repository now contains the required iOS project metadata for permissions and CocoaPods.
- iOS Firebase options already exist in `lib/firebase_options.dart`.

Risk status:
- `GoogleService-Info.plist` is not checked into the repo and must be added on macOS.
- iOS signing/provisioning cannot be completed from this Windows environment.

Next action plan:
- Open project on macOS, run `pod install`, add `GoogleService-Info.plist`, configure signing, and execute iPhone smoke test.

## 15. Sprint 7 Code QA Audit (2026-04-11)

Status: Complete (code phase)

Implementation summary:
- Added unit tests for outfit generation logic, recommendation logic, and caption generation.
- Consolidated sprint tracking documentation to distinguish completed code validation from pending physical-device validation.

Validation evidence:
- `flutter analyze` passes.
- `flutter test` passes with service-layer coverage added under `test/services/`.

Risk status:
- Physical-device behavior (camera/gallery permissions, Google sign-in runtime, end-to-end upload path) still requires on-device smoke testing.
- iOS remains dependent on macOS/Xcode signing and `GoogleService-Info.plist` provisioning.

Next action plan:
- Execute Android physical smoke checklist.
- Execute iOS physical smoke checklist on macOS.
- Record outcomes and decide final release gate.

## 16. Web Go-Live Stabilization Audit (2026-04-23)

Status: In Progress

Implementation summary:
- Added explicit generator readiness checks so users get clear feedback when required clothing is missing.
- Added generator offline-mode UX messaging and fallback behavior so users can still generate from already-synced items.
- Added local in-memory outfit history fallback to preserve session history visibility when Firestore is unavailable.
- Updated go-live checklist with a dedicated Web Blockers Log and explicit documentation locations for progress tracking.

Validation evidence:
- Service-level readiness test added in `test/services/outfit_bot_service_test.dart`.
- Manual UX validation points captured for web blockers in `PRE_GO_LIVE_CHECKLIST.md`.

Risk status:
- Offline mode currently supports local generation and session-local history fallback, but first-load offline wardrobe sync still depends on prior successful online sync.
- Web event-reminder behavior requires explicit release decision (disable on web or implement fallback reminder strategy).

Next action plan:
- Run `flutter analyze` and `flutter test` after dependency sync.
- Execute web smoke test in Chrome with normal and offline/limited-network scenarios.
- Confirm final web go-live blocker status in `PRE_GO_LIVE_CHECKLIST.md` and append test outcomes to `PROJECT_HISTORY.md`.

## 17. LLM Integration and Exposure Audit (2026-04-23)

Status: In Progress

Implementation summary:
- Added optional hybrid AI generation enhancement via `OutfitLlmService` for Gemini/DeepSeek.
- Kept resilient baseline: existing rule engine remains active fallback if LLM is unavailable/offline.
- Updated generator UI with explicit AI enhancement status and fallback guidance.
- Added `.gitignore` coverage for local env secrets and local output artifacts.

Validation evidence:
- Static error scan passed for updated files (`outfit_llm_service.dart`, `outfit_generator_page.dart`, `.gitignore`, `pubspec.yaml`).

Risk status:
- LLM calls are client-side and require runtime API key injection; keys must not be hardcoded.
- `android/app/google-services.json` is currently tracked; acceptable for client config, but team may choose stricter template-based handling.

Next action plan:
- Run full `flutter pub get`, `flutter analyze`, `flutter test` with new dependency set.
- Execute on-device AI generation quality pass.
- Finalize repository policy decision for tracked Firebase client config files.

## 18. Regression Prevention Gate (2026-04-23)

Status: Complete

Implementation summary:
- Added reusable preflight quality gate script at `tooling/preflight_check.ps1`.
- Updated README with mandatory preflight usage before app/web runs.

Validation evidence:
- `flutter analyze` -> passed (`No issues found`).
- `flutter test` -> passed (`All tests passed`).
- `flutter build web --release` -> passed (`Built build/web`).

Risk status:
- Flutter on `C:\Program Files\flutter\bin\flutter.bat` still hangs in this environment.
- Stable command path for this workspace remains `C:\Users\TshiamoMoloto\Documents\flutter\bin\flutter.bat`.

Next action plan:
- Use `tooling/preflight_check.ps1` before every release and before physical-device smoke tests.
- Keep Flutter PATH alignment as a cleanup task to avoid accidental use of hanging SDK path.

## 19. AI Generator Grounding Audit (2026-04-29)

Status: Complete

Implementation summary:
- Strengthened `OutfitLlmService` prompt rules so AI enhancement is locked to the selected outfit pieces.
- Added optional `styling_tip` response handling and surfaced it in generator UI.

Validation evidence:
- Focused `flutter analyze` passed for `lib/views/home/outfit_generator_page.dart` and `lib/services/outfit_llm_service.dart`.

Risk status:
- AI quality still depends on runtime API key availability and network access.
- Base outfit correctness still comes from the rule engine, which is the intended safety net.

Next action plan:
- Run on-device AI generation checks with real wardrobe data.
- If quality is still too average, add personalization signals like recent liked outfits, favorite colors, and style DNA weighting into the AI prompt.