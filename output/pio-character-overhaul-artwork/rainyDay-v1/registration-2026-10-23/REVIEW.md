# Rainy Day artwork registration review — 2026-10-23

Status: **UNAPPROVED ARTWORK CANDIDATE — visible assembly improved; strict endpoint alpha preservation needs review.**

This folder contains offline artwork derivatives and review evidence only. The approved original, all native sources, earlier registration snapshots, app code, asset catalogs, and production data were preserved. No new generation was performed in this continuation. No application build, test suite, device rendering, commit, or push was performed.

## Registration and depth

The existing separately generated canopy and shaft-v2 are retained as native whole sources. Every component uses a single uniform downscale plus rotation and translation. No source crop, mask, alpha cleanup, painting, deformation, flat geometry, or upscale was used.

Back-to-front order is canopy → body → shaft/J → right sleeve/hand. The shaft/J is therefore visible over the hood, while the hand overlaps the handle. Canopy, shaft/J, and right hand all rotate around exactly **(745, 875)** in the 1254-square top-left coordinate space. Their neutral component transforms differ because they are separate native artwork sources; their additional grip rotation and world pivot are identical.

Changes from the preceding registration snapshot:

| Component | Whole-source registration |
|---|---|
| Canopy | Unchanged: scale 0.56, offset (662, 221), neutral rotation −16° |
| Shaft-v2 / J | Scale 0.65, offset (647.2, 177.7), neutral rotation −16° |
| Right sleeve/hand | Existing uniform scale 0.25; translated upward 35 px; pivot unchanged |
| Body, eyes, left wing, feet, sprout | Existing registration retained |

The useful umbrella demonstration is neutral to **−5°**. A trial +5° endpoint visibly clipped the canopy at the right edge, so it is excluded from final images and GIF. Left-wing −12° and +12° proofs rotate only the left wing; umbrella and body remain at neutral. The GIF uses left-wing ±12°, umbrella 0…−5°, and an eye blink, while the body transform remains fixed.

## Actual visual review

Viewed native shaft-v2, native canopy, native right hand, native body, approved original, neutral dark at 1254 px, both left-wing endpoints, umbrella −5°, 64 pt light comparison, 220 pt dark comparison, and four decoded frames from the actual GIF. Additional light/dark comparison sheets are included.

The right hand previously hid the J completely. Raising the complete hand/sleeve source and shifting the complete shaft exposes the inner J opening and lower curve. The canopy remains behind the hood; silver shaft and yellow J remain in front of it. The silhouette, glossy yellow rainwear, soft fur, pink cheeks, and sprout remain coherent at the small preview size. The exposed rounded metal attachment cap is still visually apparent under the canopy; this remains a candidate quality detail rather than an asserted perfect match to the original. The candidate boots are slimmer and the face slightly broader than the approved original.

The hand is a rounded stylized overlap, not newly painted fingers wrapped around the J. Hood, coat, blush, and mouth remain baked into the body source. Feet reuse one boot source twice, and sprout is shared from the earlier Cherry source. This is a registration candidate, not newly reconstructed fully independent anatomy.

## Evidence and exact limitation

- 14 actual registered component PNGs are 1254 × 1254 RGBA with transparent background.
- All native source hashes match the preceding snapshot manifests; approved original hash is unchanged.
- Neutral derivatives have zero alpha outside the output canvas.
- Left-wing ±12°, canopy 0/−5°, and right hand 0/−5° have zero alpha outside the canvas.
- Shaft at −5° has **one native stray pixel at world (1338, 577), alpha 1/255**, outside the 1254 canvas. There are **zero outside pixels at alpha ≥16**. No cleanup was performed. Consequently, strict preservation of every nonzero source-alpha pixel at that endpoint is **not passed**. A genuine corrected shaft source or a different composition would be required for that absolute requirement; the report does not conceal the limitation.
- Canopy–shaft alpha overlap is 942 pixels at neutral / 940 pixels at −5°. Hand–shaft overlap is 4,992 / 4,957 pixels. These quantify overlap only; visual quality is judged from the images.
- GIF decodes to 48 frames at 512 × 512; each frame's stored delay is 60 ms (GIF centisecond quantization). This is an offline compositing proof, not evidence of native app behavior.

`registration-and-provenance.json` records source dimensions, source hashes, generation sidecars where present, all per-source transforms, output hashes, original hash, and depth order. `offline-verification.json` records actual dimensions, transparency, unchanged source/original hashes, overlap, and explicit motion bounds.

## Review entry points

- `neutral-dark.png` / `neutral-light.png`: full-size assembled candidate.
- `comparison-64pt-3x-{light,dark}.png` and `comparison-220pt-3x-{light,dark}.png`: approved original versus open/closed/half eyes and motion endpoints.
- `registered-layers/`: actual transparent component derivatives.
- `independent-offline-proof.gif` and `gif-decoded-frames.png`: offline movement proof and actual decoded frame review.
- `register-and-qa.py`: reproducible whole-source registration/export.
- `verify-offline.py`: reproducible artifact/provenance/overlap/bounds audit.

Run the scripts with `/Users/mungyubin/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3`. This folder is not an approved replacement for the current application artwork.
