# Cherry Blossom Pio — new component candidates

Method: built-in `image_gen`, transparent-background editing/reconstruction. No CLI or upscaled sheet crops. The approved wardrobe PNG is unchanged. Native outputs are 1254×1254 RGBA; they are not claimed to be 1536 masters. These files are candidates pending registration and artwork QA, not an approved or integrated outfit.

Source reference: `Daylog/PioWardrobe.xcassets/pio_outfit_cherryBlossom.imageset/pio_outfit_cherryBlossom.png`.

Four active component roles were generated: body, left wing, right wing and head flower. Three body attempts exist; the first changed framing, and the second retained an arm. Only body-v3 is used by the candidate preview. Existing genuine high-resolution eye/lid/sprout/foot artwork may be reused through measured rendering transforms; these are not counted as newly generated art.

## Final body correction prompt

Edit target: saved `body-v2-rejected-wing-remains.png`.

> Precise local correction of this existing TRANSPARENT 1254x1254 body rig layer. Change ONLY the remaining separate cream arm hanging down on SCREEN LEFT, around x230..355,y790..975. That arm is an ERROR: remove it completely. Pixels exterior to the body/cape should become fully transparent. Reconstruct only the small hidden shoulder and left edge of pink cape behind that arm, continuous fluffy ivory torso beneath the collar and continuous pink floral cape edge with white piping. No stump, fingers, wing, arm or hand may remain at this spot. The body layer must contain ZERO eyes, ZERO wings/arms, ZERO feet and ZERO head sprout/flower. Keep all other existing pixels, full1254square canvas, large upper transparent headroom, original head/body placement, round body silhouette, fixed rosy cheeks and orange smiling open beak, precise garment embroidery/bow/clasp unchanged. Do not enlarge, recenter or redesign anything else. Do not add eyes or detached parts. Preserve genuine alpha background, fluffy premium 2.5D shading. One clean body layer only.

Output: `body-v3-candidate.png`.

## Left wing prompt

> Precise game artwork component reconstruction from approved reference. Produce ONE standalone SCREEN-LEFT LOWERED CREAM WING/ARM from Cherry Blossom Pio, complete with hidden shoulder root. Only this single wing; absolutely no body, face, cape, sprout, flower, eyes or feet. Preserve its source rounded chubby oval wing silhouette, little soft feather lobes, ivory fuzzy material, warm cream-to-pale-gold 2.5D shading and fine soft fur. Natural neutral direction: shoulder/root toward upper-right, wing hangs down and to left. Reconstruct generous continuous hidden shoulder pixels at top-right, rounded and tapered to fit under cape. Roots and tips fully visible with transparent padding. This must match the reference's LEFT lowered wing, which is different from its raised right wing: do not mirror the raised wing. Native high-resolution genuine artwork with real transparent RGBA background, no outlines, flat shapes, checkerboard, text, borders or cast ground shadow. Actual rigging component candidate, not a concept sheet.

Output: `wing-left-candidate.png`.

## Right wing prompt

> Precise game-art reconstruction. Extract and reconstruct ONLY THE SCREEN-RIGHT RAISED CREAM WING of the approved supplied fluffy Cherry Blossom Pio. One standalone complete wing/arm, no entire character, no eyes, face, clothes, flowers, leaves, feet or other objects. Preserve the approved cream fuzzy texture, subtle warm 2.5D shading, silhouette and softly rounded three-feather/lobed edge of the source wing at the character's right, exactly its raised neutral direction. Reconstruct a generously long hidden rounded shoulder attachment root continuing naturally from the visible wing, so it can rotate while covered by torso and cape. Root on the lower-left of wing, fingers/feather tips toward upper-right. Same material and lighting as reference; no redesign or geometric substitute. Native high-resolution standalone wing with substantial real fur detail, transparent RGBA background, no floor shadow, no checkerboard or text. Keep full uncropped root/tips and 10% transparent padding. This is one production layer candidate for independent rigging, not a sprite sheet or concept illustration.

Output: `wing-right-candidate.png`.

## Head flower prompt

> Reconstruct ONE standalone accessory from the approved Cherry Blossom Pio reference: ONLY the pink sakura blossom attached to the character's upper SCREEN-RIGHT head, near the green sprout. Do NOT reproduce the bow/clasp flower on the cape. Match the head flower's five softly rounded notched blush-pink petals, delicate pink material/veining, small warm gold rounded stamen stems, soft premium2.5D diffuse shading, friendly plush collectible style. Keep its original slight three-quarter tilt/direction and petal shape. Render complete uncropped petals and include a small natural hidden pink blossom-base attachment behind flower for stable independent swaying. Do not add a green leaf, long stalk, stem, ribbon, body, eyes, wing, background, outline, border, watermark or text. One large high-resolution isolated fullflower, genuine transparentRGBA background with generous transparent padding, no checkerboard and no floor shadow. Not a sprite sheet, not a concept board, not a simplified geometric icon. This is actual detailed character accessory artwork to be scaled DOWN into its measured attachment position.

Output: `head-flower-candidate.png`.

Registration/preview renders do not edit these source images and do not grant animation support to the application. The actual application catalogs and code have not been modified for these candidates.
