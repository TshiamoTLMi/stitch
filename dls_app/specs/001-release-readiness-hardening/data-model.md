# Data Model: Release-readiness hardening

This feature extends existing Firebase/application entities. It does not create a new remote collection or migrate existing accounts.

## User Account

Existing Firebase Auth identity plus `users/{uid}` profile document.

| Field | Source | Rules |
|---|---|---|
| `uid` | Firebase Auth | Stable identity; all user-owned reads/writes use this value. |
| `email` | Auth/profile | Never expose more than the existing signed-in user email; do not use recovery outcomes to enumerate accounts. |
| profile fields | `ProfileService` | Preserve across recovery, upgrade, and Web deployment update. Do not recreate on sign-in. |

State transitions: signed out -> recovery request -> signed out with neutral confirmation/retry -> authenticated with the same UID. An expired session may require re-authentication but never account deletion or recreation.

## Password Recovery Request

An in-memory/UI operation state; reset secrets and links are never persisted by the app.

| Field | Values |
|---|---|
| `emailInput` | Trimmed, normalized display value retained for retry; not written to Firestore or evidence. |
| `status` | `idle`, `invalid`, `sending`, `success`, `failure`, `offline`, `expired-link` where applicable. |
| `message` | Concise user-facing copy without raw Firebase exception text or account enumeration. |
| `canRetry` | True after recoverable failure; false while `sending`. |

Validation: required input and malformed email are rejected before Firebase. Only one active request is allowed for the dialog. Success means the Firebase request completed, not that the user opened the email or completed a reset link.

## Event

Existing `events/{eventId}` document represented by `EventModel`.

| Field | Existing representation | Rules |
|---|---|---|
| `id` | Firestore document ID | Stable reminder identity; empty only before create. |
| `userId` | `user_id` | Must equal the authenticated UID on create/read/update/delete. |
| `name` | `name` | Required, readable event label. |
| `date` | Firestore `Timestamp` | Interpreted in the user's intended local calendar context; used to identify today/next-day/upcoming. |
| `occasion` | `occasion` | Existing controlled values such as Work, Date, Groove, Braai, Event; incomplete values produce an unknown-data state. |
| `recommendedOutfits` | `recommended_outfits` | Existing persisted generator summaries; do not treat text as the structured missing-item contract. |
| `source`, `sourceKey` | Existing optional fields | Preserve calendar-import deduplication; source key remains stable when present. |

State transitions: draft -> persisted -> upcoming/next-day -> reminder scheduled or Web fallback -> completed/past; edit/date change -> reconcile reminder; delete -> delete event and cancel its reminder. A failed Firestore write must not be reported as a created event.

## Event Reminder

Derived application/platform state, not a new Firestore collection.

| Field | Values |
|---|---|
| `eventId` | Stable association to one existing event. |
| `platform` | `android`, `web`, or unsupported platform status. |
| `status` | `scheduled`, `inAppFallback`, `permissionDenied`, `unavailable`, `cancelled`, `past`, `error`. |
| `scheduledAt` | Local timezone instant when Android scheduling succeeds; never shown as proof of delivery. |
| `leadTime` | Existing one-hour-before-event convention, recorded in validation evidence. |
| `notificationId` | Stable derived integer for Android cancellation/deduplication; not a secret. |

Invariants: at most one current Android reminder per event; stale IDs are cancelled on delete/date change; Web never claims browser delivery; no upcoming event means no current reminder.

## Wardrobe Item

Existing `ClothingItem` and `clothing_items/{itemId}` record.

Relevant fields are `userId`/legacy `user_id`, `categoryType`, category/subcategory, status/availability, style tags, and image metadata. Recommendations may use only the current user's already-synced items. Clean/available categories count as covered; missing, unknown, in-wash, or incomplete metadata must produce an honest missing/unknown state rather than a fabricated match.

## Missing-Item Recommendation

New application-level value derived by `RecommendationService`; not a mandatory persisted entity.

| Field | Required behavior |
|---|---|
| `need` | Plain-language missing or unsuitable item, such as formal shoes. |
| `reason` | Event name/occasion explanation grounded in the rule and available data. |
| `eventId` / `occasion` | Context used for display and action handoff. |
| `state` | `missing`, `covered`, or `unknown` for incomplete event/wardrobe data. |
| `action` | Existing destination: add wardrobe item or open outfit generation. |
| `dedupeKey` | Deterministic need + action key to avoid duplicate chips/cards. |

The result is deterministic for the same wardrobe/event inputs and sorted for stable tests/UI. It must remain available without the optional LLM service or network.

## Analytics Summary

Application-level result assembled from existing UID-scoped collections.

| Field | Meaning |
|---|---|
| `itemCount` | Distinct current-user clothing records across supported legacy/new field names. |
| `outfitCount` | Current-user `outfit_history` records. |
| `eventCount` | Current-user `events` records. |
| `styleScore` | Existing derived score when source scores are valid; otherwise unavailable, not an implied zero. |
| `topCategory` | Deterministically derived readable category or unavailable. |
| `latestCaption` | Latest valid caption or a plain-language empty fallback. |
| `freshness` | `live`, `cached`, `stale`, or `unavailable`. |
| `status` | `loading`, `ready`, `empty`, `partial`, `error`, `offline`. |

No metric may be presented as complete zero data when the underlying read failed or only partially loaded.

## Style Evolution Entry

Derived from current-user `audit_events`.

| Field | Source/fallback |
|---|---|
| `createdAt` | `created_at` timestamp; stable placeholder ordering only when absent. |
| `label` | Mapped human-readable audit type such as Outfit generated or Event created; fallback Activity. |
| `description` | Safe message; fallback to a concise label, never raw field dumps. |
| `metadata` | Optional non-sensitive context; omit secrets and unnecessary personal data. |

Entries render newest-first with readable `intl` dates. Missing caption/metadata does not create blank rows or crash the timeline.

## Release Evidence Record

Documentation-only record described fully in [contracts/release-evidence.md](contracts/release-evidence.md). It is not stored in the app database.

Required fields: gate ID, story/area, platform, environment/deployment identity, build identity where applicable, test date/time, result (`pass`, `fail`, `blocked`, `not-applicable`), observed behavior, evidence reference, blocker/reason, owner, next action, and rollback/accepted-risk note. Secrets, reset links, credentials, and unnecessary personal data are prohibited.