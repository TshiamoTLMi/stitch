---
description: "Implementation tasks for the on-device adaptive outfit engine + 300+ item seed wardrobe"
---

# Tasks: On-device adaptive outfit engine + 300+ item seed wardrobe

**Input**: Design documents from `specs/002-on-device-outfit-engine/`

**Execution rule**: Tests precede implementation where behaviour is new. Manual/external gates
are listed separately and are never marked passed by source inspection alone.

## Phase 1: Audit and SpecKit reconciliation

- [x] T001 Audit `lib/`, `assets/`, `test/`, `integration_test/`, `pubspec.yaml`, rules, and the
  existing SpecKit; classify implemented / partial / missing / conflicting / reusable.
- [x] T002 Record dataset provenance BEFORE generating data (source, licence, attribution,
  redistribution status). Result: Europeana Fashion - MoMu Thesaurus drawings, CC0 1.0.
- [x] T003 Create `specs/002-on-device-outfit-engine/spec.md`, `plan.md`, `tasks.md`.

## Phase 2: Seed dataset (foundational)

- [x] T004 Add deterministic seed generator `tooling/seed_generator/main.dart` importing the
  real taxonomy from `lib/core/constants/wardrobe_taxonomy.dart` (no duplicated enums).
- [x] T005 Generate `assets/seed/wardrobe_seed.json` with >=300 items and stable UUIDv5 ids.
- [x] T006 Generate `assets/seed/dataset_manifest.json` with truthful provenance.
- [x] T007 Register `assets/seed/` in `pubspec.yaml`.
- [x] T008 Generator self-validation: item count, unique ids, enum conformance, CC0-only image
  references (fails loudly).

## Phase 3: Affinity rule matrix

- [x] T009 Author `assets/ml_seed_rules.json` with >=100 rules across the five implemented
  dimensions: `categoryCompatibility`, `styleEventAffinity`, `weatherSuitability`,
  `colorHarmony`, `defaultWeights`. Layering is carried inside
  `categoryCompatibility` (layered structure profiles) and inside
  `weatherSuitability` (per-class `layering` / `sleeve` / `waterproof` fields plus the
  `layeringNeeded` hint on each weather condition) rather than a separate
  `layerCompatibility` dimension. Implemented: 127 rules.
- [x] T010 Unit test the rule matrix in `test/core/engine/rules_matrix_test.dart`
  (JSON parse, taxonomy enum alignment, symmetric colour matrix, weight sum = 1.0,
  rule count >= 100, pubspec asset registration).

## Phase 4: Weather (US: context sensitivity)

- [ ] T011 Add `lib/models/weather_context.dart` + `lib/services/weather_service.dart`
  (Open-Meteo via existing `http`, local cache via `path_provider`, neutral fallback).
- [ ] T012 Test cache hit, cache miss + offline, and neutral default.

## Phase 5: Affinity engine (US: explainable local fit)

- [x] T013 Add `lib/core/engine/affinity_engine.dart` with normalised weighted scoring
  `w_style*S + w_event*E + w_weather*W + w_color*C + w_category*K` -> 0-100. Implemented as a
  pure, synchronous class (isolate-ready) that loads `assets/ml_seed_rules.json` at runtime.
- [x] T014 Support variable structures: `standard`, `outerwear_layered`, `one_piece`,
  `one_piece_layered`, plus layered/context profiles in the rule matrix. Structural
  validation rejects missing/duplicate footwear, multiple tops/bottoms/one-pieces/layers and
  overlapping dress+top or dress+bottom combinations.
- [x] T015 Expose a real `Style Match` percentage (no random/hardcoded scores), rendered by
  `outfit_generator_page.dart` together with the engine's own reason.
- [x] T016 Tests in `test/core/engine/affinity_engine_test.dart` (23 tests): rule loading,
  structural acceptance/rejection, score bounds over 42 candidate/context combinations,
  determinism, occasion and weather ranking, colour harmony, explainability hooks.
- [x] T017 Add `lib/core/engine/feedback_store.dart` with
  `W_new = W_old + 0.1 x (Feedback - W_old)`, clamped to `[0.0, 1.0]`, persisted to
  `<app documents>/user_weights.json` via a temp-file + atomic rename.
- [x] T018 Update ONLY the dimensions implicated by `AffinityBreakdown.contributions`
  (`cc-*` -> category, `style:*` -> style+event, `weather:*` -> weather, `color:*` -> colour),
  then re-normalise the vector to sum 1.0. Verified by test.
- [x] T019 Tests in `test/core/engine/feedback_store_test.dart`: default initialisation from the
  rule matrix, the documented worked examples, clamping, re-normalisation, contribution
  mapping, 200-iteration stability, atomic write, persistence across instances, corrupt-file
  recovery.

## Phase 6: Feedback adaptation (US: adaptive learning)

- [ ] T017 Add `lib/services/outfit_weight_store.dart` with
  `W_new = W_old + 0.1 x (Feedback - W_old)`, clamped to `[0.0, 1.0]`, persisted locally.
- [ ] T018 Update ONLY the affinities that contributed to the displayed recommendation.
- [ ] T019 Tests: like, dislike, persistence, clamping bounds.

## Phase 7: Seeding + dev/prod separation

- [x] T020 Add `lib/core/engine/candidate_generator.dart` (seed loader for runtime wardrobe
  injection lands in Phase 7). Partitions the wardrobe into slot buckets, pre-ranks each bucket
  with `AffinityEngine.itemPrior`, generates combinations for the four canonical templates,
  validates and scores them, and returns `ScoredOutfit`s sorted by Style Match.
- [x] T021 Candidate pruning verified: per-bucket cap (default 4) plus a scored-list cap
  (default 60) keep a 332-item wardrobe bounded and deterministic.
- [x] T022 Candidate generation tested against the real 332-item seed dataset in
  `test/core/engine/candidate_generator_test.dart` (every candidate passes structural
  validation, sorted descending, deterministic, occasion/weather change the winner).

## Phase 8: UI + offline

- [ ] T024 Additive `outfit_generator_page.dart` update: structured layout, Style Match,
  Like/Dislike. Document in `SCREENS.md` first if layout/tokens change.
- [ ] T025 Verify offline recommendation path (no network, no AI).
- [ ] T026 Move `OutfitImageService` off the local render path (avoid HTTP in core flow).

## Phase 9: Polish, evidence, SpecKit sync

- [ ] T027 Run `flutter analyze` + `flutter test`; record results.
- [ ] T028 Update `PROJECT_HISTORY.md`, `AUDIT_TRACKING_PLAN.md`, `SCREENS.md`.
- [ ] T029 Update this SpecKit to reflect what was ACTUALLY implemented.

## Dependencies

- Phase 3 depends on Phase 2 (rules reference taxonomy + seed).
- Phases 4-6 are independent of each other after Phase 3.
- Phase 7 depends on Phases 2-6.
- Phase 8 depends on Phases 5-7.
- Phase 9 last.

## Deferred / accepted risks

- Local image bundling (offline image rendering) - follow-up slice.
- `geolocator` not added; default location used.
