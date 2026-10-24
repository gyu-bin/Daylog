# Basic cloud layered candidates — native review in progress

This folder contains actual transparent artwork, not only a plan. Source copies are byte-identical PNGs from built-in imagegen or existing genuine brow donors. `register.py` only reads dimensions/alpha and writes metadata/copies; it does not segment, repaint, crop, resize or re-encode images. Runtime CALayer `contentsRect` samples transparent pair atlases independently.

## Delivered source art

| Source | Role | Genuine independent content |
|---|---|---|
| source/body-v1.png | Eyes removed from original seated pose | Clean fur under the two removed eyes; tablet/arms remain baked |
| source/openPair-v1.png | Original-style open eyes | Two glossy eyes, real alpha, registered into original eye slots |
| source/closedPair-v1.png | New fully closed eyelids | Two new isolated lids; not opacity-squashed open eyes |
| source/halfPair-v1.png | New half-open eye candidate | Actual fur lid and lower eye globe; source-only until next native review |
| source/browLeft-v1.png / browRight-v1.png | Genuine existing donor brows | Opposing worried brows, used only for failure expression |
| source/torso-v1.png | New restored torso | Body/face/sprout/feet without eyes/arms/tablet; hidden torso is actually reconstructed |
| source/tablet-v1.png | New complete prop | Full green tablet, including formerly hand-occluded edges |
| source/armPair-v1.png | New independent arms | Two inward-curved arms with complete root ends, mapped into original pose |
| source/feetPair-v1.png | New foreground feet | Genuine original-style seated toe pair; newly registered in front of tablet for V2 candidate review |

All are 1254×1254 RGBA. Pair atlases are not falsely described as one-part-per-PNG files. Runtime layers select one eye or arm using a measured sampler rectangle. No claim that the generator exactly honored requested part location: it did not, so the source geometry and target registration are explicit.

## Registrations

- `registration-v1.json` → new `pio_cloud_basic_v1_registration.dataset`: clean-face plus open/closed eyes and failure brows. Existing original seated arm/tablet pose retained.
- `registration-v2.json` → new `pio_cloud_basic_v2_registration.dataset`: genuine restored torso, separate tablet and separate arms. The three held components share a finite-range ±1.5° group at (650,1000); torso, eyes and foreground feet do not inherit that group motion. Newly generated feet are outside the group at z20/21 so they can correctly overlap the tablet. This does **not** claim a free hand release or wave while holding the tablet. Pre-foot registration is retained in `registration-v2-before-feet.json`.
- `provenance.json` records generated source paths, app catalog copy paths, SHA-256, alpha bounds, dimensions and approval=false. New half pair initially stays source-only and is not counted as an integrated eye state.

Candidate catalog names use the `pio_cloud_basic_v1_` prefix. Existing 761 protected sources are not overwritten. The runtime integration owner keeps hands V2 behind explicit DEBUG opt-in. After the corrected Mac eye-appearance gate, the root owner separately copied the five unchanged eyes-V1 PNGs into new `PioCloudProduction.xcassets` names `pio_cloud_basic_prod_v1_*` and added a Release-capable Basic eye registration. That production path contains no new V2 arm/torso/tablet/feet assets. Its final Release build/runtime status belongs to the main QA report, not this source-only registration script.

## Quality gate and known limitations

Candidate approval is pending actual 64pt/220pt light/dark, neutral/open/closed/failure, hold-group extremes and live presentation frames on Mac and iPhone. Initial Mac run proved opacity changed but invisible eyes exposed a runtime sampler-origin mismatch (Mac bottom-left versus source top-left). The runtime owner is correcting that and adding pixel assertions. The first log/captures remain historical failure evidence; they are not art approval and must not be silently substituted for the corrected run.

Generated alpha has small near-transparent noise outside the visible silhouette; at alpha≥16, the new clean face bbox differs from the original by only about 1–3px. Exact PNG bytes are retained; whether the tiny edge drift is acceptable must be decided from the actual assembled character, not only that bbox number. V2 shoulder placement and cuff/body seams remain provisional until neutral and ±1.5° renders pass.

Source art has been reconstructed, but it is not an automatic recovery of original hidden pixels. Native visual evidence determines whether each candidate can be promoted. Full 14-outfit animation, free wing release, vacation independent layers, exact two-rope locking and four distinct growth-stage appearances are outside this Basic pilot's completion claim.

Generation: built-in `image_gen`; [exact worker prompts and root normalized prompt log](PROMPTS.md). No CLI/API fallback and no raster-generation substitute.
