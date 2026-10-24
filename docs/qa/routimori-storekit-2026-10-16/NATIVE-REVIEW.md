# Native StoreKit review evidence

2026-10-16; Xcode local StoreKit only. No real payment/account credentials entered.

## iPhone 17 dedicated simulator

Device: `87EA3A43-121C-4FFA-A716-A79E614ABEFA`. Actual host app built from this workspace; test harness uses in-memory routine store and a dedicated wardrobe preference suite.

- Opened wardrobe from new home card, selected Cherry Blossom. Actual localized price ₩2,000 visible.
- Apple purchase sheet explicitly showed **Xcode**, **For testing purposes only. You will not be charged**.
- Closed Apple sheet. No ownership granted, purchase button returned, no error message. Screenshot `ios-cancelled-purchase-still-locked.png`.
- Opened it again and pressed Buy. Apple returned **Your purchase was successful. [Environment: Xcode]**. Screenshot `ios-apple-purchase-success.png`.
- Dismissed success. Application showed **보유 중** and **피오에게 입히기**, with purchase button removed. Screenshot `ios-owned-outfit.png`.
- Equipped Cherry Blossom. Application showed **지금 입고 있어요**. Screenshot `ios-equipped-outfit.png`.
- Pressed explicit **구매 복원**. Apple showed a simulated Xcode account authentication confirmation (no credentials). Confirmed; application reported **의상 1개의 구매 내역을 복원했어요.** Screenshots `ios-restore-xcode-confirmation.png`, `ios-restore-success.png`.
- First review test ended and its process exited. Relaunched the test host as new PID95269 (previous PID84640). Verified home automatically showed **벚꽃 피오**, still equipped, with original art. Screenshot `ios-home-cherry-relaunch-closeup.png`. New startup attachment records verified ownership and equipped state; no manual equip or ownership injection on second launch.
- Native preview exposed low contrast purchase button text. Fixed explicit on-accent foreground for purchase label/progress; subsequent builds include it.

## Mac

Actual temporary Debug app rendered new home card and wardrobe, ₩2,000 prices and original art. Screenshots `mac-home-basic-dark.png`, `mac-wardrobe-products.png`, `mac-purchase-preview.png`.

Initial native purchase request did not show its confirmation over the nested detail sheet. Adapter now uses macOS15.2+ `purchase(confirmIn:)` with frontmost attached sheet. Reverification pending; do not count initial interactive harness PASS as purchase-flow PASS.

## Limitations and automated failures

- Unexpected real account-form dialog from an earlier simulator run was cancelled without credentials. After a stale earlier test process was stopped, all13 real local purchases passed in an isolated invocation. Exact cause is not proven.
- Cancellation error injection in StoreKitTest returns undocumented ASDServerErrorDomain907 instead of public userCancelled on this runtime. Actual Apple sheet cancellation above works; no private error-code workaround added.
- Combined suites have pending/refund/verification/cache-sensitive failures. Preserve their logs; isolate processes before declaring these pass.
- Unit tests: 30/30 native Mac Swift Testing tests passed (`mac-unit.log`).
- No Sandbox/App Store production purchase verification.
