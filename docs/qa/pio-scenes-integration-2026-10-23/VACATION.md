# Vacation outfit scene integration — 2026-10-23

Overall: **PARTIAL — integrated authored candidates; independent pose animation and final rope registration remain incomplete.** Runtime/build results are recorded by the independent scene validation owner in this directory's final results. Do not infer runtime PASS from the parse and source-byte checks below.

## Implemented

- Added 26 paid-outfit foreground images to `Daylog/PioVacationScenes.xcassets`: thirteen actual reclining costumes × genuine daytime/nighttime lighting. The existing Basic foreground and both shared beach backgrounds remain unchanged.
- Every packaged PNG is a byte-identical copy of the active source identified by `output/pio-vacation-outfits-2026-10-23/manifest.json`. Astronaut uses **v2**, without the impossible glass/straw-through-closed-visor. Rejected v1 files are not packaged.
- Source filenames, SHA-256, candidate version and limitations are retained in the catalog's `pio_vacation_sources.dataset/sources.json`.
- `PioVacationSceneResources` maps authorized outfit/context to `routimori_vacation_{day|night}_{outfit.rawValue}`. Coordinator changes are owned by the shared scene integration worker; no separate wardrobe state or purchase grants were introduced.
- The native vacation host consumes the coordinator's day/night resolution. Pending or unavailable verification (`checking` / `verificationUnavailable`) hides the entire character foreground and stops its animation, leaving the stationary beach. It does not flash Basic or render an unverified paid costume. Known unowned access still follows the coordinator's Basic fallback policy.
- Actual night sources and the original moonlit beach are selected together; no dark filter is applied to daytime character art.
- Existing vacation controls, slot layout, persistence, purchase code, registry and approved original art are untouched.

## Motion supported by these files

Each source is **one flattened transparent image** containing character, clothing, held props, front hammock, back hammock and ropes. Only the whole foreground can move honestly. Existing Core Animation supplies a calm seven-and-a-half-second sway; the beach/canvas remain stationary. Paid candidates use conservative **±0.55°** preview motion. Original Basic retains its existing **±1.5°** motion.

Independent blinking, waving, breathing deformation, sipping, hands, straw, fabric and accessory motion are **unsupported**, not PASS. They require newly authored clean face and eyelid states, separate arms/held items with complete hidden roots, and front/back hammock occlusion layers. A standing rig or whole-image rotation is not a substitute for those parts.

## Registration limitation

The preserved source canvas is 1024×1536. The new source package itself states that matching dimensions do not prove the old pivots.

The provisional integration points were read visually from the candidate assemblies:

| Mode | Foreground pivot | Display focus | Status |
| --- | --- | --- | --- |
| Day candidate | (968, 500) | (512, 820) | PARTIAL: conservative shared preview registration |
| Night candidate | (58, 225) | (512, 870) | PARTIAL: conservative shared preview registration |
| Original Basic day | (968, 484) | (512, 740) | Preserved original |
| Original Basic night | (68, 465) | (512, 845) | Preserved original |

These are not artist-approved per-file attachment roots. Mathematical pivot invariance only proves a selected coordinate stays fixed; it does not prove the painted knot is there. Actual native views at neutral/both sway extremes, especially large Hanbok night and different rope spans, need visual approval. No source was stretched, repainted or regenerated to hide registration differences. The existing canvas-edge fade remains and is not evidence that seams cannot occur.

## Lifecycle and performance scope

- Core Animation owns continuous motion; no per-frame SwiftUI state/layout timer was added.
- SwiftUI gates by appearance/disappearance, scene activation and Reduce Motion. Pending verification also removes foreground animation.
- Mac observes ancestor clip bounds and checks visibleRect/hidden ancestors before animation. iOS observes ancestor scroll offsets and intersects clipped ancestor/window bounds. Detached hosts stop through representable dismantling.
- Each host loads only its selected outfit's day/night pair and shared backgrounds, not all 26 foregrounds proactively. Native named-image caches are framework-managed; repeated-switch CPU/resident memory were **NOT_TESTED** by the implementation worker. Do not claim a measured memory budget from source image dimensions.

## Focused checks

| Check | Result |
| --- | --- |
| Active source count and copied PNG SHA-256 equals source manifest | PASS — 26 |
| Active Astronaut v2, retired v1 not packaged | PASS — copy mapping |
| Swift frontend parse: scene, helper, new tests | PASS |
| Native bundle image decode / 26 dimensions and alpha | PASS — focused Mac unit test |
| Model pivot invariance and beach stationary / stop resets pose | PASS — focused Mac unit test; not painted-root approval |
| Pending foreground hidden; Reduce Motion/inactive/hidden gates | PASS — focused Mac model tests; native viewport lifecycle evidence remains separate |
| Mac/iPhone builds and actual rendered day/night / visual extremes | NOT_TESTED by implementation worker; independent validation pending |
| Offscreen CPU and repeated switching memory | NOT_TESTED |
| Independent eyelid/hand/sip motion | Unsupported: required layers absent |

New `PioVacationSceneIntegrationTests` has four focused tests, all PASS in the independent [Mac recheck log](mac-vacation-recheck.log). The first run exposed a test-only Core Animation value bridge (`NSNumber`, not `[CGFloat]`); that assertion representation was corrected without changing app motion or weakening the angle/count checks. Existing `RoutimoriVacationTests` remains intact and its three tests passed in [Mac v2](mac-test-v2.log). Actual native animation evidence should use `RoutimoriVacationRig(outfit:)`, which shares the same image loading/registration initializer used by the app; offline source composites alone do not establish an app rendering PASS.

## Remaining work

1. Review actual integrated Mac/iPhone shots of all paid day/night scenes and both sway extremes, preserving the cute character scale and controls.
2. Approve/correct per-file rope registration from real native evidence; reject candidates with unacceptable knot motion or clipping.
3. Author genuine reclining-pose component layers before independent blinking/sipping/waving can be implemented.
4. Measure repeated outfit switching and offscreen behavior before declaring performance PASS.

No commit, push, deployment, production app replacement, StoreKit activation or production user-data operation was performed by this integration.

## Native capture review note

Initial raw Mac vacation PNGs appeared vertically inverted. The vacation capture CGContext applied a negative Y transform while cloud capture used a different transform; this is a concrete capture-path difference, not yet proof of an application orientation defect. Their existence is not a visual PASS. The independent validator compared an actual AppKit `cacheDisplay` host capture and confirmed the scene displays upright: this was a raw-capture-path problem, not a reason to change the application rig. Original source PNGs and the original geometry-flipped Mac rig remain unchanged. Native model-pose extreme captures are being reviewed separately; they must not be labeled wall-time animation frames.

## Selected native extreme review

Actual AppKit host proof was viewed directly: [Hanbok night host](native-AppKit-proof/vacation-hanbok-night-AppKit-host.png), upright with the character fully visible.

Eight additional native **model-pose** images were directly viewed, not merely generated or inferred from code:

- [Hanbok night negative](native-extremes/vacation-hanbok-night-model-extreme--1.png) / [positive](native-extremes/vacation-hanbok-night-model-extreme-1.png).
- [Christmas day negative](native-extremes/vacation-christmas-day-model-extreme--1.png) / [positive](native-extremes/vacation-christmas-day-model-extreme-1.png).
- [Astronaut night negative](native-extremes/vacation-astronaut-night-model-extreme--1.png) / [positive](native-extremes/vacation-astronaut-night-model-extreme-1.png).
- [Rainy night negative](native-extremes/vacation-rainyDay-night-model-extreme--1.png) / [positive](native-extremes/vacation-rainyDay-night-model-extreme-1.png).

In these selected views, face/sprout/helmet/umbrella remain visible, props stay within the authored foreground, and no obvious internal hammock break appears. Astronaut v2 correctly has no drink. Hanbok night has a larger, more upright head than other variants but is not clipped in the checked host/slot.

This is limited visual evidence, not approval of every painted attachment root. Night knot heights differ between generated variants; the shared provisional pivot can therefore produce small painted-knot displacement for variants such as Rainy/Astronaut. Final per-file roots still need approval/correction if this displacement is unacceptable. These snapshots set the native rig to the two model extremes; they are **not wall-time animation frames or video**. Independent blinking/sipping remains unsupported.
