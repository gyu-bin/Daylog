# Pio layered pilot — rigging contract

Canonical canvas: 1254×1254, top-left origin. No source upscaling. Native image-generation dimensions, source hashes and prompts are in generation-prompts.json and the individual alpha-audit.json files. This is genuine raster reconstruction using the built-in image_gen editing tool, followed by uniform registration; not extraction of animation layers from flattened originals. Original13 costumes plus Basic reference remain unchanged.

## Selected artwork

| Kit | Selected full-canvas layers | Parts | Scope |
|---|---|---:|---|
| Basic | registered/base-half-a |12| One tilted cream-wing body; not a growth-stage rig |
| Christmas | registered/christmas-half-a |13| Christmas-f placement, Christmas-g grip motion |
| Hanbok | registered/hanbok-half-a |12| Hanbok-e sleeves/body; brief half-eye state |
| Astronaut | registered/astronaut-half-a |14| Astronaut-c helmet/gloves/visor placement |

Each registration.json names the genuine source PNG, uniform scale/offset, pivot, neutral rotation and depth. Whole transparent master layers are retained. The runtime packer removes only exact-alpha-zero outer padding and verifies decoded RGBA equality. 51 parts and4 reference textures are cached; no per-frame decoding.

## Attachment and motion

CALayer tree: root → canonical canvas → movement → independently registered parts. SwiftUI only selects parameters and reports lifecycle/visibility; Core Animation runs keyframes without a per-frame SwiftUI layout timer. Root/canvas/movement remain unanimated in isolated blink and wave modes.

Eyes: real open/half/closed artwork, six discrete opacity tracks. Exactly one texture per eye is opaque. Blink cycle3.6s; half states briefly bridge the closed state. No fading two eyes together.

Wings: individual shoulder pivots, up to±12°. Christmas left hand and gift share one leftGrip parent at(513,870), ±6° during flap; right hand±12° relative to the−60° neutral placement. The gift cannot drift away from the hand. Headwear is a single Santa hat+sprout+pompom texture; these do not move independently from one another.

Hanbok: one reconstructed sleeve/hand per side with hidden shoulders. Dress, bow, hairflower and tassel stay baked into the body. No independent fabric simulation claim.

Astronaut: left/right glove+sleeve parts have neutral−18°/−5°. Helmet and visor are separate art layers but remain fixed to the body. Eyes are underneath visor and helmet. The visor keeps genuine source alpha at layer opacity1; no whole-character filter or opacity cheat. Suit panel, hoses and boot cuffs stay baked into the body.

Walking uses alternating independent foot rotation/lift. Basic right foot has a reviewed+35 master-pixel ground offset. Jump/landing move/squash the assembled movement parent, preserving every local attachment. Idle adds breathing, blinking and sprout/headwear sway. Celebration combines body bounce and hands. These are small authored2D loops, not3D skeletons or physics.

## Lifecycle and honest scope

All source files and the diagnostic route are DEBUG-only. PioLayeredTrial.xcassets is excluded from both Release configurations. Runtime requires explicit DaylogDebugLayeredRig and DaylogDebugLayeredDiagnostics flags. No production wardrobe, purchases, growth model, SwiftData or CloudKit is changed.

Animations stop on Reduce Motion, view removal, inactive scene, absent native window and supported scroll visibility callbacks; resume creates fresh tracks from neutral. Native tests distinguish viewport exit from removal.

Growth thresholds remain Lv1–9 /10–24 /25–49 /50+. Four distinct green flattened stage artworks exist, but clean frontal layered bodies, stage-specific wing/sprout kits and costume registration are incomplete. Every manifest therefore states supportsGrowthStages=false and pilot-neutral-only. Retired orange Pio assets are never substituted. Other ten costume designs remain preserved and unsupported by this new rig.

## Reproduction

Tools/pio-layered-rig contains the native Swift registration, half-eye registration and lossless packing scripts. Use new candidate output directories; do not overwrite approved originals. Final runtime manifests are copied in runtime-manifests. See final-art-gate.md for selected-art visual differences and remaining approval limits.
