Latest full-catalog continuation: [Basic + all 13 outfits](full-catalog-v1/README.md). The following report describes its earlier batch snapshot; latest Rainy and Pajamas selections resolve additional issues.

# Pio artwork-first review — 2026-10-16

Latest continuation: see `BATCH2-RESULTS.md` and `qa/batch2-file-verification.json` for the next eight outfit candidates. The counts and first-batch scope below describe the original Cherry/Summer delivery; they are not cumulative totals.

Status: **PARTIAL — first artwork review batch, not completion of all 13 premium rigs.**

This batch reconstructs genuine detailed raster components using the built-in image generator and the approved individual wardrobe PNGs as identity/design references. It does not replace approved originals, edit app code, alter purchases/data, or integrate candidates into the running application. No existing app tests or builds were rerun. No commits, pushes or deployment.

## Review these first

- `qa/cherry-motion/cherry-independent-offline-proof.gif`: body fixed; separate eyes switch and wings rotate, with one separately authored petal instanced for drift.
- `qa/summer-motion/summer-grip-offline-proof.gif`: body fixed; left sleeve/wing moves while the right hand and complete drink move together around the registered grip.
- `cherryBlossom-v2/registration/comparison-220pt-3x-dark.png`: approved original / prior candidate / revised candidate.
- `summerVacation-v1/registration/comparison-220pt-3x-dark.png`: original / candidate / independent attachment endpoints.
- Both registration folders also contain64pt and220pt, light/dark PNG comparisons and full-size transparent composites.

GIFs are **offline artwork motion proofs**, not native app recordings or performance/Reduce Motion verification. Continuous application motion and the eight-action experience overhaul remain separate work.

## Newly generated source files

**10 actual source PNGs, representing eight primary component roles, one rejected headwear iteration and one optional frame alternative.** These are native generated artwork, not enlarged sprite-sheet crops. Exact prompts, original generated paths and design references are in `generation-prompts.json` and `summerVacation-v1/frame-only-generation.json`.

| Set | Source candidates | Scope |
| --- | --- | --- |
| Cherry | Matching two-leaf sprout; one standalone sakura petal | Reuses existing genuine clean bodyv3, two wings, head flower, eye/lid and foot sources. Sprout registration replaces the provisional silhouette; petal is a separate effect asset. |
| Summer | Clean clothed body/face; left sleeve+wing; right sleeve+wing; full drink; headwear+sproutv2; sunglasses | New genuine layered candidate kit. Original approval does not automatically approve reconstructions. |
| Rejected/optional | Headwearv1 rejected; frame-only glasses optional | v1's large underside covered the face. Optional empty-aperture frame reveals independent eyes but loses approved sunglasses tint and is not used as the primary design. |

Registered derivatives share a1254×1254 top-left coordinate system. Their raw native source sizes vary and are recorded; exporting onto the common canvas is not claimed as new high-resolution source creation. Independent registered layer PNGs and transform/provenance manifests are in each `registered-layers/` folder. Original source pixels remain unchanged; no alpha cleanup, repainting or masks were applied to force a fit.

## Artwork validation and remaining limitations

- **PASS, scoped:** genuine alpha inspected on light/dark; complete source roots; body-fixed independent attachment samples; source hashes recorded. New sprout has no broad composited haze. Corrected Summer headwear fits the face after a measured rigid registration adjustment. Cup upper glass is genuinely translucent.
- **PARTIAL:** reconstructed cape/shirt motifs, exact eye/foot/flower shapes and some silhouettes differ from originals. User visual approval is pending. Endpoint samples do not certify every possible joint angle.
- **PARTIAL:** Summer's primary lens centers have alpha252–253, so visible eye blinking through those lenses is unsupported. The optional clear-frame source proves separate eyes can render, but is an unapproved design alternative; a matching translucent lens layer is still needed to preserve dark-tinted sunglasses and visible eye expressions together.
- **NOT_TESTED:** native Mac/iPhone playback of these new candidates, all eight actions, jump/landing, performance, Reduce Motion and global scene integration. No new scene artwork is claimed.

## Catalog status at the first delivery

The catalog is Basic plus13 premium outfits. Before this batch Basic, Christmas, Hanbok and Astronaut already had51 registered pilot parts. They retain their existing limited pilot status; this batch does not count them as newly created or recertify them.

Cherry and Summer have reviewable layered candidates outside the app. The subsequent eight-outfit reconstruction batch is documented separately in `BATCH2-RESULTS.md`; do not use this historical first-delivery paragraph as its status. Outfit-specific vacation day/night and cloud receiving/success/failure art remains missing (13×5 scene combinations). Standing characters are not substituted into the approved hammock or cloud scenes.

The latest brief requests **one visual Pio at every level**. No growth-stage variants were generated; XP, levels and previous artwork remain intact.

Further technical/visual details: `qa/SUMMER-AND-CHERRY-REVIEW.md`, each registration's `ART-REVIEW.md`, `registration-candidate.json`, `png-verification.json`, and the motion proof JSON files.
