# Research: Fashion Training Data Mapping

**Status**: Planning research complete for repository architecture. Source provenance, permitted use, completion evidence, and product meaning remain explicit blocking decisions; research has not established them.

## Decisions

### R-001: Treat the catalog as a separate domain, not as `ClothingItem` instances

**Decision**: The mapper may map approved values to the canonical field vocabulary but must not create, serialize, or persist a `ClothingItem` from a catalog row.

**Rationale**: `lib/models/clothing_item.dart` requires `userId`, ownership status, and user timestamps, and `toMap()` includes Firestore-oriented fields. Supplying synthetic ownership values would blur catalog products with a user's actual closet. The source record and its mapping result therefore stay separate from the existing user-owned model.

**Alternatives considered**: Reuse `ClothingItem` as a convenient catalog DTO (rejected: it fabricates ownership semantics and permits unintended persistence); create a second closet model (rejected: unnecessary duplication).

### R-002: Reuse, do not duplicate, DLS taxonomy values

**Decision**: Treat `categoryTaxonomy`, `styleTagOptions`, `seasonOptions`, `genderOptions`, `deriveCategoryType`, and `deriveColorGroup` in `lib/core/constants/wardrobe_taxonomy.dart` as the canonical mapping targets. `categoryType` may be derived only after its source category has been explicitly mapped; fit mapping is excluded until a suitable approved source field and decision exist.

**Rationale**: This keeps the mapping aligned with the current application and prevents source vocabulary from silently expanding DLS taxonomy. Existing helpers may have defaults for user-entry flows; the mapper must not use those defaults to accept unknown catalog values.

**Alternatives considered**: Define parallel catalog enums or extend taxonomy from observed data (rejected: drift and unsupported values would become implicit app behavior).

### R-003: Keep affinity use within the current local rule engine

**Decision**: Any accepted output that informs recommendations must be explicit rule metadata/priors compatible with `lib/core/engine/affinity_engine.dart` and its existing dimensions. Catalog products are not candidate outfits or wardrobe inventory.

**Rationale**: The current engine is synchronous and local, but scoring accepts `List<ClothingItem>`. Rule metadata is the only safe planned path for catalog-derived influence without manufacturing owned items. The exact semantics and activation point for mapped signals remain reviewable implementation decisions.

**Alternatives considered**: Pass catalog examples through `score()` as clothing items (rejected: violates data ownership); add model training or a remote recommender (rejected: explicitly out of scope and rights/product intent unresolved).

### R-004: Fail closed on readiness and rights

**Decision**: Require an explicit loading-complete attestation plus an authoritative expected file inventory, stable per-file checksums, authoritative row/item counts, and a provider-documented schema identifier. Separately require documented approval for each intended activity. Profiling may read rows only after its own permission, readiness, and schema gates pass; mapping additionally requires approved mapping rules.

**Rationale**: A manifest generated solely by scanning whatever happens to be on disk cannot prove that loading is finished or that expected files are present. A schema identifier lets a profile reader validate structure before parsing records. Rights for profiling, mapping/rule use, model training, image use, and redistribution may differ.

**Alternatives considered**: Infer completeness from directory presence, observed row count, or stable checksums alone (rejected: none is provider-authoritative); treat one general approval as permission for all uses (rejected: activities differ).

### R-005: Keep processing and outputs local

**Decision**: Real-data reads, when gated and later implemented, must be offline, read-only against the incoming folder, and must not fetch or redistribute image URLs. Reports must be written outside the input folder to a local destination verified as untracked/ignored.

**Rationale**: The root `.gitignore` protects `/training_data/`; metadata-only Git checks confirmed that representative existing CSV and JSON paths match the ignore rule and that no `training_data/` paths are tracked at the time of planning. A separate output destination avoids modifying incoming material; implementation must recheck ignore status and the absence of network paths.

**Alternatives considered**: Bundle source or reports as app assets, write reports beside source files, or upload for analysis (rejected: violates stated data boundaries).

### R-006: Start with synthetic fixtures and deterministic reports

**Decision**: Build readiness, mapper, and boundary tests from authored synthetic fixtures. Tie real reports to manifest and mapping versions and account for every disposition: accepted, quarantined, rejected, or not reviewed.

**Rationale**: The incoming dataset is still loading, and no completeness or rights conclusion may be inferred from its presence. Synthetic tests can establish behavior without reading it.

**Alternatives considered**: Use current incoming rows as fixtures or inspect images to infer labels (rejected: premature, unapproved, and unnecessary for the metadata-only first stage).

## Decisions Still Required (Blocking)

| Decision | Required evidence / owner input | What remains blocked |
| --- | --- | --- |
| Exact source, version, attribution, license, and terms | Source/provider documentation and a reviewer-approved record | All source use until the exact activity is approved; no legal conclusion is implied. |
| Permitted activities | Explicit decision per local profiling, taxonomy mapping/rule use, model training, image analysis, and redistribution | Any activity without explicit approval. |
| Dataset completion evidence | Loading workflow/provider attestation, expected inventory, stable checksums, and authoritative row/item counts | Parsing or mapping real rows. |
| Meaning of “train the outfit engine” | Product decision: deterministic mapping, rule tuning, ML fitting, or another outcome | Rule-affecting activation beyond the approved metadata-mapping scope; all ML fitting remains deferred. |
| Source schema and mapping rules | Approved field definitions and explicit unambiguous value map for each target | Mapping affected values; unsupported or ambiguous values remain quarantined. |
| Local report destination and retention | Developer workflow decision and verification that destination is outside input and untracked | Writing real-data reports. |
| Performance reference environment | Named machine/toolchain and representative approved 50,000-row input | Claiming the two-minute success criterion. |

## Evidence Boundary

Repository source inspection covered the existing model, taxonomy, affinity engine, tests, feature `002` planning material, and Flutter/Dart project configuration. A limited directory listing showed a nested `fashion-dataset` layout with duplicated CSV filenames and `images/` and `styles/` folders; the workspace index reported roughly 47,000 paths, which is not a completeness check. Only the first few lines of the outer `styles.csv` and `images.csv` were read to identify headers and sample metadata/URL shape. No full CSV was parsed, no files were hashed, and no image was opened or processed. The sample image URLs use `assets.myntassets.com`; exact source/version, license, terms, and rights remain unknown. Loading may still be in progress, so no conclusion about completeness or permitted use is made. Git metadata checks confirmed the root ignore rule matches representative existing CSV and JSON paths, and `git ls-files -- training_data` returned no tracked source paths at the time of review.
