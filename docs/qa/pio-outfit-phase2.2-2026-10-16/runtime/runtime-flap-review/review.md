# Christmas native flap — sampled visual art review

2026-10-16. **ACCEPT for the inspected iPhone220pt light-background pilot flap samples.** No new visual blocker was found. This acceptance covers eight time-sampled native frames from the first3.2seconds, not every frame or the full recording.

## Actual evidence

- Source: `../ios-christmas-flap-220-light.mp4`, a DeviceHub native app recording supplied by the parent. ffprobe reports1206×2622pixels and duration47.471667seconds. Encoding frame-rate metadata is not an app performance measurement and no FPS claim is made.
- Extracted unchanged full screenshots: `frame-01.png` through `frame-08.png` using `ffmpeg -i <source> -t 3.2 -vf 'fps=5/2:start_time=0' -frames:v 8 frame-%02d.png`. Eight output sampling slots are0.4seconds apart; ffmpeg selects source frames for those slots. No claim of frame-exact source timestamp annotation is made.
- `contact.png` shows those eight frames in row-major order. It is a diagnostic crop of each actual screenshot at source rectangle x250,y1230,width700,height760, reduced to490×532 for the contact sheet. All full original screenshots remain beside it. No character asset was edited.
- Viewed the full native screen and all eight character samples. The screen itself identifies Christmas, flap,220pt and independent-parts mode, and visibly states that only Basic/Christmas in one body form are trial-supported; growth stages1–4 and other outfits are not yet supported.

## Observations

The gift and left hand visibly change angle/position together across the samples, while the right hand changes pose relative to the gift. The face, hat/sprout, coat and feet remain visually fixed. This is actual differential part motion evidence, not merely rotation of a single full-character PNG.

Across all eight samples, the left sleeve stays covered at its coat attachment, the right cuff remains plausibly attached near the shoulder, and no exposed background hole or severed root is visible. The left hand maintains gift contact; the right palm retains visible contact/overlap as the gift changes angle. Intermediate samples agree with the accepted offline Christmas-g endpoint geometry. No duplicate hand imprint appears on the uncovered coat.

At the raised gift positions, the bow comes closer to the lower right cheek/scarf region but neither eye nor the beak is obstructed. Face expression remains readable. Sprout, pompom, sleeve tips, gift and both feet remain completely inside the visible character panel in the inspected samples. Plush material and color remain coherent with the accepted reconstruction.

## Exact limits

Sparse sampling cannot rule out a one-frame root flash, every possible transient, dropped frames or a problem later in the remaining44seconds. This review did not watch all47.47seconds, measure continuous FPS, or certify other screen sizes, dark mode, Reduce Motion, other motion modes, growth-stage compatibility or additional outfits. Those retain their own evidence requirements.

The Christmas hat/sprout/pompom is one combined part; scarf is part of the coat; bow/ribbon is part of the gift. The accepted behavior is the scoped left-hand/gift coupled flap and right-hand movement. It is not independent animation of those baked decorative elements.

This task created only extraction/contact/report files inside this new review directory. No application source, artwork or test was changed or run.
