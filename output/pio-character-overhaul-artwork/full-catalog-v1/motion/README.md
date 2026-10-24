# All 14 outfits — offline action studies

**Status: PARTIAL. Artwork motion candidates only; no app integration or runtime certification.**

Each outfit folder contains eight transparent 400×400 keypose PNGs, one `eight-actions-contact.png`, one labeled `eight-actions-offline.gif`, decoded GIF samples and `motion-manifest.json`. The genuine 1254×1254 canonical layers are downscaled once to 300px and padded into the 400px canvas at (50,70) before any part rotation. Whole-body transforms also stay on the padded canvas. This avoids cropping moving parts to the earlier 300px character bounds. The native component files are unchanged. `motion-summary.json` verifies all 14 canonical registration/layer hashes after rendering, 112 keypose PNGs and 14 decoded GIFs.

The eight sequences use different trajectories and timings, built from the existing artwork:

| Action | Time | Motion |
|---|---:|---|
| Idle | 2.16s | Subtle whole-body breathing scale, separate blink |
| Bounce | 0.84s | Two low hops with small compressions |
| Jump | 1.26s | Crouch, one 48px high lift, landing squash and settle |
| Celebrate | 1.76s | Happy eyes, wing oscillation and horizontal wiggle; no jump |
| Greet | 1.60s | Three free-hand waves with body tilt held |
| Sleepy | 2.60s | Closed eyes, slow downward lean, pause and recovery |
| Surprised | 0.84s | Quick backward horizontal recoil, pause and recovery |
| Encourage | 2.16s | Slow forward lean, wing hold and small nod |

These are artwork movement studies, not runtime animation. They are **not** eight newly painted poses per outfit. The surprise sequence uses the existing open face with a small recoil, because bespoke surprised mouth/eyebrow artwork does not exist. No claim is made for that missing expression. Full turns, walking cycles, cloth deformation, finger gripping and released-hand poses remain unsupported by this package.

## Attachment rules

- Christmas gift and both hands share one pivot and ±2°; no released-hand wave.
- Pajamas hands and pillow share one pivot and ±2°; no hand release.
- Rainy canopy, shaft and holding hand share one pivot and 0 to −4°; only the free hand waves.
- Fitness each dumbbell and hand share the same pivot and max ±4°.
- Cafe, Student, Summer, Halloween and Autumn hand-held props follow their corresponding hand pivot, capped at ±4°. Greet uses the free hand.
- Hats, clothing, sprout and helmet remain aligned with the torso. Genuine separate wing parts move at their own pivots; this is not claimed from whole-body movement alone.

All blink/happy/sleepy changes use genuine separately authored eye/lid images. Whole-body float, lift and lean are explicitly whole-body movement. The registered neutral transforms are already baked and are never applied twice.

## Review evidence

Inspected the actual eight-action contact renders for all 14 outfits, plus decoded GIF samples for Basic, Rainy, Pajamas and Fitness and one decoded greet frame across all 14 (`all14-decoded-greet-samples.png`). The visible attachment behavior is coherent within these small motion ranges. Every sampled RGBA frame also has a numeric outer-border alpha check, recorded per outfit; this detects output-boundary contact, not a strict source-bound or all-alpha clipping certification. Held-item costumes deliberately have more restrained gestures. Open-face comparison and pose differences remain from the existing candidate reconstruction; this pass does not certify original-art fidelity.

GIF indexed color creates visible quantization on beaks/eyes/feet. The full-color PNG keyposes are the material-quality reference. GIF encoding merges identical frames: each study was sampled at 158 frames with action-specific sample durations, while actual decoded counts merge identical hold frames and are recorded per outfit. Every sequence is timed separately in its manifest, total 13.22 seconds. Sequence labels and timing are retained.

Mac/iPhone rendering, Reduce Motion, CPU, memory and runtime animation correctness are **NOT_TESTED**. No application files, production assets or user data were modified. No builds, app tests, commits, pushes or deployments were performed.

## Reproduce

Run the bundled-runtime Python with Pillow against `scripts/render.py` (optional outfit IDs to render a subset), then `scripts/summarize.py`. These scripts write only below this motion folder. The inputs must remain stable during rendering; a source-hash guard stops if another task updates canonical art mid-render.
