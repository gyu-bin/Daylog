# Christmas candidate source review

2026-10-16. **Historical source-only review: the five v1 files were accepted for an assembly experiment, not for integration. Later assembly exposed problems and superseded the v1 hands/headwear. See the current status below and `christmas-assembly-review.md`.** No targeted source regeneration is justified by the currently inspected alpha/material evidence. In particular, the apparently tight white hat edges are not significantly clipped.

## Sources and inspection

Each file below is a genuine standalone 1254 × 1254 PNG under `candidates/christmas/`. All five were individually viewed at native resolution and correctly composited with CoreGraphics over ivory and forest. Only temporary diagnostic composites were made; source images were not changed, cleaned, trimmed, repaired or recolored.

| Source | Source-candidate decision | Findings and limits |
| --- | --- | --- |
| `body-clean-v1.png` | ACCEPT | Complete eye-clean cream head and red clothed torso. The beak, pink cheeks, scarf/tail, belt/buckle and white coat trim preserve the approved Christmas motifs and plush material. The former gift/hand area is now a genuine completed coat surface, enabling later independent assembly. Scarf and tail remain baked into this body plate; do not claim separate scarf motion. Neutral proportions and visible face alignment still require comparison after registration. |
| `hat-v1.png` | ACCEPT | Full red drooping cap, white fur brim and round pompom. Correct composites show no hard cut across the pompom or right brim. Alpha evidence below rejects the suspected significant edge clipping. Hat and pompom are one supplied part: independent hat-to-head motion may be tested, but a separately moving pompom is not yet a separate authored component. |
| `gift-v1.png` | ACCEPT | Complete green box with red bow/ribbon, recognizable approved palette and soft fabric surface. No hand imprint, missing side, label or watermark. Gift bow is baked into the box component. Final scale, perspective, two-hand contact and occlusion must be checked in assembly; an attractive isolated box does not prove correct grip. |
| `hand-left-v1.png` | ACCEPT | Continuous red sleeve, white plush cuff and cream palm with substantial upper sleeve/root material. No visible clipping. One sleeve/cuff/hand assembly, not independent wrist/fingers. Final shoulder coverage and gift contact remain pending. |
| `hand-right-v1.png` | ACCEPT | Opposite sleeve/hand candidate has matching materials and complete upper root. No significant edge clipping despite the relatively close right margin. Final mirrored-light consistency, shoulder coverage and gift contact remain pending. |

## Exact edge-alpha evidence

Decoded native pixels into a premultiplied-last RGBA CGContext, then counted each source's outside canvas edges. Bounds below are inclusive `minX,minY,maxX,maxY` of alpha≥16/255. Left/right are image columns; top/bottom are image rows. Low-alpha RGB viewer artifacts are not silently removed.

| Source | Significant bounds | Clear margins L/R/T/B (px) | Edge maxima L/R/T/B (0–255) | Edge pixels alpha≥16 |
| --- | --- | --- | --- | --- |
| Body | `68,171,1193,1186` | `68 / 60 / 171 / 67` | `1 / 0 / 0 / 1` | 0 on every edge |
| Gift | `196,192,1075,1140` | `196 / 178 / 192 / 113` | `1 / 0 / 0 / 1` | 0 on every edge |
| Hat | `16,251,1242,1027` | `16 / 11 / 251 / 226` | `1 / 3 / 0 / 1` | 0 on every edge |
| Left sleeve/hand | `100,208,1174,1070` | `100 / 79 / 208 / 183` | `1 / 0 / 1 / 1` | 0 on every edge |
| Right sleeve/hand | `154,101,1230,1100` | `154 / 23 / 101 / 153` | `1 / 0 / 0 / 0` | 0 on every edge |

The hat's rightmost canvas alpha maximum is 3/255, not an opaque slice of cut fur. The meaningful brim stops 11 pixels before that edge; the pompom stops 16 pixels inside the left edge. Normal ivory/forest compositing preserves their curved outlines. The native canvas should remain unchanged. When registering and rotating the complete part, ensure external host padding; source padding is not a guarantee of motion clearance.

## Design preservation and final gate

These sources maintain the approved costume's red coat/scarf, white trim, brown/gold belt, cream hands, green/red gift and drooping red hat. They are reconstruction candidates rather than pixel-identical cutouts; assembled neutrality must still be compared with `Daylog/PioWardrobe.xcassets/pio_outfit_christmas.imageset/pio_outfit_christmas.png`. The original approved design remains untouched.

Before integration approval, inspect the registered neutral/closed-eye assembly at64/220pt light/dark and native face/root crops; then check both extrema and intermediate samples for the intended hat, gift and sleeve tracks. Required observations: hat cannot cover/drift the eyes; sprout must emerge naturally with a covered root; both palms must retain physical gift contact; gift movement must uncover genuine clean coat rather than an imprint; shoulders must remain covered without detached cuffs or duplicated red edges. Shared Basic eyes/lids/feet/sprout require Christmas-specific registration and cannot inherit a Basic approval automatically.

This source review does **not** approve independent animation from static part images, native runtime playback, continuous FPS, full flap/walk, or stage1–4 costume compatibility. The current five-part set also does not contain an independent scarf tail, independent pompom or independent bow. Those remain honest scope limits unless further genuine parts are supplied and tested.

Only this review Markdown was added to the project by this review task. No source artwork, registered asset, application file or other worker's report was modified.

## Update after genuine v2 reconstruction and Christmas-e assembly

The isolated-source decision above did not approve neutral anatomy. Registered v1 long sleeve roots protruded above the intended arm position; those v1 hand assemblies are rejected for this pilot and superseded by `hand-left-v2.png` / `hand-right-v2.png`. The separate hat/sprout assembly also failed depth/embedding; current `headwear-v2.png` is a genuinely authored combined Santa hat + pompom + embedded sprout. Do not claim independent sprout or pompom animation for this combined texture.

V2 source shapes and materials are suitable for registration tests. Christmas-e was BLOCKED because its right hand/cuff was undersized and its red root extended horizontally beyond the coat, reading as a small detached-looking end cap. Alpha overlap with the gift confirmed geometric coverage but did not resolve the anatomical presentation.

**Christmas-f update:** whole-part uniform scale0.26, neutral rotation−60° and true root placement at(1050,790) resolve the right-hand presentation issue without changing source pixels. Independent review of the neutral comparison, right±12 and grip-shift closeups, and all ten poses at64/220pt light/dark accepts f for the **limited static pilot art gate**. No new generation or source painting is required on current evidence. This does not approve continuous/native animation, intermediate or combined extremes, all growth stages or independent sprout/pompom motion. See `christmas-assembly-review.md` for exact evidence and limits.
