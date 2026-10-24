# Genuine layered artwork delivery contract

Status: **SPECIFICATION READY / ARTWORK BLOCKED_ASSET**. This is a production handoff specification, not a claim that production-ready layered artwork has been delivered. Existing approved Pio identity, costume, pose, lighting and material are the visual authority. Preserve 13 paid designs plus Basic. No new drinks, generic geometric wings, retired orange Pio parts, sheet crops or enlarged crops may substitute for missing source pixels.

## 1. Common coordinate and transparency contract

| Scene | Full-canvas authoring size | Existing source | New source status |
|---|---|---|---|
| Standing home/complete-cloud rig | 1254×1254 RGBA | 213 genuine existing component files; exact path/rect/z/pivot in inventory | No regeneration requested |
| Seated cloud Basic | 1254×1254 RGBA | Existing loading and failure full-character PNGs | Clean face/eye states missing |
| Seated cloud paid 13 | 1254×1254 RGBA | Existing body plus genuine eye layers, 120 files total | Hidden torso/sleeves, hands and complete tablet missing |
| Vacation all 14 × day/night | 1024×1536 RGBA | Existing original Basic ×2 and paid candidates ×26; astronaut active v2 | Independently layered face/arms/props/cloth/rope missing |

Use top-left origin, x-right, y-down, source-pixel units. Every authored layer retains the entire canvas. Pixel bounds and pivot must be reported separately; do not center each cutout on a new canvas. Deliver PNG RGBA with genuine alpha, original fur edges, contact shading and daytime/nighttime light preserved. Source-size imagery is required; enlarging a crop is not reconstruction. Runtime tight packing is permitted only after preserving sourceSize, crop rectangle and pivot and proving pixel identity, as existing 213 packed standing parts do.

Complete hidden roots must be painted/reconstructed behind the silhouette, including the torso exposed by shoulder rotation, hand behind its held object, prop behind fingers, and beach behind moving cloth. Soft alpha alone cannot restore these pixels. Do not sharpen feathers/foliage or increase bulk to hide seams.

Metadata per part: `outfit`, `scene`, `mode`, `partID`, `sourceSize`, `file`, `parentID`, `pivotPx`, `z`, `visibleBounds`, `hiddenRootBounds`, `occludes`, `occludedBy`, `safeTransformRange`, `colorProfile`, source SHA-256 and authoring provenance. `safeTransformRange` is artist- and runtime-verified, not a guessed ±40° default. Missing bounds/pivots remain null and block import approval. Exact current full file metadata is in [inventory.json](inventory.json).

## 2. Cloud Basic eyes — blocker CLOUD_BASIC_EYES

Existing references are the unmodified `routimori_sync_loading` and `routimori_sync_failure` PNGs, copied in `references/Daylog/RoutimoriTrial.xcassets/`. Their eye pixels are baked. Standing/open/half/closed eye donors exist, but placing donors over existing eyes would double-paint the face. The fur beneath eyes is unavailable in the flattened PNG.

Required genuine files, same 1254 canvas: `seatedBodyCleanFace`, `eyeLeft/Right`, `halfLeft/Right`, `lidLeft/Right`, `browLeft/Right`. Preserve the seated tablet pose, beak and cheeks. Remove baked eye/brow features only through real clean-face reconstruction, preserving all other pixels/design. Newly measured face centers must come from the actual seated art. No current cloud Basic eye pivot exists to reuse. Loading and worried state may share the same clean body where original face/pose alignment truly matches; otherwise deliver aligned variants, not a morph claim.

## 3. Paid cloud hands — blocker CLOUD_PAID_HANDS

The 13 existing `output/pio-completion-2026-10-23/cloud/<outfit>/layers/body.png` files are clean of eyes, **not clean of hands/tablet**. Isolating exposed hand pixels is insufficient: the silhouette behind shoulders and torso behind raised hands is absent. Reuse all current genuine eyes and optics unchanged unless a measured new body alignment requires separately reviewed placement.

Required files: `seatedTorsoRestored`, `armLeft`, `armRight`, optional sleeve cuff front/back where the costume has them, `handLeftFront/Back`, `handRightFront/Back` where the grip occlusion requires a split. Keep original Christmas cuffs, Hanbok sleeves and astronaut gloves. Shoulder pivots, hidden-root bounds, free versus occupied hand and safe rotation limits must be measured per outfit. They are all unknown for the new seated hand rig. Home standing pivots in the inventory are documented references only.

Proposed semantic hierarchy (new contract; not current implementation): `sceneRoot → characterPose → torso`, left/right `shoulderJoint → arm/sleeve`; held `gripJoint` is a child of the occupied arm, never a second independently drifting body transform. A two-hand-held tablet uses one shared hold group with both hands keyed in local coordinates; independent hand-release is unsupported until a complete release pose is actually authored.

## 4. Cloud tablet — blocker CLOUD_TABLET

Required: complete tablet outline behind hands, restored torso behind the tablet, authentic tablet lighting/logo and accurate front/back contact mattes. Cropping visible green rectangle pixels cannot create the occluded edges. Reconstruct using the approved current tablet design; do not replace it with a flat rounded rectangle.

Current seated z order is exactly `body(0), eyeLeft(1), eyeRight(2), lidLeft(3), lidRight(4), halfLeft(5), halfRight(6), browLeft(7), browRight(8), optics(9)`; absent optics are omitted. All are sibling full-canvas layers. Current eye slot centers/widths/offsets are recorded per outfit in inventory; these are not shoulder pivots.

New compositing contract, back to front: rear arm/sleeve roots → restored torso/clothing → face/eyes one-hot → complete tablet/other held assembly → front fingers/cuffs. A helmet/glasses overlay stays above its face. An object cannot globally go in front of the hands and behind the same hand without split mattes. Exact numeric z values are assigned only after each outfit's authored mattes establish that relation. Eye/half/lid states must never all be opaque simultaneously; worried brows belong to failure expression, not idle loading by default.

## 5. Vacation eyes — blocker VACATION_EYES

Required per outfit and light mode: `recliningFaceClean`, open/half/closed eyes with complete under-eye fur, and separate original optics/visor when present. Current vacation eyes are baked smiling closed arcs; they cannot produce a real blink. Face centers must be measured in the existing reclining source, not scaled from standing home or seated cloud slots. Day/night assets must preserve their own existing lighting, including warm lamp light at night. Opaque summer sunglasses naturally hide eye motion; do not promise visible expression through opaque material. Student glasses and astronaut visor must retain glass/frame occlusion above the face.

## 6. Vacation arms and real props — blocker VACATION_HANDS_PROPS

Required: hidden reclining torso, each arm/hand with authentic shoulder root, held props complete behind fingers, and front hand/contact layers. Use the actual per-outfit prop inventory in [PER-OUTFIT.md](PER-OUTFIT.md); no universal sip animation.

- Café: coffee cup with lid; no straw-to-mouth action is present.
- Pajamas: pillow hug; no drink exists.
- Astronaut v2: closed visor and hands at suit controls; **no drink/straw**. Do not reintroduce rejected v1 straw-through-visor behavior.
- Student: book/backpack and juice; no page-turn claim without page layers.
- Fitness: dumbbells and juice; occupied-hand groups must remain attached, without implying simultaneous physically impossible grips.
- Rainy day: closed umbrella and juice; umbrella opening requires separate authored canopy states and is not included.
- Christmas: gift exists and changes side in authored day/night sources; resolve continuity via visual approval, not silent mirroring.

Proposed hierarchy: `clothMotion → seatedBodyPose → shoulderJoint → arm → gripJoint → existingProp`, with front fingers above prop and rear hand portions below. Face/hat/sprout follow their actual parent attachment. None of the new independent vacation pivots is currently known. Shared rigid foreground sway may continue as a clearly labeled partial implementation; it does not satisfy independent eye, drink or hand animation.

## 7. Hammock and two fixed endpoints — blocker VACATION_ROPES

Required components: `fixedLeftRopes`, `fixedRightRopes`, `clothBack`, `clothFront`, clean beach behind moving cloth, optional strand/cloth contact masks where required. Reconstruct occluded cloth and background when the character/swing exposes them. Full 1024×1536 alignment must remain unchanged. Fixed tree knots and moving cloth joins are distinct anchors.

| Existing source class | Mode | Current renderer attachment | Focus | Existing swing | Status |
|---|---|---|---|---|---|
| Basic original | day | (968,484) | (512,740) | ±1.5° | Original renderer registration, not independently verified two-root rig |
| Basic original | night | (68,465) | (512,845) | ±1.5° | Same limitation |
| All paid candidate originals | day | (968,500) | (512,820) | ±0.55° | Shared approximate preview pivot |
| All paid candidate originals | night | (58,225) | (512,870) | ±0.55° | Shared approximate preview pivot |

Source: `PioVacationSceneResources.registration`, `.originalDay/.originalNight`. These numbers are documented current behavior, not artist-authorized new joints. Each of 28 sources needs measured leftTreeKnot, rightTreeKnot, leftClothJoin, rightClothJoin. All four new anchors are null in inventory. Rotating a flattened image about one point necessarily moves another distinct endpoint; tiny sway reduces visibility, not the geometric constraint.

Proposed z/parent relation: static beach/tree → fixed rear ropes → moving clothBack → reclining character and attached props → clothFront → rope/strand front mattes where needed. Fixed ropes stay in scene coordinates; cloth joins need a validated deformation or joint solution respecting both knots. Do not duplicate the same rope pixels into both fixed and moving layers. The exact deformation implementation is outside this artwork-only task.

## 8. Import budget and acceptance gate

This is a 2D UI PNG/CALayer pipeline, not a 3D mesh or shader LOD pipeline. Keep source texture dimensions as above; UI mipmaps are off for authoring delivery, renderer minification remains an implementation concern. Deliver lossless PNG references with embedded color-profile information retained. Do not apply BC/ASTC recompression to source masters. Runtime packing/asset-catalog compilation needs separate visual/performance approval.

One uncompressed 1254² RGBA layer is 6,290,064 bytes (~6 MiB); one 1024×1536 layer is 6,291,456 bytes (6 MiB), excluding row alignment and caches. A 16-layer full-canvas decoded stack alone is ~96 MiB. Therefore many new full-canvas layers cannot be decoded across all 14 outfits concurrently. Preserve source masters but pack transparent bounds for runtime with explicit rect/pivot; load only the current outfit and limited transition overlap. The 16-layer example is a memory estimate, **not an observed peak or a performance PASS**. Do not change texture compression/caching merely to meet a paper target without measurement.

Blocker release requires actual supplied files and measured anchors, assembled neutral match to the original reference, no exposed seams at both intended joint extremes, and correct one-hot eye states. Check 64pt/220pt on light/dark for cloud, both day/night lighting for vacation; neutral, transition midpoint and endpoints; character/prop grip contact; both tree knots; bounds/clipping; and changing outfits without a Basic flash. Capture actual native rendering on Mac and iPhone simulator. Check Reduce Motion and offscreen suspension plus comparable CPU/memory with the new final layer count. Existing neutral PNGs cannot prove these future motions. Approval must happen per outfit, not by assuming Christmas covers all 13. Stage 1–4 distinct growth appearance requires separate source availability and rendering evidence, not just retained level thresholds.
