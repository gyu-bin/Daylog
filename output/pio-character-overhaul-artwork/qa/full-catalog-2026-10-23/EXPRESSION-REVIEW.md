# Independent full-catalog expression review — 2026-10-23

**PARTIAL — reviewable independent eye-expression artwork across Basic + 13 outfits; not full animation or final character approval.** This reviewer wrote only this report. No source art/application changes, builds, native tests, purchases or deployment.

## Findings

1. **Summer at 64pt ×1 has weak expression discrimination.** The tinted panes preserve dark-sunglasses identity and correctly sit over the eyes, but open/closed/happy/wink differ only subtly at the actual small size. At 220pt ×1 and the decoded 300px GIF, happy arcs and wink are visible. Do not call all expressions clearly readable at every size. This is the optional translucent v2 optical candidate, not approval of a replacement for primary sunglasses.
2. **This is an eye-expression set, not eight completed body actions.** Actual GIFs for Summer, Student, Astronaut and Pajamas decode to six distinct 300×340 frames, with repeated holds collapsed by GIF encoding. They show open → closed → open → happy → wink → open while costume, limbs and props stay fixed. This is genuine independent eye switching, not a whole-body rotation mislabeled as independent animation; no wing, foot, prop, jump or fabric animation is demonstrated by these GIFs.
3. **Existing costume/fidelity limitations survive.** Reusing the same body artwork preserves the candidate costume appearance but does not resolve original-design deviations, grip geometry, baked cloth, hat/sprout grouping or source edge fringes. Pajamas was being updated during this review: the final native happy render and decoded GIF inspected here use the final-candidate registration, while the first overview/small-board observation was from the prior rendered state. Rainy was still undergoing a separate attachment refinement; this expression review does not approve its canopy/shaft update.

## Eye-slot and optical observations

- Both whole-catalog overview PNGs (`full-catalog-v1/catalog-happy-light.png`, `catalog-open-dark.png`) were actually viewed. Happy arcs remain aligned to the tilted two-eye spacing; faces remain round and friendly. No extra original pupil is visible underneath the happy replacement in the inspected unglazed faces.
- Native 1254 transparent happy compositions actually viewed: Astronaut, Student, Christmas, and final Pajamas. Glossy rounded happy-eye artwork is proportionate to their existing eye positions. Student's left arc sits lower within its lens because its eye slot follows the face tilt; neither arc visibly crosses a frame. Christmas arcs stay below the hat and above cheeks. Pajamas arcs remain clear above pillow and cheeks.
- Astronaut happy eyes stay within the face aperture beneath the transparent visor; visor reflection and helmet border remain above them. Student clear glasses stay above eyes. Summer smoked panes/frame stay above expression states and attenuate their contrast naturally; no eye is pasted in front of the optical layer.
- The compositor replaces each original eye slot with one chosen eye state before compositing higher-z glasses/visor. New happyLeft/happyRight derivatives are separate true artwork layers from one shared authored source; 28 fitted derivatives do not equal 28 newly generated original artworks.
- Numerical open-versus-happy PNG differences were checked across all 14 kits; all change bounds stayed in facial eye regions. In the four decoded GIF examples, body and accessories visibly stay fixed. This is scoped evidence for eye-only changes, not proof of every alpha/root or every native animation.

## Sizes and frames actually inspected

- Summer: 64pt ×1 dark board and 220pt ×1 light board.
- Student: 64pt ×3 light board.
- Astronaut: 64pt ×1 light board.
- Pajamas: 64pt ×3 dark board (prior arm registration), followed by final native happy render and final GIF samples.
- Four actual GIFs independently decoded, all six distinct frames per GIF examined in a temporary contact sheet (`/tmp/pio-expression-review-decoded.png`, not deliverable source art).

At 64pt ×1 Astronaut expressions are distinguishable but small; the tiny shapes do not warrant claims of detailed expression visibility. Student at ×3 clearly differentiates open, relaxed closed, happy and wink under its glasses. Summer remains the weakest contrast case.

## Decision

**PARTIAL** for expression-art candidates. **NOT_TESTED** here: all 14 GIFs frame-by-frame visual review, eight core actions, app integration, Mac/iPhone playback, performance, Reduce Motion, combined limb/eye poses, final source-root/clipping acceptance and user visual approval. The new expression set is meaningful progress toward the full catalog and does not close the remaining artwork/action/scene requirements.

## Final-selection follow-up — 2026-10-23

This update supersedes the earlier in-progress Rainy/Pajamas selection caveat above. Both canonical catalog registration paths now point to `registration-final-candidate-2026-10-23`; the rerendered `catalog-happy-light.png` was actually viewed again, along with the updated Pajamas 64pt ×1 dark board.

Rainy native `neutral-dark.png` and `before-after-light.png` were directly inspected. The newly authored **umbrella-shaft-v3-candidate.png** ends naturally behind the canopy/hood depth, removing the previous conspicuous capped tip while leaving a visible shaft section and lower J grip. The hand overlaps the grip; it is still a reconstructed mitten overlap, not articulated fingers. Reference face/body/boot proportions remain different, so this is a better review candidate rather than an exact restoration.

The shaft-v3 source exists and its SHA256 matches the final provenance manifest. `all-frames-motion-bounds.json` contains 48 sampled frames × 4 moving components = 192 rows, with maximum outside-any-alpha = 0 and outside-alpha≥16 = 0. The recorded method counts bounds from one padded raster and its exact1254 crop. This evidence supersedes the old selected shaft's one-alpha1-outlier limitation **for this sampled motion only**. The reviewer read the audit and verified its summary/selected source; did not independently rerun its raster calculations or test unbounded angles.

Pajamas now selects the **v5** broad oval mitten/shorter cuff candidate. The rerendered full-catalog overview and tiny dark board show the updated hands without the prior thumb lobe; native final happy art was already inspected above. The pillow remains visibly embraced. At64pt ×1 eye states are still readable as small distinct alternatives; this does not certify original proportions at all angles or full stretch/release animation.

Overall remains **PARTIAL, visual approval pending**. Final selections improve the two attachment issues and are used by offline catalog expression renders. They are not applied to or certified in the app; no new expensive tests/builds were run by this reviewer.
