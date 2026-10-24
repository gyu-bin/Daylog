# Existing native image review — 2026-10-24

Verdict: **PARTIAL**, missing independent source art remains **BLOCKED_ASSET**. This review opened 56 existing PNGs: 14 standing neutral rigs at 220pt, 14 cloud receiving/light/Reduce Motion frames, and 28 neutral vacation day/night scenes. These are reused prior native renderer evidence, not new captures or a new app build. The [gallery](review.html) links each exact PNG; SHA/dimensions are in [inventory.json](inventory.json).

## Findings

### P1 verification defect — four historical Basic cloud fixture images are invalid display evidence

Historical files under `docs/qa/pio-scenes-integration-2026-10-23/native-cloud-final/`:

- `cloud-basic-receiving-light-reduce-motion.png`
- `cloud-basic-receiving-dark-reduce-motion.png`
- `cloud-basic-trouble-light-reduce-motion.png`
- `cloud-basic-trouble-dark-reduce-motion.png`

The Basic receiving/light image was opened and is visibly empty below the cloud arrow. Fixture `DaylogTests/PioSceneNativeEvidenceTests.swift` historically forced `usesIndependentCharacter: true` for every outfit. That selects the independent seated path even though Basic has no `pio_cloud_basic_body`. The other three share that test branch; they must not count as valid Basic seated display coverage. This finding is about fixture provenance, **not proof of an actual SwiftUI fallback bug**. Actual `RoutimoriSyncScene` uses `PioCloudSceneResources.hasSeatedLayers` and can retain the original Basic pose. Existing `routimori_sync_loading.png` and `routimori_sync_failure.png` both exist at 1254×1254 RGBA; unchanged copies are included here. Keep the failed historical evidence; any corrected fixture/native recapture should be reported separately by its owner.

### P1 missing art — genuine seated/reclining hand and eye motion cannot be signed off

All 13 paid cloud neutral images retain the seated tablet pose and recognizable costume. Their existing independent eye assets are real; hand/tablet/feet/clothes are still one body bitmap. All 28 vacation images retain their actual reclining pose; eyes/arms/props/hammock/ropes are flattened together. No neutral screenshot or whole-image rotation proves an independent shoulder, blink, sip or fixed-knot rig. The exact six unfulfilled groups and recoverability limits are recorded in the spec/inventory. This is a delivery gap, not a demand to replace good artwork with programmatic shapes.

### P2 authored continuity — Christmas gift swaps side across day/night

The day native scene places the gift on viewer-left beside Pio; the night scene places it on viewer-right. This is already present in the original day/night foreground source (unchanged references copied here). It is not an app z-order or mirroring regression. Decide whether this authored variation is acceptable before claiming day/night pose continuity. Do not silently mirror or regenerate the approved design during an integration fix.

### P2 registration limitation — exact rope locking remains unverified

The 28 neutral scenes show coherent reclining characters and day/night scenery. That single pose does not prove either tree knot remains stationary through motion. Current paid ±0.55° pivots are shared approximate source positions, not per-file artist-measured roots. Existing Basic uses separate original pivots/±1.5°. One flattened rigid image cannot keep both distinct ends fixed during rotation. Clear this finding only with split ropes/cloth (or another verified rig), measured endpoints and actual motion evidence. No programmatic correction or art change was performed in this audit.

## Scope observations, not blockers

- Standing 14/14 neutral renders preserve cute identity and recognizable costume, with no obvious missing central body part or neutral outer-canvas clipping seen. These images are rendered rigs, **not complete Home UI screenshots for 14 outfits**. Stage 1–4 distinct appearances and motion extremes were not newly reviewed here.
- Paid cloud 13/13 receiving/light neutral scenes show feet and coherent hand/tablet contact. Student glasses retain face visibility; summer opaque sunglasses intentionally hide eye expression. Astronaut visor remains over the face. Failure/ready × dark × animated transitions are not covered by the 14-image receiving/light review.
- Vacation 28/28 neutral scenes preserve the soft character proportions and actual costume-specific props. Night has authored moonlit beach and warm lights, not a color filter. Neutral central silhouettes look intact; outer soft scene mask is intentional rendering treatment, not proof that source alpha is missing.
- Café uses coffee cup, pajamas hugs a pillow with no drink, astronaut v2 has closed visor and no drink/straw. Student includes book/backpack+juice; fitness dumbbells+juice; rainyDay closed umbrella+juice. New motion must follow each real grip/prop setup.
- Several day/night pairs change pose and framing. Shared attachment coordinates alone cannot prove cross-mode anatomical alignment. Every new day/night layer set needs measured per-file alignment and visual approval.

## Audit verification actually performed

Read-only metadata/hash/pixel checks: 213 standing packed files exactly match the declared rectangles of their full-canvas sources; 120 cloud app copies and 26 paid vacation app copies are byte-identical to their existing sources. Basic vacation uses its original two files. All expected paths used by this inventory exist. Six standing half-eye source files come from `output/pio-completion-2026-10-23/expressions/{summerVacation,cafe,student}/layers/`, rather than the older full-catalog directory; inventory records those real paths. No source PNG was created, edited or re-encoded. Sixteen selected reference copies are SHA-identical.

No StoreKit session, build, app install, production data action, animation test or performance test was run by this artwork audit. Do not upgrade other reports' FAIL/PARTIAL/NOT_TESTED findings based on this file-only verification.
