# Native visual checkpoints — candidate-only

## 1. Basic eyes v1, Mac sampler corrected: PASS within reviewed scope

Evidence folder: `docs/qa/pio-independent-2026-10-24/native/mac-eyes-v1-samplerfixed/`.

Opened actual 220pt light neutral/open/closed/failure, 220pt dark open/closed, 64pt light open/failure and 64pt dark closed. Eye material and upper-right glossy highlights match original Basic seated identity; original hand/tablet/feet pose remains intact. The closed lids are delicate at the registered eye size, with no obvious pasted fur-patch seam in those images. Worried brows remain soft and readable. Open/closed state change is visibly real, not whole-body rotation. No anatomical redesign or oversize eyes was observed in this reviewed set.

This is a pilot component appearance gate, not final human visual approval, all14 outfits or Stage1–4 appearance completion. Half-pair artwork was generated separately but intentionally not registered. After this gate, the root owner copied the five unchanged V1 textures into new `PioCloudProduction.xcassets` and added a Release-capable Basic-eye path. Final Release/native verification is reported by the main integration QA owner. The hands-V2 candidates remain explicit DEBUG opt-ins.

Additional iOS checkpoint: opened the actual UIKit 220pt light open/closed and 64pt dark open/closed frames identified by `native/ios-eyes-v1-attachments/manifest.json`. The eyes and face are visually coherent and match the Mac material, without obvious pasted-lid seams or clipping. Scoped iOS V1 component appearance PASS; this does not prove Release whole-screen integration.

Historical `mac-eyes-v1/` failed to display sampled eyes because Mac CALayer texture coordinates use the opposite Y origin from source metadata. Opacity assertions alone initially passed. Corrected native pixels, not those historical passes, support the scoped result above. Failure logs/images must remain available.

## 2. Basic hands v2, initial sampler-corrected capture: FAIL — held group invisible

In the first corrected V2 native 220pt neutral and both ±1.5° hold frames, the clean torso and eyes were visible but both arms/tablet were hidden; only a small green strip appeared beneath the body. Therefore no shoulder/hand/prop quality approval was possible. The likely cause was root insertion order: the held group was inserted before the opaque torso and `render(in:)` painted by traversal order despite zPosition. The integration owner is applying stable back-to-front root ordering and stronger pixel assertions before new captures. Do not retune source art against invisible-group evidence.

Unresolved art check after that renderer repair: Basic feet are baked into the torso while the tablet should be behind toes. A genuine new transparent feet pair exists at `source/feetPair-v1.png`, but foreground layering/alignment must be tested before assuming it solves the contact region. Duplicated toe contours or pasted/extra toe shapes are grounds to reject. A rectangular torso sampler containing surrounding fur is not a valid foot matte.

## 3. Christmas hands v2: PARTIAL — source inspected, assembled native gate pending

The genuine new torso retains the existing hat/sprout/scarf/belt/feet design. The detached sleeves/cuffs/hands are larger in the generated atlas and explicitly registered into the existing hand pose, with no claim that generation preserved exact coordinates. Existing eight eye/lid/half/brow layers are reused unchanged. Tablet source is the new genuine green device, mapped to the original Christmas visible bbox [498,808,854,1050].

Exact sleeve bulk, shoulder seams, grip contact and ±1.5° motion remain unapproved until the repaired native group rendering is inspected. No extrapolation to the other eleven paid outfits is justified by this metadata alone.
