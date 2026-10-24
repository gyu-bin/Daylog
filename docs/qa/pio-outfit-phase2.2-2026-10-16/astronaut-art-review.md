# Astronaut reconstructed art review

2026-10-16. **Visor and shell source-transparency gate ACCEPT for registration experiments. Final costume assembly and native motion remain pending.** No source artwork or application was changed.

Native1254×1254sources inspected: `candidates/astronaut/visor-v1.png` and `helmet-shell-v1.png`. The visor's raw gray center must not be interpreted as an opaque matte: native premultiplied-last RGBA decoding gives these exact values (0–255):

| Source point x,y | Visor premultiplied RGBA | Helmet shell RGBA |
| --- | --- | --- |
| 627,627 | 8,8,8,13 | 0,0,0,0 |
| 627,700 | 3,3,3,5 | 0,0,0,0 |
| 400,650 | 27,27,27,31 | 0,0,0,0 |
| 850,650 | 27,27,27,33 | 0,0,0,0 |
| 627,450 | 35,35,36,39 | 0,0,0,0 |

Across source rectangle x450..<800,y500..<800, visor alpha min/median/p90/max is3/21/35/46 with mean21.884/255. Shell alpha min/median/p90/max is0/0/0/1 with mean0.020667/255. Thus the visor has genuinely low center alpha and the shell genuinely open center, rather than relying on lowering the entire layer's opacity.

Correct CoreGraphics composites placed the unchanged visor over the existing Basic assembled face on both ivory and forest at layer opacity1.0 (source scale0.6, top-left offset230,230 on its1254canvas). Diagnostics are preserved in this QA package at `diagnostics/visor-alpha/visor-face-light.png`, `visor-face-dark.png` and audit script `pio-visor-audit.swift`. This temporary placement demonstrates transparency only and is not a proposed final helmet registration. Eyes/beak remain clearly visible with slight glass tint and stronger reflective edges. No arbitrary whole-layer opacity reduction, alpha cleanup, pixel repainting or cutout was used.

## Additional body/glove native-source review

Individually viewed `body-clean-v1.png`, `glove-left-v1.png`, `glove-right-v1.png` and the exact approved original at `Daylog/PioWardrobe.xcassets/pio_outfit_astronaut.imageset/pio_outfit_astronaut.png`. The clean body retains cream face/beak/cheeks, white/lilac suit, three blue/green/red panel buttons, gold star and lilac hose details, with removed eyes/helmet/gloves/sprout/feet areas completed. Both glove candidates contain one rounded mitten and a complete fabric root, with matching white/lilac plush materials. Unlike rejected Hanbok right-v1 there is no second cream hand at the root.

Both astronaut parts include a relatively long sleeve with rear bands. The original character has short compact arms; registration must bury the rear root via actual body coverage and retain a rounded exposed cuff/mitten. Exposing the full tube would fail that proportion requirement. This constraint was sent to the rig worker. These sources are suitable for assembly trials, not yet approved as a complete astronaut rig. Body star, buttons and hoses remain baked into the torso.

The final astronaut assembly still needs shell-to-body fit, face clearance under the visor highlights, glove roots, sprout/helmet depth and motion clearance at64/220pt light/dark. Passing source transparency does not approve the final character, visor movement, all growth stages or native animation.

## Astronaut-a assembly — REJECT

Independently viewed `registered/astronaut-a/astronaut-assembled-comparison-220pt-3x-light.png` after the parent and rig worker flagged it. The lower helmet/visor rim crosses the lower beak/mouth area, the broad lower helmet plate crowds the torso, the face reads low within excessive forehead space, the left arm extends as a long horizontal tube and both feet expose too much orange ankle. These are visible anatomy/proportion defects, despite correct transparency. A is not approved for integration.

The worker identifies a v1 aperture-to-base geometry limitation: keeping width reasonable still places an excessively deep lower plate across face/controls. Parent supplied genuine `helmet-shell-v2.png`, individually viewed here: a thinner lower rim and more usable opening without the previous lower base pods. V2 is suitable for a new registration attempt, not yet assembly-approved. Registration must restore mouth clearance, compact down-left mitten placement and feet tucked into suit cuffs. No global visor-opacity reduction or image masking is authorized by this review.

## Astronaut-b first review — BLOCKED pending fit refinement

Viewed b's original/assembled220pt3x light comparison and full neutral dark. V2 shell clears the mouth and panel, and raised feet reduce excessive ankle exposure. However the visor's right rim protrudes outside the helmet/ear housing as another curved glass hoop, roughly around master x930–1010,y470–800. This is a registration mismatch visible on the dark neutral; transparent glass should sit within the shell opening rather than forming an external ring. Both sleeves still expose more long thin arm than the approved compact original. Worker was asked to nest the unchanged visor inside the shell through real registration and bury rear sleeve bands through actual torso coverage. No alpha mask/opacity workaround is requested. B is not the selected final assembly.
