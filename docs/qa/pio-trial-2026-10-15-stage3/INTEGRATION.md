# Pio Stage 3 integration

The three new components are registered to the existing 1536 × 1536 master canvas. The original body, face, eyes, feet and Stage 1/2 assets are unchanged. Stage 3 reuses the previously approved wings byte for byte.

## Files

- `assets/pio_stage3_crest.png`
- `assets/pio_stage3_tail_left.png`
- `assets/pio_stage3_tail_right.png`
- `assets/pio_stage3_wing_left.png` and `pio_stage3_wing_right.png` are unchanged approved dependencies.

All five are RGBA PNGs with transparent backgrounds. Generation produced one component per image. Complete source components were uniformly reduced and positioned on the master canvas; none was upscaled or painted over. Original generated sources remain in `sources/`. Their interior alpha is predominantly 253/255, also seen in the approved wings; that alpha is preserved, with no added translucent root strip. Check native dark-background evidence when reusing them.

## Rig

Stage 3 is selected at Lv.25–49. Lv.50+ continues to display Stage 3 with the existing “artwork in preparation” treatment for Stage 4. The Pio switch remains DEBUG-only (`-DaylogDebugCharacter pio`). Release keeps Saessagi.

Layer order inside the existing torso is crest, left/right tails, original body, Stage 3 wings, original face. Feet remain under the existing breather. The crest keeps its original pivot (approximately 745,588 in 1536 coordinates) and all original motion tracks. Tails inherit torso movement. Old wing/shadow layers are replaced, not overlaid; Stage 3 uses no old contact-shadow asset.

The renderer keeps identical body scale and anchor positions. Stage 3 alone uses padding `max(2, ceil(size × 27 / 1228.5))` points: 2pt at 48/64/76, 5pt at 220. The extra margin prevents approved wing tips being clipped. Do not independently fit each component to its own bounds or reduce the animation angles.

## Reproduce static validation

Run from the repository root:

```sh
swiftc -O -module-cache-path /tmp/daylog-stage3-swift-cache Tools/pio-rig/validate-stage3.swift -o /tmp/pio-validate-stage3
/tmp/pio-validate-stage3 docs/qa/pio-trial-2026-10-15-stage3/assets docs/qa/pio-trial-2026-10-15-stage3/validation-padded . --stage3-padding
```

`validation/` records the original 2pt-crop limitation. `validation-padded/` is the corrected evidence set. Native images and joint close-ups preserve source pixel scale. Size previews use the real app crop, vImage resampling and CALayer transformations at 1×/2× display scale. Jump and landing are static samples of existing motion tracks, not proof of runtime animation.

The broad reconstructed forehead shading belongs to the existing body layer. A small rounded gold rear tuft can emerge at +12° and landing; it remains connected and has no flat cut or background gap. Both were accepted in independent static review without altering the locked body.

## Isolated application verification

Use a separate Debug verification app and `-DaylogStoreName pio-stage3-20261015` to disable CloudKit and isolate test records. Existing `-DaylogDebugGrowthBonus 2400` selects Lv.25 without changing stored XP. `-DaylogDebugPioStage 220` enables the enlarged preview. Existing `-DaylogDebugSaessagiAction` can exercise individual motions.

Device Hub target verified before use: Daylog Store iPhone 17 Pro Max, iOS 27.0, UDID `CF19DDA2-20F5-440C-9133-7A4594341DAE`. The other project's running iPhone 17 (`66B81EA7-8132-4677-A443-2C5F96FB06ED`) must remain untouched.

No commit, push, production app replacement, TestFlight upload or release publication is part of this delivery. See `RESULTS.md` for completed checks and remaining limits.
