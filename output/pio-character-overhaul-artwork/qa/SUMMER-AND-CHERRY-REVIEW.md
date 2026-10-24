# Summer component and Cherry registration artwork review

Scope: offline artwork QA only. No application code, asset catalogs, original source pixels, purchase settings or production data were changed. No app builds or tests were run.

## Summer Vacation — PARTIAL

All seven source files were opened through native alpha compositing against light and dark backgrounds. `summerVacation-v1/component-sheet-light.png` and `component-sheet-dark.png` show every complete component. `alpha-audit.json` records dimensions and alpha statistics; individual native-size composites are preserved alongside the sheets.

- Body: 1254×1254, alpha0–255. Clean eye-free face, rosy cheeks and beak; floral shirt reads coherently with sleeves. Candidate usable for registration, not full costume approval.
- Wing left: 1402×1122, alpha0–255. Wing right:1374×1145, alpha0–255. Both have genuine alpha and soft cream/fabric texture. Sleeve root geometry and shoulder occlusion need actual character assembly and rotation proof. Their different poses are not mirrored duplicates.
- Headwear v1:1254×1254, alpha0–255. **REJECT for front-layer use**: broad solid underside would obscure the face. Preserve as rejected iteration, do not secretly cut it out.
- Headwear v2:1536×1024, alpha0–254. Arched underside has a genuine transparent face opening. Probe (600,800)–(1000,950) is99.9267% alpha0; remaining pixels are alpha1. Straw texture and sprout remain detailed, with no broad external halo in either background composite. **Usable registration candidate**. Head-root fit/occlusion remains unverified here.
- Sunglasses:1774×887, alpha0–255. **Opaque-lens limitation**: left/right central lens patches have alpha252–253 (means252.9996 and252.9204). They are dark opaque painted lenses, not see-through tinted lenses. A blinking eye behind them will not be meaningfully visible. Do not claim visible blink through these lenses; removing glasses or separately authored transparent lens artwork is required for that behavior. Frame material itself is usable candidate artwork.
- Drink:1254×1254, alpha0–255. The glass above the liquid is genuinely translucent: clear upper patch alpha50–74, median56. Orange liquid/slice/straw stay suitably opaque; glass edge highlights survive both background composites. Usable accessory candidate; cup-to-hand grip and shared movement remain unverified by this component-only audit.

Exact probe rectangles and numeric statistics: `summerVacation-v1/transparency-probes.json`. These are measurements of source alpha, not manually added transparency. No alpha cleaning or painting occurred.

## Cherry Blossom revised — PARTIAL

Actually viewed the original/prior/revised comparisons at64pt and220pt3x in light/dark; additionally viewed the220pt dark and64pt light pose boards (neutral, authored half/closed eyes, wings±12°).

- Revised sprout removes the provisional green edge haze and reads coherently with the soft body. The original direction is better preserved than the prior candidate.
- At64pt, eyes/beak/flower and overall rounded identity are readable; costume and sprout remain a clear coherent silhouette.
- At220pt, the texture/shading are attractive but this is still reconstructed candidate artwork: cape flower layout, head flower, eye spacing/highlights, raised-foot view and wing tips differ from the approved original.
- Static±12° wing samples do not show an exposed shoulder slice or visible hole. Left wing is heavily hidden by the cape, so its independent motion is less obvious than the right wing. This is not a claim that every extreme pose or joint combination passes.
- Half-eye appears sleepy and less lively as a held pose. Keep it a brief blink transition, not the default expression. The current proof uses actual authored half/closed-eye assets.
- Cape/bow are baked into the body; no separate fabric or bow motion is demonstrated. Head flower and wings are separate.

## Offline motion proof — PARTIAL, not runtime QA

`cherry-motion/cherry-independent-offline-proof.gif` is a real48-frame440×440 GIF,80ms/frame (~3.84seconds), generated from unchanged full source canvases using the registration manifest. Body, cape, flower, sprout and feet remain fixed; both wings rotate±12° around registered shoulder pivots, open/half/closed eye assets switch independently, and one unchanged petal source is instanced three times with gentle drift. It does not rotate a flattened whole character.

`cherry-motion/cherry-motion-frame-proof.png` was visually inspected; six sampled frames show body-fixed eye and wing changes without visible shoulder gaps at the tested samples. `cherry-motion/motion-proof.json` records each frame's eye state and wing angle and verifies all source file SHA256 hashes are unchanged before/after rendering. Body source hash is956fd164e1402d25f665f4c49cbabaea6bf79b9e4733438c1a920f21e3a8f853.

The GIF is explicitly labeled OFFLINE ARTWORK CANDIDATE. Palette quantization is an export property of GIF only; source PNGs are untouched. It is not a native app video and does not certify runtime timing, Reduce Motion, CPU/memory, walk/jump/landing, growth-stage compatibility or final visual approval.

## Optional Summer frame-only experiment — PARTIAL

A subsequently generated eighth source `sunglasses-frame-only-candidate.png` was separately composited and visually inspected against light/dark. It is1774×887 RGBA, alpha0–255. Central left lens-hole patch is99.9067% fully transparent with remaining alpha1; central right lens-hole patch is100% alpha0. This is a genuinely empty frame with transparent holes, not an opaque fake checker/background. Exact probes: `summerVacation-v1/frame-only-probes.json`.

This optional source removes the approved dark lens tint and reflections. It therefore reads like optical frames and is **not an approved replacement** for the original summer sunglasses. If used for eye-visible animation, a proper separately authored translucent tinted lens remains missing. Primary Summer motion proof retains the opaque-lens candidate and makes no blink claim.

## Summer offline motion proof — PARTIAL

After the primary registration was finalized (hat lowered and reduced; feet buried25px), `summer-motion/summer-grip-offline-proof.gif` was regenerated from its current primary manifest. The verified file is440×440,48frames,80ms/frame (~3.84seconds). Body, hat, glasses and feet are fixed. Cup and right hand use the same world pivot, angle and translation; left wing moves independently. Primary opaque glasses are retained, and no invisible eye motion is presented as visible blink.

Three final sampled frames were visually inspected in `summer-motion/summer-grip-frame-proof.png`. Cup/hand contact stays together in these samples, without an obvious exposed shoulder hole. The attachment is a side/back grip, not an exact restoration of the original foreground palm. Continuous native playback and performance are not tested. `summer-motion/motion-proof.json` proves all source hashes unchanged; body hash342e0cb81ea9f080652e5b127dd55c43938ed1756767f2eb486ae71e2345d91d. `gif-verification.json` verifies both real GIF files, dimensions, frame counts, durations, bytes and SHA256.
