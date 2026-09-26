# Feature Specification: Release-readiness hardening for the existing DLS MVP

**Feature Branch**: `001-release-readiness-hardening`

**Created**: 2026-09-26

**Status**: Draft

**Input**: User description: "Release-readiness hardening for the existing DLS MVP"

## Scope and Intent

Digital Lesela Sete has an implemented MVP spanning authentication and onboarding, wardrobe upload/filter/edit, outfit generation and history, event persistence, profile analytics and style evolution, and demo seeding. This feature closes the remaining release blockers that can prevent an existing user from recovering access, understanding upcoming-event guidance, reading their personal insights, or using the Android and Web release candidates with confidence.

This is a release-hardening slice, not a new product roadmap. Work is limited to the four independently testable user journeys below, the smallest behavior corrections needed to make those journeys reliable, and the validation evidence and documentation required by the project audit process.

### In Scope

- Reliable forgot-password behavior and actionable authentication feedback on Android and Web.
- Next-day event reminders with a platform-appropriate user-visible fallback.
- Actionable "You might need" recommendations connected to event context and wardrobe actions.
- Readable wardrobe analytics and style evolution history for non-technical users.
- Android and Web release smoke tests, low-network checks, PWA install-flow validation, launcher icon verification, and account-preservation checks.
- Evidence updates in `PROJECT_HISTORY.md` and `AUDIT_TRACKING_PLAN.md`; updates to `SCREENS.md` whenever behavior, layout, navigation, or tokens change.

### Out of Scope

- New wardrobe, generator, event, or profile product capabilities beyond the release blockers listed above.
- A new recommendation model, a mandatory remote AI service, or a redesign of the existing DLS visual language.
- iOS device/build validation on Windows. iOS remains a documented macOS-only caveat.
- Firebase Console configuration changes, OAuth credential creation, Android SHA registration, authorized Web origins, or production rules deployment as code tasks. These are explicit release dependencies and must be validated by an appropriately authorized release owner.
- Forced account migration, account deletion, Firebase project replacement, application identifier replacement, or domain replacement.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Recover account access with reliable feedback (Priority: P1)

As an existing DLS user who cannot remember my password, I want to request a password reset and receive clear progress, success, and failure feedback so that I can regain access without a crash or uncertainty about whether the request worked.

**Why this priority**: Account recovery is a release blocker and a prerequisite for retaining existing users. A broken recovery path can strand otherwise valid accounts and creates avoidable support burden.

**Independent Test**: On a release candidate, run the forgot-password journey independently on Android and Web using a test account, including valid, malformed, unknown, blank, offline, and repeated requests. The journey passes when every case ends in a readable, recoverable state and the valid request produces the expected reset-email outcome without a runtime exception.

**Acceptance Scenarios**:

1. **Given** a signed-out user is on the existing login screen, **when** they submit a valid account email for password recovery, **then** the app shows progress, prevents duplicate submission while the request is active, and shows a clear confirmation after the request completes.
2. **Given** a user enters a blank or malformed email, **when** they submit the recovery form, **then** the app explains the correction needed, does not send a request, and keeps the user on the recovery flow.
3. **Given** the recovery service rejects a request or the device has no usable network, **when** the user submits the form, **then** the app shows a human-readable error with a retry action and does not crash or discard the entered email unnecessarily.
4. **Given** a valid recovery request has completed, **when** the user returns to sign in after resetting the password, **then** the existing account remains available and the normal authenticated routing path is preserved.
5. **Given** a user is already authenticated or has an existing profile, **when** the authentication state changes during recovery or re-login, **then** routing does not force an unnecessary new account or onboarding record.

### User Story 2 - Act on upcoming-event guidance (Priority: P1)

As a DLS user with an upcoming event, I want to be reminded at the right time and see practical wardrobe guidance with a clear reason and a quick action so that I can prepare an outfit instead of discovering a missing item too late.

**Why this priority**: Event planning is already persisted in the MVP, but the release checklist identifies reminders and "You might need" guidance as remaining blockers. These behaviors turn stored event data into useful, timely action.

**Independent Test**: Create a test event for the next day with a known occasion and an incomplete wardrobe. Verify the event appears as upcoming, the reminder contract is honored on Android and Web, the recommendation explains its reason, and the user can navigate directly to a relevant wardrobe or generator action without manually reconstructing context.

**Acceptance Scenarios**:

1. **Given** an authenticated user has an event scheduled for the next calendar day, **when** the event is saved or the app evaluates upcoming events, **then** the user receives an upcoming-event reminder according to the active platform contract and can identify the event, date, and occasion.
2. **Given** the user is on Android and notification permission is available, **when** an event is scheduled for the next day, **then** a local reminder is scheduled once, is attributable to that event, and does not create duplicate reminders after refresh or app restart.
3. **Given** the user is on Web, **when** an event is scheduled for the next day, **then** the app shows an in-app upcoming-event reminder on the next relevant app visit and clearly communicates any Web notification limitation; the user is not told that a browser notification was delivered when it was not.
4. **Given** an event context exposes a wardrobe gap, **when** the user views "You might need" guidance, **then** each recommendation states what is missing and why it fits the occasion or event context.
5. **Given** a recommendation is shown, **when** the user selects its quick action, **then** the app opens the appropriate wardrobe-add or outfit-generation path with the event context preserved where supported.
6. **Given** an event has no wardrobe gap or has insufficient event data, **when** the user views its guidance, **then** the app shows a useful covered-state or missing-information message instead of an empty, misleading, or fabricated recommendation.
7. **Given** the user has no upcoming events, **when** they open the relevant event or home surface, **then** the app shows a clear empty state and does not schedule or display stale reminders.

### User Story 3 - Understand wardrobe analytics and style evolution (Priority: P1)

As a DLS user, I want my wardrobe metrics and style evolution history to be readable at a glance, with plain-language labels and meaningful empty, loading, error, and offline states, so that I can understand how my style activity is changing without interpreting raw data.

**Why this priority**: Profile analytics and style evolution are implemented but remain a release blocker because unreadable insights reduce trust in the core MVP value and can hide data-loading failures.

**Independent Test**: Use a test account with seeded and partial data, then open the Profile / Style DNA experience on Android and Web in online, slow, offline, empty, and error conditions. A passing experience lets a non-technical tester identify the key counts and the latest style activity without clipped text, unexplained abbreviations, or an unrecoverable state.

**Acceptance Scenarios**:

1. **Given** an authenticated user has wardrobe items, generated outfits, and planned events, **when** they open Profile / Style DNA, **then** the primary metrics are readable, visibly associated with their labels, and expressed in language a non-technical user can understand.
2. **Given** a user has style activity in the audit-backed history, **when** they open the style evolution view, **then** entries appear in an understandable chronological order with a readable date, activity label, and concise description.
3. **Given** a user has no history or only partial profile data, **when** they open analytics or style evolution, **then** the app explains what is unavailable and how to create meaningful activity, without displaying misleading zeroes as if the data were complete.
4. **Given** analytics data is loading or temporarily unavailable, **when** the user remains on the screen, **then** the app shows a stable loading or error state with a retry action and preserves the surrounding navigation.
5. **Given** the device has low or no network access but has previously available data, **when** the user opens the profile experience, **then** the app remains usable with cached or local information where available and clearly labels data that may be stale.
6. **Given** the feature requires a visual or interaction change to the locked profile contract, **when** that change is accepted, **then** the corresponding screen structure, tokens, and states are documented in `SCREENS.md` before implementation is treated as complete.

### User Story 4 - Validate a release candidate and preserve existing accounts (Priority: P1)

As a release owner, I want repeatable Android and Web smoke evidence covering authentication, core MVP flows, offline behavior, installability, security configuration, and account preservation so that I can make a release decision from documented evidence rather than assumptions.

**Why this priority**: The remaining blockers include platform smoke tests, PWA installation, launcher icon verification, low-network behavior, Firebase configuration, and upgrade/account preservation. These are release gates across the whole MVP and cannot be inferred from unit tests alone.

**Independent Test**: Execute the release evidence matrix against an Android release candidate and the production-like Web deployment, record pass/fail/blocked results with environment and date, and confirm that a pre-existing test account and its user-owned records remain available after an upgrade or redeploy.

**Acceptance Scenarios**:

1. **Given** the release candidate is built for Android and Web, **when** the release smoke flow is executed, **then** it covers signed-out routing, sign-up/sign-in, onboarding, wardrobe upload/filter/edit, outfit generation/history, event creation/recommendations, profile metrics, and sign-out without an unhandled crash.
2. **Given** Android and Web integration smoke tests are run, **when** a check passes, fails, or is blocked by environment access, **then** the evidence records the target platform, build or deployment identity, test date, observed result, and follow-up owner or reason.
3. **Given** the app is used with low or unavailable network access, **when** a user opens a supported core flow or submits an action, **then** the app communicates the degraded state, avoids data loss where practical, offers retry or recovery, and does not present unsaved work as completed.
4. **Given** a supported Web deployment is available, **when** a tester follows the browser or install prompt path, **then** the PWA install experience is either verified as successful or documented as a release blocker with the exact environment and observed limitation.
5. **Given** an Android release candidate is installed on a physical device, **when** the launcher icon is inspected from the device launcher, **then** the icon has the intended foreground, corner, and background appearance without the known visual defect.
6. **Given** a pre-existing account has wardrobe, history, event, profile, and audit data, **when** the release candidate is installed over the prior build or the Web deployment is updated, **then** the account remains usable without forced re-sign-up and its user-owned data remains associated with the same account.
7. **Given** Firebase rules, OAuth settings, Android SHA keys, and Web authorized origins are not verifiably configured, **when** release readiness is reviewed, **then** the affected gate is marked blocked or at risk and is not represented as passed based only on source code inspection.
8. **Given** all applicable Android and Web gates are complete, **when** the release owner reviews the evidence, **then** the release decision lists green gates, accepted risks, remaining external dependencies, rollback readiness, and sign-off status.

### Edge Cases

- A password-reset request is submitted repeatedly before the first response returns; only one active request is allowed and the user receives stable feedback.
- The email is syntactically valid but does not identify an account; the message must not expose unnecessary account-enumeration detail and must remain actionable.
- A password-reset link is opened after it expires or has already been used; the user receives a recovery instruction rather than a crash or dead end.
- A next-day event is edited, deleted, duplicated, or moved to a different date; obsolete reminders must not continue to fire and the current event state must be authoritative.
- An event crosses midnight, daylight-saving changes, or a device time-zone change; reminder behavior must use the event's intended local date and document any platform limitation.
- Notification permission is denied, revoked, unavailable, or the app is force-stopped; Android must provide an in-app fallback or clear status rather than claiming delivery.
- Web storage, browser notification, or install support is unavailable; the app must retain the in-app reminder contract and explain the limitation.
- A wardrobe does not contain the category needed for an event, contains only unavailable or in-wash items, or has incomplete category metadata; recommendations must remain honest and actionable.
- Recommendation data is duplicated or stale after an event refresh; the user must not see duplicate actions or contradictory missing-item guidance.
- Analytics contain zero, partial, delayed, or malformed records; the screen must remain legible and distinguish no activity from unavailable data.
- A style-history entry has no optional caption or metadata; the timeline must use a stable fallback label and date rather than showing blank or raw field names.
- A release smoke test loses network during an upload, event save, or password request; the app must show whether the action completed, failed, or needs retry and must avoid unsafe duplicate submission.
- A user opens a release candidate with an expired session; re-authentication may be requested, but the app must not delete or recreate the account.
- Firebase rules or OAuth configuration differs between environments; evidence must identify the environment and prevent a local green result from being reported as production readiness.
- Android physical-device authorization, Chrome availability, or production Web deployment access is missing; the check is blocked with evidence, not silently skipped.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The authentication recovery journey MUST be reachable from the existing signed-out login experience on Android and Web.
- **FR-002**: The recovery journey MUST validate required and malformed email input before sending a request and MUST provide a correction message that a non-technical user can act on.
- **FR-003**: The recovery journey MUST expose distinct progress, success, failure, and retry states and MUST prevent ambiguous duplicate submissions while a request is active.
- **FR-004**: Recovery failures, expired or already-used recovery links, and low-network conditions MUST end in a recoverable user-visible state without an unhandled runtime error.
- **FR-005**: Successful recovery and subsequent sign-in MUST preserve the existing account identity, profile state, and normal authenticated routing behavior.
- **FR-006**: The event experience MUST identify events occurring on the next local calendar day and MUST present the event name, date, and occasion in the reminder experience.
- **FR-007**: On Android, the event experience MUST schedule at most one next-day local reminder per event when notification capability and permission are available, and MUST provide a visible fallback status when they are not.
- **FR-008**: On Web, the event experience MUST provide an in-app upcoming-event reminder on the next relevant app visit and MUST state any browser-notification limitation accurately.
- **FR-009**: Reminder state MUST respond to event creation, edit, deletion, date changes, duplicate prevention, and app restart without leaving stale or contradictory reminders.
- **FR-010**: "You might need" guidance MUST identify each missing or unsuitable wardrobe need, explain its relationship to the selected event or occasion, and distinguish a covered wardrobe from an unknown or incomplete one.
- **FR-011**: Each actionable recommendation MUST offer a clear next action that opens the relevant wardrobe-add or outfit-generation path, with event context preserved where the existing experience supports it.
- **FR-012**: Wardrobe analytics MUST present the existing item, outfit, event, and style measures with readable labels, stable layout, and plain-language interpretation appropriate for non-technical users.
- **FR-013**: Style evolution MUST present available activity in understandable chronological order with readable dates, labels, descriptions, and safe fallbacks for missing optional data.
- **FR-014**: Analytics and style evolution MUST provide explicit loading, empty, permission or data error, offline, stale-data, and retry states appropriate to the available data.
- **FR-015**: Release smoke validation MUST cover the implemented authentication, onboarding, wardrobe, generator, event, profile, and sign-out journeys on Android and Web.
- **FR-016**: Release evidence MUST record platform, environment or deployment identity, build identity where applicable, date, test result, observed behavior, and blocker or follow-up owner for every required gate.
- **FR-017**: Low-network validation MUST cover at least authentication recovery, event/reminder visibility, outfit generation/history visibility, profile analytics visibility, and wardrobe upload behavior, including a clear distinction between completed and unsaved actions.
- **FR-018**: The release validation MUST include Web PWA installation-flow verification and Android launcher icon verification on the applicable target environments.
- **FR-019**: Account-preservation validation MUST confirm that an existing user can continue using the same account after an Android upgrade installation or Web deployment update, without forced re-sign-up or loss of user-owned data.
- **FR-020**: Firebase rules, OAuth provider configuration, Android SHA keys, Web authorized origins, production deployment, and notification capability MUST be treated as explicit release dependencies whose status is recorded as verified, blocked, or not applicable; source code alone MUST NOT mark them green.
- **FR-021**: Any accepted change to screen structure, navigation, layout, tokens, or interaction states MUST be reflected in `SCREENS.md` before the behavior is considered complete.
- **FR-022**: The implementation and validation delta MUST update `PROJECT_HISTORY.md` and `AUDIT_TRACKING_PLAN.md` with what changed, evidence collected, risks, blocked checks, and next actions.
- **FR-023**: The feature MUST preserve existing user scoping and authenticated ownership for profiles, wardrobe items, outfit history, events, recommendations, and audit events; recovery, reminders, recommendations, and analytics MUST NOT expose another user's data.
- **FR-024**: The feature MUST preserve the existing DLS design contract from `SCREENS.md`, including the current navigation, dark layered surfaces, typography, primary and tertiary accents, pill controls, rounded cards, and no-visible-border rule, unless a documented contract update is approved.

### Nonfunctional Constraints

- **NFC-001**: The release candidate MUST remain usable on the supported Android and Web targets without an unhandled crash in the affected journeys.
- **NFC-002**: User-facing messages MUST be concise, readable at supported screen sizes, free of raw exception text, and understandable without Firebase or engineering terminology.
- **NFC-003**: The feature MUST remain tolerant of absent optional network enhancement services; core recommendations and user feedback MUST not require a remote AI service to operate.
- **NFC-004**: Validation MUST distinguish automated code checks, Android physical-device evidence, Web browser or production evidence, and external configuration evidence.
- **NFC-005**: Secrets, private keys, service-account credentials, reset tokens, and unnecessary personal data MUST NOT appear in source, logs, screenshots, test artifacts, or audit documentation.
- **NFC-006**: Any behavior change MUST have a documented rollback or disablement path appropriate to the affected release gate, especially for reminders and external configuration.
- **NFC-007**: iOS checks MUST be labelled as unavailable on Windows and MUST NOT be counted as passed Android or Web evidence.

### Key Entities

- **User Account**: The existing authenticated identity and its profile state. It remains stable across password recovery, app upgrade, and Web deployment updates.
- **Password Recovery Request**: A user-initiated recovery attempt with input state, outcome, retry state, and time-bound recovery status. It must not retain or expose reset secrets in application data or evidence.
- **Event**: A user-owned planned occasion with a local date, name, occasion, recommendation context, and reminder status.
- **Event Reminder**: The user-visible reminder state associated with one event, including platform, scheduled or fallback status, and whether it is current after event changes.
- **Wardrobe Item**: A user-owned clothing record with category, availability/status, and metadata used to determine event needs.
- **Missing-Item Recommendation**: An explainable, user-owned suggestion describing a wardrobe gap, its event or occasion reason, and a quick action destination.
- **Outfit History Entry**: A user-owned generated outfit record used for activity counts and style evolution context.
- **Analytics Summary**: A readable presentation of user-owned wardrobe, outfit, event, and derived style measures, including freshness and availability state.
- **Style Evolution Entry**: A user-owned chronological activity record with a date, label, description, and optional metadata or caption.
- **Release Evidence Record**: A traceable validation result containing gate, target, environment, build or deployment identity, date, result, observed behavior, risks, and follow-up ownership.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In release-candidate testing, 100% of valid forgot-password requests on Android and Web reach a clear success or explicitly documented external-service failure state without an unhandled runtime error.
- **SC-002**: In release-candidate testing, 100% of invalid, unknown, offline, repeated, and expired-recovery cases provide a readable next action or retry path without losing the user to a dead-end screen.
- **SC-003**: For a next-day test event, 100% of Android runs with notification permission either deliver one attributable local reminder or show a documented fallback state, and 100% of Web runs show the in-app reminder contract without falsely claiming browser delivery.
- **SC-004**: At least 90% of task-based testers can identify what is missing for a selected event and reach the relevant add-or-generate action within 60 seconds without additional explanation.
- **SC-005**: At least 90% of task-based testers can correctly identify the wardrobe item count, outfit count, event count, and latest style activity from the Profile / Style DNA experience within 60 seconds.
- **SC-006**: Across the required Android and Web smoke matrix, all applicable core MVP journeys complete without an unhandled crash; every failed or blocked check has an owner, reason, and next action recorded.
- **SC-007**: Low-network validation produces an explicit state for 100% of tested affected actions, distinguishing completed, failed, pending, stale, or retry-required work from silent failure.
- **SC-008**: A pre-existing test account retains sign-in access and its user-owned profile, wardrobe, outfit history, event, and audit data in 100% of tested Android upgrade and Web deployment-update runs.
- **SC-009**: The release evidence set contains a dated result for every applicable pre-go-live gate covering automated checks, Android, Web, Firebase configuration, PWA installation, launcher icon verification, low-network behavior, and account preservation before release sign-off.
- **SC-010**: No accepted UI behavior change is released without a corresponding `SCREENS.md` update, and no implementation-status or validation change is closed without corresponding audit updates in `PROJECT_HISTORY.md` and `AUDIT_TRACKING_PLAN.md`.

## Assumptions

- The existing Firebase Auth, Firestore, Storage, audit-event, event, recommendation, analytics, and style-history contracts remain the starting point and are extended only where required to close a listed blocker.
- The release target is Android plus Web. Android physical-device validation and a production-like Web deployment are available before final sign-off.
- Android local notifications are the preferred next-day reminder mechanism when the platform and user permission support them. Web uses an in-app reminder fallback as the minimum release contract; browser notifications are not assumed to be available or reliable.
- Reminder timing uses the user's local calendar and the event's intended local date. Exact notification lead time may follow the existing platform convention, but the selected value must be recorded in validation evidence.
- Recommendations may use the existing deterministic wardrobe/event logic when optional remote enhancement is unavailable, and must explain low-confidence or incomplete-data states rather than inventing certainty.
- Existing authentication provider settings, rules, authorized origins, Android SHA keys, production deployment access, and notification permissions are controlled outside the source repository and require release-owner verification.
- Existing users and their data are authoritative. No migration that deletes, recreates, or silently reassigns accounts is permitted for this feature.
- `SCREENS.md` remains the authoritative UI and token contract. Any deliberate change to it is part of the feature's documentation and review scope.
- Automated unit, widget, and integration checks can validate repeatable behavior, but physical-device, browser, install, launcher, low-network, and Firebase Console checks require manual or environment-specific evidence.
- iOS remains outside this feature's executable validation scope on Windows; its status is recorded as a macOS dependency and not used to claim Android or Web readiness.

## Dependencies and Release Gates

- Firebase project identity, Auth provider enablement, OAuth client configuration, Android SHA registration, Web authorized origins, Firestore rules, and Storage rules must be verified in the target release environment.
- An authorized Android physical device is required for notification, launcher icon, upgrade, and device smoke evidence.
- A production-like Web URL is required for forgot-password runtime verification, Web OAuth, PWA installation, hard-refresh behavior, upload behavior, and low-connectivity checks.
- The release owner must have access to the evidence locations and approve any accepted risk, blocked external dependency, rollback plan, and final release decision.
- Existing `PRE_GO_LIVE_CHECKLIST.md`, `AUDIT_TRACKING_PLAN.md`, `PROJECT_HISTORY.md`, and `SCREENS.md` are governing release and traceability artifacts for this feature.

## Deliberate Scope Decisions

- This specification treats release-readiness hardening as four P1 slices so account recovery, event guidance, readable insights, and evidence collection can be implemented and validated independently.
- Android and Web are the only executable target platforms in this slice. iOS is explicitly documented as a macOS-only caveat rather than represented by unexecutable Windows tasks.
- Web reminders require an in-app fallback with truthful messaging. This keeps the user journey testable without depending on browser notification permissions or service-worker behavior.
- Firebase Console, physical-device, production-hosting, and release-owner actions are represented as dependencies and evidence gates. They are not disguised as source-code requirements.
- No visual redesign is authorized. Any necessary readability change must preserve the `SCREENS.md` contract or update that contract before implementation.
