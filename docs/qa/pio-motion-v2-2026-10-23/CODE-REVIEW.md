# Independent native rig source review

Scope: `Daylog/Components/PioOverhaulCharacter.swift`, appearance view/coordinator wiring, and both target Release asset exclusions. Reviewer did not author or edit native application code. This is a source review, **not runtime, visual, build, CPU, or memory certification**.

Verdict at review: **PARTIAL / changes requested**. No production data, schema, purchase, bundle-ID or release-path writes were found in this change.

## Findings

### P2 — Explicit landing events are converted into a full looping jump

`PioAppearanceView.overhaulAction` combines `.jump, .landing` and returns `.jump`. The new native jump has crouch, substantial lift, and landing, and every animation track repeats infinitely. Thus an appearance whose requested motion is landing starts another full jumping loop, instead of depicting its landing/recovery. The existing pilot renderer maps `.landing` separately.

Recommendation: preserve a distinct landing action with compression/recovery and a settled endpoint, or otherwise explicitly implement a bounded landing response. Test the appearance mapping for jump and landing separately. This affects the opt-in DEBUG renderer only.

### P2 — Two held-object groups exceed the previously inspected art range

`PioOverhaulRig.animate()` clamps Christmas gift + both hands and Pajamas pillow + both wings at ±3°. Prior offline art inspection and registration used ±2° for these two shared groups. Pivot sharing is correct, but it does not prove hidden shoulder roots survive an enlarged motion envelope.

Recommendation: use ±2° until native maximum-angle frames are reviewed. Umbrella remains 0…−4°, consistent with its previously inspected envelope. Single-held props share hand pivots and clamp ±4°; no release is invented.

### P2 / documented limitation — Scroll-offscreen suspension is incomplete on older deployment targets

`PioOverhaulVisibility` calls scroll visibility only on macOS 15 / iOS 18+. Its fallback leaves `onScreen` true. Native host refresh checks window attachment and hidden state, which do not establish that a view retained by a scroll container is outside the visible clip. Thus offscreen-stop support is not established for macOS 14 / iOS 17, or native occlusion cases without another refresh.

Recommendation: add a platform visibility/intersection fallback or clearly mark older-target scroll suspension unsupported/NOT_TESTED. Do not report offscreen performance PASS on source inspection alone.

## Reviewed properties that are structurally consistent

- Entire native implementation is enclosed in `#if DEBUG`; runtime opt-in is an explicit process argument.
- Appearance view and resource resolver only reference this renderer inside DEBUG branches, with a valid-manifest check before selection.
- Both Mac and iPhone target Release configurations exclude `PioOverhaulTrial.xcassets` alongside older trial catalogs. Confirm exclusion with actual Release build settings if packaging is in scope; this review did not build Release.
- Configuration changes stop animations, replace layers when outfit changes, neutralize state, and resume only if previously active. Same outfit/action updates avoid reconfiguration.
- Removal/disappearance, inactive scene phase, `isAnimating == false`, and Reduce Motion all reach `setActive(false)` and neutralize transforms and opacity. Host dismantling also removes animations.
- Open / half / closed / happy eye substitutes use mutually exclusive selection per eye. Missing expression substitutes fall back to the original open eye. Wink selects one authored happy eye and one open eye.
- Eye replacements get the original eye slot depth, so helmet/visor/glasses ordering is retained from the manifest. Actual optical edge appearance still needs native frame inspection.
- Shared grip pivots are used for gift+hands, pillow+hands, umbrella+right hand, and independent held props. Transform tracks are native Core Animation rather than per-frame SwiftUI layout state.
- Bounds updates are guarded and use disabled implicit transactions; image caching has a declared cost limit. This does not measure actual CALayer-retained decoded memory or switching stability.

## Visual/runtime checks still required

Review maximum wing angles for all 14 outfits; inspect held-group endpoints and visor/glasses overlap; observe Reduce Motion while a sequence is playing; scroll characters offscreen and back; switch outfits repeatedly; inspect iPhone orientation and macOS vertical direction; compare CPU and memory under identical conditions. Front-view stepping should not be described as an authored side-view walk, and frontal compression/lean should not be described as a reconstructed 3D bow.

Application authors may fix the findings after this report. Treat the report as the inspected revision, and record follow-up evidence for any resolutions.

## Follow-up source re-review

The implementation was subsequently updated and read again:

- **Finding 1 CLOSED at source level:** `PioOverhaulAction.resolve()` now resolves `.landing` distinctly; the new landing keyframes compress/recover without another airborne arc. Landing still uses the common infinite-loop preview playback; this is suitable for explicit motion review, while one-shot production-event semantics remain outside this review.
- **Finding 2 CLOSED at source level:** Christmas and Pajamas shared groups now clamp at ±2°, matching the inspected offline art envelope.
- **Finding 3 CLOSED at source level:** the Mac host observes enclosing clip-view bounds changes and checks `visibleRect`; the iPhone host observes ancestor scroll offsets and intersects the view with visible clipping ancestors/window, including ancestor hidden/alpha checks. This addresses the previous fallback gap structurally.

**Runtime status remains NOT_TESTED by this reviewer.** Source fixes do not establish actual scrolling suspension, new pose appearance, frame-time cost, or native optical/shoulder seam quality. Native harness evidence was pending at this follow-up. The offline visual pilot review covers the PNG/APNG artifacts only.

## Native rendered-frame follow-up

Actually viewed the harness-exported presentation-layer PNGs in `native-readable/`: Hanbok jump frames 0/1/2; Christmas greet frame 1; Astronaut celebrate frame 2 and greet frame 1; Basic jump frame 1; Hanbok 64pt dark; and the gallery capture. These are native harness evidence, not a claim that the user-facing production app was exercised.

The inspected native character stills retain the premium cute material; Christmas hands and gift remain visually aligned; Astronaut eye expressions sit inside the visor. Hanbok 64pt remains recognizable, with substantially smaller visible character due to reserved jump margins.

### New P2 — High-jump sprout reaches output top border

Hanbok `hanbok-jump-native-2.png` and Christmas `christmas-jump-native-2.png` have visible character pixels on image row zero. Numeric check: compared each row-zero pixel against the corner background, max-channel delta > 8 occurs for 15 pixels at x199…213 in Hanbok and 10 pixels at x201…210 in Christmas. The rendered Hanbok sprout visibly touches/cuts against the top boundary.

Recommendation: reserve more top headroom, shift the canonical canvas downward, or slightly reduce the maximum jump scale/translation. Re-export the highest pose and assert no character pixels touch any frame edge. Testing only arbitrary elapsed-time presentation samples is not sufficient to prove global trajectory bounds.

### Evidence limitation — Gallery capture is not a faithful UI readability proof

`native-motion-gallery-hanbok.png` shows black/transparent surrounding areas and multiple white controls without readable labels. This may result from the offscreen SwiftUI rendering harness rather than the actual presented app. Do not use this image alone as gallery layout/readability PASS. Capture the real visible DEBUG gallery before approving the user interface.

Remaining runtime distinctions: rendered native frames are now inspected; scrolling, Reduce Motion interaction, iPhone runtime, CPU/memory comparison and all-outfit native endpoints are not independently certified by this reviewer.

## Final jump-boundary resolution

**High-jump border finding CLOSED for the exported final poses.** Re-opened the corrected final 220pt peak PNGs for Hanbok, Christmas and Astronaut in `native-final/`; their sprouts now have visible transparent headroom and the body proportions remain cute. Independently decoded all **84** final idle/landing/jump-peak RGBA PNGs (14 outfits × 2 sizes × 3 poses) and checked all four outer alpha borders: every maximum equals zero.

The worker's named verification JSONs agree with this direct pixel check. This closes the concrete crop observed in the earlier native-readable exports, not a blanket proof of every interpolated frame, every container geometry, or all possible actions. Actual native 60-frame Hanbok jump / Christmas greeting sequences and encoded MP4s are now available as separate motion evidence. This reviewer inspected still frames and boundary pixels; no all-action video/performance certification is implied.
