# Data Model: Fashion Training Data Mapping

All entities below are local planning concepts for a gated developer tool. They are not Firestore collections, app assets, closet records, or permission to consume the incoming source.

## Entities

### Dataset Readiness Manifest

- **Purpose**: Prove that the provider/loading workflow declared completion for a specific source snapshot and that the expected local files still match it.
- **Fields**: Manifest schema version; source identity and version; explicit completion attestation/reference and time; sorted expected file inventory; normalized relative file path per entry; checksum algorithm and digest per file; authoritative row/item count per data file; required provider-documented schema identifier/reference; manifest validation status and failure reasons.
- **Validation**: Completion evidence must be explicit and attributable. Inventory must be complete against the authoritative declaration. Counts, schema identifier, and checksums must match. Missing, unexpected, changed, duplicate, or unreadable entries invalidate readiness. A local scan cannot invent authoritative expected values. The machine-readable contract validates evidence fields and references but does not itself establish the truth of a provider claim or make a legal determination; a named reviewer records that assessment.
- **State**: `not_verified` -> `blocked` or `ready`; readiness is derived from validation and does not imply rights approval.

### Provenance and Rights Record

- **Purpose**: Record evidence and approval for the precise source/version and each proposed use.
- **Fields**: Source identity/version; attribution; license and terms references supplied by the provider; evidence description/reference; named reviewer; review timestamp; status per activity (`not_reviewed`, `approved`, `denied`); notes and scope/expiry if applicable. Store as a machine-readable local record validated against a versioned field contract; preserve evidence references without embedding raw dataset rows or images.
- **Activities**: Local metadata profiling; deterministic mapping/rule metadata use; model training; image analysis/training; redistribution.
- **Validation**: Unknown is not approved. Approval for one activity must not be generalized to another. Tool output must not claim legal usability.

### Source Catalog Record

- **Purpose**: A transient third-party product row while a gated local profile or mapping is run.
- **Fields**: Source-record key or stable row fingerprint; source field values in memory only; source-manifest reference. Remote image URL, if present, is opaque provenance text only.
- **Validation**: Do not fetch URLs or persist/export raw rows in reports. Missing IDs, malformed data, duplicate identities, or conflicting signals must remain reviewable through a non-reversible or otherwise privacy-reviewed record reference and reason.
- **Relationship**: No ownership or persistence relationship to `User Closet Item`.

### Mapping Rule

- **Purpose**: A versioned, explicit transformation from one approved source field/value to an existing DLS value or engine signal.
- **Fields**: Rule ID/version; source field; exact normalized source value; canonical target field/value; rationale; review status; applicable rights record; deterministic normalization specification.
- **Validation**: Targets must already exist in the approved taxonomy/rule vocabulary. No fuzzy inference, default-to-neutral behavior, or taxonomy growth for unknown source values. Conflicts make the affected value ambiguous and unapproved until reviewed.

### Mapping Result and Disposition

- **Purpose**: Record a field- or record-level result with enough provenance for reproducibility and review without exposing raw source rows.
- **Fields**: Stable source-record reference; source-manifest digest; mapping-rule version; canonical field/value when accepted; disposition (`accepted`, `quarantined`, `rejected`, `not_reviewed`); reason code and review status.
- **Validation**: Every input record and mapped field must be counted in exactly one applicable disposition. No silent drops. A result is deterministic for identical approved input, manifest, taxonomy version, and mapping rules.

### Profile and Mapping Report

- **Purpose**: Summarize a local run for review.
- **Fields**: Source-manifest digest; schema and mapping versions; readiness status; rights-review status for the requested activity; input and output record counts; exactly one final disposition per input record; separate field-level outcome and coverage counts; missingness; duplicate and malformed counts; reason totals; run/tool version; validation failures.
- **Validation**: Record-level dispositions reconcile exactly to input record count; field-level counts use their own denominator and are never added to record totals. No raw rows, image bytes, fetched URL content, user IDs, or secrets. Report destination is outside `training_data/`, local-only, and verified not to be staged or bundled. Rights status is descriptive evidence status, not a legal-usability conclusion.

### User Closet Item (existing)

- **Purpose**: Existing user-owned inventory represented by `lib/models/clothing_item.dart` and governed by current app/Firebase ownership flows.
- **Fields**: Existing model fields, including required `userId`, status, and user timestamps, plus clothing attributes.
- **Boundary**: Catalog records and mapping results never instantiate, mutate, serialize, or persist this entity. `ClothingItem` is referenced only as the canonical vocabulary/compatibility target. No user identity, owned status, timestamps, or catalog image URL is synthesized.

## Relationships and Gate Flow

```text
Dataset Readiness Manifest --validates snapshot--> Source Catalog Record
Provenance and Rights Record --authorizes activity--> Profile / Mapping run
Mapping Rule --maps explicit value--> Mapping Result
Mapping Results --summarized as--> Profile and Mapping Report
Mapping Results --optional approved rule metadata--> Existing local AffinityEngine
Source Catalog Record -X-> User Closet Item
```

The affinity engine receives only approved, canonical rule metadata/priors. It must not receive catalog records as outfit candidates. If a requested use depends on constructing `ClothingItem` objects or introduces any user-owned state, that use is blocked pending redesign and explicit approval.
