<!--
Sync Impact Report
- Version change: unratified template -> 1.0.0
- Modified principles: none; all seven principles are newly adopted for DLS
- Added sections: Additional Constraints; Delivery Workflow and Release Gates
- Removed sections: none
- Templates requiring updates:
	- .specify/templates/plan-template.md - updated: existing Constitution Check gate
		remains sufficient
	- .specify/templates/spec-template.md - updated: no mandatory sections changed
	- .specify/templates/tasks-template.md - updated: existing story and test task
		structure remains compatible
	- .github/agents and .github/prompts SpecKit commands - updated: no outdated
		agent-specific references found
- Follow-up TODOs: none
-->

# Digital Lesela Sete Constitution

## Core Principles

### I. User-Value-First Incremental Delivery
Every feature MUST name the user problem, the user-visible value, and an independently
testable smallest increment before implementation. Work MUST follow the priority order in
`FEATURE_PLANS.md`: release blockers before core value improvements, then polish and
experiments. Each increment MUST preserve existing user journeys and MUST be demonstrable
without requiring unrelated future work. This keeps delivery useful, reversible, and
focused on the wardrobe, outfit, event, and style workflows that define DLS.

### II. Screen and Design Contract
`SCREENS.md` is the authoritative contract for screen structure, navigation, design tokens,
typography, spacing, surfaces, and interaction states. A feature MUST update `SCREENS.md`
before changing a locked layout, navigation relationship, or frozen token. Implementation
work SHOULD be additive where the contract is locked; visual rewrites require an explicit
documented decision and validation against the updated contract. This prevents visual drift
and keeps the product coherent across the five-tab shell and its supporting flows.

### III. Test-Gated Quality and Validation Evidence
No feature, sprint, or release MAY be marked complete without evidence appropriate to its
risk. At minimum, code changes MUST pass `flutter analyze` and `flutter test`; affected
flows MUST have focused unit, widget, integration, or manual smoke evidence. Build and
platform checks MUST be run when applicable, including Android debug/release builds and
`flutter build web --release`. The evidence, remaining risks, and blocked checks MUST be
recorded in `AUDIT_TRACKING_PLAN.md` and the implementation delta in `PROJECT_HISTORY.md`.
Tests are a release gate, not a substitute for user-flow validation.

### IV. Firebase Security and User Scoping
Firebase Auth MUST protect authenticated application flows. Firestore and Storage access
MUST be enforced by production rules and ownership checks, not only by UI visibility.
User-owned records and files MUST be scoped to the authenticated Firebase UID, including
profiles, clothing items, outfit history, events, recommendations, and audit events. Reads
and writes MUST reject cross-user access and unauthenticated mutation. Service-account
credentials, private keys, and secrets MUST never be committed to source; client config is
not a substitute for security rules. Security-rule changes MUST be tested and recorded as
release evidence.

### V. Explainable and Offline-Tolerant Recommendations
Outfit and item recommendations MUST be explainable in user-facing language, with reasons
grounded in available wardrobe data and the selected occasion, mood, weather, or event
context. Optional LLM enhancement MAY improve captions or reasoning, but the local
rule-based generator MUST remain the reliable fallback when configuration is absent or the
device is offline. The UI MUST communicate fallback, missing-data, and low-confidence
states without presenting fabricated certainty. Recommendation logic MUST remain testable
without a network service.

### VI. Observability and Audit Traceability
Key user actions and consequential data mutations MUST leave an attributable audit trail
through the existing `audit_events` model or an explicitly approved successor. Audit data
MUST identify the authenticated user, action, relevant entity, timestamp, and outcome while
excluding secrets and unnecessary sensitive content. Every sprint update MUST state what
was implemented, what was validated, current risks, and next actions in the project audit
documents. This makes production behavior explainable and keeps delivery claims verifiable.

### VII. Simplicity and Maintainability
The application MUST favor the smallest clear design that satisfies the current user value
and constitution. New abstractions, dependencies, persistence paths, and background
processes MUST have a concrete maintenance or product justification. Changes MUST follow
the existing Flutter + Provider structure and preserve clear ownership between views,
controllers, services, and models. Public behavior, error handling, and configuration
defaults MUST remain understandable to a maintainer who has only the repository documents
and source tree available.

## Additional Constraints

- **Technology**: The application MUST remain a Flutter mobile/web application using
	Provider for state coordination and Firebase Core, Auth, Firestore, and Storage for the
	current backend. Existing packages such as image picking/compression and permissions
	MUST be extended only when the feature requires them.
- **Supported platforms**: Android and Web are the supported validation targets for the
	current release line. iOS is a prepared but caveated target: final build and device
	validation require macOS, Xcode, CocoaPods, signing/provisioning, and the required iOS
	Firebase configuration. Windows-based validation MUST NOT be reported as iOS release
	evidence.
- **Configuration and secrets**: Secrets MUST be supplied through approved runtime or
	deployment configuration such as `--dart-define`, environment configuration, or a
	server-side secret store. `.env` files, service-account credentials, private keys, and
	production secrets MUST remain untracked and absent from source, logs, fixtures, and
	screenshots.
- **UI tokens**: Existing tokens and conventions in `SCREENS.md` are frozen defaults,
	including the dark layered surfaces, gold primary, lime tertiary, Plus Jakarta Sans and
	Inter typography, pill controls, rounded cards, and no-visible-border rule. New screens
	MUST reuse these tokens and document deliberate exceptions.
- **Data behavior**: Loading, empty, error, permission-denied, offline, and retry states
	MUST be explicit for asynchronous Firebase and media flows. User-facing failures MUST
	be recoverable where practical and MUST NOT crash the core onboarding, dashboard,
	wardrobe, generator, event, or profile journeys.

## Delivery Workflow and Release Gates

1. A feature proposal MUST identify user value, scope, affected screens, data ownership,
	 security implications, and validation evidence before implementation. The implementation
	 plan MUST include a passing Constitution Check before design work and again after design.
2. Developers MUST run `flutter pub get` when dependencies or package resolution change,
	 then run `flutter analyze` and `flutter test` for every meaningful change. Relevant
	 Android, Web, integration, physical-device, and low-network smoke checks MUST be added
	 according to the affected risk surface.
3. Before launch, the applicable pre-go-live gates MUST pass: analysis, tests, Android
	 build, Web build, auth and routing flows, Firebase data/security checks, regression
	 checks, and platform smoke tests. Any skipped iOS check MUST be labelled as a macOS
	 limitation, not silently treated as green.
4. A change MUST update `PROJECT_HISTORY.md` and `AUDIT_TRACKING_PLAN.md` when it changes
	 implementation status, validation evidence, risk, or next actions. A change MUST update
	 `SCREENS.md` when it changes screen behavior, navigation, layout, tokens, or the screen
	 roadmap. Documentation updates are part of the change, not optional cleanup.
5. A release MUST have green P0 gates, documented accepted risks, a rollback path, and
	 release-owner sign-off. `pubspec.yaml` versioning and upgrade/account-preservation
	 checks MUST be completed for a published build.

## Governance

This constitution is the governing project policy for DLS planning, implementation,
validation, and release decisions. When another document conflicts with it, the conflict
MUST be resolved in favor of this constitution or explicitly amended through the process
below. `README.md`, `SCREENS.md`, `PRE_GO_LIVE_CHECKLIST.md`, `FEATURE_PLANS.md`, and
`AUDIT_TRACKING_PLAN.md` provide the operational details that implement these rules.

Amendments MUST be proposed as a focused change to this file, state the affected principle
or section, explain the rationale and migration impact, and update the Sync Impact Report.
The amendment MUST be reviewed against the named project documents and SpecKit templates,
then pass the validation checks for placeholders, dates, version consistency, and
declarative MUST/SHOULD language. A change that adds or materially expands a principle
increments the MINOR version; a backward-incompatible removal or redefinition increments
the MAJOR version; wording-only clarification increments the PATCH version. The last
amended date MUST be the date the accepted amendment is written.

Every feature plan and review MUST check constitutional compliance, and every release
review MUST verify the quality, security, traceability, and platform gates that apply to
the change. Violations MUST be recorded with an owner, remediation, and disposition; an
exception requires explicit rationale, affected risk, expiry or review date, and approval
from the release owner.

**Version**: 1.0.0 | **Ratified**: 2026-09-26 | **Last Amended**: 2026-09-26
