# Native Pio motion evidence

2026-10-16. Dedicated iPhone 17 simulator, opt-in native global-review test host,
real Xcode-local StoreKit ownership, actual production `PioAppearanceView` and
`PioOutfitMotionView`. No character art, animation tracks or production lifecycle
guards were bypassed for this review.

## Confirmed QA-host lifecycle issue

The manually presented `UIHostingController` inherited SwiftUI `scenePhase =
background` while its attached `UIWindowScene` was active. Production motion
correctly requires an active phase; the disconnected test environment therefore
kept the earlier review static even with system Reduce Motion off.

The test-only bridge now derives phase from the attached native scene's actual
activation state and matching lifecycle notifications. It does not force an
always-active phase or override Reduce Motion. The production App/Scene path is
unchanged. In [the native review log](ios-native-motion-review.log), diagnostics
show `inherited=background native=active` and the following actual renderer state:

| Observation | Native system / renderer evidence | Result |
| --- | --- | --- |
| Christmas growth idle, Reduce Motion off | `environmentReduce=false`, `nativeReduce=false`, one active rig, one animation track | PASS for instrumented activation; not a separate idle-motion quality assessment |
| Christmas upright, 220 pt, jump, Reduce Motion off | Native scene active; one active rig, three animation tracks; actual changing character pixels in the recording below | PASS for this native jump sample |
| Same requested Christmas jump, system Reduce Motion on | Native scene stays active; `environmentReduce=true`, `nativeReduce=true`; zero active rigs and zero tracks | PASS for the instrumented system Reduce Motion gate, with one valid native screenshot |
| Resume after Reduce Motion is switched off again | System setting restored through the device Settings UI after the review; no new valid foreground motion sample after that restoration | NOT_TESTED |

## Actual animated recording

[Christmas jump preview](ios-native-christmas-jump.mp4) is a 10-second extract of
the actual native animated recording. The longer source was approximately 189
seconds. The saved [character-region frame hashes](ios-native-jump-video-framehashes.txt)
contain **758 sampled frames and 389 unique hashes** at a 1/4-second time base,
using an 800 × 1000 pixel character region. The clip plus the renderer diagnostics
support visible movement in this sample; the hash count is not an FPS or
smoothness benchmark.

`ios-native-jump-active-a.png` and `ios-native-jump-active-b.png` both happened to
sample the resting portion of the cycle and are identical. **Do not use that
screenshot pair as visual motion proof.** The video is the motion evidence.

The initial [unbridged static investigation recording](ios-review-static-motion-investigation.mp4)
is **not animation proof**. Its near-static frame changes were insufficient to
establish motion. Earlier Mac jump snapshots also do not establish active native
animation without a valid lifecycle/renderer observation.

## Actual system Reduce Motion

The reviewer changed the simulator's real Accessibility Reduce Motion setting.
[The valid on-state screenshot](ios-native-reduce-motion-on-a.png) shows the
native review with Reduce Motion on, matching the log's zero active rigs/tracks
while the native scene remains active.

`ios-native-reduce-motion-on-b.png` was taken after the test's ten-minute timeout
and shows the simulator Home Screen. It is **INVALID** for this comparison and
must not be paired with screenshot A. Consequently the changed-pixel comparison
in `native-reduce-motion-observation.json` is also **INVALID** as stillness proof;
its two images do not depict the same app view. Sustained pixel-level stillness
has not been established by that pair. The log's actual-system gate observation
and valid screenshot A remain valid independently.

## Performance observation, not a benchmark

[Active Christmas jump process samples](ios-active-christmas-jump-samples.json):

- Measurement duration: **15.1750409603 seconds**.
- Mean CPU from process CPU-time delta: **0.8566698458% of one core**.
- Observed RSS: **404,352–407,376 KiB**.
- DeviceHub recording was active during the measurement.

There is no controlled idle baseline, physical-device measurement, long-run
memory study or frame-time profile. These samples must not be presented as an
animation-performance target being met. The prior approximately **0.33% Mac CPU**
sample likely measured the inactive manually hosted view; it is **not evidence
of active-animation performance**.

## Remaining scope

This result covers one Christmas whole-body jump at 220 pt in a native iPhone
simulator review. It does not verify all outfits/motions/sizes, separate accessory
or wing motion, stage-specific art, the production navigation lifecycle, repeated
background/resume, scroll-offscreen stop/resume, native Mac animation, or every
scene's Reduce Motion response. Vacation/cloud scene-specific premium art remains
missing and those scenes remain PARTIAL regardless of this motion result.

The review test finishing with `TEST EXECUTE SUCCEEDED` after its 600-second wait
does not certify these untested behaviors. See the [screen compatibility matrix](../pio-global-outfit-2026-10-16/SCREEN-COMPATIBILITY-MATRIX.md)
for the separate static visual and functional-flow evidence.
