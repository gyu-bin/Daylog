# Vacation outfit foreground candidates — 2026-10-23

## Scope and provenance

13 paid costumes × day/night. Each source PNG is a separately authored native transparent image made with built-in imagegen from the approved individual costume and the approved matching hammock foreground. No sticker-sheet crop, simple geometric costume, pasted standing character, mask-based repaint or upscaling. Exact prompts, reference paths and original generated save locations sit beside each source file. Approved app sources were not overwritten.

The source consists of the reclining clothed Pio, complete sage/cream hammock and suspension ropes together. Front hammock fabric occludes the torso/props naturally. The matching approved daytime beach or actual moonlit night beach is used unchanged in every QA assembly. Night foreground lighting was authored separately with amber left rim light and cool moonlight fill; it is not the daytime image behind a dark filter.

## Technical contract

- Target/source canvas: 1024 × 1536 pixels, portrait, full-coordinate RGBA.
- Preserve native generated PNGs; no alpha cleanup or hidden-root painting applied.
- UI sprites: no mipmaps. Proposed budget: one full foreground + one existing shared background, approximately 12 MiB decoded RGBA per pair; never decode all 26 foregrounds concurrently. Source PNG storage and source pixel alpha are in `manifest.json`. This is a proposed budget, not runtime profiling evidence.
- Day reference anchor (968, 484), focus (512, 740). Night reference anchor (68, 465), focus (512, 845). These belong to the approved original, not automatically to generated candidates.
- Generation can alter hammock span, knot position, face proportion and prop placement. Same canvas dimensions do not prove pixel-exact registration. Each candidate needs approved anchor/focus registration before an app swap.

## Validation boundaries

`verify-scenes.py` decodes each actual file, records alpha, pixel size and SHA-256, composites it over the matching unmodified background, and builds day/night contact sheets. This is focused offline asset validation; no app build or old application test was rerun.

These foregrounds are flattened scene artwork. A whole-hammock sway can be honest, but independent eyelid/hand/straw/sip motion is NOT supported by this file structure. No independent motion PASS is claimed. Those actions require authored clean face/eye states, arm/glass/straw layers, and front/back hammock separation with hidden roots. Do not reuse the standing rig to claim the reclined pose is animated.

## Remaining work after source generation

1. Per-candidate visual approval for costume fidelity, cute proportions, cloth/hammock occlusion, and prop logic. Astronaut visor and straw clearance, rainy umbrella placement, fitness weights, and pajamas pillow must receive close inspection.
2. Exact per-candidate rope anchor/focus registration; verify both sway extremes against the fixed trees and no canvas clipping. Current manifest records original reference anchors only.
3. Genuine scene-specific component reconstruction for independent blinking, sipping or waving. Current complete foreground alone cannot provide it.
4. App integration, Mac/iPhone runtime views, Reduce Motion, CPU and memory measurements remain NOT_TESTED. No production data, app assets, app code, purchases, commits, pushes, installation or deployment is part of this package.

Overall status: **PARTIAL — reviewable authored scene candidates, not final or app-ready animation.**

## Astronaut correction v2 — active day/night candidates

Independent review identified impossible straw passage through the closed visor in both v1 Astronaut candidates. Those files and their v1 assemblies are preserved unchanged and are rejected for that prop logic. New genuine imagegen edits `source/astronaut-day-v2.png` and `source/astronaut-night-v2.png` remove the entire glass, straw and citrus decoration without adding a helmet port or opening the visor. Both gloves now rest comfortably against the suit, with the original sprout, white/lavender closed helmet, reclining pose and hammock occlusion. Day and night assemblies over the unchanged approved beaches were viewed at full size: the drink is absent, closed visor is uninterrupted, and relaxed cute character identity remains readable. Night retains amber rim light and cool fill.

The active manifest and current contactboards use Astronaut v2 only. The previous complete manifest/boards were preserved with `before-astronaut-v2` suffix. Prompts and generated-original paths are beside both new native PNGs; their hashes and unchanged-native-copy checks are in the active manifest. There are 26 active candidates plus 2 preserved superseded v1 Astronaut sources, 28 source PNGs total. This correction resolves the impossible-drink issue only; rope registration and independent scene animation remain PARTIAL/unsupported.

## Actual review observations

All 26 actual native PNGs decoded successfully at 1024 × 1536 with real transparent pixels. Each matches its original generated file byte-for-byte; `manifest.json` contains hashes and provenance. Both complete 13-costume day/night boards were visually inspected after generation. Full-size Christmas day, Rainy night, Pajamas night and Astronaut day assemblies were additionally viewed directly.

Clothing is visible above the front hammock lip; Christmas gift, Halloween candy basket, student's book, fitness weights and folded rainy umbrella rest within the hammock rather than hanging as unrelated stickers. Pajamas hugs its original white pillow and omits juice; Cafe holds the original coffee cup. These are useful scene-specific pose candidates. Night gives genuine amber edges on the character and rope with cool marine shadow fill against the existing moonlit scenery.

Visual concerns retained for review: Hanbok night has a larger upright head/torso than most variants; the generated dome/neck opening and external straw on Astronaut require close approval for credible visor clearance; costume detail and hammock depth vary across independently generated images. Source canvas registration is consistent in size only. No assertion of exact original rope registration, independent roots between flattened objects, or complete scene-animation support is made.
