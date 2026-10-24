# Pio outfit artwork candidates

Updated: 2026-10-16. These files are artwork candidates for review. Their presence does not certify a finished layered outfit or app integration.

## Existing inventory before this candidate run

`Daylog/PioLayeredTrial.xcassets` already contains 55 PNG files:

| Existing pilot | PNG files | Parts referenced by its rig manifest |
| --- | ---: | ---: |
| Basic | 13 | 12 |
| Christmas | 14 | 13 |
| Hanbok | 13 | 12 |
| Astronaut | 15 | 14 |
| Total | 55 | 51 |

The remaining four PNGs are reference images. These are preexisting Phase 2.2 assets, not assets newly created during the recent StoreKit implementation. The four current manifests use a 1254×1254 canvas, `stageArtID: pilot-neutral-only`, and `supportsGrowthStages: false`. These counts do not certify that every possible animation or growth stage is supported.

The wardrobe also preserves the approved flattened artwork for all 13 premium outfits. A flattened character PNG is not an independent animation layer set.

## New files in this candidate run

There are **8 newly generated source PNG files, representing 4 current component candidate roles and 4 rejected/superseded attempts**. Generated file count is not finished asset count.

| Source file under `cherryBlossom/v1/` | Current status |
| --- | --- |
| `body-v3-candidate.png` | Current clean body/cape candidate; used in the QA composite. |
| `wing-left-candidate.png` | Current standalone left-wing candidate with a complete generated root; used behind body/cape. |
| `wing-right-candidate.png` | Current standalone right-wing candidate with a complete generated root; used behind body/cape. |
| `head-flower-candidate.png` | Current standalone head-flower candidate; used in the QA composite. |
| `body-candidate.png` | Superseded: changed framing and clothing details. Not used. |
| `body-v2-rejected-wing-remains.png` | Rejected: retained a baked left wing. Not used. |
| `sprout-v1-rejected-halo.png` | Rejected: visible green halo outside the physical leaves. Not used. |
| `sprout-v2-rejected-halo.png` | Rejected: halo remained after a cleanup attempt. Not used. |

The candidate composite reuses existing genuine high-resolution source artwork for eyes, closed/half eyelids, feet and a provisional sprout. These reused components are not newly created assets. The shared sprout differs from the approved Cherry Blossom leaf silhouette; the new set remains **PARTIAL**. No finished outfit, final visual approval, runtime animation PASS, or app integration is claimed.

`cherryBlossom/v1/registration-preview/` contains **19 rendered QA PNGs**: 5 transparent composites, 10 full-size light/dark views and 4 comparison boards covering 64pt/220pt in light/dark. They are render previews, not 19 additional authored source components. `png-verification.json` records file existence, PNG header/dimensions, byte sizes and hashes. `PREVIEW-REVIEW.md` states the inspected scope and remaining limitations.

## Premium outfits without complete layered sets

The ten premium outfits below do not yet have complete layered sets in `PioLayeredTrial.xcassets`:

- Cherry Blossom (`cherryBlossom`) — four current component candidates plus reused pilot parts; complete approved set missing.
- Summer Vacation (`summerVacation`).
- Autumn (`autumn`).
- Winter (`winter`).
- Halloween (`halloween`).
- Cafe (`cafe`).
- Student (`student`).
- Fitness (`fitness`).
- Rainy Day (`rainyDay`).
- Pajamas (`pajamas`).

Each requires its own artwork inventory. Existing basic or pilot parts cannot be assumed to fit another costume without registration and visual review.

## Cherry Blossom completion requirements

Approved reference: `Daylog/PioWardrobe.xcassets/pio_outfit_cherryBlossom.imageset/pio_outfit_cherryBlossom.png`.

Preserve the fluffy cream body, glossy black eyes, pink cheeks, orange beak, green two-leaf sprout, pink head flower, floral pink cape with white trim, and front bow. Preserve the original neutral pose and cute proportions.

Required work includes a clean underlying face/body, rooted left and right cream wings, rooted feet, sprout/head-flower attachment, and matching open/half/closed eye artwork. The cape and front bow may initially remain part of the body; independent fabric or bow movement must remain unsupported until suitable separate artwork exists.

Use a single coordinate system for every component. The current runtime contract is 1254×1254. If a 1536×1536 master is introduced, document and apply one uniform registration transform across all parts; do not independently fit each component to its alpha bounds or reuse unscaled 1254 pivots.

## Gates before approval or app integration

1. Compare the neutral composite with the approved original: face identity, body proportions, costume details, apparent body size, and pose.
2. Inspect real transparency on light, dark, and checkerboard backgrounds, including edge contamination and soft fur detail.
3. Hide each moving component to verify a clean underlying surface and absence of painted duplicate eyes, wings, feet, or accessories.
4. Register complete hidden roots and measured pivots; inspect safe rotation endpoints and intermediate shoulder, sleeve, foot, and head attachments.
5. Inspect actual composites at 64pt and 220pt in light and dark, with blink, wing motion, jump, and landing.
6. Validate the independently moving parts in the native renderer. A whole-body transform does not prove independent animation.
7. Document stage-specific artwork and limitations. Reusing one appearance with four stage labels does not establish four distinct growth-stage designs.

Current new Cherry Blossom candidate: **artwork QA NOT_PASSED; registration NOT_PASSED; native animation NOT_TESTED; app integration NOT_DONE.**

This candidate documentation introduces no app code, purchase configuration, production data, or approved-art changes. No build or test results are asserted by this document.
