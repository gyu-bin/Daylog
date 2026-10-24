# Stage 4 artwork provenance and static gate

Built-in image_gen was used once per component with genuine transparency. Each original is 1254 × 1254 pixels, retained in `sources/`. These are individually generated full-component originals, not pieces cropped from a concept sheet. Each component was uniformly **downsampled**, never upscaled, and placed on the original 1536 × 1536 RGBA character canvas with `Tools/pio-rig/register-part.swift`. Transparent margins were removed; generated interior alpha and colors were preserved. The generated material's modal alpha is 253, as in the approved Stage 3 source art.

## Prompt specification

Shared direction: one isolated component only; original Pio master as identity/material reference, approved Stage 3 counterpart as orientation/style reference; premium softly shaded 2.5D soft clay with subtle fine feather texture, warm upper-left illumination, rounded sculpted overlapping feathers, maximum cuteness. Full hidden rounded attachment root and clear transparent margins. No bird/body/face, text, board, background, checkerboard, ground shadow, black outlines, sharp tips or primitive capsules. New geometry, not recoloring/stretching existing art. Requested square1536 RGBA; generator returned1254 square originals, which are sufficient for the smaller registered components without enlargement.

- Crest: three broad warm-orange lobes, staggered heights and playful rightward sweep, compact golden lower tier. Fuller through overlap rather than a taller mohawk. References: original master + Stage 3 crest.
- Screen-left wing: upper-right cream shoulder root; folded feathers sweep down-left; cream coverts, golden middle, soft orange tips; broad rounded main feathers with richer overlap, compact folded outline. References: original master + Stage 3 left wing.
- Screen-right wing: opposite geometry matching the newly generated left wing; root upper-left, tips down-right; maintain global upper-left illumination rather than mirroring light. References: original master + new left wing.
- Screen-left tail: four short broad softly rounded staggered lobes sharing an upper-right cream-golden root; tips fan down-left with orange ends. References: original master + Stage 3 left tail.
- Screen-right tail: matching four-lobe construction with upper-left root and tips down-right; preserve upper-left illumination. References: original master + new left tail.

## Registration

Coordinates are top-left pixels on the1536 master canvas. Width is uniform scaling; height follows source aspect ratio.

| Component | x | y | width | height |
|---|---:|---:|---:|---:|
| Crest |503|175|570|507.07|
| Left wing |140|837|424|351.34|
| Right wing |972|837|424|342.90|
| Left tail |277|1045|238|208.51|
| Right tail |1021|1045|238|206.38|

Candidate A crest (475,190,width625) hid its third orange lobe too much at64pt and was rejected. Candidate B uses the smaller crest above, exposing its rounded lower lobe while preserving a compact silhouette. Wings and tails were unchanged.

Static inspection passed light/dark48/64/76/120/220pt comparisons, native48° flap/62° wave, crest±12°, landing and expanded-canvas jump. Original body/face/feet are reused. The existing yellow reconstructed cap at the forehead is present in approved Stage 3 and is not modified.

The fixed-size per-pose jump tiles can clip translated artwork by construction; the native jump has headroom. Actual application jumping must be inspected separately before animation approval. Static review is an integration gate, not final runtime or user visual approval.
