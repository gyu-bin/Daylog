# Per-outfit handoff — current anchors, not new art approval

Exact source paths, dimensions, SHA-256, packed rectangles, every z/pivot and day/night source are in [inventory.json](inventory.json). Existing standing runtime pivots below are NOT reusable seated/reclining shoulder coordinates. All new shoulders/grips/two-knot anchors remain `null` until actual hidden-root artwork exists.

| Outfit | Genuine standing parts | Existing effective standing pivots (px) | Existing seated eye slot centers (px) | Actual vacation props observed in day and night |
|---|---:|---|---|---|
| basic | 14 | wingLeft=[375, 810]; wingRight=[940, 830]; sprout=[650, 430] | Baked: no clean seated eyes | juice glass, straw, citrus slice |
| cherryBlossom | 15 | wingLeft=[310, 790]; wingRight=[965, 830]; sprout=[620, 400] | eyeLeft=[510, 650]; eyeRight=[827, 640] | juice glass, straw, citrus slice |
| summerVacation | 16 | wingRight=[1000, 930]; wingLeft=[360, 885] | eyeLeft=[510, 650]; eyeRight=[827, 640] | juice glass, straw, citrus slice, opaque sunglasses |
| autumn | 15 | wingRight=[960, 910]; wingLeft=[390, 860] | eyeLeft=[510, 650]; eyeRight=[827, 640] | juice glass, straw, citrus slice, leaf decoration |
| winter | 14 | wingRight=[975, 915]; wingLeft=[430, 865] | eyeLeft=[510, 650]; eyeRight=[827, 640] | juice glass, straw, citrus slice |
| halloween | 15 | wingLeft=[300, 850]; wingRight=[970, 840] | eyeLeft=[510, 650]; eyeRight=[827, 640] | juice glass, straw, citrus slice, pumpkin bucket |
| christmas | 15 | hat=[660, 450]; gift=[790, 925]; handLeft=[790, 925]; handRight=[790, 925] | eyeLeft=[510, 650]; eyeRight=[827, 640] | juice glass, straw, citrus slice, gift (viewer-left day / viewer-right night) |
| hanbok | 14 | wingRight=[975, 810]; sprout=[625, 365]; wingLeft=[400, 790] | eyeLeft=[510, 650]; eyeRight=[827, 640] | juice glass, straw, citrus slice |
| cafe | 15 | wingRight=[1000, 860]; wingLeft=[400, 880]; prop=[400, 880] | eyeLeft=[510, 650]; eyeRight=[827, 640] | coffee cup with lid (no straw) |
| student | 16 | sprout=[620, 380]; prop=[310, 875]; wingRight=[990, 850]; wingLeft=[310, 875] | eyeLeft=[510, 650]; eyeRight=[827, 640] | book, backpack, glasses, juice glass, straw, citrus slice |
| fitness | 17 | sprout=[625, 360]; wingLeft=[410, 935]; wingRight=[882, 875] | eyeLeft=[510, 650]; eyeRight=[827, 640] | dumbbells, juice glass, straw, citrus slice |
| rainyDay | 16 | wingLeft=[320, 800]; sprout=[500, 300]; wingRight=[745, 875] | eyeLeft=[510, 650]; eyeRight=[827, 640] | closed umbrella, juice glass, straw, citrus slice |
| pajamas | 15 | pillow=[820, 900]; wingLeft=[820, 900]; wingRight=[820, 900] | eyeLeft=[510, 650]; eyeRight=[827, 640] | pillow (no drink) |
| astronaut | 16 | wingRight=[933, 855]; sprout=[625, 400]; wingLeft=[515, 870]; helmet=[650, 650] | eyeLeft=[510, 650]; eyeRight=[827, 640] | closed helmet/visor (no drink, no straw) |

All standing/paid seated source canvases: 1254×1254 RGBA. Vacation full-canvas source: 1024×1536 RGBA. Runtime standing tight crops retain an explicit source rectangle and pivot; they are packed delivery, not new high-resolution reconstruction.

Special constraints: summer opaque sunglasses obscure eye expression; student glasses must stay above eyes. Astronaut closed visor must remain closed and above the clean face, with no added drink/straw. Pajamas has pillow, no drink; café coffee is not a juice/straw assembly. Christmas gift side changes between day/night authored sources and needs continuity approval.
