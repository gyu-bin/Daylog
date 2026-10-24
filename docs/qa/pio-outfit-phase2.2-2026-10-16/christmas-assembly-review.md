# Christmas registered assembly review

2026-10-16. Current reviewed candidate: **`registered/christmas-f` — ACCEPT for the limited static pilot art gate.** The right sleeve/hand blocker identified in Christmas-e is resolved by whole-part registration. Earlier Christmas-a/b/c/d/e are historical iterations, not the accepted final registration. This is not runtime or continuous-animation approval. No application or source image was changed here.

## Final Christmas-f re-review

Independently inspected f's full neutral dark composite, original/assembled/closed/right+12 comparison at220pt3x light, both source-size right±12 joint crops, and grip-up/down joint crops. Also inspected all ten poses at64pt1x and220pt1x in both light and dark via temporary diagnostic contacts made from the exact rendered images: neutral, closed, right−12, right+12, hat−4, hat+4, grip-up, grip-down, step-left, step-right.

The corrected right part uses uniform scale0.26 and neutral rotation−60°, with source root landmark(1000,600) registered at world(1050,790), according to the rig handoff. The fuller cuff now balances the left hand; the short red sleeve points toward the shoulder/scarf region and the palm points down-left over the gift. The e version's small horizontal outer nub no longer dominates the silhouette. Both right-arm endpoints retain a plausible shoulder connection, and both coupled left-hand/gift shifts preserve visible holding contact. No exposed root hole, hard cut, face obstruction or canvas crop is apparent in these inspected poses. No further art generation or placement change is required for this limited pilot.

The reconstructed face remains cute and expressive at64/220pt. Body fullness, headwear width/brim curve and foot perspective differ slightly from the original, so this is a cohesive reconstruction rather than pixel-identical reproduction. These differences do not block the scoped pilot. The earlier e contact-audit pixel counts below are historical evidence only; they are not f measurements and are not substituted for f's visual review.

**Accepted scope:** only the rendered neutral/closed and listed endpoint poses. The right arm may move independently while the left hand carries the gift; the inspected gift shifts move gift and left hand together. Combined hat/sprout/pompom is one accessory. Native-device playback, intermediate trajectories, blink transitions, larger angles, combined extreme tracks, full locomotion, performance and stage1–4 compatibility still require separate evidence.

## Evidence inspected

### Additional Christmas-g coupled flap endpoints — ACCEPT

After f's neutral and part endpoints were accepted, inspected `registered/christmas-g` poses `grip-flap-minus6` and `grip-flap-plus6`: source-size shoulder/grip crops, both endpoints at64pt1x in light/dark, minus6 at220pt3x light and220pt1x dark, plus6 at220pt3x dark and220pt1x light. The rig handoff specifies the exact same affine ±6° transform for left hand and gift around(513,870), with right hand moving opposite±12° relative to its−60° neutral. Source artwork is unchanged from f.

Both inspected endpoints retain a buried left shoulder/root and fixed left-hand/gift contact. The right palm remains visibly in contact/overlap with the gift. Raising the gift brings the bow into more of the lower cheek/scarf region, but it does not obscure either eye or the beak. No exposed root gap, hard joint cut, severed prop, or canvas crop was found. At64pt the face and gift remain readable. **Accept these exact static coupled flap endpoints for implementation and native motion validation.** This does not prove all intermediate frames or combined motions, and must not be described as separately animated ribbon, scarf, sprout or pompom.

Exact approved reference: `Daylog/PioWardrobe.xcassets/pio_outfit_christmas.imageset/pio_outfit_christmas.png`.

For Christmas-e, inspected the original/assembled comparison at220pt3x light; full neutral dark; all ten poses (neutral, closed, right−12, right+12, hat−4, hat+4, grip-up, grip-down, step-left, step-right) at64pt1x and220pt1x in both light/dark using temporary diagnostic contacts; 64pt3x dark comparison; hat−4 dark and hat+4 light at220pt3x; and source-size closeups for both right-arm extremes and both grip shifts. Also read `registration.json`, `poses.json`, `contact-audit.json`, and individually viewed genuine `headwear-v2.png` and both `hand-*-v2.png` sources.

## Historical Christmas-e blocker — resolved in f

In `christmas-assembled-neutral-dark.png` and both `christmas-assembled-joint-right-*.png` closeups, the right palm/cuff is conspicuously smaller than the left and than the approved reference's right cuff. Its small rounded red upper sleeve points horizontally out beyond the coat, making the part look like an end cap attached to the gift rather than a bent arm attached at the shoulder. This is visible at220pt as well as in enlarged root views. The approved original has a fuller right cuff and a down-left palm emerging from a root above/right near the torso.

This is an anatomical presentation problem, not a claim of an alpha hole. `contact-audit.json` correctly records left-hand/gift overlap2737 significant pixels and right-hand/gift overlap7158; both palms do overlap the gift. The left grip remains plausibly attached across the coupled up/down shifts. Geometric overlap does not by itself fix the right arm's size or shoulder direction.

Requested no-pixel-edit first refinement to the rig worker:

- Uniformly enlarge the right sleeve/cuff/hand about1.35–1.45× relative to e (scale approximately0.25–0.267 instead of0.184426).
- Test a neutral rotation around−55° to−65° in top-left canvas coordinates, placing the red root above/right and the palm down/left, closer to the approved reference.
- Register the buried red root near x1040–1060,y800–820; keep palm contact near gift's right edge, approximately x1000–1040,y885–940. These are proposed test targets, not a validated final transform.
- The root must meet/overlap actual coat/scarf and stop reading as a horizontal external nub. Render neutral, both right-arm endpoints and grip shifts again. Adjust the actual root/palm anchors as needed without moving the face, stretching the artwork or painting over the joint.

No new generation is requested on the present evidence. If whole-part registration cannot both preserve the shoulder and maintain grip, the remaining need must be reported instead of masking away the failure.

## What is already improved and not blocking

- Genuine combined `headwear-v2.png` embeds the sprout into the Santa hat naturally. Previous floating stem/incorrect rear-leaf depth issues are resolved in e. Headwear is slightly narrower/higher than the original, with a different front-brim curve, but preserves the Santa identity and clear cute face at inspected sizes.
- Headwear ±4° samples keep the face visible and the sprout/pompom complete. This is **one combined hat + sprout + pompom layer**; it is not independent leaf or pompom animation.
- Open eyes retain expressive glossy identity; closed eyes read as soft lids without an iris ghost or cream patch in the inspected sizes.
- The clean body/coat provides genuine underlying surface rather than old hand/gift imprints. No original sleeve horns from v1 remain.
- Gift, ribbon, left hand and white cuff are recognizable and materially coherent. The coupled gift/left-hand shift visibly retains contact. When the right hand changes angle, the left grip continues carrying the gift; this is a valid scoped constraint, not independent two-hand grip solving.
- Feet and inspected step endpoints remain connected under the coat; no crop or exposed foot-root cut was found. This does not certify walking.
- All inspected64/220 light/dark poses retain recognizable color, face and costume. No significant source clipping or obvious matte halo is observed.

## Scope and next gate

Christmas-e was not approved for implementation because of its right-arm blocker. Christmas-f has passed the changed right-arm/affected grip static re-review documented above. Implementation may use f's tested registration for the scoped pilot, followed by actual motion and runtime review; unrelated accepted source evidence need not be regenerated.

Even after static art acceptance, endpoint renders establish only those poses. They do not certify every intermediate angle, blink transition, continuous motion, FPS/performance, full flap/walk/dash or native device behavior. No stage1–4 costume compatibility is approved. Scarf remains baked into the body; bow remains part of the gift; Christmas's sprout/pompom remain part of combined headwear. The thirteen approved full-character originals stay unchanged.
