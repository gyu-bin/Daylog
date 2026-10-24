# Basic cloud generation provenance

Tool: built-in `image_gen`, transparent_background=true. No API/CLI fallback. Every accepted source PNG is copied byte-for-byte; registration uses runtime CALayer sampler rectangles, not offline raster resizing. These are candidate assets awaiting actual native visual approval.

Root-generated Basic clean-face, eye pair, restored torso, tablet, arm pair and Christmas torso/arms use the root's [normalized actual prompt log](../../../docs/qa/pio-independent-2026-10-24/ROOT-GENERATION.md). That log is normalized, not claimed to be a byte-for-byte transcript. Verbatim tool arguments remain in the conversation. New eyelid and half-eye prompts below are verbatim from this worker's calls.

## Closed pair — exact prompt

Inputs: `/Users/mungyubin/.codex/generated_images/01a13e4c-eb2f-7c33-a58c-004a195b88c3/exec-ec8dd001-6239-489d-9c83-cb8b5a39c2b6.png` (edit target); `Daylog/RoutimoriTrial.xcassets/routimori_sync_loading.imageset/routimori_sync_loading.png` (style reference).

Output: `/Users/mungyubin/.codex/generated_images/01a167e0-d86f-7633-94a1-40ac5235c4f4/exec-ef710958-dda3-4053-9e9a-dba250a55ad4.png`; project copy `source/closedPair-v1.png`.

```text
Use case: precise-object-edit. Asset type: genuine isolated transparent closed-eye pair for RoutiMori Pio's independent blink animation. Image1 is the edit target: two existing tiny glossy eyes only on a transparent 1254x1254 canvas. Image2 is character identity/style reference only, do NOT include character/body/tablet/sprout. Change ONLY the two eyes in Image1 to gently fully closed eyelids, keeping both lid positions, approximate eye widths, angle, spacing and the entire 1254x1254 transparent canvas unchanged. The eyelids should be delicate soft curved closed eye seams with subtle premium 2.5D depth, small dark-brown lashes/creases and a tiny edge of warm ivory fur matching Image2 face. Eyes peacefully closed for one blink, not grinning happy eyes, not downcast eyebrows. Keep each tiny eyelid about the same135px width as the existing eye in Image1, centered at its existing eye position. Do NOT make huge puffy fur sausages, thick tubes, giant lashes, or flat vector shapes. Preserve soft natural texture and shading. Output exactly two isolated fully closed lids, no open eye iris or eye globe, no brows, no face, no body, no cheek patches, no text, no board, no background or shadow plane. Genuine transparent alpha.
```

The tool changed pair placement and width; do not directly overlay the whole generated canvas. `registration-v1.json` measures each source part and maps it to the original eye slot without changing PNG pixels. Closed lids remain a visual candidate until checked against the assembled face.

## Half pair — exact prompt

Same two input images. Output `/Users/mungyubin/.codex/generated_images/01a167e0-d86f-7633-94a1-40ac5235c4f4/exec-2cb37364-341b-46c2-9634-0e05bf1897d6.png`; project copy `source/halfPair-v1.png`. Not part of v1/v2 initial native build until explicitly added to registration for a subsequent focused review.

```text
Use case: precise-object-edit. Asset type: transparent independent half-blink eye pair for RoutiMori Pio. Image1 edit target contains ONLY two small glossy dark-brown eyes on the transparent 1254x1254 canvas. Image2 is identity/material reference ONLY. Modify ONLY the two eyes in Image1 into HALF-OPEN eyes in a calm natural blink. Keep the existing eye globes, their exact tiny sizes, two highlights, colors, positions and transparent canvas. Lower a soft warm ivory fur eyelid from the top over the upper 45 percent of each eye; leave the lower glossy iris/globe naturally visible. The lid edge is soft textured fur matching Image2, attached tightly to the eye top, not a thick eyebrow, pillow, hat, tube or large face patch. Preserve all lower eye shading and a subtle visible highlight. No eyebrows, cheek, body, beak, tablet, text, background, board, face or additional objects. Exactly two small genuinely isolated semi-closed eye sprites with real transparent alpha. Do not enlarge eyes. Do not include any full character. Keep canvas1254x1254 and original pair locations exactly. Premium adorable2.5D original style.
```

The tool's image shows separate glossy half-eyes with actual fur lids. It is genuine new eye-state art, not an upscaled crop or a flattened complete character. As with the open/closed pair, independent runtime sampling/registration is necessary before visual approval.
