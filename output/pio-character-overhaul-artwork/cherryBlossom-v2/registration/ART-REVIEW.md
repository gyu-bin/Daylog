# Cherry Blossom revised registration — candidate only

Status: PARTIAL. Static artwork review, not final approval or app integration.

The QA compositor uses unchanged Cherry v1 clean body v3, two wings and head flower, genuine existing Basic eye/lid/foot sources, and the new sprout-v3-review source. No source image is repainted, cropped, masked, warped, upscaled or alpha-cleaned. All full source canvases remain intact; registration uses uniform downscale/translation and existing rigid foot/wing rotations. Shared output coordinate system is1254×1254, top-left origin. The new1536×1024 sprout uses uniform scale0.45, source root(795,900), target root(620,400), hence offset(262.25,-5). Roots are covered by the body; the full source remains included.

## Real outputs and inspection

- Four comparison boards: original / prior candidate / revised candidate at64pt and220pt, each at3x, light/dark.
- Four pose boards at64pt and220pt3x light/dark: neutral, half-eye, closed-eye, wings−12°, wings+12°.
- Fifteen full1254-square static pose PNGs: each of the five poses as transparent alpha and on light/dark.
- Three optional signature-static PNGs: same genuine petal source instanced three times around neutral Pio. These are static composition proposals, not a completed special animation and not three new source assets.
- png-verification.json verifies26 actual PNG files, dimensions, bytes and SHA256. registration-candidate.json records all source hashes and transforms. signature-static.json records one unique petal source/hash and its three instance transforms.

Actually viewed: full neutral dark, signature still dark,64pt original/prior/revised dark,64pt pose light,220pt pose dark, and220pt original/prior/revised light. On inspected composites the new sprout has no visible exterior green haze; its leaf direction is closer to the approved reference than the provisional shared sprout. Body/eyes/costume remain unchanged from prior candidate. No exposed shoulder gap or root slice is apparent at the inspected ±12° endpoint boards. The left wing remains partly occluded by the cape. These observations cover static samples only.

## Remaining limits

This is a reconstruction, not pixel-identical restoration: the revised body's floral cape details, flower petal shape, eye spacing/highlights, wing silhouette and raised-foot perspective differ from approved original. Sprout texture and left-leaf proportions still differ somewhat; its broad material and direction are now coherent but need user visual approval. Head flower and cape bow are separate/baked respectively, so no independent bow/fabric motion is demonstrated. Half-eye is a brief transition or sleepy expression, not default pose. Continuous blink/flap, combined joint sweeps, walk/jump/landing, native Mac/iPhone playback and performance remain NOT_TESTED. No growth variants were authored because the latest brief requests one visual Pio. No app source, asset catalog, original artwork or purchase/data configuration changed; no app build/tests rerun, commit or push.
