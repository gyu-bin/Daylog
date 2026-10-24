# Cherry Blossom layered registration preview

Status: **PARTIAL — candidate artwork and static registration only. Not approved for app integration.**

This QA compositor uses the actual `body-v3-candidate.png`, the two newly generated wing candidates, and `head-flower-candidate.png`. The original approved character and all source PNGs remain unchanged. It reuses genuine high-resolution Base pilot source artwork for eyes, eyelids, feet, and the provisional sprout. It does not use low-resolution sheet crops, paint over seams, stretch parts, or enlarge source artwork. All source transforms and SHA-256 hashes are recorded in `registration-preview/registration-candidate.json`.

The script `render-registration-preview.swift` is a standalone QA compositor. It does not install assets, change app manifests, or exercise the runtime renderer. The transparent neutral and posed composites are preview artifacts; they are not additional newly authored source components.

## Actual outputs

- `registration-preview/neutral-alpha.png`: complete candidate neutral composite, transparent, 1254×1254.
- `registration-preview/neutral-light.png` and `neutral-dark.png`: full-size candidate views.
- `registration-preview/comparison-64pt-3x-light.png` and `comparison-64pt-3x-dark.png`.
- `registration-preview/comparison-220pt-3x-light.png` and `comparison-220pt-3x-dark.png`.
- `registration-preview/half-*`, `closed-*`, `wings-minus12-*`, and `wings-plus12-*`: static expression/attachment endpoint previews.

The comparison boards show approved original, candidate neutral, half eyes, closed eyes, wings −12°, and wings +12°, all using the same 1254-square framing. The point labels describe the square canvas display size; they do not independently normalize each part or character to its alpha bounds.

## Inspected observations

The 64pt and 220pt comparison boards in both light and dark, full neutral light/dark views, full wing ±12° dark views, and full half/closed-eye dark views were visually inspected. The face remains expressive, and the fur, wing and cape material are coherent in those samples. Both wings sit behind the clean body and baked cape. At the inspected endpoints, the shoulder roots remain hidden, no cheek-mounted attachment is visible, and no background hole or rectangular repair patch appears at the shoulder. This is evidence for those static samples only.

The shared sprout's initial registration clipped the canvas top; this was corrected by reducing its uniform scale. The current sprout remains a provisional identity mismatch: its aspect and leaf direction differ from the approved Cherry Blossom reference. Two new matching sprout generations were rejected because of a visible green halo outside the leaves. Further generation was stopped; this preview retains the genuine shared sprout and its explicit identity limitation. No final artwork PASS is assigned.

The right foot uses a local −25° candidate rotation to better retain the original playful raised-foot posture. Feet and wings remain independently textured components, but this static compositor does not establish natural continuous walking, jumping, landing or flapping.

## Remaining limitations and required gate

- The regenerated body is a reconstruction, not a pixel-identical restoration. The formerly covered left cape region includes reconstructed floral detail. Costume fidelity requires final visual approval.
- The provisional shared sprout must be replaced or explicitly accepted after comparison with the original. Neither rejected sprout generation is used in any current composite.
- Eye highlights, exact foot perspective and flower petal shape differ from the approved flattened illustration. Material and fit are candidate-quality judgments, not automatic approval inherited from the older pilots.
- The baked cape occludes more of the left wing than the original front-wing pose. This preserves a natural rear shoulder but changes the neutral silhouette slightly. If a front sleeve/cape occluder is needed later, it must be genuine separate artwork.
- The cape, central bow and chest flower remain baked into the body. Independent fabric, bow or chest-flower animation is unsupported.
- Static closed/half eye textures are mutually selected in the preview, but native blink timing has not been tested for this outfit. The half-eye texture is only a brief transitional blink pose; holding it reads as sleepy and is not an approved default expression.
- Continuous root coverage, jump/landing, native Mac/iPhone rendering, Reduce Motion and performance are **NOT_TESTED** for the new Cherry Blossom set.
- Distinct Stage 1–4 appearance and mounts remain incomplete. This single-body candidate does not establish growth-stage compatibility.

No app code, approved source asset, xcassets catalog, production data or purchase configuration is changed by these preview files. No app build or existing test suite was rerun.
