> Cleanup: At the user’s request, generated QA images, recordings, source candidates and review ZIP were deleted after verification. Historical evidence paths below are no longer available. Final five integrated catalog assets, code, test/build logs, hashes, performance measurements and text records were preserved.

# Pio Stage 4 — final visual review package

Status: ready for the user's final visual approval. **Not committed or pushed.** Base commit:702e611aa1a95323bb1a78e27772d583972c383a.

Stage4(Lv.50+) now uses five dedicated transparent parts on the approved shared rear-shoulder rig. The three rounded orange crest lobes distinguish the final stage; compact layered wings and short four-lobe tails preserve the original round body and face. Candidate A was rejected because its lowest crest lobe disappeared at64pt; candidate B is the integrated artwork.

## Results

| Check | Status | Evidence and scope |
|---|---|---|
| ARTWORK_QUALITY | PASS | Five individually generated components; final1536×1536 RGBA; inspected light/dark and all requested sizes. `ARTWORK.md` documents original1254px sources and downsampling, with no enlargement. |
| MASTER_IDENTITY | PASS | Original face/body/eyes/feet reused. All47 previously approved PNG hashes unchanged. Stage1–3 neutral exports byte-identical to approved renders. |
| STAGE_4_DISTINCTION | PASS | Three orange crest lobes and fuller compact feathers remain distinguishable from Stage3 at64pt; no increase in body size. |
| WING_ATTACHMENT | PASS | Existing rear shoulders(480,995)/(1056,995), scale.72, source pivots, perspective and48°/62° ranges unchanged. Static joints and actual Mac/iOS samples show no gaps or cheek attachments. |
| CREST_JOINT | PASS | Neutral and±12° static checks; actual sway and peak jump retain attachment and full visibility. |
| TAIL_ATTACHMENT | PASS | Both tails stay behindbody, connected during inspected wave/flap/walk/dash/jump/landing samples. |
| ANIMATION | PASS | Actual Mac and iPhone simulator captures cover idle/blink, walk, dash, jump/landing, wave, flap, peek and crest sway. Timings/tracks unchanged. Sampled visual review, not a frame-time or continuous playback certification. |
| REDUCE_MOTION | PASS | iPhone native full-screen RGB pixels identical59.36seconds apart; same PID45683. Motion resumed in same process after restoring OFF. Mac CALayer stop/root behavior covered by focused tests; live macOS system Reduce Motion was not toggled. |
| MAC_BUILD | PASS | Debug, optimized DEBUG verification, and pure Release builds succeeded. |
| IOS_BUILD | PASS | arm64 iOS Simulator Debug build succeeded and ran on verified dedicated iPhone17ProMax/iOS27. |
| TESTS | PASS |37tests in4 focused suites. Initial new CGFloat/Double expectation mismatch was corrected; complete focused rerun passed. |
| PERFORMANCE | PASS | Short optimized Mac samples show no observed Stage4 CPU increase over Stage3; numbers below. No long-duration leak/GPU/physical-device claim. |
| RELEASE_UNCHANGED | PASS | Pio remains DEBUG-only. Pure Release Assets.car contains zero Pio-named assets. Production Saessagi assets, XP, storage, CloudKit, icon and splash source unchanged. |
| READY_FOR_APPROVAL | PASS | Artwork, DEBUG integration, comparison images, native recordings and build/test evidence complete; final subjective approval belongs to the user. |

## Review first

- `final/comparison-64pt-light.png` / `comparison-64pt-dark.png`
- `final/comparison-220pt-light.png` / `comparison-220pt-dark.png`
- `final/comparison-light-1x.png` / `comparison-dark-1x.png`:48/64/76/120/220pt, allfourstages.
- `final/joints/`: crest, shoulders and tails; `final/native/`: complete native poses.
- `runtime/ios-wave-120-light-native.mp4`
- `runtime/ios-jump-220-dark-native.mp4`
- `runtime/ios-flap-220-light-native.mp4`, walk/dash/peek/crest equivalents.
- `runtime/ios-growth-transition-native.mp4`
- `runtime/mac-*.mp4`: actual Mac window sequences at recorded capture cadence.
- `runtime/*review-contact.png`: representative actual recorded poses reviewed for attachment and clipping.

The small fixed-canvas static jump tiles deliberately expose translated-layer overflow and can clip the crest. The expanded native jump and actual220pt iPhone landscape recording show the full crest at peak; this is not a runtime defect. Peek verification uses the moving header character and its intentional hiding behind navigation controls; the enlarged debug preview stays near rest during peek.

## Runtime setup and transitions

Dedicated device identity was checked in Device Hub: **Daylog Store iPhone17ProMax, iOS27.0, CF19DDA2-20F5-440C-9133-7A4594341DAE**. Other projects' simulators were not operated. No physical-device testing was performed.

Separate Mac bundle `com.daylog.verify` and simulator bundle `com.daylog.verify.ios`, local-only `pio-stage3-20261015` store. Generated simulator widget bundle ID was corrected only inside the temporary build output before install; source project settings were not altered. Production Mac app was not replaced.

Mac actual48pt header,76pt growth card,120pt and220pt previews; iPhone portrait header/card and120pt preview, landscape220pt preview. Static rig exports cover every48/64/76/120/220pt size at1× and3×, light/dark. Native iPhone captures are original screen recordings; Mac videos are lower-rate window captures, with cadence in `runtime/frames/*/timing.json`.

Both Mac and iPhone transitioned **Lv.49/90XP → Lv.50/20XP → Lv.49/90XP** by completing and undoing the isolated test routine, without relaunching during the transition. Stage3/4 art switched correctly and kept animating. Test routine was returned to unchecked; original user records were not accessed. Reduce Motion was restored OFF and phone orientation restored portrait.

## Performance

Same optimized DEBUG build, repeated bigHop, header+growthcard+220ptpreview, approximately30seconds after warm-up, no Mac captures while sampling. CPU is percent of one core.

| Stage | CPU | RSS range | Sample |
|---|---:|---:|---:|
|3|0.165%|80.63–138.73MiB|30.31s|
|4|0.165%|80.92–86.19MiB|30.33s|

Raw samples: `runtime/performance-after-stage3.json` and `performance-after-stage4.json`. RSS varied during short samples; these numbers do not establish a statistically significant improvement or prove long-term leak safety. Rendering remains CoreAnimation-based; no per-frame SwiftUI work was introduced.

## Delivered assets and code

Five final assets are in `assets/` and identical catalog imagesets under `Daylog/PioTrial.xcassets/pio_stage4_*.imageset`. Individual source generations remain in `sources/`. `asset-manifest.json` records hashes; `protected-assets-before.json` and `PRESERVATION-CHECKS.txt` record prior-art preservation.

App change: `Daylog/Components/PioTrial.swift` enables fourth-stage selection and selects five dedicated part names. Existing renderer, shared mounts, animation tracks and growth calculation were not changed. Focused assertions in `DaylogTests/SaessagiTests.swift` cover new asset loading, identity, size/scale registration, level boundaries and root invariance. New `Tools/pio-rig/validate-stage4.swift` and `compare-stage4.swift` reproduce static QA.

Build/test logs: `build-logs/`, including `artifact-checks.txt` and successful `mac-debug-tests-rerun.log`.

## Remaining work

User visual approval is pending. Physical-iPhone testing, long-duration memory/leak testing, GPU/frame-time profiling and live macOS Reduce Motion toggling were **NOT_TESTED**. No commit, push, TestFlight upload, release publication or deployment was performed. Unrelated local experiments remain untouched.
