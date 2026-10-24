# Costume component separability audit — 2026-10-16

**No ready independent component rig is available for Christmas, Hanbok or Astronaut from the supplied flattened originals.** Static artwork remains high quality. Preserve those images and report missing layers; no reconstruction or regeneration was performed.

Each 1254 × 1254 source PNG was individually viewed at original resolution, then at 1:1 over a correctly composited forest background. Both ivory and forest diagnostic composites were saved. Bright hidden RGB seen in the transparent-source viewer does not constitute a visible outline defect: the forest composites are clean. Source SHA-256 values and dimensions are recorded in `art-separability-sources.json`.

## Meaning of separation

A mask can select visible original pixels without changing their colors. That does **not** recover the original hidden surface behind the selected part, a full buried joint, or a rear-facing surface. Leaving the original underneath produces a duplicate; cutting a complement exposes a hole. None of the three PNGs supplies a closed-lid/clean-face layer or independent hidden-root artwork. Neutral-pose equality alone is insufficient.

Current safe use is the unchanged complete image, including a restrained whole-character transform. This is PARTIAL animation. A pinned-root mesh deforming only an exposed outer tip could be explored with original texture pixels and fixed attachment contours, but it is not a ready separated layer, has not been implemented/tested here, and must not be claimed as a complete limb rig.

## christmas

Source: `Daylog/PioWardrobe.xcassets/pio_outfit_christmas.imageset/pio_outfit_christmas.png`

| Component | Existing original pixels | Missing source material | Why independent motion is not ready |
| --- | --- | --- | --- |
| eyes / eyelids | Two open eyes and highlights are fully baked into the face. | Clean face underneath both eyes; Approved closed/half-closed eyelids and eye-layer edges | Removing/scaling open eyes uncovers holes or leaves bright/dark remnants; a flat skin ellipse or black line would invent art. |
| beak / mouth | Open beak and tongue are visible. | Clean underlying face; Closed/intermediate mouth poses | Mouth scale or movement reveals the missing face; no phoneme/closed-mouth layer is supplied. |
| sprout | Visible green leaf surfaces and exposed stem can be masked. | Complete stem root and clean head/hat/helmet beneath original root; Overlapping leaf surfaces where leaves meet | Rigid separation uncovers original attachment gaps or duplicated leaf edges. A fixed-root mesh of only an exposed outer tip is an untested experiment, not a ready layer. |
| gift and ribbon | Visible front/side gift surfaces and red ribbon/bow. | Gift edges hidden by hands; Both complete hands/grips; Torso, belt and sleeve surfaces hidden by gift | Gift-only translation breaks both grips and uncovers unpainted torso. Moving gift plus both hands still uncovers cuffs/torso. |
| left/right hands and sleeves | Cream hands, white cuffs and visible red sleeves. | Full hand roots behind gift/cuffs; Clean coat/scarf below sleeves; Rear grip pixels | Cannot raise or wave either hand while preserving gift contact and original coat; palm-root cut reveals holes. |
| hat and pompom | Red drooping hat, brim and white pompom. | Head under brim and pompom overlap; Hat fabric hidden by leaf root/brim; Pompom attachment overlap | Rotating pompom or hat as a separate image exposes face/hat gaps. Free outside tip deformation could be experimented with only while original contact contour stays pinned. |
| scarf / fringed tail | Front neck band and left fringe. | Coat beneath scarf; Full tail root and occluded folds | Swinging scarf exposes missing coat and doubled fringe unless removal/underlay is solved. |
| coat / belt / feet | Outer red coat and two visible toe clusters. | Body beneath coat; Foot tops behind hem; Full legs/contact poses | Independent stepping needs missing foot roots and body coverage; body bounce remains whole-character motion. |

## hanbok

Source: `Daylog/PioWardrobe.xcassets/pio_outfit_hanbok.imageset/pio_outfit_hanbok.png`

| Component | Existing original pixels | Missing source material | Why independent motion is not ready |
| --- | --- | --- | --- |
| eyes / eyelids | Two open eyes and highlights are fully baked into the face. | Clean face underneath both eyes; Approved closed/half-closed eyelids and eye-layer edges | Removing/scaling open eyes uncovers holes or leaves bright/dark remnants; a flat skin ellipse or black line would invent art. |
| beak / mouth | Open beak and tongue are visible. | Clean underlying face; Closed/intermediate mouth poses | Mouth scale or movement reveals the missing face; no phoneme/closed-mouth layer is supplied. |
| sprout | Visible green leaf surfaces and exposed stem can be masked. | Complete stem root and clean head/hat/helmet beneath original root; Overlapping leaf surfaces where leaves meet | Rigid separation uncovers original attachment gaps or duplicated leaf edges. A fixed-root mesh of only an exposed outer tip is an untested experiment, not a ready layer. |
| raised right sleeve and hand | Right cream hand and embroidered sleeve outside torso silhouette. | Shoulder root under collar; Clean face/body contour beneath original sleeve overlap; Sleeve back and hidden cuff connection | Visible outside pixels are extractable, but rigid rotation changes exposed shoulder/cheek/skirt boundary. No hole-free range is certified. A pinned shoulder-tip deformation is only a test candidate. |
| lowered left sleeve and hand | Rounded sleeve over left torso/skirt and exposed cream hand. | Skirt/bodice underneath full original sleeve; Complete upper sleeve root and hand beneath cuff | Lifting or rotating this sleeve reveals large unpainted garment area, not merely transparency outside silhouette. |
| skirt / pleats / ribbon | Pink pleated skirt, navy ribbon and floral pendant. | Clean skirt under ribbon/pendant; Back of hem/pleats; Torso and leg roots under skirt | Whole skirt translation opens waist/foot gaps; ribbon movement exposes missing printed skirt and contact shadows. |
| hair flower / tassel | Pink flower, leaves and dangling tassel over right forehead. | Clean head fur and light under ornament; Flower/leaf occluded pixels; Tassel root and its background | Separating tassel or flower reveals their original colored imprint or a hole in head. |
| feet | Two visible yellow feet below hem. | Foot tops and legs behind skirt; New contact poses | Independent walk moves visible feet away from hidden roots; no approved leg layer. |

## astronaut

Source: `Daylog/PioWardrobe.xcassets/pio_outfit_astronaut.imageset/pio_outfit_astronaut.png`

| Component | Existing original pixels | Missing source material | Why independent motion is not ready |
| --- | --- | --- | --- |
| eyes / eyelids | Two open eyes and highlights are fully baked into the face. | Clean face underneath both eyes; Approved closed/half-closed eyelids and eye-layer edges | Removing/scaling open eyes uncovers holes or leaves bright/dark remnants; a flat skin ellipse or black line would invent art. |
| beak / mouth | Open beak and tongue are visible. | Clean underlying face; Closed/intermediate mouth poses | Mouth scale or movement reveals the missing face; no phoneme/closed-mouth layer is supplied. |
| sprout | Visible green leaf surfaces and exposed stem can be masked. | Complete stem root and clean head/hat/helmet beneath original root; Overlapping leaf surfaces where leaves meet | Rigid separation uncovers original attachment gaps or duplicated leaf edges. A fixed-root mesh of only an exposed outer tip is an untested experiment, not a ready layer. |
| helmet visor / face | Face, highlights, visor tint and inner rim shading are composited together. | Clean uncovered face; Independent transparent visor transmission/reflection layer; Helmet front/back shells and face occlusion mask | A face crop includes the visor; moving helmet/eyes/reflection independently drags or duplicates lighting. Original visor alpha cannot be recovered uniquely from composited pixels. |
| helmet shell / ear modules | White-lilac ring, side modules and rim occlude face/body. | Head behind shell; Complete rear shell and neck seal; Independent rim overlays | Helmet turn or bob uncovers unavailable head and neck and changes face framing. |
| raised right glove / sleeve | Right glove and lilac bands extend outside suit. | Shoulder attachment behind shell/body; Sleeve/glove underlap; Clean suit contour at root | Mask can isolate visible pixels, but swing can open shoulder gaps or carry rim/body fragments. Only a pinned-root tip experiment is plausible before rendering; no ready independent limb. |
| left glove / sleeve | Left glove and joint overlap torso/hose. | Torso and hose beneath glove; Full shoulder/hand roots | Independent motion uncovers missing suit/hose pixels and contact shadows. |
| buttons / star / hoses | Three chest buttons, yellow star and lower hoses. | Clean suit under each accessory; Complete hose routes beneath arms | Separating these surfaces leaves holes or double symbols. Pulsing entire pixels is an effect, not genuine reconstructed component motion. |
| boots / feet | Yellow toes emerge from suit cuffs. | Toe roots and legs under cuff; Independent boot and contact poses | Toe motion exposes missing cuff underlap; stepping not supported by original layer structure. |

## Growth stages 1–4

The following applies separately to all three costumes:

| Stage | Available approved costume image | Stage-specific costume layers/rig | Verdict |
| --- | --- | --- | --- |
| 1 | Same flattened costume PNG only | Missing | Not certified |
| 2 | Same flattened costume PNG only | Missing | Not certified |
| 3 | Same flattened costume PNG only | Missing | Not certified |
| 4 | Same flattened costume PNG only | Missing | Not certified |

The green growth illustrations under `docs/qa/routimori-growth-stages-2026-10-15/assets/stage1..4.png` are separately generated flattened rest poses. Their README expressly calls them artwork previews, not a rig kit or app integration. They do not supply clean registered bodies, costume fit, buried joints or eyelids for these three costumes. Do not substitute the older orange Pio rig. Showing one costume at four selected stages while labeling the limitation is acceptable persistence/preview behavior; it is not proof of four-stage visual compatibility.

## Acceptance gate for any future extracted component

A proposed component must keep every original contact edge covered across its entire motion range and preserve clean underlying original pixels where revealed. Render neutral and both extrema against light/dark at 48/64/120/220pt; check every root at source resolution and actual runtime. Reject a missing wedge, duplicated contour, rectangular seam, dragged face/visor highlight, unattached gift grip, or a sleeve that carries a piece of the cheek/skirt. Blink requires the actual clean face and approved eyelid states. The three inspected sources cannot satisfy these missing-layer requirements today. No new approved-art authoring was authorized or performed.

Basic Pio is a separate case: its existing approved exposed-wing mask rig is wired to basic-wave. That does not make these costume PNGs independently layered, and its masks cannot be copied onto their differently clothed silhouettes.

## Files

- `art-separability.json`: component-by-component and all-four-stage machine report.
- `art-separability-sources.json`: original paths, dimensions, image count and SHA-256.
- `art-separability-{christmas,hanbok,astronaut}-{light,dark}.png`: full-resolution diagnostic composites, not new art.
- `art-separability-composites.swift`: reproducible read-only compositor.

No app/source changes, asset generation, masks, reconstruction, runtime implementation or performance measurements were performed by this audit.
