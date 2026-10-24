# Routimori growth stages — artwork preview

Four individual transparent full-character PNGs, generated from the same sprout-character master. This is an artwork set for review; it is not a rigged animation kit or an app integration.

| Stage | Sprout | Wings |
|---|---|---|
|1|Small two-leaf sprout|Small cream wings|
|2|Growing two-leaf sprout|Developed cream feathers|
|3|Developed two-leaf sprout|Small green wings|
|4|Full two-leaf sprout|Full green wings|

Stage4 is an exact copy of the previously shown master. Stages1–3 are separate built-in image_gen edits of that master. All four originalPNG files are1254×1254RGBA with genuine transparency. They were not enlarged or cut from a concept sheet. `PROMPTS.md` records the generation prompts; the Stage4master prompt remains in the preceding master-preview folder.

## View

- [220pt light](comparisons/comparison-220pt-light-3x.png) / [dark](comparisons/comparison-220pt-dark-3x.png)
- [64pt light](comparisons/comparison-64pt-light-3x.png) / [dark](comparisons/comparison-64pt-dark-3x.png)
- [Stage1PNG](assets/stage1.png), [Stage2PNG](assets/stage2.png), [Stage3PNG](assets/stage3.png), [Stage4PNG](assets/stage4.png)

Comparisons use the same torso width and aligned feet. The scale is measured at the pupil-center row, so the smaller sprouts do not cause younger stages to be enlarged to the same total height. Stage2's generated source body is slightly smaller in pixels; uniform scaling corrects its presentation only. SourcePNGs remain untouched. This is visual identity consistency rather than pixel-identical face/body layers.

`registration.json` records all landmarks and `comparison.swift` reproduces the eight light/dark64/220pt @1x/@3x boards. The requested size is a Stage4reference span; younger stages remain shorter above their equal-sized bodies. Maximum source-derived eye-line spread is approximately0.58pt at64pt and1.99pt at220pt. These slight source variations need attention before future animation-layer registration.

Visual inspection found consistent material, face and rest pose, readable leaf/wing progression, no observed clipping and no obvious colored halos on normal dark previews at the inspected sizes. Full-resolution transparency edge cleanup and production rigging have not been certified. No tests/builds or app modifications were performed for this artwork-only task. Existing Pio assets and all prior uncommitted code changes remain in place.
