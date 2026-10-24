# Independent vacation candidate review

Verdict: **PARTIAL / NOT APP READY**.

Actually inspected: the day and night 13-outfit assembly boards, plus full-size Astronaut night, Hanbok night, Rainy Day night, and Cafe day assembly PNGs. Also compared the Cafe approved wardrobe source. This is a review of rendered still images, not animation or app/runtime evidence. No artwork was edited.

## Findings by severity

### P2 — Astronaut straw/visor interaction is not physically resolved

`output/pio-vacation-outfits-2026-10-23/qa/astronaut-night-assembly-v1.png`: the glass and straw are in front of the helmet, while the straw visually reaches the mouth through the face/visor region without a clear open visor or drinking port. The cute face and suit read well, but this is not a correct independently animatable visor/accessory attachment.

Before integration: author a visibly open-visor variant or a deliberate port, or use a resting pose without the drink. Preserve the approved helmet design; avoid solving it with a crude erase mask.

### P2 — These complete foregrounds cannot independently animate eyes, hands, cup and hammock

The candidate manifest explicitly states each generated foreground is flattened and not independently rigged. Still-image cuteness is not proof of the requested character motion. A whole foreground swing would move the authored rope attachment with the entire subject and must not be described as separate eyes/wings/accessories.

Before integration: separate genuine anatomy/eyes, held prop, hammock fabric, and stationary rope/tree anchors. Reconstruct hidden intersections. Keep the fixed tree knot in scene coordinates and constrain rope movement at that attachment. Do not animate a detached floating hammock across the knot.

### P3 — Framing/registration varies between outfits

The night Hanbok fills noticeably more of its frame than Astronaut/Cafe, and foreground hammock/rope placement varies between generated sources. This looks acceptable as independent concept-quality still candidates, but switching costumes in one persistent app scene would visibly change the composition and attachment line.

Before integration: establish shared anchor positions and a consistent resting body footprint; compare transitions in a fixed scene rather than accepting each pleasant still separately.

## Positive visual observations / limits

- All 26 board thumbnails preserve the round cream Pio, green sprout, warm cheeks and friendly expression. No retired orange crest was introduced.
- Night is a genuinely authored moonlit scene with warm lantern highlights, not a dark filter over the day background.
- The full-size inspected Hanbok has readable patterned sleeves and skirt; Cafe preserves the brown beret, green apron and branded cup from the approved source. Rainy Day retains its yellow coat and a closed umbrella prop.
- Inspected still rope/tree connections do not show an obvious gross gap at the displayed scale. This is **not** approval for rope continuity during rotation or independent movement.
- Full-size translucent/soft edges blend plausibly on their intended assembled background. Black/white matte halo stress tests and motion endpoint tests were not performed by this reviewer.
- Closed smiling faces remain cute, but a single flattened happy pose does not provide open, blink or half-lid states.

## DEBUG motion gallery code review

Read `Daylog/Components/PioOverhaulMotionReview.swift` and the sheet/button wiring in `Daylog/Views/Wardrobe/PioWardrobeView.swift`.

No additional material correctness defect found in the reviewed code. The gallery has local-only outfit/action/play/size/background state; it never calls wardrobe ownership/equip APIs. Entry and sheet are DEBUG-only. It renders the native overhaul view directly for deliberate candidate review. It explicitly explains repeat playback and the held-object limitation for Christmas/Pajamas, and shows a Reduce Motion notice. Size and background choices are concrete review controls.

This is source-only assessment. Layout at narrow iPhone widths, action selection, actual 64pt readability, scrolling suspension, runtime optics/shoulder endpoints, and screen-reader operation remain NOT_TESTED here. The native preview's reserved jump headroom means a nominal 220pt slot contains a smaller actual character; avoid interpreting slot size as a 220pt filled silhouette.

## Astronaut v2 visual follow-up

**The visor/straw P2 finding is CLOSED for the two v2 still candidates.** Actually viewed `qa/astronaut-day-assembly-v2.png` and `qa/astronaut-night-assembly-v2.png` at full size. The replacement keeps the recognizable lavender astronaut helmet/suit and changes to a relaxed pose with both gloves resting together; there is no cup or straw crossing the visor. Pio remains round, warmly lit and cute in both day and night.

This does not close the separate flattened-art/independent-rigging requirement or shared hammock-anchor registration requirement. Both v2 outputs are still **PARTIAL offline candidates, not app-ready animated scenes**. The previous v1 visor finding remains historical and should not be attributed to the selected v2 candidates.
