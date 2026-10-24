# Pajamas artwork candidate — 2026-10-23

Status: **ARTWORK_CANDIDATE_PENDING_USER_VISUAL_APPROVAL**. This is offline artwork evidence, not a native-app animation PASS.

Selected genuine new arm sources: `../source/wing-left-candidate-v4.png` and `../source/wing-right-candidate-v2.png`. Both were newly rendered by built-in image_gen from approved-original / existing-arm references. Body, combined cap/sprout/pompom and pillow remain existing native parts; shared feet and eyelids are reused and do not count as newly generated parts. Existing five functional native parts remain body/headwear/left arm/right arm/pillow.

The large cream palms overlap the pillow in the same sleepy hug, with shorter visible cuff lengths and complete rounded shoulder roots. Lavender stars, ivory piping, fuzzy plush and original open beak remain. Default eyes are closed. A small thumb lobe appears on the new left mitten; this differs from the approved original oval hand and is specifically subject to user visual approval. The right visible sleeve remains slightly longer than the original's compact cuff. Do not call this an exact original match or final approval.

Left v2 and v3 were rejected because the generated source included a broad translucent halo. They are preserved for traceability and are not used in final dated registration. The selected v4 has no broad halo; source antialiasing and any native edge fringe are preserved without alpha cleanup.

## Evidence

- `neutral-alpha.png`: actual transparent 1254×1254 composite.
- `exports/*-1254.png`: 13 full-canvas source registrations, including shared eye state alternatives; five functional character part exports are body/headwear/wingLeft/wingRight/pillow.
- `neutral-dark.png`, `neutral-light.png`: direct background checks.
- `comparison-64pt-3x-{dark,light}.png` and `comparison-220pt-3x-{dark,light}.png`: approved original, prior candidate, neutral, hug −3°, hug +3° at 3× density.
- `sleepy-hug-offline.gif`: 32 frames / 440×440 / approximately 2.88 seconds. Both hands and pillow rotate as one rigid group ±3° around top-left pivot (820,900); body/headwear/feet/eyelids remain fixed. No free hand waving while holding the pillow.
- `registration-candidate.json`: every exact top-left uniform scale, offset, pivot, angle, z-order and SHA-256.
- `source-alpha-audit.json`: selected native source dimensions, bounds and alpha counts.
- `artifact-audit.json`: output alpha/dimensions, 32 GIF frames and hash agreement.
- `generation-prompts.json`: exact built-in image generation prompts including rejected candidates.

## Method and limits

`register.py` uniformly downsizes complete source canvases and applies rigid transforms for QA. It does not crop native sources, mask, paint, clean alpha, upscale or nonuniformly deform them. Alpha bounds guide placement only. The source alpha is never rewritten. Pillow −10° base angle and both hands are then grouped for the ±3° rocking proof. No app code, asset catalogs, runtime resources, builds, app tests, user data, purchases, commits or pushes were changed/run by this work.

Viewed original, prior composite, every generated arm, new neutral dark, ±3° endpoints and 64pt light comparison. Palms remain visibly in contact with the pillow and no detached grip appears at either endpoint. Generated sources and 1254 exports contain real transparency. Pending user choice: final sleeve compactness, left thumb silhouette and overall cuteness relative to the approved original.

Reproduce artwork-only derivatives with the bundled Python runtime and `scripts/register.py`. This is artifact rendering only; target-hardware rendering and app motion are unverified.
