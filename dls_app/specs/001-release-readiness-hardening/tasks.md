---
description: "Concrete implementation and release-evidence tasks for release-readiness hardening"
---

# Tasks: Release-readiness hardening for the existing DLS MVP

**Input**: Design documents from `specs/001-release-readiness-hardening/`

**Scope**: Four independently testable P1 user stories covering account recovery, event guidance/reminders, profile insights, and Android/Web release evidence. Tasks preserve the existing Flutter + Provider + Firebase structure, Firebase UID ownership, deterministic/offline behavior, audit traceability, and the `SCREENS.md` contract. No new dependency or backend is planned.

**Execution rule**: Tests marked as story work are written before the corresponding implementation tasks and must fail for the missing behavior before implementation is considered complete. Manual and external gates are listed separately from source-controlled tasks and cannot be marked passed by automated source checks alone.

## Phase 1: Setup

**Purpose**: Establish the baseline and evidence vocabulary for work in the existing Flutter repository.

- [ ] T001 Confirm the existing Windows Flutter baseline with `flutter pub get`, `flutter analyze`, `flutter test`, `flutter build apk --debug`, and `flutter build web --release`, recording command scope and current results in `specs/001-release-readiness-hardening/quickstart.md`.
- [ ] T002 [P] Add deterministic shared event, wardrobe, audit, and Firebase-error fixtures for focused tests in `test/fixtures/release_readiness_fixtures.dart`, with redacted identifiers and no credentials, reset links, or tokens.

## Phase 2: Foundational

**Purpose**: Add only the shared value/state seams needed by the four stories while preserving existing Provider, Firebase, and UID-scoped ownership boundaries.

- [ ] T003 [P] Add the structured deterministic recommendation value with need, reason, event context, state, action, and dedupe key in `lib/models/missing_item_recommendation.dart`.
- [ ] T004 [P] Add explicit analytics freshness/status and readable metric/timeline state types in `lib/models/profile_analytics_state.dart`.
- [ ] T005 Verify that the planned implementation reuses the dependencies already declared in `pubspec.yaml`; document any unavoidable dependency exception in `specs/001-release-readiness-hardening/plan.md` before adding a package.
- [ ] T006 Audit affected Firestore and Storage reads/writes for authenticated UID scoping, including legacy `user_id`/`userId` compatibility, and apply only necessary rule/source corrections in `firestore.rules` and `storage.rules`; record any deployed-environment limitation in `AUDIT_TRACKING_PLAN.md`.

## Phase 3: User Story 1 - Recover account access with reliable feedback (Priority: P1) - MVP

**Goal**: Make the existing signed-out forgot-password flow validate locally, expose stable progress/success/failure/retry states, prevent duplicate requests, and preserve the same Firebase UID/profile route after recovery.

**Independent test**: Run the focused recovery unit/widget tests and the auth smoke flow, then exercise valid, malformed, blank, unknown, offline, repeated, and expired-link cases on Android and Web. Every case must end in readable recovery or retry feedback without an unhandled exception or account recreation.

### Tests for User Story 1

- [ ] T007 [P] [US1] Add `AuthController.sendPasswordReset` tests for idle, sending, success, duplicate-call prevention, Firebase/network/action-code failures, neutral anti-enumeration copy, retained email, and retry mapping in `test/services/auth_controller_test.dart`.
- [ ] T008 [P] [US1] Add login recovery widget tests for blank/malformed validation, progress-disabled submission, success confirmation, failure/retry rendering, and preserved entered email in `test/widgets/login_recovery_test.dart`.
- [ ] T009 [P] [US1] Extend the existing auth smoke test in `integration_test/auth_web_android_smoke_test.dart` to cover the recovery dialog state contract without requiring secrets or recording reset links.

### Implementation for User Story 1

- [ ] T010 [US1] Split password-recovery operation state from global sign-in loading, normalize recovery errors to concise safe messages, retain retry input, and prevent concurrent reset requests in `lib/controllers/auth_controller.dart` and `lib/services/auth_service.dart`.
- [ ] T011 [US1] Implement the full recovery dialog state flow, including strict required/malformed email validation, progress, neutral success, retryable failure/offline feedback, and expired-link guidance in `lib/views/auth/login_screen.dart`.
- [ ] T012 [US1] Verify and preserve signed-out, authenticated, onboarding, and existing-profile routing by adding only the needed recovery regression handling in `lib/app_router.dart` and `lib/services/profile_service.dart`; do not create or migrate a user record.
- [ ] T013 [US1] Document any accepted recovery dialog state or interaction change, while preserving the existing navigation and visual tokens, in `SCREENS.md`.

**Checkpoint**: Story 1 is independently testable when T007-T013 pass and the same test account can sign in after completing the reset flow.

## Phase 4: User Story 2 - Act on upcoming-event guidance (Priority: P1)

**Goal**: Reconcile next-day reminders without duplicates or stale entries, provide truthful Android/Web fallback status, and show explainable wardrobe-gap recommendations with an existing quick action.

**Independent test**: Create a next-local-day event for a test UID with an incomplete wardrobe. Focused tests must prove deterministic recommendation/reconciliation behavior, and Android/Web evidence must show the event name/date/occasion, one current Android reminder or fallback, a Web in-app reminder, and a preserved add/generate action context.

### Tests for User Story 2

- [ ] T014 [P] [US2] Extend `test/services/recommendation_service_test.dart` for structured reason/action output, unsuitable or unavailable categories, deterministic ordering, deduplication, covered state, incomplete-data state, and no-event state.
- [ ] T015 [P] [US2] Add event ownership, next-local-day selection, create/edit/delete/date-change reconciliation, duplicate source-key handling, and failed-write behavior tests in `test/services/event_service_test.dart`.
- [ ] T016 [P] [US2] Add notification tests for stable event-derived IDs, one-current-reminder behavior, cancellation, permission/unavailable/error status, Web fallback, and restart reconciliation using an injectable platform boundary in `test/services/notification_service_test.dart`.
- [ ] T017 [P] [US2] Add dashboard and notification-panel widget tests for event/date/occasion display, reason text, covered/unknown/empty states, and quick-action navigation in `test/widgets/dashboard_recommendation_test.dart`.

### Implementation for User Story 2

- [ ] T018 [US2] Replace plain-string-only recommendation output with the structured deterministic model, filter unavailable or incomplete wardrobe data honestly, and preserve offline/local operation in `lib/services/recommendation_service.dart`.
- [ ] T019 [US2] Add stable event-derived reminder identity, explicit scheduled/fallback/permission/error status, Android permission handling, and cancellation/reconciliation hooks without claiming delivery on scheduling failure in `lib/services/notification_service.dart`.
- [ ] T020 [US2] Make event persistence authoritative before reminder status, reconcile create/edit/delete/date changes and app restart, keep all queries/writes UID-scoped, and expose next-local-day event state in `lib/services/event_service.dart`.
- [ ] T021 [US2] Render recommendation reasons and one actionable wardrobe-add or outfit-generate destination, preserve supported event/occasion context, and show truthful Web in-app reminder status in `lib/views/home/dashboard_page.dart`, `lib/views/home/home_shell.dart`, `lib/views/home/event_planner_page.dart`, and `lib/views/home/outfit_generator_page.dart`.
- [ ] T022 [US2] Document accepted reminder, recommendation, quick-action, or notification-panel state changes in `SCREENS.md` without adding a top-level navigation destination or redesigning the DLS visual language.

**Checkpoint**: Story 2 is independently testable when T014-T022 pass and obsolete reminders are absent after event edits/deletes and app restart.

## Phase 5: User Story 3 - Understand wardrobe analytics and style evolution (Priority: P1)

**Goal**: Make profile metrics and style history readable, chronologically stable, honest about partial/unavailable data, usable with cached/offline data, and retryable without disturbing the authenticated shell.

**Independent test**: Use seeded, partial, empty, slow, offline, and permission-error accounts on Android and Web. A non-technical tester must identify item/outfit/event counts and latest activity without clipped text, raw audit fields, fabricated zeroes, or a dead-end state.

### Tests for User Story 3

- [ ] T023 [P] [US3] Add profile analytics mapping tests for UID-scoped collection reads, deduplicated clothing counts, valid/ unavailable style score, partial/empty/error/offline freshness, readable labels, and newest-first timeline fallbacks in `test/services/profile_service_test.dart`.
- [ ] T024 [P] [US3] Add profile widget tests for stable loading, readable metrics, empty/partial guidance, permission/data error with retry, cached/stale labeling, and style-evolution date/label/description rendering in `test/widgets/profile_insights_test.dart`.

### Implementation for User Story 3

- [ ] T025 [US3] Move profile metric and audit-history assembly behind explicit typed result/state mapping, preserve UID-scoped reads and available local/session fallback data, and distinguish loading, ready, empty, partial, error, offline, cached, and stale outcomes in `lib/services/profile_service.dart` and `lib/models/profile_analytics_state.dart`.
- [ ] T026 [US3] Update the profile experience to render readable item/outfit/event/style labels, stable layout, honest unavailable values, retryable errors, stale/offline status, and newest-first mapped style evolution entries with safe missing-field fallbacks in `lib/views/home/profile_page.dart`.
- [ ] T027 [US3] Preserve existing local/session fallback behavior and UID ownership while exposing the profile state contract through the existing Provider graph in `lib/controllers/wardrobe_controller.dart`, `lib/services/outfit_history_service.dart`, and `lib/main.dart`.
- [ ] T028 [US3] Document accepted analytics, style-evolution, loading, error, empty, offline, or retry presentation changes in `SCREENS.md` while retaining the locked shell, tokens, surfaces, typography, pills, rounded cards, and no-visible-border rule.

**Checkpoint**: Story 3 is independently testable when T023-T028 pass and a failed read is never presented as complete zero-valued analytics.

## Phase 6: User Story 4 - Validate a release candidate and preserve existing accounts (Priority: P1)

**Goal**: Produce repeatable Android/Web source, build, smoke, low-network, configuration, installability, launcher, and account-preservation evidence, with external gates clearly separated from repository checks.

**Independent test**: Run the repository checks and release smoke harness, then execute the applicable manual/external gate matrix against an Android candidate and production-like Web deployment. Every result has the release-evidence fields, and blocked checks are not reported as passed.

### Automated and source-controlled validation for User Story 4

- [ ] T029 [P] [US4] Add deterministic route/core-flow checkpoint assertions for signed-out routing, auth/onboarding, wardrobe, generator/history, events/recommendations, profile, and sign-out in `integration_test/release_readiness_smoke_test.dart`.
- [ ] T030 [P] [US4] Add source-level configuration checks for UID rule guards, notification declarations, Web manifest install metadata, and absence of prohibited secrets in `test/release_configuration_test.dart`, without treating source checks as deployed Firebase or physical-device proof.
- [ ] T031 [US4] Extend `tooling/preflight_check.ps1` to invoke the focused story tests, `flutter analyze`, `flutter test`, Android debug/release build checks, and `flutter build web --release` with safe redacted output paths.
- [ ] T032 [US4] Review and correct only release-source declarations needed for the evidence matrix in `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/res/mipmap-anydpi-v26/launcher_icon.xml`, `web/manifest.json`, `web/index.html`, and `firebase.json`; do not add console configuration or secrets to source.

### Manual and external release gates for User Story 4

These tasks are deliberately separate from source implementation. Record each result using the fields in `specs/001-release-readiness-hardening/contracts/release-evidence.md`; automated tests cannot substitute for these gates.

- [ ] T033 [US4] Execute the full Android and Web core smoke matrix, including sign-up/sign-in, onboarding, wardrobe upload/filter/edit, outfit generation/history, event creation/recommendations, profile insights/style history, and sign-out, and record platform/build/environment/result evidence in `PRE_GO_LIVE_CHECKLIST.md`.
- [ ] T034 [US4] Execute low-network and offline checks for recovery, event visibility/reminder fallback, generator/history, profile analytics, and wardrobe upload, recording completed, pending, failed, stale, or unsaved outcomes and retry behavior in `PRE_GO_LIVE_CHECKLIST.md`.
- [ ] T035 [US4] Verify the production-like Web URL, hard refresh, OAuth/reset runtime, upload path, browser limitation copy, and PWA installation flow; record browser/version/deployment identity or a blocked result in `PRE_GO_LIVE_CHECKLIST.md`.
- [ ] T036 [US4] Inspect the Android launcher icon on an authorized physical device for foreground, corner, and background appearance, and test notification permission, force-stop/restart, and one-current-reminder behavior; record device/build evidence in `PRE_GO_LIVE_CHECKLIST.md`.
- [ ] T037 [US4] Verify Firebase project identity, Auth/OAuth providers and authorized Web origins, Android SHA-1/SHA-256 keys, deployed Firestore/Storage rules, hosting deployment, and notification capability with an authorized release owner; record unavailable checks as blocked in `PRE_GO_LIVE_CHECKLIST.md`.
- [ ] T038 [US4] Install the Android candidate over the prior build and update the Web deployment, then verify the same test account UID, profile, wardrobe, outfit history, events, and audit records remain usable; record redacted evidence in `PRE_GO_LIVE_CHECKLIST.md`.
- [ ] T039 [US4] Record Windows iOS/macOS limitations as `not-applicable` or `blocked` with the macOS owner/action, and ensure they are not counted toward Android/Web readiness in `PRE_GO_LIVE_CHECKLIST.md`.

## Phase 7: Polish, Audit, and Release Evidence

**Purpose**: Close traceability, rollback, documentation, and sign-off requirements after the four stories are validated.

- [ ] T040 [P] Update `specs/001-release-readiness-hardening/quickstart.md` with the final focused test commands, build commands, evidence locations, selected reminder lead-time convention, and redaction rules.
- [ ] T041 Update `AUDIT_TRACKING_PLAN.md` with implementation status, automated evidence, manual/external gate results, UID/security findings, owners, risks, blocked checks, rollback/disablement paths, and next actions.
- [ ] T042 Update `PROJECT_HISTORY.md` with the implementation and validation delta, affected stories, evidence references, accepted risks, external dependencies, and account-preservation result; record final release-owner sign-off and disposition in `PRE_GO_LIVE_CHECKLIST.md`.

## Dependencies and Execution Order

### Phase Dependencies

- **Phase 1** has no feature dependency; it establishes the baseline and redacted test fixtures.
- **Phase 2** depends on Phase 1 and blocks story implementation because shared recommendation/profile values and ownership checks must exist first.
- **User Stories 1-4** depend on Phase 2. Their focused test tasks may be prepared in parallel across different files; story implementation remains ordered after its own tests.
- **Phase 7** depends on the completed source tasks and applicable manual/external gates from Phases 3-6.

### User Story Dependencies

- **US1** depends only on Phase 2 and is the MVP slice.
- **US2** depends only on Phase 2; it uses existing auth/provider state but is independently testable with a fixed authenticated UID.
- **US3** depends only on Phase 2; it uses existing local/session caches and UID-scoped profile reads.
- **US4** depends on completed source behavior from US1-US3 for the full matrix, but its configuration/static checks can begin after Phase 2.

### Parallel Opportunities

- T003 and T004 can run in parallel because they add separate model files.
- T007-T009 can run in parallel because they add or update separate recovery test files and precede the US1 implementation.
- T014-T017 can run in parallel because they touch separate US2 test files.
- T023 and T024 can run in parallel because they touch separate US3 test files.
- T029-T031 can run in parallel because they touch separate release-test/preflight files; T032 follows their expected configuration contract where relevant.
- Tasks that update `SCREENS.md`, `PRE_GO_LIVE_CHECKLIST.md`, `AUDIT_TRACKING_PLAN.md`, or `PROJECT_HISTORY.md` are intentionally not marked `[P]` because they share documentation surfaces and require ordered evidence.

## Implementation Strategy

### MVP First: User Story 1

1. Complete Phases 1-2.
2. Write and fail the US1 tests in T007-T009.
3. Implement T010-T012 and document the accepted UI contract in T013.
4. Validate Android/Web recovery independently, including same-account re-login, before starting broader release work.

### Incremental Delivery

1. Add US2 event guidance/reminder behavior and validate stale/duplicate reminder handling.
2. Add US3 readable analytics/style evolution and validate partial/offline/error states.
3. Add US4 automated smoke/config checks, then run the separately listed Android, Web, Firebase, PWA, launcher, low-network, and preservation gates.
4. Close audit documents, rollback/disposition, and release-owner sign-off only after every applicable evidence record is dated and owned.

## Traceability Notes

- **FR-001-FR-005** map to T007-T013.
- **FR-006-FR-011** map to T014-T022.
- **FR-012-FR-014** map to T023-T028.
- **FR-015-FR-020** map to T029-T039.
- **FR-021-FR-024** and **NFC-001-NFC-007** map across T005-T006, T013, T022, T028, T031-T042.
- The release-evidence record contract is `specs/001-release-readiness-hardening/contracts/release-evidence.md`; the user-facing state contract is `specs/001-release-readiness-hardening/contracts/user-facing-state-contract.md`.
