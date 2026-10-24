# Pajamas — oval palm refinement candidate, 2026-10-23

**Gate: PARTIAL — improved candidate, awaiting visual approval.** Offline artwork proof only. This folder does not replace the original artwork or alter the application.

## Change and provenance

One controlled built-in ImageGen edit produced `../source/wing-oval-compact-candidate-v5.png` at its native 1402×1122 resolution. It is a genuine detached painted arm with transparent alpha, broad smooth oval palm, compact fleece cuff and closed shoulder root. Exact prompt, native generation path and reuse policy are saved in `generation-prompts.json`. The one native module is reused with a whole-image horizontal mirror for the left hand. This is explicitly one new source, not two independently authored arms.

Existing clean body, hat/sprout, pillow, feet, eyes and lids are reused unchanged. Registration uses whole-source uniform downscaling, rigid positioning and left-hand mirroring only. No sheet crops, masking, alpha cleanup, source repainting or upscaling were used. All source SHA256 values match after rendering (`artifact-audit.json`). The 13 PNGs under `exports/` are registered derivatives on one 1254×1254 coordinate canvas, not 13 new source artworks.

## Actual visual inspection

- Inspected native neutral dark PNG, four 64pt/220pt @3x light/dark comparison boards, both native ±3° hug endpoints and four decoded frames from the written GIF.
- Smooth broad palms improve the visible pillow-holding silhouette. The previous left thumb lobe is gone. The right arm projects less and has a shorter cuff. Soft fleece/star material remains consistent with the existing kit.
- At 64pt the palms and pillow remain readable. At 220pt/native size the candidate still differs from approved art: the left hand is broader and faces more directly forward; the right cuff remains more exposed than the original. Existing shared thin closed lids, hat/pillow outlines and coat shading also differ from the approved original. No exact original-fidelity or final quality PASS is claimed.
- The two hands and pillow move together as a hug group about pivot (820,900), through ±3°. Body, face, hat and feet stay fixed. This proves the held group moves separately from the body; it does not demonstrate independent sleeve deformation or fingers gripping.
- Native PNG endpoints show attached roots and no obvious exposed gap in the inspected ±3° range. No claim is made for broader arm rotation or walking/jumping.

## Verification and limitations

`artifact-audit.json` records successful PNG decoding, 13 registered layers, unchanged source hashes, and 32 decoded 440×440 GIF frames. GIF indexed-color quantization introduces visible color artifacts in beak/feet; use PNGs for material judgement. `sleepy-hug-offline.gif` is an offline motion diagnostic, not an app recording.

Mac/iPhone rendering, eight runtime actions, Reduce Motion, CPU and memory are **NOT_TESTED**. No app builds/tests, commits, pushes or deployments were performed for this artwork pass. The new candidate remains outside application asset catalogs.
