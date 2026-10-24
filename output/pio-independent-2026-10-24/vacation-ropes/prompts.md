# Vacation rope production prompts

Built-in image_gen, transparent_background=true. Existing reference pixels never edited.

## Attempt 1

Use case: background-extraction. Edit target: attached existing 1024x1536 RGBA vacation hammock art. Produce one transparent 1024x1536 PNG containing ONLY the existing ivory braided suspension ropes, right knot, and two wooden end spreader bars, at EXACT original pixel positions and scale. Remove all character, green/cream hammock fabric, drink, leaves, glow, shadows and background to genuine alpha. Preserve original rope texture, strands, lighting and geometry; do not redesign or recenter. Right knot center approximately (952,500), rope exits top/right edge around(1024,400), right spreader endpoints around(758,664) and(885,700). Left ropes enter left edge around(0,681), left spreader around(84,730). Preserve these exact anchors and the original visible rope fans; reconstruct only tiny rope portions occluded by cloth at their attachment roots with 8 pixels overlap. Most of canvas must remain transparent, no phantom gray/green halo. No text, no new objects, no full hammock.

## Attempt 2 (single targeted registration correction)

Use case: precise-object-edit. Input1 is exact original1024x1536 hammock, input2 is FAILED extracted rope layer that moved ALL ropes down ~200px. Correct this: reproduce ONLY the original ivory suspension ropes/knot and end-bars from INPUT1 at their ORIGINAL coordinates. Input2 is negative geometry reference, DO NOT preserve its displaced position. Right knot center must be (952,500), not(952,700). Right bar endpoints(758,664),(885,700), not(758,874),(885,924). Left cord entry(0,681), bar(85,730), not(0,850),(85,960). Output1024x1536 genuine transparent PNG. Remove diffuse beige glow entirely; only rope/bar pixels and antialiasing. No Pio, fabric, drink, shadows or background. Keep original braided rope texture and knot shape. Do not recenter or auto-fit object bounds; exact full source canvas registration is essential.
