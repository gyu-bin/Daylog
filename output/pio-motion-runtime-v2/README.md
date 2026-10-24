# DEBUG-only full-catalog runtime v2

Implemented additive `Daylog/Components/PioOverhaulCharacter.swift` and `Daylog/PioOverhaulTrial.xcassets`. Opt in with process argument `-PioOverhaulTrial`. Code is entirely guarded by DEBUG; both Release configurations exclude the new catalog. No existing source artwork or earlier rig is overwritten.

213 registered parts from all 14 canonical outfits were cropped **only at exactly zero alpha** to avoid unnecessary texture memory. Every nontransparent RGBA source pixel is identical after reconstructing the registered canvas; full alpha equality is asserted. `asset-verification.json` records original source hashes and rects. Existing neutral transforms are already baked; manifest pivots remain in the original 1254 coordinate system.

`PioOverhaulCharacterView(outfit:action:isAnimating:)` accepts 10 actions: idle, bounce, walk, jump, landing, celebrate, greet, sleepy, surprised, encourage. Base body translation, lean, squash/stretch are explicitly whole-body motion. Eye substitution, free-wing rotation and walk feet are genuinely independent. This is retained Core Animation, with no per-frame SwiftUI state, timer or display link. DEBUG appearance renderer can select this runtime across character slots; composed vacation/cloud scenes remain their authored original renderer.

Jump has anticipation, a single 240-source-pixel rise, hang, distinct landing squash and recovery. Bounce uses two 42px hops. Explicit landing uses squash/recovery only, with no new upward launch. Greet has three wave cycles. Celebration has happy eyes, wide free wings and alternating lateral shimmy. Sleepy alternates half-lids and closed eyes with two nods. Surprise quickly recoils with a slower return. Encourage approaches with a longer happy-wing hold. These loops are for review, not a finished one-shot event scheduler.

Christmas gift + both hands share pivot/angle. Pajamas pillow + both hands share pivot/angle. Rainy canopy + shaft + right hand share pivot and restricted negative angle. Christmas/Pajamas attachment groups are capped to the previously validated ±2°. Other held items match their hand pivot/angle, capped to ±4°. Free wings can reach ±20°; these wider ranges require rendered seam review before approval. They do not imply independent cloth deformation, finger release or a 3D turn.

Motion stops and resets to neutral on offscreen/hidden/inactive/disappearing views, Reduce Motion and explicit isAnimating=false. NSCache uses a 96MB cost limit (not a process RSS promise); live CALayers retain their current images. No performance PASS is claimed from build success. Native tests/rendering and CPU/RSS evidence are separate.

Final native placement reserves additional headroom with a downward .09×minimum-dimension center offset at unchanged .78 scale; see `docs/qa/pio-motion-v2-2026-10-23/NATIVE-EVIDENCE.md` for actual native border checks and presentation sequences.

Mac Debug build: `docs/qa/pio-motion-v2-2026-10-23/mac-build.log`. Initial sandbox build failed package DNS; escalated isolated build succeeded. No application was installed/launched by this worker. iOS simulator compile was requested separately; inspect its log for final status.

Native visibility refinement: macOS hosts additionally check visibleRect and observe ancestor clip-view bounds changes; iOS hosts intersect the window and clipping ancestors and observe scroll content offsets. These event-driven checks avoid a per-frame visibility timer. Native offscreen acceptance remains a separate verification.
