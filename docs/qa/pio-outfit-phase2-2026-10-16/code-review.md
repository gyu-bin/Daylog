# Phase 2 focused code review

Scope: read-only application/test review of `PioWardrobe.swift`, `PioWardrobeView.swift`, `Saessagi.swift`, new `PioOutfitMotion.swift`, and focused wardrobe/motion tests. No application or test source was edited by this reviewer. This document is the review artifact; it is not a build, visual approval, or performance result.

## Result

No remaining actionable code findings in the inspected final changes. Implementation scope remains **PARTIAL**, not thirteen independently rigged outfits or complete four-stage animation support.

## Findings resolved during review

- **P1 — minimum OS compatibility:** unconditional `onScrollVisibilityChange` required macOS 15 / iOS 18 while app targets are macOS 14 / iOS 17. The renderer now uses an availability-guarded modifier without raising deployment targets.
- **P2 — truthful static behavior:** motion controls and animation-specific copy were visible outside the DEBUG Routimori trial, where rendering is static. Controls and copy are now trial-gated; the equip confirmation and growth-stage paragraph describe the actual active behavior.
- **P2 — dashboard outfit transition:** replacing an outfit changed view identity without an animation transaction observing the outfit. A Reduce Motion-aware animation keyed by equipped outfit now supports the existing opacity transition.
- Missing image handling was restored: the animated host requires a real cached source image, otherwise native-image lookup falls back to the theme symbol.
- The existing outer SwiftUI completion lift is disabled in the outfit trial, avoiding a second bounce on top of the native celebration track.

## Verified by code inspection

- Preview stage persists in its own local key, accepts only 1–4, and does not modify ownership, outfit, icon selection, XP or level.
- Existing ownership guards, DEBUG mock ownership, Release basic-only ownership and unavailable real-payment/restore behavior remain intact.
- Dashboard outfit rendering is DEBUG plus Routimori opt-in. Default/Pio/Release dashboard branches remain available as before.
- Animated code/cache are DEBUG-only. Non-trial and Release views show static artwork and do not offer inactive animation controls.
- Native rigs stop tracks on visibility/scene/window loss and dismantling; Reduce Motion reaches the same stop path. Repeated configuration/layout does not duplicate tracks or intentionally re-decode the same source.
- Stage changes preserve the same outfit/source and do not pretend to adapt its silhouette. The UI and capability model call this partial support.
- Costume motions are whole-image breathing, bounce, jump, landing, celebration and rest. Only basic Pio uses the existing approved independent wing mask. No independent costume blink, walk, run or flap is claimed.
- The source cache is bounded by the fourteen-item catalog. No per-frame SwiftUI timer or image decoding loop was introduced.
- Focused tests cover capability limits, stop/restart/Reduce Motion, basic wave teardown, same-source cache reuse, stage changes without rig reconstruction, unsupported costume-wave fallback, and selection persistence.

## Verification limits

Builds/tests are run and reported separately by the parent task; this reviewer did not rerun them. Artwork hash preservation, attachment quality, small-size readability, real render-server motion, CPU/memory measurements and runtime navigation are separate QA evidence.

On macOS 14 / iOS 17 the scroll-visibility callback is unavailable. Scene, view disappearance and window gates still apply, but a mounted view merely scrolled offscreen does not gain that newer OS visibility signal. This follows the existing renderer availability policy and should not be reported as verified scroll-offscreen pausing on those older systems.

## Final growth-card integration review

Reviewed the final `SaessagiGrowthCard.swift` diff read-only. **No actionable finding** in this addition.

- The new branch is selected only by `PioOutfitMotionView.isTrialEnabled` (DEBUG plus Routimori opt-in). Default and Pio branches retain their prior artwork, growth values, event handling, accessibility label and hop behavior.
- The trial reads the shared equipped outfit and existing level-to-stage mapping. It does not change XP calculations, thresholds, records, ownership or selections.
- Outfit replacement uses a Reduce Motion-aware opacity transition. Native celebration handles the trial movement; the former outer lift and hop loop are disabled only in the trial, preventing duplicate motion.
- The existing event timer still clears the celebration. On disappearance the timer is cancelled and trial `shown` is cleared, so revisiting the card cannot restart an indefinitely retained celebration.
- The trial stage badge and accessibility description explicitly disclose missing stage-specific artwork; the equipped costume persists through stage changes.

Parent reports final Mac/iOS builds passed. The thirteen focused model/renderer tests passed before this card-only change; those models/renderers were not changed afterward. This review did not rerun tests or builds, and does not replace pending updated runtime header/card screenshot evidence.
