# iPhone simulator native scene verification — 2026-10-23

Overall: PARTIAL. Focused implementation/runtime checks PASS; independent vacation hands/eyes and Basic seated cloud eye artwork remain absent. This is native scene-component evidence, not complete end-to-end cloud-data or vacation-control testing.

## Actual execution

- Isolated iPhone 17 simulator: `0426CD78-3807-4650-9776-B649780E2884`, iOS 27.0.
- Scheme: `DaylogiOSPioMotionReview`, Debug, unsigned simulator test build. A copied temporary xctestrun selected only `PioScenesIOSReviewTests`, with `-PioIOSSceneReview` and `-PioOverhaulTrial`.
- Test: `testNativeCloudAndVacationCurrentOutfits()` — PASS, 1/1, 0 failures, 0 skips.
- Current-source build: `ios-scene-build-v3.log` — TEST BUILD SUCCEEDED.
- Current-source runtime: `ios-scene-test-v2.log`, `ios-test-results-final.json` — TEST EXECUTE SUCCEEDED.
- Original result bundle: `/tmp/PioScenesIOSReview-20261023-v2.xcresult`; preserved QA copy: `ios-scene-final.xcresult`.
- No StoreKit session/transactions, purchase grants, preference writes, production app replacement or production data writes were performed by this test. The host asserts the existing XCTest/in-memory runtime mode.

## Verified checks

| Check | Result | Scope |
|---|---|---|
| Central coordinator scene mapping | PASS | 14 outfits × receiving/ready/trouble = 42 mappings; preview resolution only, no ownership changes |
| Reduce Motion configuration | PASS | All42 native stages have zero CA tracks with configuration reduceMotion=true; OS accessibility setting was not toggled |
| Pending-verification character suppression | PASS | Character hidden with zero own/child tracks while cloud feedback remains active |
| Native window detachment | PASS | iOS native cloud host stops all scene tracks after removal from its window |
| Vacation hidden foreground | PASS | Actual pilot rigs stop hammock tracks when character foreground is hidden |
| Independent cloud blink | PASS visual evidence | Christmas actual presentation open and closed eyes captured separately; body/tablet unchanged |
| Pilot cloud rendering | PASS component rendering | Christmas/Hanbok/Astronaut × three states, actual native presentation |
| Pilot vacation rendering | PASS component rendering | Christmas/Hanbok/Astronaut × day/night, actual native presentation |
| iPhone CPU/RSS, long-term memory | NOT_TESTED | No performance PASS inferred from a short XCTest |
| Full workflow / live CloudKit | NOT_TESTED | No network sync or production user data touched |
| iOS64pt full visual matrix | NOT_TESTED | Neutral mapping/lifecycle configured at220pt; pilot scene images captured at340pt@3x |

## Real visual defect found and fixed

The first runtime test passed its assertions, but inspection of its actual PNGs showed the legacy 256pt-at-y226 scene registration cut off the premium characters' feet. This affected authored seated sources and the shared completed-state rig. Those first images remain in `native-ios/`; they are historical evidence, not the final preview.

Only the independent scene registration was changed to a uniform230pt square at y215 in a340pt scene, leaving original Basic fallback geometry and source pixels untouched. A focused neutral frame-bound assertion was added. The same focused test was rebuilt and rerun successfully. Corrected Christmas receiving and Hanbok completed PNGs were opened and visually inspected: both now show complete feet with lower margin.

The final images are in `native-ios-final/`. Their human-readable copies are byte-identical to the original exported XCTest attachments, with the original export manifest preserved:

- `ios-cloud-{christmas,hanbok,astronaut}-{receiving,ready,trouble}-{light,dark}-native.png` — 9 PNGs. Receiving/ready light, trouble dark.
- `ios-cloud-christmas-blink-{0,1}-native.png` — 2 actual eye-state PNGs, transparent standalone native cloud rig.
- `ios-vacation-{christmas,hanbok,astronaut}-{day,night}-native.png` — 6 PNGs.
- `ios-scene-native-results.json` — 42 exact mappings and limitations.

Total: 17 final PNG attachments plus1 JSON attachment. Cloud scene PNGs are1020×1020; vacation PNGs are1206×2340. They were rendered from UIKit/Core Animation presentation trees, not assembled from original character image files in an offline compositor.

## Honest limits and review notes

- Premium cloud receiving/failure: independent eyes/lids/brows are real. Hands, tablet and sleeves remain together in the authored scene body. No isolated typing/waving is claimed.
- Basic cloud receiving/failure: original approved flattened scene remains; independent eyes are unavailable.
- Completed state: shared genuine independent rig used once; all14 mappings verified. Only the three representative outfits have new iOS presentation screenshots here.
- Vacation: only whole authored foreground sway, with conservative ±0.55° candidate pivots. Separate eyes, hands/drink and hammock front/back occlusion are absent. Native Christmas/Hanbok/Astronaut day/night scenes retain cute identity and authored costume texture; exact rope attachment at both swing extremes still needs artist approval.
- The night beach is real authored night scenery, not a color filter. Read-only review of native Mac Hanbok night and Astronaut day, plus native iOS Astronaut night, found no additional P1 source issue. Existing wide-layout fade/blur and provisional hammock registration remain visibly deliberate preview behavior, not final independent scene-rig approval.

Initial unprivileged build/export cache access failed under sandbox restrictions; those logs are preserved. Repeating the same operations with approved Xcode cache access succeeded. No test exclusions or assertion removals were used to obtain PASS.
