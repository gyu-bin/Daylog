# Green growth-stage artwork and attachment readiness

2026-10-16. **Four distinct green-family growth illustrations exist and are suitable reference artwork. Reusable stage1–4 animated outfit attachments are not yet established.** This read-only audit inspected each native stage PNG, existing comparison composites and registration metadata, and the new Basic candidate-a assembly. Only this report was added; no artwork, application code, tests or registration files were changed.

## Existing exact sources and visual distinction

All four sources are1254×1254 transparent full-character PNGs in `docs/qa/routimori-growth-stages-2026-10-15/assets/`. They are individual full-resolution illustrations, not board crops or orange-family substitutes. All four depict the same frontal rest-pose family: round cream body, symmetrical glossy eyes, pink cheeks, compact closed/smiling orange beak, lowered wings and two planted orange feet.

| Stage / exact filename | Existing visible growth distinction | Missing stage-specific moving artwork |
| --- | --- | --- |
| 1 — `stage1.png` | Smallest two-leaf green sprout; tiny cream wings with a simple soft feather silhouette. | Complete detached small sprout/root; left/right tiny cream wings with hidden shoulder roots. |
| 2 — `stage2.png` | Larger two-leaf sprout; cream wings with more developed layered feather tips. Source body is slightly smaller in pixels and is normalized only in the comparison render. | Complete medium sprout/root; left/right developed cream wings with hidden roots. Do not enlarge the entire source to simulate body growth. |
| 3 — `stage3.png` | Developed sprout and small green wings. Cream-to-green wing transition is the clearest distinction from Stage2. | Complete developed sprout/root; left/right small green wings with hidden roots. |
| 4 — `stage4.png` | Largest/fullest sprout and fuller green wings. Sprout silhouette is the clearest small-size distinction from Stage3. | Complete full sprout/root; left/right full green wings with hidden roots. |

Stage4 is byte-identical to `docs/qa/routimori-master-preview-2026-10-15/routimori-master-v1.png` according to the saved manifest (SHA256 `cb57ff6b8097bf4c6196d18ec00c43c2e766ec9ea77769bc6d866747a6bbb24a`). The supplied comparison render's body normalization preserves stage-height progression rather than forcing all leaf tips to equal height. At64pt dark and220pt light/dark, the four variations remain understandable, though Stage1→2 and Stage3→4 differences are subtler than the cream→green wing transition. No obvious normal-composite halo or crop was seen at these inspected sizes. Raw transparency-view edge colors alone are not evidence of a baked halo. Full-resolution production edge certification was not repeated here.

Evidence inspected: all four native files; `README.md`, `asset-manifest.json`, `registration.json`, `comparison.swift`; `comparisons/comparison-64pt-dark-3x.png`, `comparison-220pt-light-1x.png`, `comparison-220pt-dark-1x.png`; and Phase2.2 `registered/candidate-a/base-assembled-comparison-220pt-3x-light.png` plus its `registration.json`.

## Existing registration is a whole-image presentation alignment

The saved stage registration uses top-left source pixels. It contains a torso width measured at the pupil row and a shared feet baseline, not articulated joints, attachment sockets or clean-body regions.

| Stage | Torso width | Eye-line y | Feet center x | Feet baseline y | Body normalization factor648/width |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1 | 649 | 673 | 627 | 1119 | 0.998459 |
| 2 | 611 | 696 | 625 | 1117 | 1.060556 |
| 3 | 661 | 672 | 627.5 | 1118 | 0.980333 |
| 4 | 648 | 672 | 626 | 1116 | 1.000000 |

The comparison's exact display scale is `requestedPointSpan / 1025 * 648 / sourceBodyWidth`, followed by feet-center/baseline alignment. Its requested64/220pt is a Stage4 reference span, not the entire1254px canvas fitted into a64/220pt square. This distinction must be retained when comparing it to the new rig's1254-square renders. The prior README reports residual eye-line spread about0.58pt at64pt and1.99pt at220pt; whole-image scaling does not make the faces or body textures identical.

There are currently **no stage shoulder pivots, hat seats, sleeve anchors, hand grips, local root transforms or occlusion-depth contracts** in this stage registration. The numerical table must not be promoted into an attachment map.

## Difference from the new Basic pilot

Phase2.2 Basic candidate-a reconstructs the currently supplied wardrobe/splash reference at `Daylog/PioWardrobe.xcassets/pio_wardrobe_basic_reference.imageset/pio_wardrobe_basic_reference.png`. It uses a tilted, open-mouth expression, a raised right cream wing, lowered left cream wing and asymmetric foot height. That differs from all four frontal rest-pose stage illustrations; it is not automatically Stage4 simply because its sprout is developed.

The candidate-a top-left1254canvas map has eyes at(550,689)/(815,644), shoulders(375,810)/(940,830), sprout(650,430), feet(550,1010)/(815,975), body pivot(650,740). These are **candidate-a-specific** pivot values read from its registration. They do not apply to the symmetric stage faces/shoulders. The stage set's green wings for Stages3/4 also cannot be represented by candidate-a's cream wings without genuine corresponding artwork and a reviewed transform.

Existing Basic source components provide useful plush material and eye/lid/foot candidates, and the registration/engine structure can be reused. Their fit to frontal stage art remains unverified. Reusing code is not equivalent to reusing the current attachment coordinates or approving every stage.

## Exact missing artwork and registration contract

1. **A defined stage body/face foundation.** To preserve these four frontal designs, reconstruct a clean frontal body with genuine surfaces beneath eyes, both wings, sprout and feet. Determine whether one approved neutral body can represent all four after registration or whether their small source variations require stage-specific clean plates. The current open-mouth tilted body cannot silently replace the approved frontal face. Keep the closed-beak expression unless an explicit design change is accepted.
2. **Four stage sprout variants and four left/right wing pairs.** Each needs a complete hidden root and covered underlap, retaining the visible stage proportions/colors above. A sprout can be one grouped two-leaf component if that is the stated motion scope; independently moving leaves require their own complete leaf/stem components. Existing flattened images do not contain the concealed root surfaces. Simple masking of the visible pixels cannot prove hole-free motion.
3. **Frontal eye/blink and feet registration.** Supply eye-clean face, paired open-eye/lid components fitted to the level eye line, and separate feet with complete ankle roots. Shared newly authored Basic eyes/lids/feet may be evaluated first, but need scale, orientation, material and silhouette acceptance on the frontal body. Record a common ground baseline and actual foot-contact landmarks; do not infer ankle joints from the existing feet-center field.
4. **Per-stage machine-readable mounts.** On a declared native1254×1254 top-left canvas, record source identity/hash, source-root landmark, uniform scale, translation, neutral angle, world pivot, z-order and tested angle/translation envelope for each part. Record separate left/right shoulder roots, sprout seat, eye centers, ankle pivots, neck/hat seat, waist/torso clothing frame and left/right grip sockets. Every numeric mount must come from rendered anatomy inspection; the current flat-file table is insufficient.
5. **Reusable costume depth and variants.** Costume torso/coat layers need genuine clean under-surfaces and defined front/back portions where a stage wing or sleeve crosses the torso. Sleeve coverage must preserve each stage's size/color identity or explicitly document the costume's covered-wing presentation. Hat/headwear needs a stage sprout opening/behind-front depth arrangement; scaling the entire hat with the sprout is not a valid substitute when head size stays fixed. Gift/prop mounts require hand-local transforms and an explicit carrying-hand constraint.
6. **Christmas-specific missing stage adaptation.** Christmas-f's hat, pompom and embedded sprout are one genuine texture. It currently encodes one sprout appearance: four-stage headwear would need four genuinely authored stage variants or a properly separated hat/back/front-brim and sprout system. It cannot inherit four-stage growth by changing only a label. Its coat/hands/gift also require frontal-stage body/shoulder/grip registration. Current static Christmas-f acceptance covers its own reconstructed pose only.

The other twelve approved costumes remain flattened full-character illustrations unless independently reconstructed elsewhere. This audit supplies no new per-stage costume components for them. No orange legacy layer is a substitute for a missing green part.

## Practical acceptance sequence

First approve a consistent frontal neutral base and the four genuine sprout/wing combinations against the four existing sources at equal torso scale. Verify native joints plus48/64/120/220pt light/dark. Then register one outfit against all four, preserving the same head/body size, eye line, shoulder attachments and ground contact. Check closed eyes, intended part extrema and intermediate angles, sprout/hat depth, sleeve-root coverage and prop contact with the body held fixed. Finally inspect native playback of individual and combined motion, growth transitions, Reduce Motion and host padding; static neutral comparisons do not certify those behaviors.

**Status by all four stages:** distinct original full-character appearance PRESENT; stage-specific separate layer kit MISSING; stage joint/attachment registration MISSING; outfit compatibility and native independent motion UNVERIFIED. PhaseE can accurately expose these four artworks as static references and document the missing layer work. It cannot claim stage1–4 animated outfit support from the accepted single-pose Basic/Christmas pilot.
