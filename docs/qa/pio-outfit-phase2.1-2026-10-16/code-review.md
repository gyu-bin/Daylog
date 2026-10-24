# Phase 2.1 diagnostics code review

Result: **No actionable code finding** in the reviewed diagnostic-only changes. This does not certify independent costume rigs, complete growth-stage animation, or performance optimization.

Reviewed application/test source read-only: `PioOutfitMotion.swift`, new `PioOutfitDiagnosticsView.swift`, `PioOutfitMotionTests.swift`, and the `RootView.swift` diff against `before-RootView.swift` from this phase. No app/test source was edited and no additional builds/tests were run by the reviewer.

## Release and business behavior

- The diagnostic screen, image/rig telemetry, counters, registry and host instrumentation are within `#if DEBUG`.
- Root routing additionally requires the Routimori trial and explicit `DaylogDebugOutfitDiagnostics` flag. Release still selects the original application navigation.
- The phase-specific RootView diff only extracts `applicationNavigation` and selects a diagnostic root in the explicit test path. Earlier unrelated RootView work is not part of this phase's change.
- The diagnostic route substitutes its content for the dashboard/shop tree, avoiding hidden animated characters from those screens. Root-level application services/modifiers still exist, so CPU/RSS samples remain whole-app measurements rather than renderer-only or GPU measurements.
- Diagnostic outfit, motion, size, stage, visibility and theme choices are local `@State`. They do not call the wardrobe equip/purchase APIs, modify ownership, or write XP, records, CloudKit, schema, or actual icon state.

## Instrumentation and lifecycle

- Counters are ordinary main-actor static storage, not observable properties. Recording a host update/layout/source lookup does not itself invalidate SwiftUI.
- Layout telemetry compares bounds/display scale and records effective changes, but still executes the original layout transaction. This is baseline instrumentation, not an optimization.
- `reset()` clears counters only. It does not evict cached images, rebuild rigs, reset animation clocks, or falsely erase still-active rigs.
- Registry entries contain weak references. Snapshots remove nil/stopped entries, then temporarily collect live rigs for counts. There is no persistent strong rig reference in the registry.
- The new focused test checks a running rig's deallocation, active-rig/track counts, and count preservation across reset.
- Metrics are refreshed on appearance or explicit button presses, not by a repeating UI timer. A manual metrics refresh changes the displayed metrics state and may itself cause a finite host update; let the view settle before comparing timed counters.
- The 30-switch task is bounded, uses cancellable sleeps, checks cancellation, and is attached through `.task(id: switching)`. Stopping the switch toggle or removing the view cancels it. The renderer retains its existing scene/visibility/window gates.

## Measurement and capability limits

- The stress task continues its requested switches while the scene is inactive until completion/cancellation. Do not treat an active switching run as an otherwise idle background baseline.
- The forced stop toggle sends an animation-stop request; the UI deliberately distinguishes it from the actual system Reduce Motion value. Stop-request evidence alone is not proof of OS accessibility preference propagation.
- `sourceLoads` counts successful CGImage retrievals entering the local cache, not physical decoder operations. Native image APIs may have already cached/decoded the source.
- The comparison screen preloads the same four images in each case. Memory comparisons consequently represent a warm common source set, not cold single-image memory cost.
- Existing costume body-track behavior, basic wing reuse, stage limitation flags and animation values are unchanged. Christmas, Hanbok and Astronaut remain flattened artwork with no certified independent component layers. The separate component audit and missing-art requirements are compatible with these code claims.
- Static source inspection does not establish final CPU/RSS savings or GPU behavior, nor prove absence of every retention issue. Runtime metrics and visual evidence must support those separate conclusions.

## Existing test evidence inspected

`focused-tests.log` reports **14 tests across 2 suites passed**, including the weak-registry test, followed by `TEST SUCCEEDED`. This reviewer read that result and did not rerun tests. Platform build and runtime results are reported separately by the parent task.

## Final initializer and preservation re-review

Reviewed the final diagnostic initializer and current source again. No new actionable finding. Requested sizes are constrained to 64/120/220 points (fallback 220), requested stage is constrained to 1–4 (fallback 1), and the appearance argument initializes local display state. Case arguments choose diagnostic state only; none modifies wardrobe ownership or app records. The same DEBUG plus explicit Routimori opt-in routing and nonobservable weak-registry instrumentation remain in place.

The `offscreen` launch case sets `showCharacter = false`, removing the view. Its measurements prove the removed/hidden case, not the behavior of the scroll-visibility callback while a mounted character is scrolled out of view.

Inspected final Mac/iOS build log endings: both report `BUILD SUCCEEDED`. The existing focused log reports 14 tests in 2 suites passed. No additional build/test run was performed by this reviewer.

Independent preservation comparison: 553 baseline files checked, 550 unchanged, exactly 3 changed source/test files, 0 missing. All 130 baseline PNGs, including basic plus all 13 approved costume PNGs, are byte-identical. See `preservation-check.md` and `preservation-check.json` for exact paths/hashes and the partial Xcode metadata-baseline caveat.

No independent costume animation, four-stage rig compatibility or performance improvement is claimed. Actual-shop performance sampling and other runtime QA are separate parent-task evidence and are not covered by this source review.

## Final RESULTS / PERFORMANCE factual audit

Read `RESULTS.md` and `PERFORMANCE.md` against the saved raw CPU/RSS JSON, current/start/end accessibility snapshots, preservation report, build/test logs and independent visual-evidence report. **No factual overclaim or report correction was identified.**

- All eight controlled comparison rows and the actual-shop sample match the saved durations, CPU values and RSS ranges after rounding. The 30-switch and removed-view samples share PID 25176 as described.
- Christmas, Hanbok and Astronaut jump start/end snapshots retain one active rig / three tracks, with unchanged host/layout/source counters. The 30-switch end snapshot reports 30 configurations and zero additional source loads. The source-load versus actual decoder distinction is explicit.
- Mac OFF→ON→OFF snapshots show system Reduce Motion state changes and tracks 3→0→3, using the current child Text rather than the cached macOS AX parent value. The iPhone initial/start, ON and restored snapshots show the same state/track progression; the separate restored Settings snapshot shows `REDUCE_MOTION` value 0. The forced-stop toggle remains off in these captures.
- The reports explicitly identify zero fully independent costume rigs, partial whole-image motions, missing stage-specific artwork, and no certified four-stage visual compatibility. Basic's existing wing mask is kept separate from costume capability claims.
- The new video is supported by sampled-frame review, not a continuous-FPS or every-extremum claim. Reused evidence is labeled prior evidence rather than freshly captured coverage.
- Performance remains PARTIAL. The reports do not claim a 16.08%→0% optimization, literal zero CPU/GPU cost, proven root cause, long-term leak absence, iOS CPU/RSS coverage, or overall performance PASS.

No report text needed correction. No app/source edits, repeated tests, new runtime actions or performance runs were performed for this audit.
