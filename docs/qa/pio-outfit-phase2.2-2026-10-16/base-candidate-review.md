# Basic candidate-a independent art review

2026-10-16. **ACCEPT for the limited Basic pilot, within the explicitly inspected static poses.** No current source needs rejection/regeneration for the apparent sprout glow or the originally suspected bulky eyelid. This is an offline art gate, not final runtime, continuous motion, full flap/walk/dash, or growth-stage approval.

## Evidence actually inspected

- All seven native candidate images individually, at original resolution, under `candidates/base/`.
- Native CoreGraphics source-over composites of all seven on ivory and forest, produced only as temporary diagnostic galleries. Source PNGs were not edited, recolored or cleaned.
- `registered/candidate-a/base-assembled-comparison-220pt-3x-light.png` and `base-assembled-comparison-220pt-1x-dark.png`.
- `base-assembled-comparison-64pt-3x-dark.png` and `base-assembled-comparison-64pt-1x-light.png`.
- Full `base-assembled-neutral-light.png`, `base-assembled-closed-dark.png` and face closeup `base-assembled-joint-closed-light.png`.
- Joint closeups for left +12 light, left −12 dark, right +12 light, right −12 dark, step-left dark and step-right light.
- Native alpha metadata in `registered/candidate-a/alpha-audit.json`; independent alpha-zero spot probes on the sprout's apparent outside glow.

The registered assembly uses a shared 1254 × 1254 candidate canvas. The native source dimensions differ and must stay accurately documented; none should be described as a 1536² original.

| Native candidate | Actual source pixels | Verdict for current pilot | Observation |
| --- | --- | --- | --- |
| `body-clean-v1.png` | 1254 × 1254 | ACCEPT | Genuine complete plush body without original eye/wing/foot imprints; beak and blush remain cohesive. Reassembled head/body is somewhat fuller/taller than the canonical reference, but retains the cute cream identity. |
| `wing-left-v1.png` | 1319 × 1192 | ACCEPT at inspected poses | Complete plush form and root material; body coverage is clean at neutral and both inspected ±12° endpoints. Less exposed than the original left wing, so neutral pose is not exact. |
| `wing-right-v1.png` | 1319 × 1192 | ACCEPT at inspected poses | Feather groups and material match the family; ±12° samples show genuine wing angle change with a covered root. No moving torso crescent or background wedge was seen. |
| `sprout-v1.png` | 1536 × 1024 | ACCEPT as source candidate | Clean genuine leaf/stem object. The broad green glow visible in the raw transparent viewer disappears in normal alpha composites. A narrower leaf span and longer visible stem remain as neutral differences, not a transparency defect. Sway extrema are not inspected here. |
| `eye-open-v1.png` | 1319 × 1192 | ACCEPT at registered size | Glossy dark-brown eye reads naturally on the clean face; no cream cutout rectangle or original-eye ghost was observed. One supplied eye reused twice is a registered derivative, not two separately authored eyes. |
| `eyelid-closed-v1.png` | 1319 × 1192 | ACCEPT at registered size | Isolated enlarged source is a thick cream/brown crescent, but at the actual eye scale it reads as a soft closed eye at 64/220pt. The face closeup shows a raised rim; it does not read as a mustache, patch or displaced brow in the inspected assembly. No reason to regenerate it solely from the enlarged standalone impression. |
| `foot-v1.png` | 1319 × 1192 | ACCEPT for limited step tests | Complete orange toes and generous upper root hide cleanly under the body in inspected step endpoints. Reusing the same frontal foot on the right changes the original oblique two-visible-toe pose; this is a documented neutral difference. It does not establish natural walking. |

## Sprout alpha finding

Normal ivory and forest composites show no broad green aura. Independent premultiplied-RGBA probes at several locations in the visually apparent outside glow returned `(0,0,0,0)`. The rig worker's native alpha audit places alpha≥16 and alpha≥128 bounds only about 1–2 pixels apart around the actual leaf/stem form (`[91,66,1381,896]` versus `[92,67,1379,894]`, x/y/width/height). These findings support transparent hidden RGB rather than a broad baked semiopaque matte. Do not modify the approved candidate to remove an artifact of the raw viewer.

## Neutral fidelity and cuteness

The assembled character remains cohesive and cute: cream plush body, asymmetric happy face, pink cheeks, orange beak/toes and green two-leaf sprout. The current candidate is a credible genuine reconstruction, not a geometry replacement or a complete PNG pretending to be a wing layer.

It is **not pixel-identical to the original**. The comparison reveals a somewhat fuller body, narrower sprout leaf spread and longer exposed stem, a less exposed left wing and a frontal right foot. The earlier contract's proposed ≤3-source-pixel neutral-landmark goal is not established and visible silhouette differences exceed that strict target. This review accepts those differences for a limited pilot, not as proof of exact canonical reconstruction. If exact pose fidelity is the product gate, refine the registration/parts before replacing the production Basic.

The narrower sprout and reduced left-wing exposure could be refined with modest whole-part registration changes first. Do not stretch the art or paint a repair to force a match. A closer original right-foot perspective may eventually need its own genuine part rather than mirroring the frontal foot.

## What is and is not approved

Approved by this review: the seven source candidates as materials for this pilot; the inspected neutral and closed-eye assembly; the sampled left/right wing ±12° endpoints; the sampled left/right foot-step endpoints; the listed 64/220pt light/dark comparisons. No visible joint gap, clipped sprout/foot, duplicated body edge, harsh matte or loss of face identity was found in those observations.

Not yet approved: half-lid transition, complete blink timing, intermediate-angle continuity, larger full flap poses, natural walking/running, dash, sprout sway, combined jump/landing with all parts active, 48/120pt full pose matrix, native iPhone/Mac motion or performance. A few clean endpoints do not certify every point on a continuous motion track. Render and inspect the actual required extremes before expanding the range; demonstrate differential part movement with body motion frozen, then demonstrate the combined animation.

No four-stage costume compatibility follows from this Basic pilot. The approved thirteen full costume designs remain unchanged. Christmas requires its own clean underlays, hand/gift contacts, registered components and independent gate.

Only this review document was written to the project by this review task. Source candidates, registered outputs, application files and other workers' documents were not modified.
