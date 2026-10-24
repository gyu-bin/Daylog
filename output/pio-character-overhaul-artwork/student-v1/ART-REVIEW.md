# Student Pio layered artwork candidate

Status: **PARTIAL — ready for visual review, not approved or integrated**.

## Genuine sources

Five active new high-resolution sources: clean body, book, left arm, right arm (all1254×1254 RGBA) and `glasses-v2-candidate.png`(1774×887 RGBA). Built-in image_gen reconstructs these components from the individually approved Student PNG; full prompts/provenance are in `source-provenance.json` and `glasses-v2-provenance.json`. Native fur, knit, fabric and paper shading is preserved in style; no low-resolution sheet crops, masks, alpha cleanup, source painting or upscaling occurred.

Original glasses candidate is preserved as superseded: its screen-right temple intruded into the lens hole and covered the pupil after assembly. The targeted v2 removes that intrusive segment while retaining the round front frame. Lens centers are genuinely transparent: measured left90×90patch is100% alpha0; right90×90patch99.9383%alpha0 with only alpha1 remaining. Exact rectangles/statistics: `qa/lens-alpha-probes.json`. Lens highlights remain authored source pixels; the face is not baked into lenses.

Shared genuine Basic eyes, closed lids, feet and the previously generated sprout-v3 source are reused and not counted as new artwork. Twelve transparent1254-square registered layer exports are in `registration/layers/`. All full source canvases are uniformly downscaled/translated into1254-square top-left coordinates, with only rigid local rotation where recorded. Complete source paths, hashes, scales, offsets, pivots and order are in `registration/registration-candidate.json`.

## Actual inspection and evidence

Native dark/light component composites and alpha audit are under `qa/`. Neutral dark, wing+12 light, both64pt3x comparison boards and220pt3x light comparison were actually viewed. Eye/closed-lid changes stay visible through the frame. At64pt the round face, glasses, green book and school sweater remain readable; no broad outside halo or exposed shoulder hole appears in inspected±12° samples.

Book and left hand share pivot(310,875), raised endpoint angle−6° and translation(0,−25); right wing rotates independently around(990,850). Their relationship is fixed by identical rigid transforms, not an independently floating prop. Body/backpack, face, frame and feet stay fixed.

`registration/offline-independent-proof.gif` is a real40-frame440×440 offline proof,80ms/frame, explicitly labeled candidate. It demonstrates authored open/closed eyes through genuine lens alpha, right wing±12° and shared left hand/book raise. Three sample frames were visually inspected in `offline-motion-frames.png`. `offline-motion-proof.json` verifies all source file hashes unchanged. This is not native playback/performance approval.

## Remaining differences / limitations

- Reconstruction changes precise knit/backpack shape, collar/tie size, book proportion, eye spacing/highlights and foot perspective. Sprout is reused and differs slightly from the original. User visual approval is required.
- Arms/sleeves are more substantial than original; shoulders are covered in sampled poses but wider/combined motion needs further review.
- Backpack, straps, collar and tie are baked into body. No independent backpack, cloth or tie motion is demonstrated.
- Only open/closed eye samples are registered here. Continuous blink timing, half-lid transition, walk/jump/landing, Reduce Motion, runtime Mac/iPhone and CPU/memory remain NOT_TESTED.

Generation and offline artwork QA only. No application code/resources, original artwork, production data, purchases, builds/tests, commit, push or deployment changed.
