# Phase 2.2 pilot artwork and rig contract

2026-10-16. Proposed authoring contract for parent-owned genuine image reconstruction. This document does not approve unseen generated parts, authorize replacement of all thirteen approved outfits, or claim a completed rig. Reconstruct Basic first; proceed to Christmas only after Basic's neutral and joint/eye gates pass.

## 1. Source, canvas and registration

| Pilot | Canonical reference | Registered export canvas |
| --- | --- | --- |
| Basic | `Daylog/PioWardrobe.xcassets/pio_wardrobe_basic_reference.imageset/pio_wardrobe_basic_reference.png` | 1319 × 1192 transparent RGBA |
| Christmas | `Daylog/PioWardrobe.xcassets/pio_outfit_christmas.imageset/pio_outfit_christmas.png` | 1254 × 1254 transparent RGBA |

All coordinates below use original-canvas pixels, origin top-left, x right, y down. Each exported part is registered on its pilot's full common canvas without independently fitting it to the frame. Keep original references unchanged. Retain every unmodified generated source separately with prompt, checksum, visible bounds and final registration transform. Source generation may use a different native canvas; place the complete component by uniform scaling/translation and record the transform. Do not stretch a part, upscale a low-resolution board crop, invent missing pixels with geometry, or crop away an incomplete root to conceal it.

Use separate outfit-local canvases. A common rig interface can normalize `x/W, y/H`; this does not require warping Christmas onto Basic's anatomy. Mac y inversion is `H − y`; keep stored manifest coordinates in the top-left convention.

**Imagegen must produce one full-resolution complete component per output**, including its genuine hidden overlap. Supply the canonical full image plus the current accepted assembly as visual context. Do not request a labeled sheet and later cut low-resolution parts from it. Generate from image reference; prose-only redraws risk changing the face and material.

Reserve 12% external motion space on every side of the neutral character envelope in the preview host, rather than changing source registration. Compute final transformed union bounds for every extreme; increase host allowance if required. Source alpha margins alone are not motion clearance.

## 2. Exact initial pivot targets

Only Basic's right shoulder `(1050,830)` is an existing code-defined pivot. **All other coordinates in this table are exact proposed starting targets estimated from the original image, not measured hidden anatomy.** Register newly reconstructed roots around them and validate the complete pose sweep before freezing a manifest. If a root needs a different anchor, record that change with a neutral/extrema comparison; never silently move the face/body to accommodate an ill-fitting limb.

| Component / purpose | Basic target | Christmas target |
| --- | --- | --- |
| Whole-character ground anchor | `(680,1128)` | `(660,1190)` |
| Screen-left wing/sleeve root | `(395,854)` | `(550,842)` |
| Screen-right wing/sleeve root | `(1050,830)` existing | `(1030,815)` |
| Sprout stem root | `(650,380)` | `(648,304)` |
| Screen-left visible eye center | `(574,676)` | `(550,650)` |
| Screen-right visible eye center | `(868,632)` | `(836,616)` |
| Screen-left foot upper root | `(589,1065)` | `(520,1110)` |
| Screen-right foot upper root | `(872,1015)` | `(814,1110)` |
| Hat mass attachment | — | `(704,350)` |
| Pompom attachment at hat tip | — | `(264,584)` |
| Gift assembly control | — | `(890,870)` |
| Scarf tail attachment | — | `(342,821)` |

Eye coordinates are alignment guides, not permission to alter the approved eye spacing. Final open-eye layers must recover original visible centers and silhouettes from actual pixel inspection; closed lids keep those same local eye frames. Do not parent eyes to a moving hat or visor.

## 3. Genuine components and overlap

The numeric overlap values are **minimum authoring reserves**, not a guarantee of coverage. Every intersection must be tested across the entire accepted range. Extra pixels are genuine painted/reconstructed plush, cloth or feather material, hidden beneath the appropriate front layer; a flat disk, stretched border or duplicate of the original PNG is not a hidden joint.

### Basic first

| Required part | Visible art preserved | Required hidden content / minimum reserve |
| --- | --- | --- |
| Clean body/head plate | Original cream shape, beak, blush, fur and light; static open mouth permitted | Complete natural torso behind both wings; uninterrupted fur under eyes, stem and feet; no original limb/eye imprint. Maintain original visible silhouette outside occlusions. |
| Open left/right eyes | Original gloss, size and asymmetric placement | Separate transparent edges; no cream rectangle around iris. Keep individual registration. |
| Half/closed left/right lids | New genuine plush lid/crease art consistent with original face | Full original eye footprint plus 10px local antialias/coverage reserve. The clean body underneath must make eye removal safe; do not squash the open eyeball to simulate closing. |
| Left/right wings | Same cream plush forms, raised/lowered pose and feather contours | At least 48px of complete root material past the neutral body intersection; natural taper and shadow. Clean body remains behind the swept wing. |
| Sprout cluster | Original two-leaf silhouette, vein direction and green value | At least 36px of complete stem below attachment; clean head beneath; render stem behind a small authentic head-fur occlusion lip if needed. |
| Left/right feet | Original orange toes and asymmetric placement | At least 36px of full foot/leg-root material behind body; no sheared horizontal top. Ground shadows remain a separate render effect and must not be cut out of body art. |

Basic neutral order: ground shadow, feet, rear root portions of wings and stem, clean body, exposed wing portions as anatomically needed, eyes/lids, authentic foreground root/face occluders. A layer may use a genuine front/rear split where the original limb overlaps the torso; do not force all wings behind body if it changes the approved silhouette.

### Christmas only after Basic passes

| Required part | Reconstruction requirement / reserve |
| --- | --- |
| Clean head and clean clothed torso | Head beneath hat/pompom, eye-clean face, uninterrupted coat/belt/scarf surfaces underneath gift and sleeves. Preserve the exact approved red/white costume, not a generic red coat. |
| Eyes and half/closed lids | Same gate as Basic; preserve Christmas's own eye coordinates and facial tilt. Do not transplant mismatched Basic eye spacing. |
| Left/right sleeve + cuff + hand | Complete plush hand/grip and sleeve shoulder, at least 48px hidden root. A hand and its cuff may be one articulated piece initially; name that limit honestly. Coat underneath must be finished. |
| Gift and bow | Full gift edges hidden by either hand. Preserve green box, red bow and lighting. At least 32px reconstructed overlap wherever a grip occludes the box; make the entire relevant side if 32px is insufficient. |
| Hat/brim | Complete concealed hat/head boundaries, minimum 40px underlap behind fur brim. Clean head must remain valid with ±4° hat motion. Preserve drooping cap and sprout opening. |
| Pompom / hat-tail tip | Full pompom and hidden cloth attachment, minimum 32px underlap. Moving pompom must not carry a crescent of cheek/hat background. |
| Scarf band and optional tail | Clean coat behind; full tail root with 40px overlap. Do not claim tail motion if it stays baked into the torso. |
| Sprout and feet | Complete stem/foot roots with at least 36px underlap, Christmas-local registration. |

Christmas occlusion priority: clean head/torso under everything it formerly occluded; hat brim in front of head; sprout appropriately behind brim; coat and sleeves above torso; gift above coat; hands/grips in front of gift. Both hands must follow their original gift contact points via coordinated transforms/constraints. Moving a gift independently while leaving gripping hands frozen fails. A single control may drive a gift-and-hands **multi-part assembly**; label the coordinated relationship rather than imply independent finger articulation.

## 4. Incremental motion envelope

These are initial test ranges, not finished animation tracks or guarantees:

- Basic wave: screen-right wing −10° through +10° around the existing shoulder. Keep body transform frozen during the part test so genuine differential motion is visible. Test left wing ±6° separately before combining.
- Blink: open → half → closed → half → open, both eyes retaining their individual face positions. Hold each pose for inspection. Reject visible old iris, skin-color patch, drifting cheek or crushed beak.
- Sprout sway: ±4° about its reconstructed hidden root. Test without body bob; leaf attachment must remain covered.
- Feet: ±5° root rotation and small pose shifts only after full roots exist. This is a foot-motion test, not proof of natural walking or running.
- Christmas hat/pompom: hat ±4°, pompom ±6°; scarf tail ±5°. Test each alone over the clean underlay.
- Christmas gift assembly: ±3° and ±8 source pixels vertical travel, hands following the gift while sleeves articulate. Reject floating grips or uncovered cuffs. Increase range only after a clean sweep.
- Body bounce/jump remains an additional whole-character track. It cannot be substituted for the isolated component tests.

## 5. Visual gates and evidence

1. **Source gate:** original reference hashes preserved, separate high-resolution component originals retained, true alpha, no source crop/text/watermark, no synthetic geometry used as missing fur/cloth. Inspect over ivory and forest; hidden transparent RGB alone is not a defect.
2. **Neutral assembly gate:** side-by-side and difference overlay against canonical full image at original resolution and 220pt. Same cuteness, body fullness, material, eye spacing, beak, cheeks, sprout and costume design. Target visible landmark displacement ≤3 source pixels after registration (about 0.5pt at220 for these canvases); this is a proposed precision goal, not a measurement already achieved. Reconstruction may change previously hidden pixels, but visible facial/design drift fails.
3. **True separation gate:** hide each component and inspect a clean physically plausible underlying plate. Show that removing eyes leaves real face fur; removing gift exposes completed coat; removing sleeve exposes completed torso. No original imprint, hole, duplicate edge, cloned streak or color patch. Inspect isolated parts to confirm full roots rather than detached visible tips.
4. **Joint sweep gate:** render neutral and both extrema, plus intermediate angles at ≤2° steps for wings/hat and ≤1° for tiny accessory tracks. Freeze body for differential proof. Inspect source-scale joint crops and full character. No exposed background wedge, wrong z-order, hard cut edge, torso crescent travelling with a limb, or prop contact loss.
5. **Size/theme gate:** 48/64/120/220pt, light/dark, neutral/closed eyes/maximum wing/sprout/gift/hat poses. Names aid48pt recognition; fine knit detail need not survive. Silhouette, face and state must remain readable. Do not resize a concept sheet and call it full-resolution QA.
6. **Actual native gate:** capture Mac and iPhone using accepted candidate components, isolated-motion demos plus combined jump/landing. Include Reduce Motion stationary state and resume check. Require observable differential part movement, complete framing and no root flash. Sampled screenshots certify only samples; continuous FPS/performance needs separate measured evidence.
7. **Review decision:** Basic must pass before transferring the architecture to Christmas. Christmas requires its own neutral, grip, blink and joint tests. Keep all thirteen approved full-character designs unchanged; newly accepted rig layers are versioned derivatives, not silent replacements.

## 6. Scope limits retained

No automatic Stage1–4 support. Current Basic pilot and Christmas each preserve one approved pose/design. The separate green growth review PNGs cannot supply registered hidden layers. A later four-stage contract needs stage-specific silhouette/leaf/wing dimensions and costume fit review per stage. Do not use orange Pio components. Missing parts remain explicitly pending, never replaced with whole-PNG movement labeled as independent animation.

This contract is an art production plan. Parent owns generation and application integration. This audit has produced only the two authorized Markdown documents.
