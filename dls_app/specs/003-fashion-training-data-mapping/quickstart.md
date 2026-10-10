# Quickstart: Planning Validation Guide

This guide defines the validation scenarios for the eventual local mapper. The mapper is not implemented by this planning change, so commands below are acceptance targets, not commands verified to exist today. No real dataset is needed or permitted for the initial test slice.

## Prerequisites

- Flutter/Dart project toolchain matching `pubspec.yaml` (Dart SDK `>=3.3.0 <4.0.0`).
- Synthetic fixture rows only for development and CI.
- Before a real-data run: explicit completion attestation, authoritative stable manifest, and reviewer-recorded rights approval for every requested activity.
- A local report destination outside `training_data/`, confirmed ignored or outside the repository. The input remains read-only.

## Validation Scenarios

1. **Fail closed before completion**: With no explicit completion signal, readiness fails with a missing-evidence reason; assert that the row parser is never invoked.
2. **Fail closed on manifest drift**: Synthetic cases with a missing/unexpected file, changed checksum, or inconsistent row count fail before mapping and identify the mismatch.
3. **Fail closed on rights**: Unknown or denied permission blocks the associated profile, rule-mapping, training, or image operation independently; no output claims legal usability.
4. **Deterministic metadata mapping**: Run the same synthetic approved fixture and versioned rules twice; compare mapped values, disposition reasons, report counts, and serialized output.
5. **Ambiguous-value quarantine**: Include missing, unsupported, malformed, conflicting, and multi-match values; verify explicit quarantine/rejection and zero invented taxonomy values.
6. **Closet separation**: Assert that mapping never constructs `ClothingItem`, calls a closet repository, assigns `userId`/ownership timestamps, or creates user inventory.
7. **No-egress boundary**: Run with network access instrumented/disabled; assert no Firebase, GitHub, API, analytics, or remote-image request is attempted and URL text is not fetched.
8. **Accounting and performance**: Reconcile all synthetic fixture records across accepted/quarantined/rejected/not-reviewed totals. Only after approval, benchmark up to 50,000 metadata records on the agreed reference workstation; exclude image processing.

## Planned Local Checks

After implementation tasks establish the tooling and test locations, run the focused synthetic mapper tests first, followed by:

```powershell
flutter test test/tooling/fashion_catalog_mapper/
flutter analyze
flutter test
```

The focused test path is a proposed implementation target and must be aligned with the files actually created in the tasks phase. Do not run a real-data command until all applicable evidence gates pass. Before any eventual real-data run, verify the root ignore rule with `git check-ignore -v` for representative input paths and confirm that no output is written beneath `training_data/`.

## Expected Result

Without complete manifest evidence or applicable rights approval, the run exits blocked with a specific reason and consumes no rows. With approved synthetic inputs, repeated runs produce identical reports, account for all values, quarantine uncertainty, and leave app assets, Firebase, analytics, and user closets unchanged.
