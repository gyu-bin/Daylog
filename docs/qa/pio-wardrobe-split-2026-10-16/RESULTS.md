# Standalone wardrobe and purchase-free DEBUG wear

2026-10-16. Scope: move wardrobe from Settings to its own sidebar section, equal-width catalog/preview on wide screens, and an explicit DEBUG-only outfit-wear playground. Approved artwork and prior uncommitted work are preserved. No commit, push, deployment, production installation or production record changes were performed.

## Results

| Check | Result | Evidence |
| --- | --- | --- |
| Mac sidebar and 50/50 layout | PASS | `mac-final-split-preview.png`: standalone sidebar item, catalog left and large Hanbok preview right. Settings no longer embeds wardrobe. |
| Preview versus actual wear | PASS | Mac native UI: selecting Cherry changed preview while Fitness remained worn; Apply changed worn outfit. Later selecting Hanbok left Cherry worn, with an enabled green Apply button. |
| Purchase-free use | PASS | Explicit `-pio-wardrobe-testing` permits Basic plus 13 outfits through `canWear`; genuine ownership, transactions and icon eligibility stay separate. No purchase sheet/session was invoked. |
| Home propagation | PASS | Mac native accessibility showed Cherry in the home header and growth card after Apply. iPhone native accessibility independently showed the same after selecting, applying and returning home. |
| iPhone compact route | PASS | Dedicated iPhone 17 simulator opened direct wardrobe, selected Cherry, applied without purchase, and returned to a valid dashboard. `ios-wardrobe-native.png` is the Device Hub screenshot, scrolled down to the catalog. |
| Focused automated checks | PASS | `mac-build-tests.log`: 70 tests / 5 suites. `mac-final-gate-tests.log`: 3 additional splash/activation tests. Both passed. |
| Final Mac Debug compilation | PASS | `mac-final-gate-tests.log`, built after the final UI and flag fixes. |
| Final iPhone Debug compilation | PASS | `ios-build.log`: TEST BUILD SUCCEEDED. `ios-playground.log`: native review harness completed without assertion failures. |
| Source review | PASS | `REVIEW.md`: both P2 navigation/rendering findings resolved; no additional material finding. |
| Release build for this revision | NOT_TESTED | DEBUG guards were reviewed; no new Release build was run for this UI revision. |
| CPU/memory benchmark, full Dynamic Type/resize matrix | NOT_TESTED | Outside this focused navigation and wear change. |

## User review app

The final Mac DEBUG playground is open from `/tmp/RoutimoriStoreKit.noindex/mac/Build/Products/Debug/Daylog.app`, using an in-memory test store and separate outfit/device preference suites. `DaylogWardrobePlayground` and `DaylogiOSWardrobePlayground` provide repeatable isolated review launches. The running Mac interactive review harness intentionally remains active for up to two hours; its log is `mac-final-playground.log`, so it is not counted as a finished automated test.

## Existing limitations retained accurately

- This change unlocks wearing existing designs in testing; it does not complete new artwork or independently animate all 13 paid outfits.
- Current green outfit artwork is shared across stages 1–4. The preview states this explicitly and does not change XP or thresholds.
- Missing outfit-specific vacation/cloud scene artwork and incomplete independent rigs remain documented in the earlier artwork/global integration reports.
- Test wear does not grant real purchases or alternate app icons. Normal purchase flow remains available outside the explicit testing mode.

