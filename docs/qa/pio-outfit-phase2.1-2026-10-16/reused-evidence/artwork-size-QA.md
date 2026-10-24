# Pio Phase 2 — static artwork and layer-readiness review

Reviewed 2026-10-16. Scope: the 13 approved full-resolution costume PNGs, without any source modification, new art generation, or application change. This report is an asset review, not an app runtime, frame-rate, Reduce Motion, or complete animation certification.

**Static artwork QA: PASS for all 13. Outfit animation capability: PARTIAL. Four-stage visual compatibility: NOT_TESTED / unsupported by the present source structure.** No serious static defect requires excluding or regenerating an outfit. All files are single flattened 1254×1254 RGBA illustrations, not independent body, eye, wing, clothing, or accessory layers.

## Evidence and reproduction

- `artwork-size-review.swift` reads each original PNG, decodes with Core Graphics, and uses normal premultiplied-alpha compositing on ivory and forest backgrounds. It does not crop, recolor, trim, repair, or write source images.
- `artwork-size-manifest.json` contains all original paths, SHA-256 hashes, dimensions, image counts, alpha statistics, significant-alpha bounds, and all 16 output layouts.
- `artwork-findings.json` records the 13 individual verdicts and remaining layer requirements.
- The entire source canvas is fit inside an exact 48/64/120/220-point square. Size is the **canvas span**, not a normalized head/body height. Extra hats/props legitimately change apparent body size.
- Eight @1x sheets were visually inspected in full, covering all 13 outfits at every requested size/theme. Matching @2x sheets are supplied for Retina inspection; no image was upscaled beyond its original pixels. Earlier full-size PNG inspections are recorded in Phase 1 QA.
- Run from the repository root: `swift -module-cache-path /tmp/pio-art-qa-swift docs/qa/pio-outfit-phase2-2026-10-16/artwork-size-review.swift`.

| Canvas size | Ivory @1x | Forest @1x |
|---|---|---|
| 48pt | [Light](artwork-48pt-light-1x.png) | [Dark](artwork-48pt-dark-1x.png) |
| 64pt | [Light](artwork-64pt-light-1x.png) | [Dark](artwork-64pt-dark-1x.png) |
| 120pt | [Light](artwork-120pt-light-1x.png) | [Dark](artwork-120pt-dark-1x.png) |
| 220pt | [Light](artwork-220pt-light-1x.png) | [Dark](artwork-220pt-dark-1x.png) |

The corresponding Retina file names end in `-2x.png`. The on-sheet `pt` label describes the rendered logical span; image viewers may resize an entire contact sheet to their window.

## Per-outfit review

Every PASS below applies to both light and dark static composites. A small-size PASS means the face and theme remain recognizable, not that all embroidery or fabric texture survives reduction. Fine surface detail is expected to disappear at 48pt.

| Outfit | 48 / 64 / 120 / 220pt | Static findings | Genuine independent-layer work still required |
|---|---|---|---|
| Cherry Blossom / 벚꽃 | PASS / PASS / PASS / PASS | Pink cape, bow and hair flower stay distinct; face, two-leaf sprout, raised wing and feet are complete. Tiny flower centers blend at 48pt. | Reconstruct clean head/body behind hair flower and cape; separate flower root, cape/bow and wing with hidden shoulder underlap. Exposed right wing is a relatively low-risk first prototype. |
| Summer Vacation / 여름 휴가 | PASS / PASS / PASS / PASS | Hat, sunglasses, blue shirt and drink read at 48pt. Sunglasses intentionally conceal the eyes, consistent with design. Orange slice and glass are intact. | Separate hat, sunglasses, shirt, cup/hand assembly and clean body. Eyes/face under dark glasses do not exist as reusable source pixels; blink requires new hidden face art or explicitly remains unsupported. |
| Autumn / 가을 | PASS / PASS / PASS / PASS | Brown hat and orange scarf read well; scarf knit/plaid detail compresses at 48pt. Maple leaf, free wing and feet are complete. | Reconstruct torso behind scarf and scarf tails behind overlaps; separate hat, scarf, maple-leaf/hand unit and right wing. Good later limited-wing candidate, but scarf clearance needs pose tests. |
| Winter / 겨울 | PASS / PASS / PASS / PASS | Blue cap/scarf and white cuffs remain readable. Pom-pom is intact on dark background; snowflake detail is mostly a white motif at 48pt. | Author neck/body behind scarf, concealed head under cap, and complete cuff/wing roots. Pom-pom and scarf-tail motion need dedicated pieces with underlap. |
| Halloween / 할로윈 | PASS / PASS / PASS / PASS | Pumpkin cap/body/bag distinguish this outfit immediately. Face is clear; candy and bag silhouette intact. Tiny candies merge at 48pt. | Separate pumpkin headwear/body shell, collar/bow, both wing roots and bag/handle grip. Hidden torso and bag-side costume need reconstruction; do not swing the bag independently around an invented floating grip. |
| Christmas / 크리스마스 | PASS / PASS / PASS / PASS | Santa hat, gift, belt and red/white outfit remain distinct. Hands visibly hold gift; feet are intact. Ribbon detail simplifies at 48pt. | Reconstruct torso and cuffs behind the front gift; separate gift/hand assembly, coat, scarf, hat and pom-pom. Coordinated two-hand gift hold makes this a high-complexity independent-arm candidate. |
| Hanbok / 한복 | PASS / PASS / PASS / PASS | Pink skirt, ivory crossover collar and navy ribbon distinguish it from the blossom cape. Sleeves, ornament, face and feet intact. Tassel/floral detail simplifies at 48pt. | Complete sleeves and shoulder roots, reconstructed torso under skirt, split front/back skirt, ribbon/ornament and hair accessory. Walking cannot be achieved by scaling the skirt without new hidden leg/hem art. |
| Cafe / 카페 | PASS / PASS / PASS / PASS | Brown beret, green apron and cup remain recognizable. Cup print is a simple sprout mark without text. Both wings and feet are complete. | Separate free right wing, cup/left-wing unit, apron straps and hat; reconstruct shoulder/torso occlusions. Relatively low-risk limited right-wing candidate; cup gesture remains a separate task. |
| Student / 학생 | PASS / PASS / PASS / PASS | Glasses and book strongly identify the outfit at 48pt. Eyes align inside frames; backpack, sweater, tie and wing remain coherent. | Clean face beneath glasses, glasses foreground, book/left-wing unit, backpack/straps and right wing. Limited free-wing prototype is plausible; independent blinking must not squash frames together with eyes. |
| Fitness / 운동 | PASS / PASS / PASS / PASS | Headband, green tracksuit and pair of dumbbells read at 48pt. Two clear grips; intact feet. Small zipper/logo detail simplifies. | Complete left/right wing+dumbbell units, hidden torso/arms under weights, tracksuit and headband. Both occupied wings require coordinated articulation and verified occlusion ordering. |
| Rainy Day / 비 오는 날 | PASS / PASS / PASS / PASS | Yellow coat, boots and umbrella remain distinct. Entire right umbrella tip is present. Significant-alpha source bounds end at x=1239 on a 1254-wide canvas: **14 clear pixels** remain, about 2.46pt at 220pt. | Reconstruct body inside hood/coat, separate hood/coat, umbrella shaft/canopy/hand assembly, boots and hidden limb roots. Additional runtime viewport padding and extreme-pose bounds checks are essential. No destructive canvas crop. |
| Pajamas / 잠옷 | PASS / PASS / PASS / PASS | Lavender stars, nightcap and pillow read clearly. Closed eyes are intentional sleeping expression, not missing eyes. Pillow does not obscure beak; feet intact. | Open-eye variants and clean face must be newly authored for wake/blink; hidden torso/sleeves behind pillow, pillow/hand assembly and cap tail require reconstruction. Gentle whole-character breathing is a reasonable PARTIAL fallback; not independent pillow/sleeve animation. |
| Astronaut / 우주인 | PASS / PASS / PASS / PASS | White/lavender helmet/suit, clear face and colored controls read at 48pt. Sprout exits helmet opening as intended stylization. Visor highlight does not hide face. | Separate clean face/eyes from visor/reflection, helmet shell, suit, gloves/arms and feet with hidden joints. Facial motion must remain behind fixed visor layers. Helmet scaling with a baked face is not independent articulation. |

## Transparency, composition, and identity

- All 13 preserve the cream plush round character, glossy eyes (except intentional glasses/sleep treatment), rosy cheeks, orange beak and green sprout. Small pose and body-width variations are present; this is a cohesive illustration set, not one pixel-identical shared body.
- No missing limb, broken sprout, serious attachment defect, board label, watermark, or source clipping was observed. Accessories overlap the body naturally in their approved static poses.
- Bright colored specks visible in a raw transparent-PNG viewer are not visible matte halos in the normal ivory/forest composites. Alpha edge statistics are retained rather than modifying approved originals. All have zero edge pixels above alpha 16/255; very low-alpha edge traces are not silently erased.
- Rainy Day has the tightest significant right margin. Static approval does not imply enough internal canvas margin for jumping/scaling. The motion host should reserve roughly 10–12% external space and verify its actual extrema (including hats, umbrella, feet and shadows), without shrinking/cropping the underlying source artwork merely to hide an error.
- At 48pt, use outfit names alongside thumbnails. The blue Winter and red Christmas, pink cape and pink Hanbok, and cream/green Cafe and Fitness remain distinguishable by silhouette/color/props; microtexture is not a dependable small-size cue.

## What the present assets can honestly support

All 13 can be displayed unchanged and can move as complete illustrations: modest translation, whole-character breathing-like scale, bounce, and a restrained pose tilt. Their baked hats, glasses and props remain together because the entire image moves together. This is **PARTIAL animation**, not articulated wings, eyes, feet, clothing or handheld objects. A translated static pose does not establish natural walking/running, and rotating a PNG does not establish flapping/waving.

No approved costume PNG contains hidden clean torso pixels, separate eye/lid images, complete occluded shoulder roots or alternate costume poses. A mask can isolate only visible pixels. Moving that region may expose holes, duplicate a piece of the body, cut a scarf, or reveal the wrong silhouette. A quality layer reconstruction must add the missing hidden content, preserve face/material/light direction, register a shared coordinate system, and pass pose and size review. That work is not performed by this audit and no new art is generated in this Phase 2 review.

Every outfit has **PARTIAL animation capability** and **no verified four-stage outfit rig**. Persisting the same selected outfit across level boundaries is useful state behavior, but does not make its picture Stage 1/2/3/4 compatible. Keep selection persistence distinct from stage-specific visual support in UI and reports.

## Existing green base and practical subset

- `Daylog/Views/Splash/RoutimoriSplashView.swift` has a 1319×1192 `RoutimoriSplashRig`. It renders a masked right wing and complementary body from the same full image, plus a whole-character bob/tilt. It does not contain independent eyes, feet, sprout, clean body, or four-stage costume attachments. Existing neutral / minus10-degree QA snapshots show the narrow right-wing operation; they are prior offline evidence, not newly recorded runtime proof.
- `docs/qa/routimori-growth-stages-2026-10-15/assets/stage1...4.png` is a separate set of four flattened resting-pose artworks. Its README explicitly says it is not a rigged kit or app integration. The 64pt comparison shows leaf/wing growth. Those front-facing small-wing bodies differ from the waving wardrobe/splash reference, so reusing wardrobe masks/coordinates across them would be unverified.
- `PioTrial.rigLayers(stage:)` exposes an older, separate layered Pio asset family. Its numeric four-stage support does not transfer to the new green-sprout costume family. Architecture may be reusable; retired character pixels are not appropriate replacement body art.
- Best currently verified independent-part subset is the **existing Basic limited right-wing mask** within its original tested pose range. For later genuine layer authoring, start with **Cherry Blossom or Cafe**, then Student: each has a largely exposed free right wing. Even these need clean shoulder/body reconstruction and extreme-pose verification; this is a prioritization recommendation, not a completed layer PASS.
- Halloween, Christmas, Hanbok and Astronaut are important representative QA subjects, but their detailed occlusions make them poor candidates for rushed generic masking. For this phase, retain their approved static art and accurately label whole-character motion PARTIAL. Leave independent facial/wing/accessory motion and stage variants pending.

## Status for this audit

| Area | Status | Evidence / limit |
|---|---|---|
| OUTFIT_ARTWORK_QA | PASS | All 13, all four sizes, both themes reviewed statically. |
| SOURCE_RESOLUTION_ALPHA | PASS | Original 1254² PNGs, no upscaling, source hashes and padding recorded. |
| OUTFIT_ANIMATION | PARTIAL | Whole-character movement possible; no independently authored costume parts. Runtime verification belongs to the integration report. |
| STAGE_1_COMPATIBILITY | NOT_TESTED | No registered green costume stage rig. |
| STAGE_2_COMPATIBILITY | NOT_TESTED | No registered green costume stage rig. |
| STAGE_3_COMPATIBILITY | NOT_TESTED | No registered green costume stage rig. |
| STAGE_4_COMPATIBILITY | NOT_TESTED | Mature-looking sprout alone does not certify Stage 4 registration. |
| APP_RUNTIME / REDUCE_MOTION / PERFORMANCE | NOT_TESTED | This worker authored only offline diagnostic artifacts. |
| SOURCE_ASSET_MODIFICATION | NONE | Original assets read only; no generation, repair or replacement. |
