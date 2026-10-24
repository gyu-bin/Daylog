# Phase 2.1 independent visual evidence review

Reviewed 2026-10-16. **No new visible defect was found in the inspected captures. Overall costume animation remains PARTIAL; this is not a full animation, stage-compatibility or release pass.**

## New actual native evidence inspected

| Evidence | Configuration visible in capture | Observation and scope |
| --- | --- | --- |
| `ios-astronaut-jump-contact.png` | Astronaut, jump, 220pt, dark background, selected stage 4; six video samples | The character occupies visibly different vertical positions across samples. Sprout, helmet, gloves and both feet stay complete, with clear surrounding panel space. The face remains legible; no root gap, detached glove, doubled contour or clipped tip is visible. This is whole-character jump motion only. |
| `ios-astronaut-220-dark-stage4.png` | Same iOS diagnostic configuration | Clean cream/lavender identity and visor highlight; complete silhouette and readable status/limitation text. The selected stage number is not a stage-specific costume appearance. |
| `ios-hanbok-64-light-stage2.png` | Hanbok, jump selected, 64pt, light, selected stage 2 | Face, sprout, pink skirt and navy ribbon identify the outfit at the configured small size. All visible extremities fit. Fine embroidery naturally simplifies. One still does not certify the jump cycle. |
| `mac-hanbok-64-dark-stage2.jpg` | Hanbok, 64pt, dark, selected stage 2 | Recognizable small pink silhouette, green sprout and cream face with ample panel clearance. No apparent clipping or dark matte artifact. One still only. |
| `ios-christmas-120-light-stage3.png` | Christmas, jump selected, 120pt, light, selected stage 3 | Hat, gift, hands, scarf and feet remain complete and coherently attached. White trim separates from the ivory background. One still only. |
| `mac-christmas-120-dark-stage3.jpg` | Christmas, 120pt, dark, selected stage 3 | Red/white outfit, green gift, face and sprout stay distinct. No visible clipping or prop separation. One still only. |
| `mac-christmas-220-light.jpg` | Christmas, 220pt, light, selected stage 1 | Larger view retains complete pompom, scarf fringe, gift and feet; no visible artifact. One still only. |

The native clip `ios-astronaut-220-dark-jump.mp4` exists at 1206 × 2622, with approximately 31.04 seconds container duration. This review visually inspects its supplied **six sampled frames**, not every decoded frame. The samples establish real position changes and framing at those instants. They do not establish continuous smoothness, frame rate, absence of frame drops, every extremum, or performance. Container timing metadata is not a measured animation FPS result.

The new captures are actual DEBUG diagnostic-screen output, distinct from the earlier real shop-sheet captures. They verify the displayed native renderer at the shown configurations. They do not independently revalidate every production shop layout or every device/size/theme/outfit/motion combination.

## Prior evidence reused, with preservation checked

- `../pio-outfit-phase2-2026-10-16/artwork-size-QA.md`: original full-canvas costume artwork at 48/64/120/220pt on ivory and forest. All 13 original PNG SHA-256 values were independently recalculated during this review and still match `artwork-size-manifest.json` exactly. Its static size/identity/alpha findings therefore remain applicable to the unchanged assets. This is retained offline static evidence, not fresh live coverage of all combinations.
- `../pio-outfit-phase2-2026-10-16/visual-runtime-QA.md`: actual Phase 2 Mac previews for all 13 costumes and 120 iPhone samples across Basic, Halloween, Christmas, Hanbok and Astronaut. Those are prior runtime observations with their original sampling limits.
- The saved `before-PioOutfitMotion.swift` was compared to the current renderer. The inspected diff adds passive counters, a weak active-rig registry and layout telemetry; existing source texture selection, transform tracks and layout behavior are not changed by that diff. This supports retaining prior visual findings without pretending the old captures were newly taken after instrumentation.
- `preservation-check.md` separately documents the broader baseline preservation check. This visual reviewer independently rechecked the 13 costume hashes, rather than independently repeating the entire 553-file audit.

## Unchanged limitations

The three target outfits are flattened approved illustrations. Their eyes, wings/hands, hats, helmets, clothes and accessories still have no independently authored hidden layers. The new Astronaut clip moves the complete illustration; it does not demonstrate blinking, glove articulation, a separately moving visor or hat/accessory secondary motion. Christmas gift/hand occlusion and Hanbok sleeve/body occlusion remain unresolved exactly as documented in `art-separability.md`.

Selecting stage 1, 2, 3 or 4 still displays the same costume source. The diagnostics explicitly state that independent eyes/wings/props and stage-specific appearances are unsupported. None of the new stage labels certifies a registered growth-stage costume rig. The separately saved green growth illustrations are flat review art; no retired orange Pio parts are acceptable substitutes.

Basic is a distinct existing case: its approved exposed-wing mask rig can move a separately masked wing. That does not transfer independent parts to the thirteen costumes, and its complete hidden-root/face rig is not certified by these new captures.

## Result

- **New sampled appearance/framing:** no defect observed in the evidence listed above.
- **Whole-character position change:** observed in the six new Astronaut samples.
- **Independent eyes/wings/hats/accessories:** missing / unsupported for the three target costumes.
- **Four-stage visual compatibility:** unsupported; not certified.
- **Continuous playback / FPS / GPU / battery / thermal:** outside this visual review. Performance claims belong to the separate measured report and retain its platform/build limits.

No source artwork, app code or existing capture was changed by this review. Only this scoped QA report was added; no expensive tests, new art generation, reconstruction or runtime implementation was performed.
