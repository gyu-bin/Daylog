# Summer Vacation component registration — candidate only

Status: PARTIAL. Actual static artwork assembly inspected; no app integration or animation approval.

## Candidate sources and coordinate system

Six active genuinely generated source roles: unchanged1254-square body, drink, corrected headwear-v2 (1536×1024), sunglasses(1774×887), screen-left sleeve/hand(1402×1122), screen-right sleeve/hand(1374×1145). Existing genuine Basic eye and foot sources are reused and not counted as new artwork. Headwear-v1 remains preserved; it failed actual assembly because its solid underside concealed the face. Its rendered failure is retained under registration-v1-rejected-headwear/ and excluded from current outputs.

Full source alpha is retained. No alpha cleanup, source painting, masks, sheet crops, warping or enlargement. Only uniform downscaling, translation and rigid articulated rotation are applied with native CoreGraphics compositing. Body uses identity transform on1254×1254 top-left canvas. Headwear+sprout form one component, not independent leaves. The actual reconstructed body keeps its own new detailed shirt/face pixels; it is not pixel-identical to original.

All source hashes and measured transforms are recorded in registration/registration-candidate.json. Neutral left shoulder=(360,885), right grip shoulder=(1000,930). The right hand/sleeve and cup share the exact same world pivot(1000,930) and rigid endpoint transform:−6° and translation(0,−25). Their relative source placement cannot drift. Their z-order differs intentionally: right hand behind torso to conceal its reconstructed cuff-root nub, drink in front. Left wing remains foreground; rooted sleeve covers the shirt seam. Feet are separately placed; existing reused feet differ from original perspective.

## Outputs and actual inspection

registration/ contains26 real PNGs:16 primary PNGs comprise four original/neutral/left−12/left+12/drink-raised comparison boards at64pt3x/220pt3x, light/dark, plus four full1254-square poses as transparent alpha and light/dark composites. png-verification.json verifies every PNG's dimensions, bytes and hash. source-alpha-audit.json records decoded native alpha-zero/partial/opaque counts and alpha≥16 bounds for every selected source. This proves actual transparency exists, not visual correctness by itself.

Viewed native-size source files, full neutral in light and dark, full raised drink dark, and220pt/64pt dark comparison boards. Corrected headwear-v2 preserves visible face; its broad exterior glow in the raw alpha viewer does not appear in normal source-over composites. Shoulders show no obvious root slice or hole in inspected left±12 endpoints. Cup and hand remain together at neutral/raised endpoints, while body, hat and sunglasses are stationary. The hand's contact presentation remains a side/back hold rather than exact original foreground palm. The left sleeve is smaller/shorter than original but attached; its independent angles are visible without cheek attachment.

## Remaining limitations

- Sunglasses significantly obscure the underlying pupils, unlike original's clearly visible eyes. Visible blinking is UNSUPPORTED by this candidate lens presentation. Do not claim independent blink completion or edit alpha to fake it; a properly authored lens/eye-visible variant is needed if blinking must be visible.
- Separate optional empty-frame art has been composed with real open and closed eyes aligned to its apertures. Ten additional optional-frame-* PNGs show original/primary/frame-open/frame-closed64/220pt light/dark and full transparent/light/dark alternatives. Actual220pt dark comparison was inspected: eyes and closed-eye poses are visible, but sunglasses tint is missing and the accessory now reads as ordinary glasses. This is an unapproved alternate proposal, not replacement of primary lenses. optional-frame-registration.json records its source hashes and transforms. No native blinking is claimed.
- Hat is a combined hat+sprout; no independent sprout claim. Initial v2 fit left a conspicuous clearance arch. The final fit moves whole headwear40px down, then shrinks it uniformly5% about its head mount: target fit rect(170,88.5,931,698.25). Full neutral dark was re-inspected: both side gaps close without concealing the glasses/face. It still differs from original rim thickness and leaf scale, requiring user visual approval. Feet were translated25px upward under the body; actual long exposed ankle stems no longer show in neutral.
- Shirt pattern, head/leaf proportions, cuff/hand presentation, glass/lemon details and foot perspective differ from approved original. Original remains unchanged. The neutral footprint is aligned by the same canvas, not separately normalized to original alpha bounds.
- These four static poses do not validate continuous joint coverage or intermediate/combined angles. Right grip rotation/translation is genuinely shared in the compositor but has not been validated by native playback.
- Eye closing, idle, walk, jump, landing, native Mac/iPhone/Reduce Motion and performance are NOT_TESTED. No growth variants authored under the latest one-appearance brief.

No app code, original approved artwork, source candidate PNG, catalog, purchases or data configuration was changed. No app build/test, commit or push.
