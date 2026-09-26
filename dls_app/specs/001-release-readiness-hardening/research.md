# Research: Release-readiness hardening

## Repository findings

- The app starts in `lib/main.dart`, initializes Firebase defensively, initializes `NotificationService`, and provides `AuthService`, `EventService`, `OutfitHistoryService`, `ProfileService`, and the Provider controllers.
- `lib/app_router.dart` already protects the authenticated shell and uses the Firebase UID to decide whether onboarding is needed. Account recovery must not replace or recreate that route.
- `lib/controllers/auth_controller.dart` and `lib/services/auth_service.dart` already own email/password operations and Firebase error mapping. `LoginScreen` already contains a forgot-password dialog, but it only validates `contains('@')`, depends on shared auth loading/error state, and has no explicit retry/status contract.
- `EventService` filters user-owned current/future events and calls `NotificationService`, while `HomeShell` streams events into a notification bottom sheet. The current notification implementation schedules one hour before the event and reschedules by cancelling all notifications. It does not provide Web behavior or visible permission/failure status.
- `RecommendationService` is deterministic and local, but returns sorted strings. `DashboardPage` renders those strings without event reason or action, and `EventPlannerPage` persists generated outfit text without a structured missing-need contract.
- `ProfilePage` directly queries user-scoped Firestore collections, catches failures by returning zero-like metrics, and displays raw audit `type`/`message` fields in a timeline. Its Wardrobe Analytics action is currently a no-op. `OutfitHistoryService` and `WardrobeController` already provide local/session fallbacks that should be retained.
- Existing tests cover recommendation behavior and a minimal auth dialog validation smoke. `PRE_GO_LIVE_CHECKLIST.md`, `AUDIT_TRACKING_PLAN.md`, and `PROJECT_HISTORY.md` already identify the four release blockers and the Android/Web/external gates.
- `firestore.rules` scopes the primary collections by `userId`/`user_id`. `storage.rules` has a user-owned path plus a broad signed-in legacy `clothing_items` path; that legacy fallback is a security/release risk that must be explicitly hardened or recorded as blocked before production.

## Decision 1: Password recovery state and feedback

**Decision:** Keep Firebase email-link recovery through `AuthService.sendPasswordResetEmail`, but make the existing recovery dialog/controller flow operation-specific: validate required and malformed input locally, disable only the active recovery submission, map known Firebase/network/action-code failures to safe copy, retain the email for retry, and provide a clear success state that does not reveal account existence.

**Rationale:** This preserves the existing AuthService/AppRouter contract and Firebase account identity while fixing the observed ambiguity. Neutral success copy (“if the account exists”) satisfies the anti-enumeration requirement. A narrow injectable service boundary or subclass in tests is sufficient; a new auth repository is not.

**Alternatives considered:**

- Replacing Firebase Auth with a custom reset endpoint: rejected because it adds a backend and secret-handling surface outside the MVP.
- Showing raw `FirebaseAuthException.message`: rejected because messages can be technical, unstable, or disclose account details.
- Reusing the global auth loading state for the dialog: rejected because sign-in and recovery can race and the dialog needs its own duplicate-submit guarantee.

## Decision 2: Android reminder and Web fallback

**Decision:** Use the existing `flutter_local_notifications` plus `timezone` path for Android, with a stable event-derived notification ID, explicit permission/capability status, and reconciliation on create, event changes, delete, login, and restart. Preserve the existing one-hour-before-event convention unless release evidence approves another lead time. On Web, do not schedule a browser notification; render the next-day event in the existing in-app notification surface on the next relevant visit and state that browser delivery is unavailable/not verified.

**Rationale:** The plugin and Android manifest already exist, and stable IDs plus cancel/reschedule provide the required duplicate and stale-reminder control. An in-app Web fallback is the minimum truthful contract from the spec and is testable without browser permission/service-worker variability.

**Alternatives considered:**

- Browser notifications/service-worker scheduling: rejected for this slice because support and permission behavior are environment-dependent and not required for the minimum Web contract.
- A server-side scheduled notification service: rejected because it introduces a mandatory remote dependency and is outside the existing Firebase client MVP.
- Silently swallowing notification errors: rejected because an event write and a reminder delivery are different outcomes and the user must see the fallback status.

## Decision 3: Explainable recommendations

**Decision:** Extend the existing deterministic `RecommendationService` result from plain strings to a small structured recommendation value containing the missing/unsuitable need, event/occasion reason, data-confidence/covered state, and an action target (`wardrobe-add` or `outfit-generate`). Deduplicate by need/action and sort deterministically. Keep the existing rule logic and avoid requiring the optional LLM service.

**Rationale:** The current service is the correct ownership boundary and is already unit tested. Structured values allow `DashboardPage` and event UI to render plain-language reasons and quick actions without parsing strings. Local rules remain reliable offline and explainable.

**Alternatives considered:**

- A new recommendation model/AI service: rejected because the spec forbids a new mandatory model or remote AI dependency.
- Embedding reasons in formatted strings: rejected because actions, covered/unknown states, and widget tests would remain fragile.
- Inferring missing items from event text alone: rejected because it fabricates certainty when occasion/category data is incomplete.

## Decision 4: Analytics and style evolution states

**Decision:** Keep `ProfileService` and `ProfilePage` as owners, but introduce explicit result/state mapping around their existing UID-scoped reads. Preserve local/session data where available, mark freshness, and render stable loading, empty, partial, permission/error, offline/stale, and retry states. Map audit event types to readable labels and use a stable date/description fallback for missing fields.

**Rationale:** The current profile page already has the needed data sources; its main release defect is that failure is converted into plausible zeroes and raw fields are shown to users. A state model or equivalent typed result keeps the navigation stable and makes behavior testable without redesigning the screen.

**Alternatives considered:**

- Adding a new analytics backend/aggregation job: rejected because the current MVP data is sufficient and the slice is release hardening.
- Treating a failed read as an empty profile: rejected because it hides outages and violates evidence/readability requirements.
- Replacing the profile screen with a new dashboard: rejected by the locked `SCREENS.md` contract and out of scope.

## Decision 5: Security and external gates

**Decision:** Include source-level audits and rule changes needed to preserve UID ownership, but keep Firebase Console configuration, rules deployment, OAuth/SHA/origin setup, production hosting, physical-device checks, PWA installation, launcher inspection, and release sign-off as separately recorded external/manual gates. Do not claim those gates green from `flutter analyze` or source inspection.

**Rationale:** The constitution requires both security enforcement and truthful evidence. The repository can define and test rule source, but cannot prove the selected Firebase project, deployed rules, authorized domains, physical notification permission, or production deployment from Windows source validation alone.

**Alternatives considered:**

- Treating local source/rules files as production proof: rejected because deployed Firebase configuration can differ.
- Adding automatic account/data migration: rejected because existing users and records are authoritative and migration is explicitly out of scope.
- Counting iOS work as complete from Windows: rejected by the project constitution and feature spec.

## Resolved assumptions

- Android and Web are the executable release targets for this feature.
- “Next-day reminder” uses the existing one-hour-before-event lead time unless the release owner changes and records the selected convention.
- Web minimum behavior is an in-app reminder, not browser notification delivery.
- Release evidence records test-account identifiers only in a redacted/non-sensitive form; no reset links, tokens, credentials, or unnecessary personal data are stored.
- No additional pub dependency is required by the current design.