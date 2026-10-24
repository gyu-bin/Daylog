# Pio Stage 3 artwork provenance

Built-in `image_gen` produced the crest and each tail in three separate transparent-image calls. No API key, asset board, primitive 3D model, gradient reconstruction or artwork patch was used. The complete generated component was registered with `Tools/pio-rig/register-part.swift` using a uniform reduction and translation only. The alpha threshold of 8 is used only to exclude nearly invisible margin speckles from registration bounds; it does not change interior alpha.

References were the original `Daylog/PioTrial.xcassets/pio_idle.imageset/pio_master.png`, the previously generated promising crest, and approved Stage 3 wings from `~/Downloads/Daylog_Pio_Stage3_Review_Candidate/01_parts/`.

## Final prompt set

**Crest — precise object edit.** Edit the original promising layered crest, preserving its two dominant swept orange feathers, subordinate gold/cream feathers, upper-left studio lighting and premium textured 2.5D material. Reconstruct the incomplete lower-left attachment as a continuous opaque rounded root around the original (745,588) pivot. Keep the complete root beneath the head during ±12° rotation. Output only one isolated crest on transparency, with no body, wings, text, panels, straight cuts, translucent root strips, external cast shadow, capsules or rabbit-ear silhouette. Use the master and approved wing as material references.

**Left tail — stylized concept.** Generate only one compact left tail tuft with three short broad curved overlapping feathers. A complete rounded cream/butter-gold shared root sits at upper right; the lobes sweep outward/downward toward lower left at roughly 9, 8 and 7 o’clock. Warm gold shading approaches orange tips. Match the master and approved left-wing fine texture, softly convex feather surfaces, front camera and upper-left studio light. Render the entire component large with clear transparent margins for later reduction. No cylindrical fingers, outlines, detached pieces, body, wing, central symmetric fan, cast shadow, labels or asset board.

**Right tail — stylized concept.** Produce the counterpart to the new left tail, using it, the master and approved right wing as references. Reverse the form: complete rounded shared root at upper left and three lobes directed toward lower right at 3, 4 and 5 o’clock. Keep the illumination coming from upper left rather than mirroring the lighting. Match the three curved overlapping feathers, cream/gold root, warm orange tips and subtle texture. Output one complete component on transparency with the same exclusions as the left tail.

## Registration

| Component | Source canvas | Visible registration bounds on master |
|---|---|---|
| Crest | 1254 × 1254 | x475, y190, width625, height540.85 |
| Left tail | 1315 × 1196 | x285, y1045, width230, height203.14 |
| Right tail | 1315 × 1197 | x1021, y1045, width230, height202.07 |

Source component bounds were larger than these registered dimensions. The final canvas is 1536 × 1536 for each file, with no component upscaling. Checksums and protected original-asset hashes are recorded in `asset-manifest.json`.
