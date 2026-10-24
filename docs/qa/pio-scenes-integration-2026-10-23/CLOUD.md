# Cloud scene integration — 2026-10-23

Status: PARTIAL. Source registration is complete, and the subsequent focused iOS build/runtime checkpoint below passed with actual native PNGs. Mac/full-matrix/performance results are recorded by the coordinated validation report. Artwork limitations remain explicit.

## Implemented

- Current authorized appearance resolves through `PioAppearanceCoordinator` for receiving, completed and failed cloud states. A preview-only `appearanceOverride` can inject a resolved appearance without granting ownership or changing preferences.
- In the explicit DEBUG `-PioOverhaulTrial` process, 13 premium seated/tablet poses use their existing genuine clean-face body, separate eyes, eyelids and concerned brows. Optics remain above the face for Astronaut, Student and Summer Vacation.
- Receiving retains the tablet pose, gentle breathing/attention, cloud float and downward glyph with periodic independent blinking. Failure settles once into its concerned pose, with independent brows and slower blinking. Hands and tablet stay attached because they remain in the authored body.
- Completed cloud sync reuses the existing all-14 native layered celebration rig once (finite repeat count), retaining independent eyes, wings and supported accessories. The protected common rig source is unchanged.
- Pending/unavailable entitlement verification hides the character rather than briefly substituting Basic. Cloud/progress content remains visible. No new entitlement or appearance persistence is introduced.
- Reduce Motion, inactive scene, SwiftUI disappearance and native scroll clipping halt retained Core Animation tracks. Native viewport checks observe clip bounds/content offset; no frame timer or per-frame SwiftUI layout state is introduced.
- Original approved Basic cloud composition remains the fallback for Basic receiving/failure and unsupported registered resources. Release excludes the DEBUG cloud catalog and independent renderer.

## Registered source preservation

`cloud-assets.json` lists 120 source/asset/SHA256 mappings: 13 × 9 full-coordinate transparent layers plus 3 optics. A focused read-only hash comparison verified all 120 registered PNGs equal their preserved source PNG bytes. These are additional imageset entries in `PioOverhaulTrial.xcassets`; existing registered artwork and motion source files were not edited.

No resampling, sheet cropping, generated replacement, redraw, body decomposition or image modification was performed. All layers retain their original 1254×1254 coordinate canvas.

## Remaining artwork limits

- Basic receiving/failure: no clean underlying Basic seated body plus separate eyes/lids currently exists. Original flattened approved scene remains; no independent Basic cloud blink is claimed.
- All 13 premium receiving/failure scenes: independent hands, tablet, sleeve/shoulder hidden roots and front/back tablet occlusion are missing. No waving, typing, tablet release or isolated hand motion is claimed.
- Standing celebration is deliberately limited to the completed cloud state, not substituted for the authored seated receiving/failure pose.
- Growth-stage-specific cloud artwork is not established by this registration. This work does not certify four distinct growth appearances in every cloud costume.

## Focused validation interfaces

- `RoutimoriSyncStage.Configuration`: `outfit`, `suppressCharacter`, `usesIndependentCharacter` default to Basic/false/false for legacy compatibility. Tests may explicitly request the DEBUG renderer without writing purchase state.
- `PioCloudCharacterRig`: `configure(outfit:kind:bounds:)`, `setActive(_:)`, inspectable `root`, `parts`, `active` and `animationCount`.
- `RoutimoriSyncScene(kind:height:appearanceOverride:)` exposes explicit resolved appearance for native UI previews.
- `PioCloudSceneHost` reports native visibility for both the full scene and compact cloud activity indicator.

Required runtime evidence: all13 seated outfits + Basic fallback in receiving/failure; all14 completed; 64/220pt light/dark; eye one-hot switching; bounded completed cycle; outfit replacement at identical bounds; Reduce Motion; background/offscreen stop; comparable CPU/RSS. Refer to the companion RESULTS report for actual outcomes rather than treating this implementation checklist as a test result.

## Checks recorded here

| Check | Result |
|---|---|
| 120 copied source PNG SHA256 matches | PASS |
| Focused `git diff --check` cloud source/coordinator | PASS |
| iOS focused build/runtime/screenshots | PASS — see IOS.md and native-ios-final; initial cropped-foot visual defect fixed and rerun |
| CPU and memory | NOT_TESTED by this implementation worker; see coordinated report |
| Independent premium eyes/lids/brows | PASS representative native iOS eye-state evidence; see IOS.md |
| Independent receiving/failure hands/tablet | PARTIAL — required art absent |
| Basic independent receiving/failure eyes | PARTIAL — required art absent |

## Subsequent iOS runtime checkpoint

See IOS.md: the focused native test passed42 scene mappings and lifecycle checks, exported17 final PNGs, and revealed a real cropped-foot defect despite the first assertion PASS. Independent-only scene registration was corrected to230pt/y215; rebuilt focused iOS test PASS and final Christmas/Hanbok images show complete feet. Initial images and failures remain preserved. Source review also closed two P2 issues: false missing-art notes during unverified authorization, and hidden character generic tracks continuing while verification was pending. No production ownership policy was changed.
