# Native cloud artwork/rig verification — 2026-10-24

Overall **PARTIAL**. Basic receiving/failure scenes now use genuine independently blinked eyes/lids through a small production resource pack. All 14 outfits now have genuine separated seated-cloud hands/tablet candidates, tested on Mac+iOS behind DEBUG flags; costume-specific sampling and visual gates remain scoped to the tested 64/220pt frames and ±1.5° occupied-hand joint. Vacation clean-face reconstruction failed its artwork gate; no new vacation blink was enabled. No new home animation, independent headwear/free-hand wave or Stage 1–4 outfit compatibility is claimed by this work. Final passing XCTest executions: **44**; the final 10-outfit batch accounts for 4 of those methods and separately proves 40 explicit outfit-method checks. A prior lifecycle-fixture failure is preserved, not omitted.

## Implemented scope

- `PioCloudCharacterRig` accepts authored canonical registrations, genuine texture subrects, explicit pivots/z order and an optional shared held-prop joint. It never redraws the character from geometric substitutes.
- Basic v1 production path: clean face/body, original-style open eyes, genuine closed lids, failure brows. Body/hands/tablet remain baked together; only eyes/lids are independently animated. Receiving/failure only; success retains its existing renderer.
- New `PioCloudProduction.xcassets`: 5 uniquely named source PNG copies plus one registration; source bytes **1,211,441**. Copy hashes are in `production-basic-pack.json`. The large DEBUG trial catalog was not promoted.
- Release texture decoding has a separate NSCache (48 MiB soft limit); no per-frame SwiftUI updates. Animation uses Core Animation, stops on native visibility loss/detach and respects Reduce Motion/pending-verification suppression.
- All 14 v2 candidates: reconstructed costume-specific torso and sleeve/arm pairs, separate complete tablet on a common ±1.5°hold joint, existing genuine eyes/lids. Basic additionally has genuine foreground feet to preserve tablet/toe ordering. Sharedrig/registration architecture; no per-costume animation implementation duplication. No candidate releases the object or waves a hand independently of its grip. Headwear/sprout remain baked; astronaut/student/summer retain original optics. Summer's approved opaque sunglasses hide the eyes, so visible blinking is not claimed for that outfit.
- No coordinator, entitlement/purchase, persisted preference, SwiftData/CloudKit, bundle-ID or production installation changes. The other 13 production outfits retain their existing scene/fallback policy; no unverified paid outfit is enabled.

## Current-source checks

All rows are focused, opt-in native test-host executions. No StoreKit session or purchase ran.

| Run | Tests | Evidence / result bundle |
|---|---:|---|
| Mac production default resource path, no candidate or Overhaul flags | PASS 5/5 | `mac-production-final.log`; `/tmp/PioCloudProduction-Mac-final-20261024.xcresult` |
| iOS production default resource path, no candidate or Overhaul flags | PASS 5/5 | `ios-production-final.log`; `/tmp/PioCloudProduction-iOS-final-20261024.xcresult` |
| Actual visible iOS review-window screenshot | PASS 1/1 | `ios-visible-screenshot.log`; `/tmp/PioCloudVisibleScreenshot-final-20261024.xcresult` |
| Mac Basic v2 final feet + all-14 existing fallback/resource regression | PASS 3/3 | `mac-hands-v2-feet-final.log`; `/tmp/PioCloudHandsV2-feet-final-20261024.xcresult` |
| Mac Christmas v2 pilot | PASS 2/2 | `mac-christmas-v2-final.log`; `/tmp/PioCloudChristmasV2-final-20261024.xcresult` |
| iOS Basic v2 final feet + actual sequence | PASS 3/3 | `ios-basic-v2-final.log`; `/tmp/PioCloudBasicV2-iOS-final-20261024.xcresult` |
| iOS Christmas v2 + actual sequence | PASS 3/3 | `ios-christmas-v2-final.log`; `/tmp/PioCloudChristmasV2-iOS-final-20261024.xcresult` |
| Visible Mac active/stopped observation | PASS 1/1 assertions; measurements below | `mac-production-performance.log`; `/tmp/PioCloudProduction-Mac-performance-20261024.xcresult` |
| Mac Release build | PASS | `mac-release-build.log`; `/tmp/PioCloudRelease-mac-20261024/Build/Products/Release/Daylog.app` |
| iOS Release build | PASS | `ios-release-build.log`; `/tmp/PioCloudRelease-ios-20261024/Build/Products/Release-iphoneos/Daylog.app` |

First production/Basic/Christmas final batches: **23 executed tests, 0 failures**, excluding earlier diagnostic batches and build-only steps. Native tests cover 64/220pt, light/dark component backgrounds, actual open/closed/reopened presentation states, unchanged body during blinking, shared-joint contact, switch/resizing, Reduce Motion, live-visible→detach stopping, pending-art suppression and nonempty sampled source pixels. All-14 resource regression is not an ownership, purchase, whole-app workflow or new stage-artwork proof.

Both Release asset catalogs were inspected with `/usr/bin/assetutil --info`. Each contains exactly the 5 `pio_cloud_basic_prod_v1_*` images plus registration, and no `pio_overhaul_*`, `pio_cloud_basic_v1_*` or `pio_cloud_christmas_v2_*` trial resources. IDs remain `com.mungyubin.daylog` / `com.mungyubin.daylog.ios`. See `release-asset-proof.json` and platform `*-release-assets.json`.

**Release was built only.** The same production-resource path was executed in Debug test hosts without candidate/Overhaul flags; a signed Release app and physical iPhone were not launched.

## Visual evidence

- Accepted default production-resource clip: [basic-cloud-eyes-native.mp4](basic-cloud-eyes-native.mp4). 104 actual wall-time Core Animation presentation frames, 20fps, 5.2 seconds, 660×660. Debug native host using production resources; not a physical-iPhone recording.
- Actual simulator display screenshot: [production-basic-visible-simulator.png](production-basic-visible-simulator.png), 1206×2622. Captured with `simctl io ... screenshot` while the opt-in SwiftUI scene review host was visible. It shows the real native scene composed in a dedicated review screen, not the production cloud-account workflow.
- `mac-production-final/`: 124 PNGs = 20 actual 64/220 light/dark state frames + 104 sequence frames, plus presentation-opacity JSON.
- `ios-production-final/`: 20 actual state PNGs + observation JSON.
- `mac-hands-v2-feet-final/` and `mac-christmas-v2-final/`: each 28 PNGs (8 neutral model frames + 20 actual presentation frames), plus observations.
- `ios-basic-v2-final/` and `ios-christmas-v2-final/`: each 132 PNGs = 8 neutral + 20 actual presentation + 104 actual sequence frames, plus observations. The Basic sequence includes the final foreground-foot fix.
- Current candidate clips from actual final iOS frames: [Basic hands](basic-cloud-hands-final-ios.mp4), [Christmas hands](christmas-cloud-hands-final-ios.mp4), [Café hands](cafe-cloud-hands-final-ios.mp4). Each104frames/20fps/5.2s/660×660. These are native presentation-frame sequences, not physical-device or whole-app screen recordings.
- Root and independent artwork reviewer inspected Basic v1 open/closed, Basic v2 final feet and Christmas v2 ±hold at64/220. Later14-outfit review is detailed below. Scope does not approve every pose/growth stage.

Earlier `basic-hands-v2-native-candidate.mp4` predates the foreground-foot fix; retain as historical candidate evidence, use the final iOS sequence for current candidate review.

## First failures retained and fixed

Tests passing did not by itself establish visual success. First Mac eye captures were missing source pixels because the texture sampler needed platform-specific Y conversion. Fixed Mac contentsRect conversion and added nonempty-pixel assertions; iOS retains its own native coordinate convention. Corrected Mac/iOS open/closed frames pass visual review.

A subsequent held-parts capture showed only a green strip behind the torso: nested foreground group had been inserted before body and CPU `CALayer.render(in:)` painted by insertion order. Explicit painter ordering now matches z ordering; actual final captures show arms/tablet. Basic tablet then hid inner baked toes; genuine generated foreground feet were registered and final Mac/iOS captures verified. Failed/old evidence remains under `mac-eyes-v1*`, `mac-hands-v2*samplerfixed*`, `mac-hands-v2-painterfixed*`.

Vacation executed 3 diagnostic compositions × 64/220/1024 = **9 captures**, despite a later test source containing a fourth mode. The compiled binary predated that addition. Visible cotton-pad seams failed the clean-face artwork gate; no extra rerun or production promotion was used to hide that failure.

## Bounded performance observations

One warm visible native Mac Basic production scene, active 10.13s then stopped 10.16s, same process/resources/configuration. Quiet slot: no other agent builds, native tests or encoding. All **20/20 visibility samples true** using public NSWindow visible/occlusion checks; active character tracks existed, stopped tracks were zero, weak stage released on cleanup.

| Phase | Process CPU | RSS begin → end |
|---|---:|---:|
| Active | 0.352% (0.035622 CPU seconds / 10.13151 wall seconds) | 200.19 → 197.81 MiB |
| Stopped | 0.979% (0.099393 CPU seconds / 10.15547 wall seconds) | 197.81 → 201.75 MiB |

Cleanup RSS 201.75 MiB; stage released. Raw samples: `mac-production-performance/production-basic-live-stopped-observations.json`. Stopped CPU was higher in this short sample, so **no animation cost reduction or performance-threshold PASS is inferred**. Process CPU excludes WindowServer/GPU/compositor work. Debug host, single short window, no repeated-switch stress/long-term leak proof, battery or Release profiling. Historical 16.08% jumping is a different scene/condition and cannot be compared to these numbers.

## Exact build/test recipe

Workspace cwd `/Users/mungyubin/Desktop/Coding/Daylog`. Xcode logs include full original command invocations. All output paths were unique; original failed results were preserved.

```sh
xcodebuild -project Daylog.xcodeproj -scheme DaylogPioCloudCandidateReview -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/PioStoreKit-20261023-mac -clonedSourcePackagesDirPath /tmp/PioOverhaul-v2-build/SourcePackages build-for-testing CODE_SIGNING_ALLOWED=NO PRODUCT_BUNDLE_IDENTIFIER=com.daylog.verify
xcodebuild -project Daylog.xcodeproj -scheme DaylogiOSPioCloudCandidateReview -configuration Debug -destination 'platform=iOS Simulator,id=89B877BB-6094-4A27-B108-3A958EF23D9B' -derivedDataPath /tmp/PioStoreKit-20261023-ios -clonedSourcePackagesDirPath /tmp/PioOverhaul-v2-build/SourcePackages build-for-testing CODE_SIGNING_ALLOWED=NO
xcodebuild -project Daylog.xcodeproj -scheme Daylog -configuration Release -destination 'generic/platform=macOS' -derivedDataPath /tmp/PioCloudRelease-mac-20261024 -clonedSourcePackagesDirPath /tmp/PioOverhaul-v2-build/SourcePackages build CODE_SIGNING_ALLOWED=NO
xcodebuild -project Daylog.xcodeproj -scheme DaylogiOS -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/PioCloudRelease-ios-20261024 -clonedSourcePackagesDirPath /tmp/PioOverhaul-v2-build/SourcePackages build CODE_SIGNING_ALLOWED=NO
```

`test-without-building` used `-parallel-testing-enabled NO`, exact destination above and target `DaylogTests` (Mac) / `DaylogStoreKitTests` (iOS). Generated xctestrun copies stay beside original products so `__TESTROOT__` paths resolve:

| xctestrun copy | Arguments / selected test methods |
|---|---|
| Mac `PioCloudProductionFinal.xctestrun` | `-DaylogDebugSplash off -PioCloudProductionReview -PioCloudCandidateSequence -PioCloudPerformanceReview`; production 3 core methods + actual blink + sequence. Performance separately only its guarded method. Neither candidate eye/hands flags nor Overhaul flag present. |
| iOS `PioCloudProductionFinaliOS.xctestrun` | `-DaylogDebugSplash off -PioCloudProductionReview -PioCloudVisibleReviewHost`; production 3 core + actual blink + visible-host. Screenshot rerun selected only visible-host. |
| Mac original `DaylogPioCloudCandidateReview_macosx27.0-arm64.xctestrun` | Scheme DEBUG candidate flags; Basic neutral/stop, all-14 fallback and actual blink. |
| Mac `PioCloudChristmasFinal.xctestrun` | Same candidate flags + `-PioCloudChristmasCandidate`; Christmas neutral/stop and actual blink. |
| iOS `PioCloudBasicV2FinaliOS.xctestrun` | `-DaylogDebugSplash off -PioOverhaulTrial -PioCloudHandsV2 -PioCloudCandidateSequence`; neutral/stop, actual blink, sequence. |
| iOS `PioCloudChristmasV2FinaliOS.xctestrun` | Same + `-PioCloudChristmasCandidate`; same 3 methods. |

Example exact final measurement command:

```sh
xcodebuild test-without-building -xctestrun /tmp/PioStoreKit-20261023-mac/Build/Products/PioCloudProductionFinal.xctestrun -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:DaylogTests/PioCloudProductionTests/testProductionBasicLiveAndStoppedObservations -resultBundlePath /tmp/PioCloudProduction-Mac-performance-20261024.xcresult
```

Attachments exported with `xcrun xcresulttool export attachments --path <bundle> --output-path <unique-folder>`; original exports retain manifests and clean folders use their human-readable attachment names. The dedicated simulator was **Pio Motion Review 2026-10-23**, UUID above; no user's existing production app/device was replaced. Local unsigned test-host installs on that dedicated simulator only.

## Remaining limitations

- Basic production v1 hands/tablet/sprout/feet are still baked into body; no sip, separate finger/wave or articulated body claim.
- Basic/Christmas v2 hands move together with held tablet. Costume headwear/sprout remain baked; no 3D turn or free release.
- All 14 seated-cloud candidates now have reconstructed held hands/tablet sources and Mac+iOS native evidence. This does not add free-wave, jump, clothing articulation or growth-specific scene poses. Only Basic v1 eyes are enabled in Release; all 14 v2 hands remain DEBUG candidates for user visual approval.
- Vacation independent eyes/hands require clean continuous face and genuine roots, not accepted after the current three artwork attempts.
- Physical iPhone, signed Release runtime, older OS versions, real purchase/refund/cloud-account workflow, new home behavior and Stage 1–4 distinct scene art: NOT_TESTED in this task.
- No commit, push, deployment or production replacement performed.


## Subsequent focused pilots / fixture review

Additional native tests (after the first 23): retained-flat-fallback regression 1; Hanbok/astronaut/café 2 each on Mac and iOS =12; corrected previously unselected production-mode fixture branches 2; café iOS actual104-frame sequence 1; corrected20-cycle lifecycle 1. These **17 additional passing executions** bring scoped passing executions to **40**. A first lifecycle-fixture attempt failed its synchronous host-deallocation assumption and remains retained; this is not an all-attempts-zero-failure claim.

- `mac-pilot-fallback.log`, `/tmp/PioCloudPilot-Mac-fallback-20261024.xcresult`: capability expectation now requires the approved production eye pack/independent child. Then the explicit flattened fallback is still rendered and all original CGImage/nonempty-alpha checks remain.4 retained-fallback PNGs in `mac-pilot-fallback/`.
- `mac-pilot-{hanbok,astronaut,cafe}.log`, corresponding `/tmp/PioCloudPilot-Mac-<outfit>-20261024.xcresult`:2 methods each.
- `ios-pilot-{hanbok,astronaut,cafe}.log`, corresponding `/tmp/PioCloudPilot-iOS-<outfit>-20261024.xcresult`:2 methods each.
- Each pilot/platform folder contains28 PNG (8 neutral +20 actual presentation) and observations. Native mechanics passing did not approve the first astronaut artwork: that initial long-arm composite read as a duplicated-arm/hip-pad silhouette and was held. Its genuine compact-arm refinement was subsequently compiled and passed the final batch/visual gate below. The first failed artwork evidence remains unchanged. Hanbok/café scoped frames were reviewed separately.
- Generic fixture selection uses `-PioCloudCandidateOutfit <PioOutfitID.rawValue>`; missing/invalid raw values throw rather than silently reviewing Basic. Actual enum values include `astronaut`, distinct from its ASC product suffix `space`.
- Reviewer identified two stale unselected fixture production-mode expectations (revision name and candidate-vs-selected resource lookup). Prior first23 selected production actual blink/sequence and dedicated ProductionTests, so their evidence was unaffected. Fixed assertions now expect `basic-production-eyes-v1`, selected registration and the existing DEBUG coordinator API opt-in policy. Only those2 methods were rerun, bothPASS in `mac-production-fixture-review.log` / `/tmp/PioCloudProduction-FixtureReview-20261024.xcresult`; no previous23 were repeated.
- Café sequence `ios-cafe-sequence/`:104 actual iOS presentation PNGs,1/1testPASS; `/tmp/PioCloudCafe-iOS-sequence-20261024.xcresult`. Candidate only, no claim of drinking or released hand motion.

### Repeated native lifecycle observation

First 20-cycle attempt: `mac-production-20cycle-lifecycle.log` / `/tmp/PioCloudProduction-20cycle-lifecycle-20261024.xcresult` failed only immediate weak-host deallocation assertions. All 20 stages released and active/visible/stop assertions passed. Reused host addresses in later cycles showed earlier hosts were actually freed after the native autorelease/runloop turn. Raw first RSS169.28→249.23MiB remains in `mac-production-20cycle-lifecycle/`.

Test-only correction encloses the actual detach/removal/cleanup in an explicit `autoreleasepool`; it retains and checks the track count **after actual detach, before explicit halt**, then asserts both weak host and stage are nil after that ownership scope drains. No app-source change, increased sleep, assertion deletion or memory threshold was used.

Controlled quiet rerun `mac-production-20cycle-ownership.log` / `/tmp/PioCloudProduction-20cycle-ownership-20261024.xcresult`: **PASS 1/1**,20/20 actually visible,20/20 stages released,20/20 hosts released, all detached nested tracks0.20 cycles ×150ms active,3.262s total, processCPU0.225623seconds (different creation/destruction workload from the10s idle observation, so not directly comparable).

RSS173.11→203.00MiB. After-cleanup samples:208.70,208.94,208.95,208.97,208.98,209.00,209.02,209.03,209.03,209.06,208.83,208.62,207.83,207.72,203.59,203.50,203.52,203.52,203.52,203.00MiB. Raw JSON: `mac-production-20cycle-ownership/production-basic-20-cycle-lifecycle-observations.json`. Objects release, but process RSS retains allocations; shared decoded-image/framework caches may contribute and are not exclusively attributed. This bounded run does **not** establish leak-free memory, long-term stability, Release/battery/GPU performance or repeated14-outfit performance.

Reproduce lifecycle run with `PioCloudLifecycleFinal.xctestrun` (only `-DaylogDebugSplash off -PioCloudLifecycleReview`, no candidate/Overhaul flags), `-only-testing:DaylogTests/PioCloudProductionTests/testProductionRepeatedAttachDetachObservations`, same isolated Mac destination and `-parallel-testing-enabled NO`.


## Final14-outfit candidate coverage

The last batch added9previously unverified outfits plus the corrected astronaut. Exact targets: `cherryBlossom,autumn,winter,summerVacation,halloween,pajamas,student,fitness,rainyDay,astronaut`. All 14 registrations therefore have current Mac+iOS evidence when combined with earlier Basic/Christmas/Hanbok/café runs.

| Final expansion | XCTest methods | Explicit outfit-method checks | Evidence |
|---|---:|---:|---|
| Mac | PASS 2/2 | PASS 20/20 | `mac-expansion-batch.log`; `/tmp/PioCloudExpansion-Mac-batch-20261024.xcresult` |
| iOS | PASS 2/2 | PASS 20/20 | `ios-expansion-batch.log`; `/tmp/PioCloudExpansion-iOS-batch-20261024.xcresult` |

The same original assertion bodies run sequentially for each explicit target: `testCandidateRegistrationNeutralAndStop` and `testActualIndependentBlinkAndHeldPresentation`. Missing/duplicate/unknown batch identifiers fail, never silently test Basic. Thrown asset failures are recorded and later targets still execute. Per-target completion and added-assertion-failure counts are retained in `candidate-batch-neutral-results.json` and `candidate-batch-presentation-results.json`. All 40 rows completed with0 added failures. This is4 XCTest method executions, **not40 separate XCTest cases**; shared host process/cache and outfit switching are explicit.

`mac-expansion-batch/` and `ios-expansion-batch/` each contain **280 PNG +12 JSON** (10 outfits ×28 neutral/actualframes;10 runtime observation JSONs +2 batch summaries). Both folders record exact compiled `partAssets` and canonical `partRects`. Refined astronaut armLeft/armRight are both `pio_cloud_astronaut_v2_armPairCompact`; original visor is retained behind the newtablet. The original hip-pad design was preserved, while a genuine shorter forearm/cuff reconstruction repaired the duplicated-limb impression. Initial long-arm artwork and first native captures remain historical failed-artwork evidence; **current Compact candidate scoped visual PASS**.

Scoped visual review is split across reviewers and root: cherryBlossom/autumn/winter/Compact astronaut; summerVacation/halloween/pajamas; independently reviewed student/fitness/rainyDay Mac220open/negativehold +iOS220positivehold/64darkclosed. Basic/Christmas/Hanbok/café were reviewed earlier. Source artwork remains candidate until user approval; no13 paid v2 Release promotion occurred.

Batch recipe, same previously documented isolated hosts/destinations:

```sh
# Copy the generated xctestrun alongside its original products; set only:
# -DaylogDebugSplash off -PioOverhaulTrial -PioCloudHandsV2
# -PioCloudCandidateBatch cherryBlossom,autumn,winter,summerVacation,halloween,pajamas,student,fitness,rainyDay,astronaut
xcodebuild test-without-building -xctestrun /tmp/PioStoreKit-20261023-mac/Build/Products/PioCloudExpansionBatchFinal.xctestrun -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:DaylogTests/PioCloudCandidateReviewTests/testBatchCandidateRegistrationNeutralAndStop -only-testing:DaylogTests/PioCloudCandidateReviewTests/testBatchActualIndependentBlinkAndHeldPresentation -resultBundlePath /tmp/PioCloudExpansion-Mac-batch-20261024.xcresult
xcodebuild test-without-building -xctestrun /tmp/PioStoreKit-20261023-ios/Build/Products/PioCloudExpansionBatchFinal.xctestrun -destination 'platform=iOS Simulator,id=89B877BB-6094-4A27-B108-3A958EF23D9B' -parallel-testing-enabled NO -only-testing:DaylogStoreKitTests/PioCloudCandidateReviewTests/testBatchCandidateRegistrationNeutralAndStop -only-testing:DaylogStoreKitTests/PioCloudCandidateReviewTests/testBatchActualIndependentBlinkAndHeldPresentation -resultBundlePath /tmp/PioCloudExpansion-iOS-batch-20261024.xcresult
```

Final test-fixture additions compile in `mac-build-expansion-batch.log` and `ios-build-expansion-batch.log`. All later additions are DEBUGcandidate assets/test helpers; no app-source changes followed the successful Mac/iOSRelease builds, so no redundant Release rebuild was run.

## Affected source files owned by runtime integration

- New `Daylog/Views/Onboarding/PioCloudCharacterRig.swift` — shared canonical authored-part rig, native samplers, painter ordering, independent eyes/held joint, small Release-only decoder path.
- `Daylog/Views/Onboarding/RoutimoriSyncScene.swift` — narrow approved Basic receiving/trouble production-eye selection and safe native rig lifetime; other production fallback/authentication policies retained.
- New `Daylog/PioCloudProduction.xcassets/` — five unique byte-identical approved Basic v1 source copies plus registration;13catalog files total.
- New `DaylogStoreKitTests/PioCloudCandidateReviewTests.swift` — opt-in individual/batch native evidence and exact runtime source mapping.
- New `DaylogStoreKitTests/PioCloudProductionTests.swift` — no-candidate default resources, ReduceMotion/auth-art suppression, actual visibility/detach, bounded CPU/RSS and20-cycle object lifecycle.
- `DaylogTests/PioMacStabilityReviewTests.swift` — historical capability expectation corrected, native production child checked, original flattenedfallbackCGImage/alpha assertions retained.
- New shared schemes `DaylogPioCloudCandidateReview.xcscheme`, `DaylogiOSPioCloudCandidateReview.xcscheme` — isolated opt-in evidence; no StoreKitconfiguration/purchases.

Other workers own the14 DEBUG registration/source catalogs and provenance. This runtime integration did not change coordinator, StoreKit/registry, production data/schema, IDs or approved original image files. No commit/push/deploy/production installation.
