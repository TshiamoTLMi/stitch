# Implementation Plan: Release-readiness hardening for the existing DLS MVP

**Branch**: `001-release-readiness-hardening` | **Date**: 2026-09-26 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from [spec.md](spec.md)

## Summary

Harden the four existing release-blocker journeys without expanding the DLS product surface: reliable password recovery, next-day event guidance and reminders, readable profile analytics/style evolution, and repeatable Android/Web release evidence. The implementation extends the existing Flutter + Provider + Firebase seams, keeps deterministic local recommendations and session-local fallbacks usable offline, preserves Firebase UID ownership, and records source, manual, and external-configuration evidence separately.

The current code already contains the relevant behavior, but several paths collapse failures into success or raw/empty data: password recovery shares a global auth state and uses minimal validation; event notifications schedule one hour before an event and silently swallow failures; recommendations are unlabeled strings with no action target; and profile metrics/timeline convert unavailable data into zeroes or raw audit fields. The plan corrects those behaviors locally and adds focused tests and release documentation rather than introducing a new backend or state-management architecture.

## Technical Context

**Language/Version**: Dart 3.3+ (`sdk: '>=3.3.0 <4.0.0'`) with the repository's Flutter SDK

**Primary Dependencies**: Flutter Material, Provider 6.1.2, Firebase Core 3.13.0, Firebase Auth 5.5.0, Cloud Firestore 5.6.6, Firebase Storage 12.4.5, `flutter_local_notifications` 18.0.0, `timezone` 0.9.4, `connectivity_plus` 6.1.4, `intl` 0.19.0, existing image and OAuth packages. No new dependency is planned.

**Storage**: Firebase Auth; Firestore collections `users`, `clothing_items`, `outfit_history`, `events`, and `audit_events`; Firebase Storage user image paths. Existing in-memory wardrobe/history caches remain the offline/session fallback.

**Testing**: `flutter_test` unit/widget tests, `integration_test` on Android and Chrome, `flutter analyze`, Android debug/release builds, Web release build, and manual Firebase/device/production-Web evidence. Firebase rules and console gates require an authorized environment and are not inferred from Dart tests.

**Target Platform**: Android physical device/release candidate and production-like Web/Chrome. iOS/macOS is documented as unavailable from Windows and is not counted as Android/Web evidence.

**Project Type**: Existing single Flutter mobile/Web application with Provider coordination and Firebase services.

**Performance Goals**: Keep existing screen interactions responsive; avoid duplicate active password requests and duplicate event reminders; do not add a blocking network call for the deterministic recommendation or profile rendering path.

**Constraints**: Preserve the `SCREENS.md` UI contract and dark/gold/lime tokens; all user records and recommendations remain UID-scoped; user-facing errors must be recoverable and free of raw exception text; offline behavior must distinguish cached/stale, pending, failed, and unsaved states; no reset token, secret, or unnecessary personal data may enter logs/evidence.

**Scale/Scope**: Four P1 user stories in the existing MVP, affecting auth, home/events, profile, release documentation, and focused automated/manual validation only. No new product roadmap capability, account migration, or Firebase project/domain replacement.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle / gate | Pre-research result | Evidence and plan response |
|---|---|---|
| User-value-first incremental delivery | PASS | Four independently testable P1 stories are preserved from the feature spec; no unrelated roadmap work is included. |
| Screen and design contract | PASS | `SCREENS.md` remains authoritative. Any changed recovery, notification, recommendation, or profile state is documented before implementation is closed; existing dark layered surfaces, gold primary, lime tertiary, typography, pills, rounded cards, and no-visible-border rule remain defaults. |
| Test-gated quality and validation evidence | PASS | Plan includes focused service/widget tests, Android/Chrome integration smoke, `flutter analyze`, `flutter test`, Android builds, Web release build, and dated evidence in the audit documents. |
| Firebase security and UID scoping | PASS WITH RELEASE GATE | Existing reads/writes use the authenticated UID in the relevant services and rules. The plan audits every affected query/write and includes Firestore/Storage rule validation; Firebase Console deployment is an external owner gate. |
| Explainable and offline-tolerant recommendations | PASS | Extend `RecommendationService` into structured, reasoned guidance while retaining local deterministic logic and existing generator/history fallbacks when network or optional LLM enhancement is unavailable. |
| Observability and audit traceability | PASS | Preserve `audit_events` and add attributable outcomes for recovery, reminder/recommendation actions, analytics availability, and release evidence without secrets. Update `PROJECT_HISTORY.md` and `AUDIT_TRACKING_PLAN.md`. |
| Simplicity and maintainability | PASS | Reuse `AuthController`, `AuthService`, `EventService`, `NotificationService`, `RecommendationService`, `ProfileService`, existing views, and Provider wiring. Only narrow state/adapter seams needed for testability are allowed; no repository or new backend layer. |
| Platform/configuration constraints | PASS WITH RELEASE GATE | Android and Web are executable targets. Firebase Console settings, production hosting, physical device access, PWA installation, launcher inspection, and notification permission are explicit external/manual gates. iOS/macOS remains a documented Windows limitation. |

No constitutional violation requires an exception.

## Phase 0 Research Summary

Detailed decisions are recorded in [research.md](research.md). The research resolves all technical unknowns identified during repository inspection:

- Firebase Auth recovery remains email-link based through `AuthService`; UI state is made operation-specific and retryable in the existing auth flow.
- Android uses the existing local-notification plugin and stable event-derived identifiers; Web uses a truthful in-app upcoming-event reminder and does not claim browser delivery.
- Recommendations remain deterministic and local, but are represented with missing need, event/occasion reason, confidence/data state, and an existing wardrobe/generator action target.
- Profile metrics and audit history use explicit loading, empty, unavailable/error, stale/offline, and retry states rather than substituting zeroes for failed reads.
- Release evidence is a documented record contract, not a new persisted application entity.

## Phase 1 Design

### Data flow

1. `main.dart` initializes Firebase defensively, initializes `NotificationService`, and provides the existing service/controller graph. No new global service locator is introduced.
2. `AppRouter` continues to derive signed-out, onboarding, and authenticated shell state from `AuthController.authState` and the UID-scoped `ProfileService.hasProfile` check.
3. Login recovery validates the email locally, enters a single in-flight state, calls `AuthService.sendPasswordResetEmail`, maps Firebase/network failures to safe copy, and returns to the same signed-out route after success. Auth state changes still flow through `AppRouter`; no user/profile recreation is allowed.
4. `EventService` reads only the current user's events, identifies next-local-calendar-day events, and coordinates create/edit/delete with reminder reconciliation. `NotificationService` owns Android scheduling/cancellation; Web state is rendered by `HomeShell` from the same event stream. Reminder failures remain visible as fallback status instead of changing a successful event write into a false notification claim.
5. `RecommendationService` receives the already-synced `WardrobeController.items` and upcoming `EventModel` values, filters unsuitable/unavailable categories, and returns explainable recommendations. `DashboardPage` renders reason and action; action navigation uses existing HomeShell tabs and preserves event/occasion context where the generator supports it.
6. `ProfileService`/profile view loading gathers UID-scoped clothing, outfit, event, and audit data. The view maps each result to readable labels, chronological entries, and explicit state. Existing local history/wardrobe caches continue to serve supported offline/session information and mark it stale where freshness is unknown.
7. Automated checks validate pure mapping and state behavior. Android/Web smoke tests and manual evidence validate Firebase runtime, permissions, installability, launcher art, low-network behavior, and account preservation separately.

### Error and offline behavior

| Area | Loading | Success | Empty/partial | Error/offline | Retry/rollback |
|---|---|---|---|---|---|
| Password recovery | Disable the recovery submit action and show progress for the active request only. | Show neutral confirmation that a reset email was requested if the account exists; retain the email for retry. | Blank/malformed input is rejected before Firebase. | Map invalid/expired/action-code, throttled, network, and unknown failures to concise actionable copy; do not expose account enumeration or raw exceptions. | Re-enable submit, keep the entered email, and allow retry. No account/profile mutation occurs. |
| Event/reminder | Show event-save/reminder reconciliation progress where needed. | Persist the event first, then show platform-specific scheduled or in-app fallback status. | No upcoming events gets a clear empty state; covered wardrobe gets a covered state. | Firestore failure is not reported as “Event created”; notification permission/plugin failure leaves an in-app fallback and evidence status. | Retry event writes safely; cancel obsolete IDs on delete/date change and reconcile on login/restart. |
| Recommendations | Use existing synced wardrobe/event streams. | Render missing item, reason, and one clear action. | Distinguish covered wardrobe, missing event data, and incomplete category metadata. | Deterministic local logic remains usable without optional LLM/network; stale/unknown data is labelled. | Recompute on stream refresh; deduplicate by need/action and preserve event context. |
| Analytics/style evolution | Keep navigation stable and show a bounded loading state. | Show readable counts, style interpretation, and newest-first dated activity. | Explain no activity/partial records and how to create meaningful activity; never present failed reads as complete zeroes. | Show Firebase permission/network/data errors and stale cached values distinctly. | Provide retry without rebuilding the authenticated route or losing profile context. |

### Dependencies and release gates

**Source-controlled implementation and validation:** `lib/`, `test/`, `integration_test/`, `SCREENS.md`, `PROJECT_HISTORY.md`, `AUDIT_TRACKING_PLAN.md`, `PRE_GO_LIVE_CHECKLIST.md`, `firestore.rules`, `storage.rules`, `firebase.json`, `web/manifest.json`, `android/app/src/main/AndroidManifest.xml`, and generated launcher assets/configuration where a source correction is required.

**External/manual gates:** Firebase Auth provider/OAuth settings and authorized Web origins; Android SHA-1/SHA-256 registration; target Firestore/Storage rules deployment; production-like Web hosting URL and hard-refresh/PWA install; Android physical-device notification permission and launcher inspection; low-network toggling; upgrade installation and existing-account preservation; release-owner evidence/sign-off. iOS/macOS build and device work remains a macOS-only dependency.

### Validation strategy by story

| Story | Focused automated evidence | Runtime/manual evidence |
|---|---|---|
| 1. Account recovery | Auth controller/service error mapping and recovery widget states; extend `integration_test/auth_web_android_smoke_test.dart` for validation, progress, failure/retry, and no duplicate submit. | Android and production-like Web valid reset request, unknown/expired/offline/repeated cases, and re-login with the same account. |
| 2. Event guidance | Recommendation service reason/action/covered/unknown tests; event date/reminder identity and reconciliation tests using a narrow injectable notification boundary; widget states for Web fallback and actions. | Android permission-granted/denied/force-stopped/restart reminder checks; Web next-visit in-app reminder; event edit/delete/date-change and no-stale-reminder checks. |
| 3. Insights | Profile analytics mapping and timeline ordering/fallback tests; widget tests for loading, empty, error, stale, readable labels, and retry. | Android/Web seeded, partial, slow, offline, and permission/error checks with a non-technical tester task. |
| 4. Release evidence | Smoke harness assertions for route/core-flow checkpoints where deterministic; rules/config static checks where available. | Full Android/Web matrix, low network, PWA install, launcher icon, Firebase Console/config, deployment identity, upgrade/account preservation, and sign-off evidence. |

## Project Structure

### Documentation (this feature)

```text
specs/001-release-readiness-hardening/
├── plan.md                         # This implementation plan
├── research.md                     # Phase 0 repository and technology decisions
├── data-model.md                   # Phase 1 feature entities and state transitions
├── quickstart.md                   # Windows/Android/Web validation runbook
├── contracts/
│   ├── user-facing-state-contract.md
│   └── release-evidence.md
└── tasks.md                        # Created later by /speckit.tasks; not part of this plan
```

### Source Code (repository root)

```text
lib/
├── main.dart                         # Existing Firebase/plugin startup and Provider graph
├── app_router.dart                   # Auth/profile routing preservation
├── controllers/
│   ├── auth_controller.dart           # Recovery operation state and safe auth errors
│   └── wardrobe_controller.dart       # Existing synced/offline wardrobe cache
├── models/
│   ├── event_model.dart               # Event ownership/date/reminder inputs
│   ├── clothing_item.dart             # Category and availability inputs
│   ├── missing_item_recommendation.dart # Explainable need/reason/action value
│   └── profile_analytics_state.dart    # Readable loading/empty/error/stale state value
├── services/
│   ├── auth_service.dart              # Firebase Auth recovery call and normalization
│   ├── event_service.dart             # UID-scoped event CRUD and reminder reconciliation
│   ├── notification_service.dart      # Android schedule/cancel and platform fallback status
│   ├── recommendation_service.dart    # Deterministic explainable event guidance
│   ├── profile_service.dart            # UID-scoped profile/analytics/history reads
│   ├── outfit_history_service.dart    # Existing local + Firebase history fallback
│   ├── firebase_service.dart          # UID-scoped wardrobe upload/storage behavior
│   └── outfit_bot_service.dart        # Existing generator action target/readiness logic
├── views/
│   ├── auth/login_screen.dart          # Recovery UI states and retry
│   └── home/
│       ├── home_shell.dart             # Notification panel/Web fallback and tab navigation
│       ├── dashboard_page.dart         # Explainable recommendations and quick actions
│       ├── event_planner_page.dart     # Event/reminder status and minimal edit/delete affordances
│       ├── outfit_generator_page.dart  # Occasion/event context handoff
│       └── profile_page.dart           # Readable analytics and style evolution states
└── core/theme/app_theme.dart           # Existing visual tokens; reuse, do not redesign

test/
├── services/
│   ├── recommendation_service_test.dart # Existing tests extended for reasons/actions/states
│   ├── auth_controller_test.dart        # Recovery validation/error/retry mapping
│   ├── event_service_test.dart          # Event ownership/date/reconciliation behavior
│   ├── notification_service_test.dart   # Stable IDs, deduplication, cancellation/status mapping
│   └── profile_service_test.dart        # Analytics/timeline mapping and freshness states
└── widgets/
	├── login_recovery_test.dart         # Progress, duplicate prevention, success/failure UI
	├── dashboard_recommendation_test.dart # Reason, covered/unknown, and quick-action UI
	└── profile_insights_test.dart       # Loading/empty/error/offline readable states

integration_test/
├── auth_web_android_smoke_test.dart    # Existing auth smoke, extended for recovery states
└── release_readiness_smoke_test.dart   # Android/Web core-flow evidence checkpoints

android/app/src/main/
├── AndroidManifest.xml                 # Existing notification/permission/launcher declarations
└── res/                                # Launcher icon verification/source assets
web/
├── manifest.json                       # PWA install metadata and icons
└── index.html                          # Production Web bootstrap/deployment smoke target

firestore.rules                          # UID ownership review and emulator/console evidence
storage.rules                            # UID path hardening and legacy-path risk record
firebase.json                            # Firebase project/rules/index configuration reference
SCREENS.md                               # UI contract updates when behavior/states change
PRE_GO_LIVE_CHECKLIST.md                 # Gate matrix and blocker status
AUDIT_TRACKING_PLAN.md                   # Evidence, risks, owners, next actions
PROJECT_HISTORY.md                       # Implementation and validation history
tooling/preflight_check.ps1              # Existing Windows preflight entry point
```

**Structure Decision**: Keep the existing single Flutter project and Provider service boundaries. New code belongs beside the current owner of each behavior; tests remain split between `test/` for deterministic logic/widgets and `integration_test/` for platform/runtime flows. Firebase rules/config and release documents remain at repository root. No new application, package, API, or persistence project is introduced.

## Post-Design Constitution Check

| Gate | Result | Design evidence |
|---|---|---|
| Four stories remain independently testable | PASS | Each story has a focused source slice, automated checks, and separate manual gates in the validation table. |
| UI contract and visual language preserved | PASS | No redesign is planned. `SCREENS.md` is updated only for accepted state/action/navigation changes and existing tokens remain unchanged. |
| Provider/Firebase structure and UID scoping preserved | PASS | Existing services/controllers remain owners; all new queries/writes require the authenticated UID and rules are part of release evidence. |
| Deterministic/offline fallback preserved | PASS | Recommendation and generator logic remains local; cached wardrobe/history are retained and states distinguish stale/unsaved work. |
| Audit and test evidence complete | PASS | Audit documents, release evidence contract, focused tests, Android/Web builds, and manual gates are required before sign-off. |
| External limitations truthful | PASS | Firebase Console, production Web, physical Android, notification permissions, PWA/launcher, and iOS/macOS are explicitly separated from source validation. |
| Complexity justified | PASS | Existing dependencies and seams are reused; narrow injectable boundaries are only for deterministic reminder/auth tests. |

No unresolved clarification or constitutional exception remains.

## Complexity Tracking

No violations. No new dependency, backend, repository layer, migration, or product subsystem is proposed.
