# Sprout candidate alpha / visual QA

Status: **USABLE CANDIDATE** for further assembly QA. This is not rig approval or app integration approval.

Source: `/Users/mungyubin/.codex/generated_images/01a13e4c-eb2f-7c33-a58c-004a195b88c3/exec-ff2d09af-23fe-4753-a435-280c93c7b475.png`

- Dimensions: 1536 × 1024. Genuine RGBA transparency, alpha range 0–254.
- 1,060,151 pixels are fully transparent. There are no alpha255 pixels; almost opaque painted regions are alpha240–254. This does not imply a baked background.
- Alpha≥2 bounds: (96,128)–(1480,912). Very faint alpha1 stray pixels extend beyond the painted silhouette; no cleanup was performed.
- Native alpha compositing on warm light and charcoal backgrounds was rendered and visually inspected. No broad white or gray halo is visible. A thin pale edge follows the lit leaf rim and reads as the existing soft material, rather than a rectangular or detached glow.
- Leaf veins, soft texture and shaded stem remain legible. Stem has a complete rounded hidden root suitable for subsequent head overlap testing.
- Source has not been changed. QA outputs are composites only.

Evidence: `sprout-light-native.png`, `sprout-dark-native.png`, `sprout-alpha.json`. Reproducible audit: `audit_sprout.py` (Pillow).

Remaining: assemble into shared character coordinates, validate scale/direction against approved Pio, test root overlap under rotation, then inspect actual 64pt and220pt composites. No animation or cross-stage compatibility has been verified by this audit.
