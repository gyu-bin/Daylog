# Rainy Day shaft and attachment refinement — 2026-10-23

**Status: PARTIAL / selected offline artwork candidate, visual approval pending. Not app integration.**

## Improvement

The shaft/J now sits behind both canopy and hood. The formerly conspicuous silver cap is naturally occluded by actual artwork, without a mask or painted patch. The right mitten remains frontmost and the yellow J remains visible below it. The existing body, approved original, canopy, sleeve, eye/lid and foot source files were preserved.

One controlled built-in imagegen reconstruction produced `../source/umbrella-shaft-v3-candidate.png`. This is a genuine newly rendered silver shaft and glossy yellow J, not an upscaled crop. Its exact prompt, reference and original generated location are in the `.generation.json` sidecar. The old v2 source is retained. V3 has a longer hidden upper shaft and slightly different handle contour; registration uses uniform scale0.4163, offset(726.2,449.4), neutral rotation−16° and world grip pivot(745,875). No crop, masking, painting, alpha cleanup, deformation or upscale was performed.

The new shaft improves the upper join and removes the old motion endpoint clipping within the sampled proof. Its attachment material matches the existing warm glossy rainwear. No source beyond this shaft was regenerated.

## Actual offline evidence

-14 transparent1254×1254 RGBA registered layer PNGs, all source hashes recorded and checked.
-64pt and220pt@3x original-versus-candidate comparison PNGs on light/dark.
-Native neutral-dark and umbrella−5° endpoint inspected; actual GIF decoded frames0/12/19/36 inspected. Left-wing±12° and open/half/closed eye variants included.
-48-frame512×512 offline GIF: body fixed; left wing±12°, umbrella+shaft+hand0…−5°, eyelid swap. It is not whole-body-only motion.
-Zero nonzero-alpha pixels outside1254 canvas for all four moving components at all48 sampled GIF poses. `all-frames-motion-bounds.json` uses a single padded raster and exact inner crop, so no mismatch from comparing separately interpolated images. This resolves the previous v2 sampled alpha1 clipping issue; it is not a mathematical guarantee at untested arbitrary angles.
-Approved original hash unchanged; source files remain unchanged after generation and export.

## Remaining limitations

The candidate still differs from the approved flattened original in face width, slimmer boot silhouettes and coat details. Hood/coat/cheeks/mouth are baked into body; the shared sprout and reused single boot are not new independent anatomy. The mitten is a rounded overlap, not painted fingers. The hand/umbrella pivot and sampled limited rotation have been demonstrated offline only. There is no native app, Mac/iPhone, walking/jumping/landing, Reduce Motion or performance verification in this folder. No app code/assets, production data, commit, push or deployment changed.

`SELECTED.json` selects this improved candidate for the review package only; it does not approve or install it.
