# Pio motion v2 — offline review

Status: **PARTIAL**. These are motion studies from genuine separated canonical parts, not app integration or newly approved artwork.

14 outfits × 11 sequences. Original 8 actions are retained: idle, bounce, jump, celebrate, greet, sleepy, surprised, encourage. Added front-view stepping, a frontal bow study, and an outfit-specific held-prop/gesture study.

[Open interactive local review](review.html). Four representative before/after MP4 files: [Basic](basic/before-after-eight-actions.mp4), [Christmas](christmas/before-after-eight-actions.mp4), [Hanbok](hanbok/before-after-eight-actions.mp4), [Astronaut](astronaut/before-after-eight-actions.mp4).

## Visible changes

| Action | Concrete movement |
|---|---|
| Idle | Gentle breath and independent eye closure |
| Greet | Free wing waves three times around its actual shoulder; 3–21° envelope with a 3° body tilt |
| Walk | Opposed feet, three steps, small body counter-sway and horizontal travel; front-view study only |
| Bounce | Two short 19 px hops with separate compression and recovery |
| Jump | 22% crouch to 12% squash, 48% airborne single 73 px arc, 16% landing squash, recovery |
| Celebrate | Happy separate eyes, ±9 px lateral sway, ±5° lean, small repeated hops and free-wing motion |
| Bow | Frontal lean and compression, closed eyes; no 3D bow claimed |
| Sleepy | Half-lids to authored closed eyes, slow 5° droop and 7 px settling |
| Surprised | Fast 10% backward recoil, hold until 50%, slower 50% recovery |
| Encourage | Both free wings held up with a small two-beat nod |
| Special | Gift lift, frontal hanbok bow, astronaut float, held cup/book/leaf/bag presentation, paired weight lift, umbrella shelter, pillow cuddle, etc. |

Numeric pixel values apply to the 480 px review canvas / 350 px canonical character canvas. Runtime integration should convert to a proportion of character size, rather than copy these pixel values directly.

## Honest limits

- Christmas and Pajamas hold their objects with both hands. They **cannot perform a free-handed wave** using these source parts. Greeting uses expression/body response; no gift or pillow release is invented.
- Hands and held objects share rigid transforms. Special lifts are 9–10 px complete hand/prop-group translations; no finger articulation, elbow flex, physically simulated cloth, or 3D turn is claimed.
- Free wings remain attached in the inspected pilot keyposes, but all-outfit rotational seam approval is still pending. Output alpha borders being clear does not prove every shoulder seam or hidden root.
- Upright wings remain upright as authored; a brand-new low-to-high arm arc would need additional anatomy artwork.
- Current green Pio source shape remains the same across levels. This does not certify four distinct growth-stage art designs.
- Summer source lens/expression visibility is the existing canonical candidate; these offline studies do not solve the separate small-size sunglasses art review.
- Native Mac/iPhone runtime, Reduce Motion, CPU, and memory are not tested by these files.

## File / quality evidence

Every outfit has 11 lossless animated PNGs, 11 transparent keypose PNGs, a contact sheet and a palette-limited GIF. APNG encoders coalesce identical adjacent frames while retaining duration. The verifier decodes actual files and counts the resulting frames; do not assume 32 encoded frames from 32 authored samples.

Four pilots also have matched-size, per-action time-normalized before/after comparisons, MP4s, and phase contacts. Comparing time-normalized action lengths highlights motion shape, not original playback speed. PNG/APNG is the full-color master; GIF is a convenience preview with unavoidable palette limits.

`artifact-verification.json` records real decoding and source hashes. Sources and application files were not edited by this offline pipeline.

## Delivery / runtime budget

The large offline review folder is not a runtime sprite atlas and must not be bundled into the app. Keep the source 1254×1254 canonical assets as masters, cache platform-sized decoded layers once per active character, animate native layer transforms rather than decoding APNG frames or issuing SwiftUI layout changes per frame. UI image mipmaps remain off. Native profiling is required before choosing the cache size or claiming a frame/CPU budget passes.
