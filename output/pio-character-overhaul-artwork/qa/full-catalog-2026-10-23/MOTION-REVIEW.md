# Independent offline motion review — 2026-10-23

**PARTIAL — 14 outfits have eight labeled offline movement studies. This is not certification of eight complete native animations or an app integration.** Reviewer wrote only this report and temporary decoded GIF contact sheets under `/tmp`. No artwork, scripts or app files were changed. No app tests/builds/performance measurements were run.

## Evidence actually inspected

- Read final `full-catalog-v1/motion/README.md`, `motion-summary.json`, and Basic/Christmas/Rainy/Pajamas `motion-manifest.json` files.
- Viewed actual full-color `eight-actions-contact.png` boards for Basic, Christmas, Rainy Day and Pajamas.
- Independently decoded the actual final Christmas and Rainy `eight-actions-offline.gif` files. Both decode to122 frames, total13220ms. For **each of eight sequences**, viewed decoded frames at20%,50%,80% of its actual time interval (24 samples per costume), rather than assuming GIF frame index equals original unmerged sample index. Temporary contact sheets: `/tmp/pio-motion-christmas-decoded.png` and `/tmp/pio-motion-rainyDay-decoded.png`.
- Cross-checked the motion equations and grouping in `motion/scripts/render.py` to interpret these samples. This supplements actual render inspection and does not substitute for it.

## Findings

1. **The action studies do use distinct motion, rather than the same vertical bob with different labels.** Jump has a visibly much higher lift and landing sequence than Bounce; Celebrate changes to happy eyes with a lateral wiggle and no large jump; Sleepy closes eyes and holds a lowered lean; Greet retains a cheerful lean with wing/group motion; Surprised uses a quick horizontal recoil while keeping the existing open face; Encourage leans/nods slowly. Manifest intervals differ: Idle2.16s, Bounce0.84s, Jump1.26s, Celebrate1.76s, Greet1.60s, Sleepy2.60s, Surprised0.84s, Encourage2.16s. Keyposes alone do not express timing, but decoded samples support the distinct lift/lean/eye behavior.
2. **Held-prop versions deliberately have weaker, constrained gestures.** Christmas gift and both hands stay together in the decoded samples; its Greet is a gift-held cheerful gesture, not a free-hand greeting wave. Likewise Pajamas Greet/Encourage hold the pillow instead of releasing a hand. These are valid constrained movement candidates, not completion of the unrestricted wing-waving/wing-opening requirement. New released/supporting hand artwork would be needed for that stronger action. At rest and in contact boards the new Pajamas hands face the pillow coherently; no reversed palm is apparent.
3. **Rainy grip remains coherent in inspected samples.** Canopy, shaft/J and holding hand keep their relative placement while the free hand moves. The cap remains hidden at the reviewed positions. No detached J, lost canopy connection or body/hand seam is obvious at the displayed scale. A sampled grip-preserving rotation is not a complete umbrella twirl.
4. **No obvious output clipping in the viewed boards/samples.** The large jump, raised costume parts and umbrella remain comfortably within the output canvas. Summary records14×158=2212 sampled border checks, maximum outer-border alpha0. This detects output-edge contact; it does not prove every original source alpha pixel was retained through every internal resampling/transform. The pipeline documentation correctly limits that claim.
5. **GIF material quality is lower than PNG quality.** Palette quantization is conspicuous around small eye/beak/foot colors in decoded GIFs. Full-color PNG keyposes preserve the better material reference. These diagnostic GIFs should not be used as finished in-app textures or proof that source material quality was degraded.
6. **Emotion breadth remains incomplete.** Surprised has no newly authored surprised eyebrow/mouth; it uses the old open smile and recoil, as documented. Sleepy does not add yawn mouth or independent head articulation. Baked cloth, hat/sprout groupings, finger grips, true turns, walking cycle and costume-specific special actions are not established by these eight studies.

## Scope decision

The reviewed evidence supports **PARTIAL offline motion progress**: distinct trajectories/timing, genuine eye substitution, genuine bounded wing/group movement and coherent held props in the inspected subset. The README appropriately separates whole-body transformations from independent-part animation and preserves constraint notes.

**NOT_TESTED by this reviewer:** every frame of all14 GIFs visually, native Mac/iPhone playback, runtime motion implementation, CPU/memory, Reduce Motion, exact original-art fidelity, arbitrary joint ranges, all-alpha clipping equivalence, 64/220pt playback readability and five scene states per premium outfit. The four contact boards and two sampled GIFs do not justify blanket visual approval of all14 fully animated costumes.

Inputs are reported unchanged by the source-hash guards and summary; this reviewer did not rerun the expensive renderer. No commit, push, production data change or deployment is part of this review.
