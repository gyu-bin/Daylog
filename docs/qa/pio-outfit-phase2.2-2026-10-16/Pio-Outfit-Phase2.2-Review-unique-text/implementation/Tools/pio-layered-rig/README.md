# Layered green Pio — offline artwork registration

This utility performs native ImageIO/CoreGraphics registration and pose compositing. It is not app code and does not grant animation capabilities or approve artwork. All image_gen originals and existing catalog resources remain untouched.

Run from the repository root:

```sh
swift -module-cache-path /tmp/pio-layered-module-cache Tools/pio-layered-rig/assemble-base.swift "$PWD" "$PWD/docs/qa/pio-outfit-phase2.2-2026-10-16/registered/candidate-a"
```

Use a fresh output directory for a revised registration. The current provisional placement table is in `assemble-base.swift`; the exact numeric transforms are emitted to the output `registration.json` and QA `base-registration.json`. `--audit-only` measures sources without registering/compositing them.

- Canonical canvas: **1254×1254**, top-left coordinates. The generated clean body is natively1254²; no1536-resolution claim or source upscaling. The earlier planning recommendation of1536 is superseded by this measured export choice.
- Reference placement: original1319×1192 at uniform0.9 scale + (33,90). Each independently generated part gets its own explicit uniform scale/translation, then a full1254 transparent export. Alpha>=16 bounds guide placement but do not crop or threshold the source pixels. Their low-alpha outliers are retained wherever within the master viewport.
- Pixel work: native resampling/compositing only. No repainting, synthesized body geometry, alpha cleanup, color filtering, local warp, or mirrored lighting. The same generated eye/foot texture is instantiated twice with separate registration/pivots as authorized.
- Pose transforms are recorded in `poses.json`: positive rotation is clockwise in top-left image coordinates. CG converts its y-up rotation once. Every pose holds the body and sprout fixed; only the named wing or foot is transformed. Blink selects generated eyelids while removing open eyes, over a reconstructed clean face.
- Open/closed endpoints and ±12° wing/foot-step poses are **static registered pose evidence**, not an app animation recording, interpolated walking-cycle proof, or approval of larger wave angles.
- Source dimensions/hash/alpha/bounds: `alpha-audit.json`. Transparent RGB can look like glow in raw viewers; assess composited light/dark PNGs.
- Outputs: native1254 full composites, separate registered layers,64/220pt comparisons at1×/3×, and600px local joint crops. Full composites retain the whole master viewport; closeups are intentionally cropped inspection windows.

Candidate-a inspection notes: no visible green glow after normal alpha compositing; closed lids read as thin curves at64/220 despite the bulky standalone source. The generated sprout is narrower with a longer exposed stem than the reference. The generated left wing is partly occluded by torso. One shared front-facing foot creates a different right-foot perspective from the oblique original. Root overlap remains covered at the supplied±12° wing and lifted-foot endpoints. Independent review accepted candidate-a for the limited single-pose pilot. The later base-walk-ground right-foot plant (+35 master pixels) and lifted pose (+17 / +8°) were accepted as static endpoints only; this does not certify the continuous native cycle.

## Christmas pilot

```sh
swift -module-cache-path /tmp/pio-layered-module-cache Tools/pio-layered-rig/assemble-christmas.swift "$PWD" "$PWD/docs/qa/pio-outfit-phase2.2-2026-10-16/registered/christmas-g" --hands-v2 --headwear-v2
```

The accepted `christmas-f` registration uses the native1254 Christmas reference directly, independently generated clean clothed body/gift, genuine short hand/cuff v2 textures, and genuine combined headwear v2. Eyes/lids/feet are reused at custom measured registrations. All component scales remain below1. Headwear contains the sprout naturally embedded: **Christmas has no independent sprout/pom layer or motion claim**. The body remains unchanged in every local-motion proof.

The left hand and gift use identical translations for grip-up/down; right-hand ±12 poses keep that left grip and gift fixed. These are contact-pose endpoints, not a runtime physical constraint engine. Individual64/220pt1×/3× light/dark renders cover all ten poses, alongside fullnative1254 images and joint closeups. `registration.json` and `poses.json` reproduce exact source/version/transform/ordering. All originals remain unchanged.

Christmas-f corrects the rejected e right arm with source root(1000,600), uniform scale0.26, offset(790,634), world pivot(1050,790), and neutral−60°; local right-wing angles add to that neutral angle. Runtime catalog input is exactly f, with lossless zero-alpha-padding packing verified pixel for pixel.

Christmas-g retains f component registration and adds shared left-grip±6° around(513,870), applied identically to gift+left hand, with opposite right-wing±12°. Independent art review accepted these additional static flap endpoints. The native pilot uses a shared leftGrip CALayer parent at that exact pivot; continuous motion remains a separate runtime gate.

Earlier Christmas a–e directories retain failed/exploratory registrations. V1 sleeves were rejected for protruding long red roots; their pixels were not masked away. Full sprout-behind-v1-hat in c hid the leaves and was rejected. Genuine headwear v2 replaces both flawed layers, with one white band and natural stem attachment. Do not use those earlier outputs as approval evidence or integration inputs.

## Half-eye and Hanbok follow-up

`register-half-eye.swift <repo> <registered-input> <new-output>` registers the genuine `base/eye-half-v1.png` by visible-globe width and lower edge, retaining the complete generated fur lid. `base-half-a` and `christmas-half-a` contain open/half/closed native and 64/220pt light/dark comparisons. Independent review accepted half as a brief intermediate expression. Native implementation must use discrete pose swaps, never opacity crossfades; this static review does not approve timing.

`assemble-hanbok.swift` preserves the original1254 reference and baked flower/tassel/bow/skirt, reuses independent eye/lid/foot/sprout, and registers independently generated sleeves. The v1 sleeves were rejected for extra rear forms; v2 a–d are registration explorations, not runtime approval. `--wings-behind-body` tests real depth ordering without masks. In d, the right sleeve scale0.27/pivot(975,810)/neutral−20° is compact; the outward left sleeve works anatomically but differs from the reference down-front pose. The selected `hanbok-e` replaces the left sleeve with genuine v3: one compact puff cap and mitten, foreground registration(225,740,225,245), pivot(400,790), neutral0°. The right retains d’s accepted rear depth. Independent art review accepted all ten e endpoints at64/220 in both themes; `hanbok-half-a` adds the same brief half-eye state without changing any sleeve geometry. These are now packed in the DEBUG-only catalog; native continuous-motion verification remains separate.


## Runtime packing and three-state blink

`pack-runtime.swift <repo> <registered-input> <outfit> [--only-half]` removes only exact-zero-alpha outer padding and verifies decoded RGBA equality for every retained pixel. Original full registered layers stay in QA. The `--only-half` path retains all existing component PNG bytes and metadata while adding the two half-eye resources. The23 previously installed Basic/Christmas PNG hashes match the saved pre-blink3 baseline exactly; previous manifest snapshots remain in QA `runtime-manifests`.

Selected inputs are `base-half-a`, `christmas-half-a` (f geometry, with g shared-grip motion), and `hanbok-half-a` (e geometry). Revisions end `-pilot-v1-blink3`. The intended native blink uses six discrete opacity tracks: open → half → closed → half → open. Exactly one eye texture per side is opaque at each segment; half is0 in the neutral model. This avoids blending two eye paintings. No growth-stage capability is introduced.

## Astronaut registration in review

`assemble-astronaut.swift` uses genuine body/gloves/visor v1 and thin-rim helmet-shell v2. Candidate `astronaut-a` was rejected: v1’s lower plate crossed the mouth and covered suit details; long visible ankles and horizontal left arm also diverged. Candidate b uses the genuine v2 lower rim, lowers the visible left arm through whole-part rotation, and places feet35 master pixels deeper inside the existing cuffs. The visor retains its original RGBA alpha at opacity1. Helmet and visor remain a fixed assembly; no independent helmet twist over a fixed face is claimed. `astronaut-half-a` adds the intermediate eye state below visor and shell. Astronaut requires its own static gate before catalog integration.

Final selected Astronaut-c nests the unchanged-alpha visor inside the thin v2 shell and moves sleeve roots inward. Parent static gate is recorded in QA final-art-gate.md; astronaut-half-a is packed as14 genuine layers. Final code review independently checked all51 packed pilot parts. Native and performance evidence remains documented separately.
