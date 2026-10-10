# Implementation Plan: Fashion Training Data Mapping

**Branch**: `003-fashion-training-data-mapping` | **Date**: 2026-10-09 | **Spec**: [spec.md](spec.md)

## Summary

Plan a gated, local-only metadata profiling and deterministic mapping path for the incoming fashion catalog. Mapping targets the existing `ClothingItem` field vocabulary, `categoryTaxonomy` and related helpers in `lib/core/constants/wardrobe_taxonomy.dart`, and the current local `AffinityEngine` rule dimensions. Catalog rows remain a separate data domain: the implementation must not construct or persist catalog-backed `ClothingItem` instances, create closet inventory, or send source data off-device. The input folder is still loading and unverified; no readiness or rights claim is made by this plan.

The first implementation is developer tooling and synthetic-fixture tests. Reading real catalog rows, producing a real-data mapping, or making mapped signals affect app recommendations remains blocked until the relevant completion, manifest, provenance, and use-approval gates pass. Model fitting, image inspection/training, image fetching, redistribution, and new backend/UI paths are out of scope.

## Technical Context

**Language/Version**: Dart 3.3+ and the existing Flutter project toolchain.

**Primary Dependencies**: Existing project dependencies and `flutter_test`; no dependency additions are assumed. Select any CSV parsing dependency only after the approved source schema is known and its need is demonstrated.

**Storage**: Read-only local source. Reports and any derived rule metadata must be written to an explicitly configured local destination outside `training_data/`, excluded from source control, and never registered as app assets or user data.

**Testing**: Synthetic fixture unit tests first; readiness/manifest tests, deterministic mapping and disposition tests, local-only boundary tests, `flutter analyze`, and `flutter test`. Do not use the incoming dataset as a test fixture.

**Target Platform**: Local developer workstation (Windows is the current planning environment). Existing Android/Web app targets are not changed by this feature plan.

**Project Type**: Flutter/Dart mobile and web application with local developer tooling.

**Performance Goals**: The spec's target is profiling and mapping an approved, stable metadata set of up to 50,000 records within two minutes on the agreed reference development environment, excluding image processing. The reference environment remains to be specified and benchmarked.

**Constraints**: Local-only; no network access or external service calls; no image processing; no application/backend/analytics egress; no writes to the incoming data folder; no user closet mutation; no guessed taxonomy values; fail closed on missing, stale, inconsistent, or unapproved evidence.

**Unresolved gates**: Exact source/version/attribution/license/terms and permitted activities; provider-authoritative completion signal, inventory, checksums and counts; exact meaning of “train”; approved source-to-DLS rules; output retention/location; and benchmark environment. These are blocking decisions, not assumed defaults.

## Constitution Check

| Principle / constraint | Result | Evidence and plan response |
| --- | --- | --- |
| I. User-value-first incremental delivery | PASS, gated | Synthetic readiness cases provide an independently testable first slice, but implementation is not scheduled until this feature is placed in `FEATURE_PLANS.md` and higher-priority release work is respected. |
| II. Screen and design contract | PASS | No screens, navigation, or visual contract changes are planned. |
| III. Test-gated quality and validation evidence | PASS, gated | Fail-closed tests and Flutter analysis/tests are required before implementation claims; real-data checks require approved evidence. |
| IV. Firebase security and user scoping | PASS | No Firebase reads/writes or user identifiers; catalog records are never user-owned closet items. |
| V. Explainable and offline-tolerant recommendations | PASS | Mapping is deterministic and local; only explicit, reviewable rule metadata may inform the existing engine. |
| VI. Observability and audit traceability | PASS, gated | Local reports record source-manifest and mapping versions, readiness/rights states, coverage, dispositions, and reasons without exporting source rows. Implementation status, validation evidence, risks, and next actions are recorded in `AUDIT_TRACKING_PLAN.md` and `PROJECT_HISTORY.md` when they change. |
| VII. Simplicity and maintainability | PASS | Reuse the existing taxonomy and affinity rules; no second closet model, database, backend, or ML stack. |
| Additional data, platform, and configuration constraints | PASS, gated | Source stays local and outside release assets; Android/Web behavior is unaffected. Rights and completion gates prevent real-data use before approval. |

**Gate disposition**: No constitutional exception is requested. The above pass applies to the proposed bounded design; it does not authorize access to the incoming dataset or resolve legal/product questions.

## Delivery Stages

| Stage | Scope | Verification / exit condition |
| --- | --- | --- |
| 0. Scheduling and safety hold | Before any implementation, place the feature in `FEATURE_PLANS.md` and confirm higher-priority release work permits it; then keep the input read-only and local and confirm ignore protection without reading data. | No implementation begins before the roadmap decision. Once scheduled, synthetic tests prove the readiness path blocks before any row parser is invoked. |
| 1. Provenance and use approval | Record source identity/version, attribution, license/terms evidence, reviewer, and separate decisions for metadata profiling, mapping/rule use, model training, image use, and redistribution. | Every activity required by the requested operation has explicit approval; unknown/denied activities remain blocked. No legal usability assertion is made by the tool. |
| 2. Completion and manifest validation | Require provider/loading-workflow completion evidence, provider-documented schema identifier, stable expected file inventory, per-file checksums, and authoritative row/item counts. Validate consistency before opening rows. | Missing, stale, changed, unexpected, or inconsistent evidence fails closed with a specific reason. Local discovery alone cannot prove completeness. |
| 3. Local metadata profile | After readiness, provider schema, and activity-specific profiling approval pass, profile counts, missingness, duplicates, malformed values, and candidate field coverage without fetching image URLs. | A deterministic report is tied to the validated manifest, states readiness and profiling-rights review status, and distinguishes per-record dispositions from per-field outcomes without dumping raw rows. |
| 4. Deterministic mapping | After mapping-specific permission and explicit mapping decisions are approved, map canonical DLS category, color/color-group, season, gender, and style signals; derive category type only from a mapped category via the existing helper. Fit is out of scope. Quarantine unsupported, conflicting, ambiguous, or absent values. | Repeated runs on identical approved inputs produce byte-stable normalized results/reasons; no fallback guesses or taxonomy additions. |
| 5. Rule-engine compatibility | Emit only approved, canonical rule metadata/priors for the existing local `AffinityEngine`; do not treat product examples as inventory or modify user data. | Synthetic tests exercise compatibility with existing rule dimensions and verify no `ClothingItem` construction, closet/repository calls, network calls, or image fetches. Any recommendation-affecting activation requires reviewed mapping and regression evidence. |
| 6. Verification and handoff | Run focused mapper tests, `flutter analyze`, and `flutter test`; measure the approved 50,000-record scenario on the agreed reference environment. | Record results and remaining gates. Do not describe incomplete/unapproved data as mapped, trained, or production-ready. |

Roadmap placement and planning can proceed without the incoming dataset. Implementation of Stage 0, including synthetic tests, begins only after the feature is scheduled in accordance with `FEATURE_PLANS.md`. Stages 1-5 cannot consume real source rows until their applicable evidence and approval gates are satisfied. Model training and all image use remain deferred pending explicit product clarification and permission.

## Project Structure

### Planning artifacts

```text
specs/003-fashion-training-data-mapping/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
└── quickstart.md
```

### Proposed implementation areas (not created by this planning task)

```text
tooling/fashion_catalog_mapper/       # local-only readiness, profile, mapping tool
test/tooling/                         # synthetic fixture and boundary tests
test/fixtures/fashion_catalog/         # synthetic rows only; never source data
lib/models/clothing_item.dart         # existing field vocabulary; no catalog instances
lib/core/constants/wardrobe_taxonomy.dart
lib/core/engine/affinity_engine.dart  # existing rule dimensions; local-only compatibility
```

No `contracts/` directory is proposed: the feature exposes no external API, and a private developer tool's command interface can be finalized with implementation tasks once the approved source and workflow are known. No files in `training_data/`, app assets, Firebase configuration/rules, or feature `002` are in scope for this plan.

**Structure Decision**: Keep the mapper in isolated Dart developer tooling, reuse the existing taxonomy and rule engine as references, and test with synthetic fixtures. Do not place data processing in closet services or UI flows.

## Complexity Tracking

No constitution violations or exceptions are identified.
