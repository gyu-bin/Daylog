# Phase 2.1 preservation check

Compared every entry in `before-hashes.json` with the current file using SHA-256. The three saved before-source snapshots also match their corresponding baseline hashes.

| Check | Result |
| --- | --- |
| Baseline files checked | 553 |
| Byte-identical files | 550 |
| Changed baseline files | 3 |
| Missing baseline files | 0 |
| Baseline PNGs unchanged | 130 / 130 |
| Approved wardrobe PNGs unchanged | 14 / 14 (basic + 13 costumes) |

The exact changed baseline files are:

1. `Daylog/App/RootView.swift` — DEBUG-only diagnostic navigation branch; original application navigation body is preserved.
2. `Daylog/Components/PioOutfitMotion.swift` — DEBUG passive counters, weak active-rig registry and measured-layout telemetry; existing animation/layout behavior remains unchanged.
3. `DaylogTests/PioOutfitMotionTests.swift` — weak-registry/reset/deallocation test.

One new application source file is `Daylog/Components/PioOutfitDiagnosticsView.swift`, wholly DEBUG-gated. This phase's QA documents, scripts, screenshots and measurements are separate review artifacts.

The inventory also found five Xcode workspace/scheme metadata files absent from the baseline. They are listed as **unbaselined**, not newly changed: the baseline covered `project.pbxproj`, not the whole Xcode metadata tree. Package.resolved and the two shared schemes are already Git-tracked. Their preservation cannot be inferred from this incomplete metadata baseline.

Within the baseline, wardrobe/shop state and views, approved PNGs, existing growth/dashboard integration, AppStore/business logic, configuration, privacy manifest, project.pbxproj and unrelated captured files remain byte-identical. This is a source/artifact preservation check; it does not inspect or certify production application data, which this reviewer did not access.

`preservation-check.json` contains before/current hashes for changed files, the approved wardrobe PNG hashes, the unbaselined-file list, and comparison timestamp. No files were repaired, replaced, deleted or reverted by this review.
