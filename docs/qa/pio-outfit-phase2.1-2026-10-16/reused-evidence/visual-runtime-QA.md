# Actual native runtime visual QA — 2026-10-16

**PASS for the sampled preview appearance and whole-character motion. Outfit animation remains PARTIAL. No new critical visual blocker found.**

This report reviews actual native iPhone capture frames and actual Mac preview screenshots supplied in this QA directory. The contact sheets only arrange the original capture images, preserving the complete captured frame. No source artwork or application files were changed.

## iPhone motion evidence

Each final `animation-videos/iphone17-<name>.mp4` contributes 24 frames, sampled at 4 fps, covering approximately 0.00–5.75 seconds. All 120 sample frames were reviewed in diagnostic contacts; representative frames were additionally viewed at their 402 × 874 source size. This demonstrates visible position/tilt changes, rather than certifying continuous playback quality or an exact frame rate.

| Clip | Samples | Sampled visual result | Observation |
| --- | ---: | --- | --- |
| basic-wave | 24 | PASS | Subtle character tilt/shift between frames 01 and 06. Code reuses the approved RoutimoriSplashRig exposed-wing mask; differential wing movement is not fully certified by these small samples. |
| halloween-jump | 24 | PASS | Clear vertical jump between frames 02 and 03; pumpkin bag stays attached and all candy remains visible. |
| christmas-celebration | 24 | PASS | Whole-character lift/tilt between frames 11 and 12; gift, both hands, scarf and pompom remain intact. |
| hanbok-bounce | 24 | PASS | Small vertical body bounce; skirt, ribbon, sleeves, hair ornament and feet remain joined and visible. |
| astronaut-jump | 24 | PASS | Vertical lift between frames 19 and 20; helmet, sprout, gloves and feet stay intact. |

Across these samples, the full character remains inside the colored preview panel: no cut sprout, missing feet, detached props, root gaps, or changed facial identity were observed. Halloween jump has clear lift/landing separation. Christmas gift and Hanbok ornaments stay fixed to the approved flattened artwork. Astronaut helmet and sprout stay fully visible. Basic-wave reuses the approved RoutimoriSplashRig with a separately transformed exposed-wing mask (±10°) and body tilt. The small sampled captures do not fully certify differential wing movement or a complete hidden-root rig. All 13 costumes remain whole-character motion only.

The screen itself correctly says “몸 전체 움직임 미리보기 · 부위 동작 준비 중.” The growth selector notice explicitly states that stage-specific part artwork is being prepared and the same costume artwork is shown for all stages. These captures do **not** constitute four-stage rig compatibility approval.

## Mac appearance evidence

All 13 actual captures show the intended themed costume, recognizable cream bird identity, complete sprout/feet/props, correctly composited transparency, and legible preparation/status labels. The prominent Rainy Day umbrella is entirely inside the live preview panel, with clear space to the panel edge. Existing window scroll bars and lower controls outside the captured viewport are normal scrolling layout, not character clipping.

| Outfit | Visible preview | Actual screenshot |
| --- | --- | --- |
| cherryBlossom | PASS | `live-app/mac-preview-cherryBlossom.jpg` |
| summerVacation | PASS | `live-app/mac-preview-summerVacation.jpg` |
| autumn | PASS | `live-app/mac-preview-autumn.jpg` |
| winter | PASS | `live-app/mac-preview-winter.jpg` |
| halloween | PASS | `live-app/mac-preview-halloween.jpg` |
| christmas | PASS | `live-app/mac-preview-christmas.jpg` |
| hanbok | PASS | `live-app/mac-preview-hanbok.jpg` |
| cafe | PASS | `live-app/mac-preview-cafe.jpg` |
| student | PASS | `live-app/mac-preview-student.jpg` |
| fitness | PASS | `live-app/mac-preview-fitness.jpg` |
| rainyDay | PASS | `live-app/mac-preview-rainyDay.jpg` |
| pajamas | PASS | `live-app/mac-preview-pajamas.jpg` |
| astronaut | PASS | `live-app/mac-preview-astronaut.jpg` |

## Evidence files and limits

- `runtime-contact-{basic-wave,halloween-jump,christmas-celebration,hanbok-bounce,astronaut-jump}.png`: full-screen native sample contact sheets, 4 columns × 6 rows.
- `runtime-contact-mac-1.png`, `runtime-contact-mac-2.png`: all 13 actual Mac captures.
- `runtime-contact-review.swift`: reproducible read-only capture compositor.
- `visual-runtime-QA.json`: per-video metadata and per-outfit findings.
- `live-app/iphone17-halloween-jump-cropped-attempt.mp4` is explicitly excluded from this review and final video evidence.

All captures reviewed here are light appearance. Dark-mode **source-art compositing** was previously reviewed in `artwork-size-QA.md`; this is separate from actual dark-mode runtime validation. No continuous FPS, GPU/battery/thermal result, independently articulated eyes/wings/feet/props, unsampled instant, all-motion/all-outfit combination, or all-four-stage compatibility is certified here. The original hidden layers needed for those features remain unavailable. The approval is limited to the recorded whole-character previews and visible Mac appearance.

Parent-supplied performance evidence: DEBUG Mac jump steady sample mean CPU 16.08%, maximum 21.7%, RSS 133 MiB; offscreen sample CPU 0%, RSS 132 MiB. This subagent did not independently profile these values. Performance status remains PARTIAL: Release builds, other hardware and iOS were not profiled.
