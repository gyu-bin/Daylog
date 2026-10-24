# Cafe Pio layered artwork candidate

Status: **PARTIAL — ready for visual review, not approved or integrated**.

## Genuine sources

Five active high-resolution source roles: `body-v2-candidate.png`, `hat-candidate.png`, `left-candidate.png`, `right-v2-candidate.png`, `cup-candidate.png`. All are1254×1254 RGBA generated with built-in image_gen from the individually approved Cafe PNG, with actual native fur, felt, paper and woven fabric texture. Full prompts and generated source paths are saved in `source-provenance.json` and `body-v2-provenance.json` / `right-v2-provenance.json`. No sheet crops, alpha cleanup, painting, masks or upscaling were used. Original app artwork remains untouched.

The first body source remains preserved as a superseded iteration: its static dangling shoulder/arm shapes made clean independent movement ambiguous. The targeted v2 reconstructs torso sides under the apron straps. Body v2 stays eye-free, foot-free and hat-free; facial cheeks, beak, costume identity and brass/green details remain coherent, but reconstruction is not pixel-identical to original. Hat and sprout form one genuine component, so independent sprout sway is not claimed.

Existing genuine Basic eyes, closed lids and feet are reused, not counted as new artwork. Registration uses the full source canvases, downscaled uniformly into one1254-square top-left coordinate system; transforms, pivots, z-order and source SHA256 are recorded in `registration/registration-candidate.json`. Eleven transparent1254-square registered exports are under `registration/layers/`. Their source footprints are never cropped or alpha-masked.

## Actual inspection and evidence

Native alpha/light/dark source composites and alpha statistics are under `qa/`. The corrected hat has a genuine transparent underside arch, so the face stays visible. Full neutral dark and raised-cup light assemblies were inspected; both64pt3x comparison boards,220pt3x dark board and ±12° endpoint samples were inspected. The round face, eye readability and costume remain recognizable at64pt. No broad halo or obvious exposed shoulder slice appears in the inspected poses.

The coffee cup and left hand share exactly pivot(400,880), angle−6° and translation(0,−25) at the raised endpoint. The right wing has its own pivot(1000,860), tested at±12°. Body and costume remain fixed. The source sleeve roots extend beneath torso overlap; they are not flat replacement shapes.

`registration/offline-independent-proof.gif`:40frames,440×440,80ms/frame, explicitly labeled offline artwork candidate. It switches genuine open/closed eye artwork, rotates right wing independently and raises left hand/cup as a group while body/hat/feet remain fixed. Three sampled frames were visually inspected in `offline-motion-frames.png`. `offline-motion-proof.json` verifies all source hashes remain unchanged; this is not native app video, timing or performance QA.

## Remaining differences / limitations

- Reconstructed body is rounder/taller, hat rim is more curled at screen-right, and facial/eye/foot perspective differs slightly from the original. User approval is required.
- The initial right sleeve duplicated the body apron strap/button. A targeted genuinely generated right-v2 removes that duplicate and reconstructs continuous white woven sleeve, with full root and original fluffy mitten. The final neutral dark and source dark composites were inspected; the duplicate is gone. The sleeve remains broader than the approved original and needs final visual approval. The superseded right-v1 is preserved.
- Cup contact is a side/back hold rather than the original foreground palm. It stays rigidly attached at the sampled poses, but exact grip restoration is incomplete.
- Apron, collar, side tie and torso detail are baked into body; no independent fabric/tie animation is demonstrated. Hat and sprout are combined.
- Static samples and offline GIF do not certify runtime interpolation, every joint combination, walk/jump/landing, Reduce Motion, native Mac/iPhone or CPU/memory. No app builds/tests were run.

Generation and QA only; no app code/resources/data/purchases, commit, push or deployment.
