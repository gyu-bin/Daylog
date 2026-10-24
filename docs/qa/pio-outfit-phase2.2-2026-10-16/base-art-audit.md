# Phase 2.2 green Basic and Christmas source audit

2026-10-16. Read-only full-resolution visual/source audit. The user now authorizes genuine reconstruction; the earlier Phase 2.1 prohibition on new hidden artwork no longer blocks that new work. This audit itself generates no art and changes no application/source PNG.

## Canonical source decision

Use the **currently displayed wardrobe/splash Basic** as the Basic pilot's exact identity and pose reference:

`Daylog/PioWardrobe.xcassets/pio_wardrobe_basic_reference.imageset/pio_wardrobe_basic_reference.png`

- 1319 × 1192 RGBA; SHA-256 `daf62f4863afde6d6cf48b4a2202c5a6c3dac45dddec72b88460d1363e4a97db`.
- Byte-identical to `Daylog/RoutimoriTrial.xcassets/routimori_splash_character.imageset/routimori_splash_character.png`; both hashes checked again for this audit.
- Cream plush round body, two green leaves, asymmetrical tilted open-mouth expression, lowered screen-left cream wing and raised screen-right cream wing. Preserve these proportions, expression and the raised right-foot pose in the reconstructed neutral assembly.
- This reference directly preserves the current user-visible Basic. Do not normalize it into a symmetrical frontal pose during separation.

Christmas remains its own approved design and registration reference:

`Daylog/PioWardrobe.xcassets/pio_outfit_christmas.imageset/pio_outfit_christmas.png`

- 1254 × 1254 RGBA; SHA-256 `7df7b6c55397cc00486ed2c83a21ad1583d7f139307efa929d5219917c75b66d`.
- Preserve Santa hat/pompom, green sprout, red coat and scarf, white fur trim, belt, two hands holding the green/red gift, visible orange toes, face and plush material. Separate hidden content around this design rather than redressing or stretching the Basic pose to resemble it.

The alternative `docs/qa/routimori-master-preview-2026-10-15/routimori-master-v1.png` is 1254 × 1254, SHA-256 `cb57ff6b8097bf4c6196d18ec00c43c2e766ec9ea77769bc6d866747a6bbb24a`. It is byte-identical to `docs/qa/routimori-growth-stages-2026-10-15/assets/stage4.png`. It has a frontal face, closed beak and green resting wings. It is valid reference art for a separate growth family, but is **not** the same pose/design as current Basic and cannot replace its body/face during this pilot.

## Genuine green components already available

| Existing material | What it really contains | Reuse decision |
| --- | --- | --- |
| Wardrobe Basic / splash PNG | One flattened complete character | Canonical identity reference and neutral comparison; no complete clean body or eye/limb layers. |
| `Daylog/Views/Splash/RoutimoriSplashView.swift`, `RoutimoriSplashRig` | Two CALayers referencing that same flattened PNG; wing region and complementary body masks; right shoulder `(1050,830)`; 8-source-pixel mask overlap; ±10° limited wave | Reuse the proven coordinate convention and modest motion range as reference. These are not independently authored hidden-root PNGs. Do not mistake a masked body with a wing cutout for a reconstructed clean body. |
| `Daylog/Components/PioOutfitMotion.swift` Basic wave branch | Reuses the same approved splash mask rig | Existing implementation reference, not new source art. |
| Christmas approved PNG | One complete flattened costumed character | Canonical Christmas design only; no hidden face, lids, sleeve roots, clean gift underlay or separated gift. |
| `docs/qa/routimori-growth-stages-2026-10-15/assets/stage1..4.png` | Four independently flattened resting-pose review illustrations | Reference only. Their README says they are not a rig kit. Body/eye/feet registrations differ; no costume compatibility implied. |
| `Daylog/RoutimoriTrial.xcassets/routimori_sync_{loading,success,failure}.imageset` and vacation characters | Complete pose/context-specific illustrations | Do not harvest a different expression/body as a hidden layer for this pilot. |
| `Daylog/PioTrial.xcassets/pio_rig_*`, `pio_stage3_*`, `pio_stage4_*` | Older orange Pio family | Excluded. Layer names do not make these green-character components. |

**Available complete independently authored green rig components: zero.** Visible pixels can be extracted as source material, but no mask can recreate the missing under-surface. Parent-controlled image generation/reconstruction must supply those surfaces, with the approved neutral image as the comparison gate.

## Required reconstruction

Basic first: a clean round body with the approved beak/cheeks but without baked eyes, wing imprints, feet or sprout; separate original-style open eyes and authored half/closed lids; complete left/right wings with buried roots; complete stem/leaf cluster with hidden root; complete feet with upper underlap. Mouth may stay static in the first pilot. Do not promise speaking until its clean face underlay and mouth states exist.

Christmas second: clean underlying head/face and clothed torso; eye/lid set; complete coat/belt region behind gift and hands; complete sleeve/cuff/hand pieces with hidden shoulders and grips; gift with its full hidden edges; hat/brim/pompom and clean head beneath; scarf/tail and clean coat beneath; stem and feet with underlap. A gift plus both hands can be a coordinated rig assembly, but moving the complete PNG is not independent gift motion.

For exact canvases, provisional authoring anchors, occlusion requirements and gates, use `pilot-art-contract.md`. None of the newly required parts has been generated or approved by this audit.
