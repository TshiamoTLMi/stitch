# Implementation Plan: On-device adaptive outfit engine + 300+ item seed wardrobe

**Branch**: `002-on-device-outfit-engine` | **Date**: 2026-09-29 | **Spec**: [spec.md](spec.md)

## Summary

Extend the existing generator rather than replace it. Reuse `ClothingItem`,
`WardrobeRepository`, the Provider graph, and `WardrobeService`. Add a deterministic seed
generator, a local-first weighted affinity engine with variable-length outfit structures, a
local feedback weight store with the specified adaptation formula, and a cached Open-Meteo
weather context. No paid API, no new backend, no duplicate model.

## Technical Context

**Language/Version**: Dart 3.3+ (`sdk: '>=3.3.0 <4.0.0'`), existing Flutter SDK.

**Primary dependencies (all already present - no additions)**:
`provider`, `http`, `uuid`, `path_provider`, `image`, `cloud_firestore`, `connectivity_plus`.

**Storage**:
- User records: Firestore via existing `WardrobeService` / repositories (UID-scoped).
- Seed wardrobe + rules: bundled Flutter assets (`assets/seed/wardrobe_seed.json`,
  `assets/ml_seed_rules.json`).
- Local feedback weights + weather cache: JSON file via `path_provider`
  (no `shared_preferences`/Hive/sqflite needed).

**Testing**: `flutter_test` for engine/feedback/rules units; generator self-validation
(300+ items, unique ids, enum conformance); `flutter analyze`; existing
`tooling/preflight_check.ps1`.

**Target Platform**: Android + Web. iOS/macOS remains a macOS-only limitation.

**Deliberately NOT used**: `geolocator` (avoids a new dependency + runtime permission); a
configured/default location is used instead.

## Constitution Check

| Principle | Result | Evidence / plan response |
|---|---|---|
| I. User-value-first incremental delivery | PASS | Independently testable slices; no unrelated roadmap work. |
| II. Screen and design contract | PASS | UI work is additive; `SCREENS.md` is updated before visual/behavioural changes. |
| III. Test-gated quality and validation evidence | PASS | Generator self-validation + focused tests + `flutter analyze` / `flutter test`; evidence recorded in `AUDIT_TRACKING_PLAN.md`. |
| IV. Firebase security and user scoping | PASS | Seed rows use a synthetic `seed` owner id and are never written to real users; no rule changes required. |
| V. Explainable and offline-tolerant recommendations | PASS | Local weighted engine is the primary path; LLM remains optional; reasons are user-facing. |
| Data behaviour (loading/empty/error/offline) | PASS | Weather and feedback degrade explicitly to cached/neutral states. |

## Reuse decisions (no duplication)

1. `lib/models/clothing_item.dart` is the **single** seed + runtime item model.
2. `lib/core/constants/wardrobe_taxonomy.dart` is the **single** enum source; the generator
   imports it directly (`package:dls_app/...`) so definitions cannot drift.
3. `WardrobeRepository.seedLocalItems()` + `cachedItems` remain the local insert/read path.
4. `Outfit` / `OutfitResult` are extended for variable structures - not replaced.
5. No second database, repository, Choice Bot, or sync system is introduced.

## Project Structure

```
tooling/seed_generator/main.dart          (NEW) deterministic seed + manifest generator
assets/seed/wardrobe_seed.json            (NEW) generated 300+ item dataset
assets/seed/dataset_manifest.json         (NEW) provenance / licence record
assets/ml_seed_rules.json                 (NEW) >=100 affinity rules (6 dimensions)
lib/services/weather_service.dart         (NEW) Open-Meteo + cache + neutral fallback
lib/models/weather_context.dart           (NEW) DLS weather domain model
lib/services/outfit_affinity_engine.dart  (NEW) normalised weighted scoring + structures
lib/services/outfit_weight_store.dart     (NEW) local feedback weights (adaptation)
lib/services/seed_wardrobe_loader.dart    (NEW) asset loader for seed + rules
lib/services/mock_wardrobe_seeder.dart    (NEW) dev-only seeder
lib/views/home/outfit_generator_page.dart (EDIT) additive: style match, structures, feedback
test/...                                  (NEW) dataset / engine / feedback / offline tests
```

## Known conflicts to reconcile (from the audit)

- `OutfitImageService` fetches `imageUrl` over HTTP - must not sit on the local render path.
- `DemoDataService` uses hardcoded Unsplash URLs - superseded by the seed dataset.
- Two overlapping scorers (`OutfitBotService._scoreItem` vs `RuleEngine._itemScore`) are
  consolidated behind the new affinity engine (existing paths retained as fallback).

## Validation strategy

| Area | Automated | Manual / external |
|---|---|---|
| Dataset | Generator asserts 300+, unique ids, enum conformance, CC0-only image refs | Spot-check image URLs resolve (4 verified 200 image/jpeg) |
| Engine | Unit tests for each scoring dimension + structure selection | Visual check of rendered structures |
| Feedback | Unit tests for adaptation + clamping + persistence | Like/Dislike in app |
| Weather | Unit tests for cache/neutral fallback | Live Open-Meteo when online |
| Production safety | Unit test that seeding is skipped outside dev/demo | - |
