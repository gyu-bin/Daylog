# Full Pio catalog — artwork review candidates

Basic + all 13 premium outfit versions are included. **PARTIAL: artwork candidates awaiting visual approval; these revisions are not application integration.**

## New work in this continuation

- One genuinely generated smiling closed-eye source, shared across all outfits without redesigning their bodies/clothes.
- 28 registered happy-eye derivatives, two per outfit. Uniform fitting to the existing open-eye location; generated source pixels remain unchanged.
- All 14 rigs exported onto the same1254×1254 transparent coordinate system. Existing neutral transforms are baked once; declared whole-source mirroring (Pajamas left arm) is retained. Existing application pilot parts and newly reconstructed candidate parts retain different approval status.
- Four expression composites per outfit: open, sleepy closed, happy closed, wink. Eye alternatives replace each original eye slot before glasses/visor are composited.
- 64pt and220pt, actual1× and3×, light/dark comparison PNGs for every outfit.
- A body-fixed independent-expression GIF per outfit. The original character PNG is not rotated to simulate independent eyes.
- Pajamas' latest broad oval-palm/compact-cuff candidate is selected for review. Summer uses the optional genuine translucent v2 lens alternative, not the primary opaque sunglasses.

## Start here

- [All14 happy/light](catalog-happy-light.png)
- [All14 open/dark](catalog-open-dark.png)
- [Approved original / current candidate](before-after/all14-before-after-light.png)
- [Full catalog source/registration manifest](catalog-manifest.json)
- [Verification and limitations](RESULTS.md)
- [Independent artwork gaps audit](../qa/full-catalog-2026-10-23/CATALOG-ARTWORK-GAPS.md)

Each outfit folder contains `registration.json`, normalized transparent `layers/`, native1254 expression composites, eight size/theme comparison boards and `independent-expression-offline.gif`. `happyLeft` and `happyRight` are additional mutually exclusive eye alternatives, not permanently visible parts.

| Version | Body-fixed expression preview |
|---|---|
| Basic | [GIF](basic/independent-expression-offline.gif) |
| Cherry Blossom | [GIF](cherryBlossom/independent-expression-offline.gif) |
| Summer | [GIF](summerVacation/independent-expression-offline.gif) |
| Autumn | [GIF](autumn/independent-expression-offline.gif) |
| Winter | [GIF](winter/independent-expression-offline.gif) |
| Halloween | [GIF](halloween/independent-expression-offline.gif) |
| Christmas | [GIF](christmas/independent-expression-offline.gif) |
| Hanbok | [GIF](hanbok/independent-expression-offline.gif) |
| Astronaut | [GIF](astronaut/independent-expression-offline.gif) |
| Rainy Day | [GIF](rainyDay/independent-expression-offline.gif) |
| Cafe | [GIF](cafe/independent-expression-offline.gif) |
| Student | [GIF](student/independent-expression-offline.gif) |
| Fitness | [GIF](fitness/independent-expression-offline.gif) |
| Pajamas | [GIF](pajamas/independent-expression-offline.gif) |

## Limits

Open Pajamas is an optional review state; the approved sleepy default is not replaced. Mouths remain baked into bodies; no independently animated mouth, yawn or surprised mouth is claimed. Fabric deformations, prop releases, full turns/rear views and scene-specific outfits still need suitable artwork. Summer's lens appearance and several reconstructed costume proportions differ from approved flattened originals.

No four-stage costume variants are created: the latest brief uses one visual appearance at every level. Outfit-specific vacation/cloud scenes are not provided by these standing rigs. The previous audit's65 combinations describe missing scene coverage, not65 necessarily unique future source paintings.

Offline motion studies, if provided under `motion/`, are artwork proposals, not native app playback, performance or Reduce Motion results. App tests/builds, production data, purchases, installed apps, commits and pushes are outside this artwork continuation.

## Generation provenance

Built-in `image_gen` was used. All three new native sources and exact prompts are indexed in [generation-index.json](generation-index.json). Exact prompt and original native path for the new shared eye are in [generation.json](../shared-expression-v1/source/generation.json). The source is a full native transparent raster component, not an enlarged sprite-sheet crop. The offline renderer is `scripts/render-catalog.py`; it does not modify source images or app files.
