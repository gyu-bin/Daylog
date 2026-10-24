# Pio Stage 4 — restored review package

The five final1536×1536 RGBA PNGs and Stage4DEBUGintegration remain intact. All five PNG hashes match the previous final manifest. The original generated-source copies, review images, runtime recordings and ZIP were removed during the earlier requested cleanup; no verified final Stage4 media copy was found elsewhere in the project. Older Stage4 prototype artwork is different and was not reused.

This package restores visual previews from the existing final catalog artwork. It does not regenerate character artwork, change application code, or rerun builds/tests. Existing uncommitted changes remain in place. BaseHEAD remains702e611aa1a95323bb1a78e27772d583972c383a.

## Start here

- [Stage1–4 at64pt, light](static/final/comparison-64pt-light.png) and [dark](static/final/comparison-64pt-dark.png)
- [Stage1–4 at220pt, light](static/final/comparison-220pt-light.png) and [dark](static/final/comparison-220pt-dark.png)
- [Stage4 full1536px preview, light](static/final/native/light-stage4-neutral.png) and [dark](static/final/native/dark-stage4-neutral.png)
- [48° left wing attachment](static/final/joints/light-stage4-wings-48-shoulder-left.png)
- [62° right wing attachment](static/final/joints/dark-stage4-wave-62-shoulder-right.png)
- [Actual Mac wave preview](animation/wave-light.mp4)
- [Actual Mac flap preview](animation/flap-dark.mp4)
- [Actual Mac jump/landing preview](animation/jump-light.mp4)
- [Historical QA results](existing-qa/RESULTS.md)
- [Historical build/test summary](existing-qa/build-logs/artifact-checks.txt)

`assets/` contains exact copies of all five final catalog PNGs. `static/final/` contains restored48/64/76/120/220pt comparisons at1×/3×, full-size poses and attachment close-ups. `tools/` preserves the standalone validator and a package-local comparison script. These tools do not change app code or asset catalogs.

## What was reused and what was restored

| Item | Recovery result |
|---|---|
| Five final PNGs | Recovered unchanged from PioTrial.xcassets; exact prior hashes |
| Stage4DEBUGintegration | Inspected intact: Lv50+, dedicated five-part selection, shared rear shoulders and.72scale |
| Stage1–3 artwork | All47 previously protected hashes still match |
| Static review images | Newly rendered from existing final artwork with existing validator |
| Animation previews | Newly captured from the existing optimizedDEBUGMac verification app; no rebuild |
|37tests/four suites | Prior successful rerun log reused; not rerun |
| MacDEBUG/optimizedDEBUG/Release and iOSSimulator builds | Prior successful logs reused; not rebuilt |
| Performance | Prior JSON measurements reused; not remeasured |
| Reduce Motion/level transitions | Prior text/JSON results retained; old screenshots/videos are unavailable |

New videos are actual Mac window screenshot sequences at their recorded capture cadence, approximately4.8–6.8fps. They are review previews, not60fps screen recordings or performance measurements. Exact timings are in `animation/capture-manifest.json`. No new iPhone recording was made. The existing temporary Mac verification app used the separate local test store; production app and user records were not modified.

The historical documents under `existing-qa/` are copied as records. Their old media/source links describe the original verification run and may be unavailable; they are not the current package inventory. Current deliverables are linked above. Historical reported results include37/37tests, four successful build configurations, zero Pio assets in pureRelease, same-process ReduceMotion stop/resume, and49→50→49transitions on Mac and iPhone. Their surviving logs/JSON/text records are included.

Original limitations still apply: no physical-iPhone testing, long-duration leak testing, GPU/frame-time profiling or live macOS system ReduceMotion toggle was established. Static small jump tiles may clip translated artwork; expanded native jump previews have headroom, and the original QA report records that actual runtime peak-jump clearance passed.

## Verification and preservation

`inspection.json` records original catalog hashes, current app-source checks, prior47protected-asset preservation and unchanged pre-existing source/tool/catalog hashes. `package-manifest.json` records the restored package file hashes. Unrelated experiments were preserved. No commit, push, deployment, TestFlight upload or production-app replacement was performed.

The ZIP contains static images, five final PNGs, animation MP4s and timing manifests, surviving QA reports/logs/measurements, restoration tools and this guide. Raw recapture JPEG frames remain locally under `animation/frames/`; the ZIP omits them to keep the delivery compact.
