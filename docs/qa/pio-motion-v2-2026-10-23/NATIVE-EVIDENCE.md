# Native motion evidence — 2026-10-23

Status: native Mac captures and focused checks PASS; final character/scene approval and performance certification remain PARTIAL.

The final runtime uses .78 canvas scale and a downward .09 × minimum view dimension center offset. The previous centered native jump clipped the sprout; an intermediate .06 offset left Winter 64pt alpha 1–2 pixels at the top border. Those versions were rejected. Sources were not alpha-cleaned or edited.

## Accepted evidence

- `native-final/`: actual Core Animation **presentation-layer** PNGs; no manual trajectory interpolation.
- All 14 outfits × 64/220pt jump peaks (28 images): every outer-border alpha is exactly zero, verified by `native-jump-peak-border-verification.json`.
- All 14 outfits × 64/220pt × neutral/landing (56 images): every outer-border alpha is exactly zero, verified by `native-neutral-landing-border-verification.json`.
- `native-sequence-hanbok-jump-000.png` through `059`: actual wall-time presentation capture, 20fps target.
- `native-sequence-christmas-greet-000.png` through `059`: same capture method. Actual timestamps in `native-motion-sequence-timing.json`.
- Seven focused rig tests PASS: 14 manifests, grip constraints, eye exclusivity/z-order, layer reuse/stopping, distinct jump/bounce/greet, dedicated landing without airlift, Christmas/Pajamas ±2° limits.
- Mac test results `/tmp/PioNativeMotionPeak-v2.xcresult` and `/tmp/PioNativeMotionGround-v1.xcresult`; exported attachments are retained here.
- iOS simulator build PASS in `ios-build.log`; that build alone is not iPhone runtime/UI evidence.

The earlier `native-readable/` v3 captures are retained as historical evidence and include the rejected centered jump. Its SwiftUI gallery cached-display PNG omitted some native buttons, so it is **not** a faithful application screenshot or UI PASS. Do not promote that image as final UI evidence.

## Controlled short observations

`native-performance-observations.json` uses one process, same 350pt native window, two trials per scenario, .7s warmup then 2s wall-time observation. No concurrent build ran during this final performance pass. Its renderer predates only the final canvas-center offset; same textures, animation tracks and algorithm were used. The earlier v3 observations overlapped a build and are not used for comparisons.

| Scenario | Mean process CPU (2 trials) |
|---|---:|
| Original pilot base jump | 1.90% |
| New base static | 0.38% |
| New base jump | 0.69% |
| New Christmas static | 0.24% |
| New Christmas jump | 0.20% |

Comparative RSS snapshots were approximately 121–159 MiB. Three batches of 42 switches settled at approximately 216, 126, 126 MiB; cache eviction and process-wide host activity affect these readings. Stopping removed all 16 active tracks, with approximately .29% process CPU over the next 2s. These are short DEBUG observations, **not** a leak PASS or stable performance budget. CPU excludes WindowServer/GPU and cannot be compared directly to the historical 16.08% measurement from different conditions. Native scrolling/Reduce Motion end-to-end checks require their own UI evidence.

No production app was replaced or installed. XCTest uses the existing in-memory test-store path and a command-line verification bundle ID, without changing project bundle identifier settings, purchasing, equipping, SwiftData schemas or CloudKit configuration. The additive review scheme has no Run action.
