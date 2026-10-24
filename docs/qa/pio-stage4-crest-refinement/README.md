# Stage 4 crest refinement — awaiting visual approval

**User visual approval remains ON HOLD.** Only the existing Stage4crestPNG was replaced. This is a refined candidate for review, not a claim of final acceptance.

The crest now has three unequal orange feather forms, softer tapering bases, shallow lengthwise surface flow and interleaved golden secondary feathers. Its rightward sweep and compact silhouette are retained. The64pt distinction from Stage3 is subtle; the layered construction is more evident at220pt. The face/body, Stage1–3, Stage4wings/tails, rear shoulders, growth logic and animations are unchanged.

## Before / after

Each comparison has three columns: **Stage3 / Stage4before / Stage4after**. Body scale and rendering geometry are held constant.

- [64pt light, @3x](comparisons/candidate-a/64pt-3x-light-neutral.png) · [dark](comparisons/candidate-a/64pt-3x-dark-neutral.png)
- [64pt light, native @1x](comparisons/candidate-a/64pt-1x-light-neutral.png) · [dark](comparisons/candidate-a/64pt-1x-dark-neutral.png)
- [220pt light, @3x](comparisons/candidate-a/220pt-3x-light-neutral.png) · [dark](comparisons/candidate-a/220pt-3x-dark-neutral.png)
- [−12° crest,220pt dark](comparisons/candidate-a/220pt-3x-dark-crest-minus12.png) · [+12°](comparisons/candidate-a/220pt-3x-dark-crest-plus12.png)
- [Jump,220pt dark](comparisons/candidate-a/220pt-3x-dark-jump.png) · [landing](comparisons/candidate-a/220pt-3x-dark-landing.png)
- [New full-size composite](candidate/rendered/native/light-stage4-neutral.png)
- [New standalone1536RGBAcrestPNG](candidate/assets/pio_stage4_crest.png)
- [Original crest backup](before/assets/pio_stage4_crest.png)
- [Actual Mac crest sway preview](runtime/crest-sway-light.mp4) · [jump and landing](runtime/jump-landing-dark.mp4)

`comparisons/candidate-a/` includes50boards across both sizes, both appearances,1×/3×, neutral,±12°, jump and landing, plus full-resolution poses. Expanded focused jump renders preserve headroom; the older fixed-tile pose exports under the general validator can clip translated artwork by construction. Use the complete comparison boards for jump review.

## Verification

| Check | Result |
|---|---|
| Standalone1536×1536transparent crest | PASS; genuine individually generated source, downsampled without enlargement |
|64/220pt, light/dark, neutral | PASS for presenting the candidate; final aesthetic approval pending |
| Crest±12°, jump, landing | PASS in focused CALayer renders; roots overlap behind the head, no observed face obstruction |
| Stage3 vsbefore/after | PASS; richer orange/gold layering, modest distinction at64pt |
| Existing crest pivot | Unchanged at(745.05,588) on1536canvas = (496.7,392) in app coordinates |
| Stage1–3 | Unchanged assets;60display-size exports byte-identical |
| Stage4wings/tails | All four catalog hashes unchanged |
| App/test source and shared rig | Unchanged from pre-task snapshot |
| DEBUG-only | Existing guards and Release exclusion unchanged |
| Focused asset test |1test in1suite passed,0.376s; Mac catalog rebuilt with newPNG |
| Actual Mac preview | Fresh DEBUG app shows new crest; light crest sway and dark jump/landing captured |
| Final user approval | ON HOLD |

477pre-existing project-file hashes were recorded before work. Exactly one differs after refinement: `Daylog/PioTrial.xcassets/pio_stage4_crest.imageset/pio_stage4_crest.png`. Existing uncommitted source/test changes and unrelated experiments are preserved. `VERIFICATION.json` contains the old/new crest hashes and scope checks.

The initial test selection omitted the SwiftTestingidentifier's parentheses and selected zero tests; it is not counted as verification. The corrected selector ran exactly one existing asset/registration test successfully. Logs: `build-logs/crest-focused-test-selected.log`. No full suite, new iOSbuild, performance benchmark, or physical-device test was run for this asset-only change. Prior Stage4logic/build evidence remains historical; fresh evidence here is limited to the checks above.

Runtime videos are actual Mac window screenshot sequences at their measured capture cadence, not a60fps recording or frame-time benchmark. Capture details are in `runtime/capture-manifest.json`.

## Artwork provenance

Built-in `image_gen` produced a genuine isolated transparent crest; the first candidate was rejected because it read as two orange primaries. A targeted second edit exposed the shorter third orange feather and retained the gold tier. The final original is `sources/crest-v2.png` (1254×1254). Complete-component transparent-margin removal, uniform downsampling and translation placed it on the1536canvas at x485,y170,width600,height570.391. No interior repaint, recoloring/stretching of Stage3, primitive drawing or upscaling was used. Generated alpha was preserved.

`PROMPTS.md` records the exact prompts. The same existing renderer and pivot are used; no code/animation adjustment compensates for the artwork. The source/root extends behind the body through the checked rotations.

No commit, push, deployment, production-app replacement, TestFlight upload or release publication was performed.
