# Feature Specification: Fashion Training Data Mapping

**Feature Branch**: `003-fashion-training-data-mapping`

**Created**: 2026-10-09

**Status**: Draft

**Input**: Use the incoming local fashion dataset to map fashion catalog items to DLS's existing closet taxonomy and inform the local outfit engine. Plan before implementation; the dataset is still loading.

## Scope and Intent

Establish a safe, auditable path for evaluating an incoming local fashion product catalog and, only after its readiness and usage rights are verified, mapping approved metadata to DLS's existing clothing model, wardrobe taxonomy, and local rule-based affinity engine.

Delivery is staged. The first eventual implementation is limited to local metadata readiness, profiling, and deterministic mapping to the existing rules. It does not create user closet inventory or train a new model. Image-based work and model training remain deferred until source rights, product intent, and a suitable technical approach are explicitly decided.

The source folder is currently present but its completeness is unverified. Its sample files resemble a third-party product catalog and include image URLs; source, version, license, terms, and image redistribution rights have not been established. Presence on disk is not evidence of completeness or permission to use.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Verify dataset readiness and permitted use (Priority: P1)

As a developer preparing the dataset, I need a local readiness and provenance review so that incomplete or unapproved source material cannot be consumed as training or application data.

**Why this priority**: Readiness, privacy, and rights gates prevent irreversible processing or exposure of an incomplete or unapproved third-party dataset.

**Independent Test**: Present incomplete, changed, and rights-unverified dataset states and confirm each is blocked with a specific, reviewable reason; present a complete manifest and approved provenance and confirm the dataset can advance to local profiling.

**Acceptance Scenarios**:

1. **Given** no explicit loading-complete signal, **When** a user attempts to profile or map the dataset, **Then** consumption is blocked and the missing readiness evidence is reported.
2. **Given** the loading-complete signal but missing, inconsistent, or changed manifest counts or checksums, **When** readiness is checked, **Then** the dataset remains blocked and no partial rows are treated as approved input.
3. **Given** stable readiness evidence but unknown or unapproved provenance, license, or terms, **When** mapping, training, or image use is requested, **Then** that use is blocked and the unresolved rights status is reported without asserting legal usability.

### User Story 2 - Profile and map approved catalog metadata (Priority: P2)

As a developer evaluating approved source metadata, I need a quality profile and deterministic mapping report so that supported catalog values can inform the existing outfit rules and unmappable records remain visible for review.

**Why this priority**: A transparent mapping report provides the first useful, bounded outcome without changing the production item model or assuming a machine-learning approach.

**Independent Test**: Run a fixed approved fixture twice and compare mappings and reports; include valid, missing, unsupported, and ambiguous values and confirm only unambiguous supported values map while the rest are reported or quarantined.

**Acceptance Scenarios**:

1. **Given** rights-approved, ready metadata, **When** it is profiled, **Then** the report records schema, row counts, missing values, duplicates, invalid values, and source-to-app mapping coverage.
2. **Given** a source category, color, season, gender, or style signal with a documented unambiguous mapping, **When** the catalog is mapped, **Then** the same source and mapping version produce the same supported app value on every run.
3. **Given** a missing, unsupported, or ambiguous source value, **When** the mapping is produced, **Then** the record is quarantined or reported with a reason and no taxonomy value is silently invented.

### User Story 3 - Keep catalog data separate from personal wardrobes (Priority: P1)

As an app user, I need imported catalog examples to remain distinct from clothing I own so that recommendations and closet actions never misrepresent product listings as my inventory.

**Why this priority**: The app's clothing records are user-owned data; catalog data has different ownership, privacy, and lifecycle semantics.

**Independent Test**: Attempt catalog profiling and mapping in a test environment and verify that no user's closet, ownership fields, closet status, outfit history, or user-facing inventory changes.

**Acceptance Scenarios**:

1. **Given** catalog records are being profiled or mapped, **When** the operation completes, **Then** no records appear as actual closet items and no user identifier, owned-item status, or user-item timestamp is assigned to catalog records.
2. **Given** the approved mapping is made available to the local affinity rules, **When** the outfit engine uses it, **Then** it influences rule metadata only and does not claim a catalog item is owned or available in a user's closet.

### Edge Cases

- Loading is declared complete while nested duplicate CSV files or image folders are still changing; changed counts or checksums invalidate readiness.
- A manifest omits expected files, includes unexpected files, or cannot establish a stable total; the dataset remains blocked.
- Source rows have duplicate IDs, duplicate products, missing IDs, malformed values, inconsistent casing, or conflicting category signals; these are reported and are not silently merged into invented categories.
- A source value has more than one plausible taxonomy mapping, including color, season, gender, or style; it is quarantined for explicit review.
- The rights status permits local metadata review but does not clearly permit model training or image use; only explicitly approved activities may proceed.
- A source row contains a remote image URL; the URL is retained only as provenance metadata and is not fetched or redistributed without explicit rights approval.
- A catalog mapping is rerun after the app taxonomy changes; the prior mapping version remains auditable and the new result does not silently rewrite user closet items.
- An attempted outbound request, analytics event, Firebase write, Git staging, or push would include source rows, image content, or raw source paths; the operation is rejected or prevented.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The dataset source MUST remain local-only. Raw source rows, images, and source URLs MUST NOT be uploaded to Firebase, GitHub, external APIs, or analytics.
- **FR-002**: Raw source material MUST be protected from accidental Git staging, commit, and push. The source remains outside application and release assets unless a separately reviewed, approved exception is made.
- **FR-003**: The system MUST NOT consume source rows until an explicit loading-complete signal and a stable manifest are present. The manifest MUST state expected file inventory, per-file checksums, authoritative row or item counts, and a provider-documented schema identifier sufficient to detect incomplete or changed input. Profiling additionally requires permission for local metadata profiling; mapping and engine use additionally require approved mapping rules and permission for those activities.
- **FR-004**: A missing, inconsistent, or stale readiness signal or manifest MUST block consumption and identify the evidence that failed validation.
- **FR-005**: Before any training or image use, provenance, source/version attribution, applicable license, terms, and permitted use MUST be inspected and recorded. Unknown or unapproved rights MUST block that use; no feature output may claim that the source is legally usable without verified evidence for the intended use.
- **FR-006**: The system MUST profile approved metadata for schema, counts, missingness, duplicates, malformed values, and mapping coverage, and MUST produce a reviewable report tied to the source manifest and mapping version.
- **FR-007**: Mapping MUST target only the existing DLS clothing model, wardrobe taxonomy, and local rule-based affinity engine. The source catalog MUST NOT introduce duplicate or unapproved taxonomy values.
- **FR-008**: Mapping of supported categories, colors, seasons, gender signals, and style signals MUST be explicit, deterministic, and auditable. `categoryType` may be derived only from an already-mapped canonical category using the existing DLS helper. Each mapped value MUST be traceable to its source value and mapping rule; fit mapping is out of scope unless a rights-approved source field and explicit mapping decision are later added.
- **FR-009**: Missing, unsupported, conflicting, or ambiguous values MUST be reported or quarantined with a reason. The system MUST NOT silently invent taxonomy values or infer certainty from absent source data.
- **FR-010**: Catalog records MUST remain distinct from user-owned closet records. Profiling and mapping MUST NOT assign user identity, owned-item status, user-item timestamps, or catalog image references in a way that makes a catalog product appear in a user's actual closet.
- **FR-011**: The first implementation scope MUST be limited to approved metadata mapping that can inform the existing local rule/affinity engine. New model training and image-based training MUST remain deferred until legal permission and the meaning, goals, and technical approach for “training” are decided.
- **FR-012**: Mapping and readiness checks MUST be repeatable: identical approved source contents, manifest, taxonomy version, and mapping rules MUST yield identical mapped outputs and disposition reports.
- **FR-013**: Any future integration with the outfit engine MUST use mapped signals as rule metadata or priors and MUST NOT create fictional closet inventory or silently replace existing user data.
- **FR-014**: The mapping report MUST assign exactly one record-level disposition (accepted, quarantined, rejected, or not reviewed) to every input record and report field-level outcomes separately, including counts and reasons, without exposing source rows to network services. It MUST include readiness and activity-specific rights status without asserting legal conclusions.

### Key Entities *(include if feature involves data)*

- **Source Catalog Record**: A third-party product listing with original source identity and metadata; it is not a user's clothing item.
- **Dataset Readiness Manifest**: A local record of source identity/version, loading-complete evidence, expected files, checksums, counts, and validation status.
- **Provenance and Rights Record**: The evidence and review status for source attribution, license, terms, and each intended use, including metadata analysis, training, and image use.
- **Mapping Rule**: A versioned, explicit relation between a source value and an existing DLS taxonomy or affinity signal, including its rationale and status.
- **Mapping Result**: A traceable disposition of a source record or field as mapped, quarantined, rejected, or not reviewed, with reasons and mapping version.
- **User Closet Item**: Existing user-owned clothing inventory, governed by the app's current ownership and privacy rules and kept separate from catalog records.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of profiling, mapping, and engine-consumption attempts made before explicit completion and stable manifest verification are blocked before any source row is read.
- **SC-002**: 100% of training and image-use attempts with unknown or unapproved rights are blocked, and the report identifies the unresolved rights evidence.
- **SC-003**: For an approved fixed fixture, repeated runs produce identical accepted mappings, quarantines, rejection reasons, and counts.
- **SC-004**: 100% of records in the validation fixture have exactly one final record-level disposition, and every required mapped field has a field-level outcome; counts reconcile to the fixture totals, none are silently dropped, and no unsupported taxonomy value is assigned.
- **SC-005**: Validation confirms zero raw source rows or image content sent to Firebase, GitHub, external APIs, or analytics, and zero catalog records created as user-owned closet inventory.
- **SC-006**: A developer can identify dataset readiness, the requested activity's rights-review status, mapping coverage, and unresolved records from the local review report without manually inspecting every source row; the report makes no legal-usability claim.
- **SC-007**: On the agreed reference development environment, profiling and mapping a stable approved metadata set of up to 50,000 records completes within two minutes, excluding image processing. This local developer-tool benchmark makes no claim about app UI responsiveness.

## Assumptions

- The existing feature `002-on-device-outfit-engine` remains authoritative for the canonical clothing model, taxonomy, and local rule-based affinity engine; this feature extends their inputs rather than replacing them.
- `training_data/fashion-dataset` is an incoming local copy whose completeness is not yet verified. Its presence, sample columns, and image URLs do not establish the exact source/version, license, permission for local processing or training, or image redistribution rights.
- The first eventual implementation may assess local file structure and manifest consistency, but must gate catalog mapping, engine use, training, and image use on applicable readiness and rights decisions.
- The word “training” is not assumed to mean machine-learning model fitting. The initial planned outcome is deterministic metadata mapping to existing local rules; any broader meaning requires an explicit product and technical decision.
- No full image inspection or dataset completeness audit has been completed. Images are not required for the first metadata-mapping stage.

## Decisions

- **Seed imagery (chosen: metadata-only, CC0 images):** Only approved metadata may inform the engine. Images stay the existing CC0 seed set in `assets/seed/`. Source image URLs are provenance metadata only and are never fetched, bundled, or shown. Metadata use stays gated by FR-003 and FR-005 until a manifest and a rights record exist.
- **Local-only photos and bundled Myntra photos:** Rejected. Both conflict with the CC0-only seed policy and FR-002.
- **Repository hygiene:** `training_data/` stays git-ignored and is never staged, committed, or pushed.

## Open Questions

- What are the dataset's exact source, version, attribution requirements, license, and terms, and which intended uses do they permit: local metadata profiling, rule-metadata mapping, model training, image analysis, and/or redistribution?
- When the user says “train the outfit engine,” do they mean map catalog metadata into existing rule/affinity signals, tune those rules using approved examples, fit a new machine-learning model, or another outcome? The first planned implementation remains metadata mapping only until this is answered.
- What explicit loading-complete signal and stable manifest will the data provider or loading workflow supply, including expected file inventory and authoritative row/item counts?
- Where should this feature be placed in `FEATURE_PLANS.md` relative to current release blockers and higher-priority work before implementation is scheduled?