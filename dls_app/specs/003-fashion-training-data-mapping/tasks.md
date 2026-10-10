# Tasks: Fashion Training Data Mapping

**Input**: Design documents in `specs/003-fashion-training-data-mapping/`

**Status**: Future, gated backlog only. This task-generation change does not authorize or execute any task below.

## Scope and Safety Gates

- All initial fixtures and tests use synthetic data only; never use `training_data/` as a test fixture.
- Keep the root `/training_data/` directory locally excluded and read-only. Do not edit `.gitignore`, stage, commit, push, or upload dataset files.
- No task may send data to Firebase, external networks/APIs, GitHub, analytics, or any other remote service; do not fetch image URLs.
- Do not create app assets, user closet records, `ClothingItem` instances from catalog rows, or user identifiers/ownership timestamps. Do not modify feature `002`, Firebase configuration/rules, or the incoming dataset.
- No real source rows may be opened, parsed, profiled, mapped, or benchmarked until provider-authoritative completion evidence, verified provenance, and activity-specific permission for the requested operation have been recorded and validated. Local directory presence or a locally generated scan is not authoritative evidence.
- Do not invent source provenance, license conclusions, manifest counts, mapping values, report retention, or output location. Record decisions and keep the affected operation blocked while any required decision is unresolved.
- Do not add dependencies until the approved schema is known and a concrete parser need is demonstrated and reviewed.
- Model fitting, image analysis/training, image fetching, and redistribution are deferred and out of scope unless a later product decision and separate rights approval authorize them.

## Phase 1: Safety-First Setup (Synthetic Fixtures Only)

**Purpose**: Establish the earliest checks without reading or needing the incoming dataset. These implementation tasks start only after T008 confirms the feature is scheduled in accordance with `FEATURE_PLANS.md`.

- [ ] T001 [P] Add synthetic-only fail-closed readiness tests in `test/tooling/fashion_catalog_mapper/readiness_test.dart`; cover absent completion evidence, missing/unexpected files, changed checksums, inconsistent counts, and prove the row-parser callback is never invoked on a blocked state.
- [ ] T002 [P] Verify representative existing CSV/JSON source paths match the root `/training_data/` ignore rule with `git check-ignore -v`, and verify `git ls-files -- training_data` returns no tracked paths; do not read dataset contents or modify `.gitignore`.

**Checkpoint**: The first test slice uses synthetic values only and demonstrates that incomplete or changed readiness evidence blocks before parsing.

---

## Phase 2: Foundational Evidence Decisions (Blocking)

**Purpose**: Obtain decisions/evidence before any future real-data operation. These tasks do not themselves read the dataset.

- [ ] T003 Record verified source identity, version, attribution, and provider-supplied license/terms evidence with named reviewer, activity scope, status, and evidence references in a machine-readable local record described by `specs/003-fashion-training-data-mapping/data-model.md`; leave the status unresolved if evidence is unavailable and make no legal-usability claim.
- [ ] T004 Record a separate approved, denied, or not-reviewed decision for local profiling, deterministic mapping/rule use, model training, image analysis/training, and redistribution in a machine-readable local record; include reviewer, source version, scope, and evidence references, and do not infer one activity's permission from another.
- [ ] T005 Obtain and record the provider/loading-workflow completion attestation, authoritative expected file inventory, per-file checksums, authoritative row/item counts, and provider-documented schema identifier/reference in a machine-readable completion manifest; do not substitute a local directory scan or guessed count.
- [ ] T006 After T003-T005, document the provider-backed source schema contract before any row reader is enabled; record initial mapping rules only for exact, unambiguous values supported by reviewed provider/schema evidence, and leave all other values quarantined until separately reviewed. Do not add taxonomy values.
- [ ] T007 Decide and document the local report destination and retention policy in `specs/003-fashion-training-data-mapping/local-output-decision.md`; require an explicit local destination outside `training_data/` that is excluded from source control or outside the repository.
- [ ] T008 Decide what “train the outfit engine” means, whether any rule-metadata activation is in scope, and where the feature belongs in `FEATURE_PLANS.md` relative to current release blockers; record the scheduling decision in `specs/003-fashion-training-data-mapping/product-scope-decision.md`, and keep model fitting and all image use deferred unless separately approved by product and rights review.

**Blocking rule**: T009-T011 may implement and test gates using synthetic data. A real metadata profile may open rows only after T003-T005 contain reviewed evidence, T004 explicitly approves local profiling, and the provider-backed schema contract in T006 is recorded. Real mapping additionally requires approved mapping entries in T006 and mapping-specific T004 permission. Real report writes require T007; recommendation-affecting activation requires T008 and regression evidence. The gate validates record structure and review status but must not claim to prove legal truth independently of the named reviewer and cited source evidence.

---

## Phase 3: User Story 1 - Verify Dataset Readiness and Permitted Use (Priority: P1)

**Goal**: Fail closed with reviewable reasons until both source readiness and the requested activity's rights are verified.

**Independent Test**: Synthetic cases for missing, stale, changed, inconsistent, unknown, denied, and approved evidence show the expected block/advance result; blocked cases never invoke the row parser.

- [ ] T009 [P] [US1] Add synthetic tests for independent activity permissions and readiness-gate decisions in `test/tooling/fashion_catalog_mapper/gates_test.dart`; assert unknown/denied permission blocks only the relevant operation and no test reads `training_data/`.
- [ ] T010 [US1] Implement fail-closed completion-manifest and per-activity rights validation in `tooling/fashion_catalog_mapper/lib/gates.dart`; report specific evidence failures and accept only verified evidence records, without making legal conclusions.
- [ ] T011 [US1] Implement a read-only local source reader in `tooling/fashion_catalog_mapper/lib/source_reader.dart` that validates T003-T005, profiling permission, and the provider-backed schema contract before opening any row; mapping remains separately blocked until reviewed mapping values exist; never fetch remote URLs.

**Checkpoint**: Readiness and rights gates pass synthetic tests independently; missing, stale, or unapproved evidence blocks before any real source row is opened.

---

## Phase 4: User Story 3 - Keep Catalog Data Separate from Personal Wardrobes (Priority: P1)

**Goal**: Keep catalog processing local and separate from user-owned inventory and application side effects.

**Independent Test**: Synthetic runs complete with network access denied/instrumented and closet/repository calls trapped; they produce no outbound requests, Firebase/analytics activity, app assets, user records, or ownership fields.

- [ ] T012 [P] [US3] Add synthetic local-only boundary tests in `test/tooling/fashion_catalog_mapper/local_only_boundary_test.dart`; trap network, Firebase, analytics, closet repository, and `ClothingItem` construction paths, and assert image URL text is never fetched or emitted.
- [ ] T013 [US3] Implement an isolated local runner in `tooling/fashion_catalog_mapper/bin/fashion_catalog_mapper.dart` that accepts only the mapper's local inputs/output configuration and has no Firebase, network, GitHub, analytics, app-asset, or closet integration.
- [ ] T014 [US3] Implement privacy-safe local report writing in `tooling/fashion_catalog_mapper/lib/local_report.dart` using the T007-approved destination; omit raw rows, image bytes/content, URLs, source paths, user identifiers, and secrets, and refuse destinations inside `training_data/`.

**Checkpoint**: Synthetic processing and reports remain local, contain no raw source content, and cannot create or mutate closet inventory.

---

## Phase 5: User Story 2 - Profile and Map Approved Catalog Metadata (Priority: P2)

**Goal**: Produce deterministic, auditable mapping and disposition reports using only approved metadata and existing DLS taxonomy/rule vocabulary.

**Independent Test**: Repeated runs of the same synthetic approved fixture, manifest, taxonomy, and reviewed rules serialize identically; every value is accounted for as accepted, quarantined, rejected, or not reviewed, with no invented target values.

- [ ] T015 [P] [US2] Add synthetic tests for deterministic category, color, season, gender, and style mapping, with `categoryType` derived only from a mapped category using the existing helper, plus missing, malformed, conflicting, unsupported, and ambiguous dispositions in `test/tooling/fashion_catalog_mapper/mapping_test.dart`; assert unknowns never use permissive taxonomy defaults and fit is not inferred.
- [ ] T016 [P] [US2] Add synthetic report tests for schema/count/missingness/duplicate/malformed coverage, exactly-one record disposition, separate field-level accounting, explicit readiness and activity-rights status, stable serialization, and privacy exclusions in `test/tooling/fashion_catalog_mapper/report_test.dart`.
- [ ] T017 [US2] Implement versioned explicit mapping in `tooling/fashion_catalog_mapper/lib/mapper.dart` using only T006-reviewed mappings and existing targets from `lib/core/constants/wardrobe_taxonomy.dart`; preserve source-to-rule traceability and quarantine uncertainty without fuzzy guesses or taxonomy growth.
- [ ] T018 [US2] Implement metadata profiling and disposition reporting in `tooling/fashion_catalog_mapper/lib/profile_report.dart`; assign exactly one record-level disposition per record and report field-level outcomes separately, tie the report to manifest/mapping versions and readiness/activity-rights statuses, and emit no raw rows or image content.
- [ ] T019 [P] [US2] Add compatibility tests in `test/tooling/fashion_catalog_mapper/affinity_compatibility_test.dart` against the current `assets/ml_seed_rules.json` and `AffinityEngine` metadata; verify proposed mapped signals match existing rule dimensions without changing the asset, engine, or feature `002`.
- [ ] T020 [US2] Implement an optional rule-metadata adapter in `tooling/fashion_catalog_mapper/lib/affinity_metadata.dart` only if T008 approves the activation semantics; do not pass catalog records to `AffinityEngine.score`, construct `ClothingItem`, or change user wardrobe data.

**Checkpoint**: Synthetic mappings and reports are reproducible and fully accounted for; any real-data mapping remains blocked until T003-T007 and the corresponding T004 permission are verified.

---

## Phase 6: Polish and Gated Verification

**Purpose**: Run project checks and only then measure approved metadata performance.

- [ ] T021 Run the focused mapper tests, `flutter analyze`, and `flutter test` for the implementation in `test/tooling/fashion_catalog_mapper/` and `tooling/fashion_catalog_mapper/`; record failures without changing unrelated files or dependencies.
- [ ] T022 [P] After T003-T007 are verified, T004 explicitly approves profiling/mapping, and a reference workstation is documented in `specs/003-fashion-training-data-mapping/benchmark-results.md`, benchmark up to 50,000 approved metadata records against the two-minute target; exclude image processing and record environment/results without exporting source rows.
- [ ] T023 Update `AUDIT_TRACKING_PLAN.md` with validation evidence, remaining risks, and blocked checks, and `PROJECT_HISTORY.md` with the implementation delta and next actions whenever implementation status or evidence changes; do not mark real-data stages complete while their gates remain unresolved.

---

## Dependencies and Execution Order

### Gate Dependencies

- T008 is the prerequisite scheduling decision for all implementation, including T001 and T002. After T008 approves scheduling under `FEATURE_PLANS.md`, Phase 1 is synthetic-only and T001/T002 can run in parallel.
- Phase 2 records decisions/evidence and blocks real source use. T003-T005 are independent evidence requests; T006 depends on verified source/schema and applicable permissions; T007 is the explicit local-output decision; T008 records product scope and scheduling priority before implementation begins.
- Phase 3 gate code and its synthetic tests do not require real rows. T011 may open rows for profiling only after T003-T005, profiling-specific T004 approval, and the provider-backed schema contract in T006 are verified; mapping still requires approved mapping entries and mapping-specific permission.
- Phase 4 can validate boundaries with synthetic data. Real report output additionally depends on T007.
- Phase 5 synthetic tests may be authored before gates, but mapping implementation requires T006 and the applicable T004 approval; real-row profiling/mapping additionally requires T003-T005 and T007. Rule activation additionally requires T008.
- Phase 6 project checks follow implementation. T022 is blocked until all listed evidence, approvals, and the reference environment exist. T023 records the applicable traceability updates before the feature is marked complete.
- Model fitting and image use are not implementation tasks in this backlog; they remain deferred pending a product decision and separate activity-specific rights approval.

### Story Order and Parallel Opportunities

- User Story 1 (P1) readiness and permitted-use gates are the prerequisite for any real-data operation.
- User Story 3 (P1) local-only and closet-separation boundaries can be developed with synthetic data independently of mapping.
- User Story 2 (P2) synthetic mapping/profile work can proceed independently after the safety setup; any real-data run or rule activation remains subject to the gates above.
- Within User Story 1, T009 can be authored alongside the Phase 1 ignore-policy check; gate implementation follows the tests.
- Within User Story 3, T012 can be authored alongside synthetic User Story 2 tests; runner/report implementation follows boundary tests and T007 where real outputs are involved.
- Within User Story 2, T015, T016, and T019 target separate test files and can be authored in parallel; mapper/profile implementation follows the corresponding synthetic tests and evidence decisions.

### Parallel Example: User Story 2

```text
T015 test/tooling/fashion_catalog_mapper/mapping_test.dart
T016 test/tooling/fashion_catalog_mapper/report_test.dart
T019 test/tooling/fashion_catalog_mapper/affinity_compatibility_test.dart
```

These test tasks use synthetic fixtures or the existing local rule asset only. They do not read `training_data/`, access the network, or change the affinity asset.

## Implementation Strategy

1. Start with the synthetic readiness tests and the non-mutating ignore-policy check; keep all incoming data untouched.
2. Resolve provenance, activity-specific permissions, provider-authoritative completion evidence, mapping/schema decisions, local output/retention, and product scope as blocking records.
3. Implement and test fail-closed readiness/rights gates and local-only/closet-separation boundaries using synthetic fixtures.
4. Implement deterministic profile and mapping against reviewed values and current DLS taxonomy/rule metadata; keep unmappable values visible and do not activate recommendation changes without T008 approval.
5. Run Flutter validation. Benchmark only after the explicit approvals and reference-environment gate; do not train a model or process images under this backlog.

## Phase 7: Convergence

- [ ] T024 Validate the opt-in `training-data-test` Compose harness as developer tooling: confirm its profile, `network_mode: none`, read-only `/training_data` mount and environment, and `.dockerignore` build-context exclusion; run its offline dependency resolution, `flutter analyze`, and existing `flutter test --concurrency=1` suite and record results. Confirm the service and tests do not parse, profile, map, hash, or train on mounted real files. Do not inspect source contents or treat this check as readiness or rights approval; actual data use remains blocked by T003-T008 and activity-specific permissions. per plan: Stage 6 verification and handoff (partial)

## Independent Test Criteria

- **User Story 1**: Synthetic incomplete, stale, changed, inconsistent, unknown-rights, and denied-rights cases produce specific blocked reasons before the parser is called; only complete evidence plus permission for the requested activity advances.
- **User Story 3**: A synthetic run with network disabled/instrumented makes no external, Firebase, GitHub, or analytics request, creates no user closet data or app asset, fetches no image URL, and emits no raw source rows.
- **User Story 2**: Identical synthetic approved inputs yield identical reports; every field/record is explicitly dispositioned; mapped values are already present in DLS taxonomy/rule metadata; ambiguity is never silently mapped.