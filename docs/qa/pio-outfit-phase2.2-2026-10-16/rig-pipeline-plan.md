# Green Pio layered outfit pipeline — Phase 2.2

Status: planning only. Artwork reconstruction is authorized; application integration is blocked until the parent explicitly records an artwork QA pass. No application code, catalogs, existing art, tests, builds, storage, XP, or production behavior changed for this plan.

## Existing implementation and constraints

- `Daylog/Components/PioOutfitMotion.swift`: `PioOutfitCapabilities` honestly exposes body-only motions for flattened costumes. `PioOutfitMotionRig` caches source images, configures only when outfit/motion changes, attaches CA tracks once, and stops on visibility/scene/Reduce Motion changes. Keep this as the fallback for all unapproved outfits. The new passive diagnostics report configuration/load/layout counts and actual active rigs/tracks; these must remain usable with the layered path.
- `Daylog/Views/Splash/RoutimoriSplashView.swift:156`: `RoutimoriSplashRig` is the approved green basic **two-mask wave**, not a complete body/eye/foot rig. Its hidden wing-root/body pixels are not a general reusable costume kit.
- `Daylog/Components/SaessagiIdleView.swift:38` defines `SaessagiLayerSet`; `:306` defines `SaessagiStage`, with torso, eyes/lids, two feet, wings, leaf and optional tails. `:599` starts idle tracks, `:720` stops them, and `:801` onward applies independent foot/leaf/eye/wing motion. Reuse these established CA timing and track patterns.
- `Daylog/Components/SaessagiWalk.swift:264` contains `SaessagiMotionPlan`; `:924–951` dispatches walk/flap/wave plans. The existence of a motion plan does not prove a new outfit can perform it.
- `Daylog/Components/SaessagiRenderer.swift:39–103` resamples/caches layers with the same crop and coordinate conversion. Its crop is tied to `SaessagiPose.content` (`Saessagi.swift:29`) and a 1024 reference canvas. It cannot directly register the new green art by swapping image names.
- `Daylog/Components/PioTrial.swift:55–91` supplies the old Pio's four-stage part sets and measured anchors. These are a different character/art registration. Do not inherit its wing shoulder coordinates, scale, body crop, or growth assets for green Pio.
- `SaessagiStage.update` (`SaessagiIdleView.swift:452`) keys configuration only by pose/size/scale. A future layered outfit adapter must include approved manifest identity/revision and stage-art identity, otherwise swapping outfits can retain stale textures/anchors.

The green basic source is 1319×1192; costume reference PNGs are 1254×1254 flattened illustrations. They contain painted eyes, limbs, outfit and accessories together. Cropping eyes or rotating the whole PNG cannot supply independent parts. Clean hidden torso, shoulder roots, feet roots, and clothing behind moving parts must be reconstructed and visually approved first.

## One registration contract

Use a **1536×1536 square canonical canvas**, origin at top left, +x right, +y down; all coordinates are canonical pixels. “Left/right” always means screen-left/screen-right. This is a proposed export contract, not a claim that source pixels already use that registration.

Each approved outfit/stage has one manifest and full-canvas transparent PNGs. Apply one documented uniform source-to-canonical scale and translation to register its reference. Never independently fit, recenter, stretch, or normalize each part by its alpha bounds. Keep eyes, belly width and feet baseline aligned to the approved body reference; hats/sprouts cannot change apparent body size by expanding the fit box. Do not force a different costume body shape to match by nonuniform scaling.

Required manifest fields:

| Field | Purpose |
| --- | --- |
| schemaVersion, rigID, revision, outfitID, stageArtID | Explicit resource/configuration/cache identity |
| canvasWidth, canvasHeight, origin | 1536, 1536, topLeft |
| referenceFile, referenceSHA256, sourceToCanonical | Provenance and shared registration transform |
| bodyReferenceBounds, eyeLineY, feetBaselineY, groundCenter | Stable display scale and alignment; measured from approved art |
| neutralBounds, motionEnvelope | Distinguish static occupied area from padded animation viewport |
| layers[]: id, file, sha256, parent, zOrder, pivot, neutralTransform | Unambiguous layer hierarchy and placement |
| layers[]: rootOverlapRegion, occludedBy, approvedAngleRange | Document real root coverage and safe motion, not arbitrary pivots |
| expressions: open/closed/happy/sleepy layer IDs | Only authored/approved expressions are enabled |
| approvedMotions, approvedStages, qaEvidence | Capabilities are granted by evidence, not file existence |

Pivots and overlaps must be measured on the reconstructed neutral composite; leave them pending until that art exists. All exported full-canvas layers have identical pixel dimensions and color space. Record alpha mode; use sRGB and proper premultiplied alpha on CG decode. Transparent RGB does not prove a halo: inspect composited pixels against light/dark backgrounds. Runtime point conversion happens once at the platform boundary; do not mix AppKit bottom-left, UIKit top-left, and image pixel coordinates in the manifest.

For a full-canvas layer with pivot P, use anchorPoint=P/canvasSize and position=P in a common master-coordinate parent. Nested pivot groups require child positions expressed relative to that group's origin. Derive this transform explicitly and verify a zero-angle composite before adding motion. Use explicit `CATransform3DMakeScale`/rotation rather than relying on unsupported key-path model writes in offline validation.

## Pilot art inventory and occlusion

Start with green basic plus Christmas at **one approved neutral stage-art identity**. Stage 1–4 remain partial until their own distinct art gates pass.

| Part | Required reconstruction | Independent proof |
| --- | --- | --- |
| Body/face base | Clean torso under eyes, wing roots and feet; preserve cheeks, beak and identity | Hiding each movable part exposes continuous clean body, no painted duplicate |
| Eyes | Isolated open pair plus closed-lid art; optional happy/sleepy only if authored | Blink changes eyes alone; eyelids match face shading without a rectangular patch |
| Wings, left/right | Entire wing with enough hidden root to stay covered through approved range | Left/right solo rotation with torso and opposite wing frozen |
| Feet, left/right | Entire feet and hidden upper connection; Christmas footwear follows each foot | Independent lift/roll with belly/hem overlap intact |
| Sprout | Whole sprout with root under head/hat where appropriate | Small solo sway without opening a hole in the head |
| Christmas clothing | Torso garment without baked movable wings/feet; sleeves/cuffs belong to their actual moving parent | Sleeve follows wing; hem covers roots without sliding over face |
| Christmas accessory | Separate hat body/brim and pom or another approved flexible element; clean pixels behind it | Pom/hat-tip motion is local, while face and hat attachment remain stable |

Suggested hierarchy: root/mover → breathing group → feet + torso group; within torso: rear wings/back accessories → clean body/torso clothing → face/eyes → front sleeve/trim occluders → sprout/headwear → accessory motion group. Exact front/back order is fixed by the approved neutral art. A wing may need a front feather section or sleeve cap; do not cut it unnaturally merely to force one global z-order. Decorative shadows must follow their associated part and cannot remain painted as dark scars on the cheek when a wing moves.

Roots must extend underneath their occluder across every approved pose. A fully reconstructed body is the occluder; no feathered whole-character duplicate, broad rectangular patch, or rotating shadow may impersonate a missing joint. If Christmas's bag/gift blocks a wing, author a separate occluding prop and hidden wing pixels, or mark that motion unavailable. Hat brim and pom need distinct anchors if only the pom flexes.

## Artwork-first QA gate

Create an offline Core Animation validator using the proposed hierarchy and manifest, outside app targets. Preserve untouched references and candidates separately with hashes. Produce reference/neutral-composite/difference views, isolated layers and checkerboard, then actual CA-rendered poses on light and dark surfaces. Difference images reveal shifts but visual review decides intentional reconstruction quality; pixel equality with a flattened source is not required for regenerated hidden parts.

Required views: 48, 64, 76, 120, 220pt at 1× and 3×, full 1536 native composites, joint closeups, and a contact sheet aligned by body/feet rather than total hat height. Keep full motion headroom; no fixed contact-sheet tile may crop a jump and masquerade as an artwork defect.

Validate each motion with **all other local parts frozen**, then in combination:

1. Eyes open → mid-close → closed → reopen. No body scale used as blink; no old open eye remains underneath.
2. Each wing at rest and proposed 15°, 30°, 48°, 62° stress poses on both sides. These are test poses, not automatic runtime range approval. Record a narrower accepted range if needed. Inspect shoulder root, sleeve, cheek and shadow continuity throughout interpolated frames.
3. Each foot lifted/rolled forward and back with the other grounded, then a complete alternating walking cycle. Record displacement/angle ranges in the manifest; inspect belly/garment gaps and planted-foot sliding. No walk capability until a cycle passes.
4. Sprout/accessory at neutral and ±6°/±12° stress poses, or a smaller physically appropriate range. The attachment remains fixed while the free end moves. Freeze body to prove local motion.
5. Jump apex, takeoff, landing squash and celebration with eyes/wings/feet/accessory combined. Check full alpha envelope, ground alignment and self-intersection; no clipping at any target size.

PASS requires recognizable approved green identity, same body size, clean alpha edges, no double features, no exposed cut seams, natural root overlap and clothing occlusion, correct stationary/independent parts, and legibility at 64pt. Save per-part/per-motion PASS/PARTIAL/FAIL with evidence. A failed optional part leaves its capability unavailable; a failed body/root blocks pilot integration. Parent must explicitly approve the art gate before application code is changed.

## Minimal integration after explicit gate approval

1. Introduce a separate DEBUG green layered manifest/rig adapter beside `PioOutfitMotionRig`, sharing its native host/lifecycle and existing `SaessagiMotionPlan` timing. Avoid modifying the production Saessagi/old-Pio layer data to accommodate green artwork. Do not create one renderer per outfit.
2. Select the approved layered adapter only for the exact outfit + approved stage-art identity. Keep untouched flattened art and current honest capabilities for all others. A missing required image fails the layered set atomically and falls back to existing static/body-only behavior.
3. Cache decoded parts by asset/revision and final rasters by manifest revision + display size/scale. Use a shared transform/crop and motion envelope for every layer; keep body display scale independent of decorative extent. No per-frame image generation, decoding, SwiftUI state, timer or layout loop.
4. Gate capabilities from verified inventory **and motion QA**: eye blink requires clean face + lid art; wave/flap requires two usable rooted wings and the tested range; walk requires two usable feet and tested cycle; accessory follow requires its authored layer and pivot. Do not advertise run solely because walk exists.
5. On outfit/revision/art-stage change, stop old tracks, atomically swap textures/anchors with implicit actions disabled, restore the requested supported motion. Ordinary layout, unchanged selection, and a preview stage pointing to the same art must not restart or decode.
6. On disappearing, inactive scene, offscreen, Reduce Motion, or dismantle: remove local and parent tracks plus scheduled actions; reset to an approved neutral pose. Resume intentionally once, preserving no stale outfit tracks. Maintain recursive actual animation diagnostics for both body and layered paths.
7. Run focused identity/configuration/cache/lifecycle tests only after integration, plus isolated real-host benchmarks for base vs Christmas, static vs blink/wave/walk, repeated switching and offscreen. Record active track counts during CPU measurement. Performance tuning needs evidence; the earlier whole-app CPU observation did not establish a renderer defect.

## Growth and later outfits

Green stage 1–4 must have authored visible developmental differences approved in a same-body-scale comparison, with manifests and motion QA for every stage. Reusing the same PNG at a different scale, changing the stage label, or borrowing old Pio's stage assets does not pass. Until all four exist, keep `hasStageSpecificArtwork=false` and exact supported/partial stage reporting.

After basic/Christmas pass, Hanbok reuses the pipeline but needs its own sleeve/cuff, hem, hat/ribbon occlusion and measured anchors; long sleeves cannot inherit Christmas's wave range unchecked. Astronaut requires helmet/glass and suit occlusion: eyes sit behind visor effects, arms attach under suit joints, footwear follows feet. Helmet reflections may need a separate foreground layer, and the sprout may be hidden or constrained. Neither outfit inherits capabilities automatically from the pilot.

Current blockers: no reviewed reconstructed clean-body/eye/wing/feet/accessory set or measured green manifest; no passed complete independent walking cycle; no four distinct approved green layered growth sets. These are artwork/registration gates, not problems solvable by animating flattened illustrations more aggressively.
