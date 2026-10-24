# Independent StoreKit stabilization review

Scope: source and supplied evidence only. No application/test source edits and no runtime StoreKit session, build, transaction or preference mutation by this reviewer. Parent serializes experiments; another worker owns manager/unit-test changes.

Goal remains unchanged: all 11 acceptance tests, three consecutive whole-suite passes, and immediate fresh-process ownership/equipment recovery. No assertion removal, private-error reinterpretation, skip, longer timeout or extra acknowledgement may manufacture a pass.

## Concrete fixture distinctions

### Cancellation: injected error is not an actual user cancellation

Current test sets `session.disableDialogs = true` and `setSimulatedError(.generic(.userCancelled), forAPI: .purchase)`. It then requires manager `.cancelled`. This exercises the StoreKitTest error-injection/translation path, not Apple's purchase sheet returning `Product.PurchaseResult.userCancelled` from a real Cancel press.

The installed public Swift interface explicitly supports a generic StoreKitError injection; the observed private server error 907 does not justify treating that private code as cancellation in production. Keep the failed injected-path evidence. A separately driven actual Cancel interaction could establish the user-facing path, but it must not silently supersede the existing injection assertion or be relabelled as the same proof. [Apple public error-injection API](https://developer.apple.com/documentation/storekittest/sktestsession/setsimulatederror%28_%3Aforapi%3A%29).

### Interrupted purchase: observation starts too late to establish ordering

Current test awaits `manager.purchase`, immediately asserts no ownership, obtains an issue transaction, then installs `ownershipDidChange` and resolves the issue. The logs already show verified updates can arrive before the callback is installed. The callback cannot reconstruct when or which transaction caused an earlier grant.

Minimal improvement to evidence: register timestamped raw verified-update/ownership observations **before** purchase begins, record the exact transaction ID plus the corresponding SKTestTransaction `hasPurchaseIssue`, and mark the resolve call in the same monotonic timeline. Preserve the pre-resolution no-ownership assertion. This separates an early verified update for this issue transaction from replay/delivery from another fixture; merely waiting longer after resolve does not answer that question.

Apple's public session API models interrupted purchases as transaction issues resolved explicitly; the installed `SKTestSession.h` describes `resolveIssueForTransaction` for transactions created with interrupted purchases enabled. The source test's intent is therefore reasonable; the early grant cannot be dismissed as success. [Apple interrupted-purchase property](https://developer.apple.com/documentation/storekittest/sktestsession/interruptedpurchasesenabled), [Apple testing guide](https://developer.apple.com/documentation/storekit/testing-in-app-purchases-in-xcode).

### Listener/session lifetime: possible boundary race, not a proven leak

The fixture resets/clears a shared local ledger in setup/teardown. Managers use weak captures and cancel their update task at deinit, but teardown does not explicitly await every underlying StoreKit update listener's termination before resetting the session. That is a test isolation gap worth measuring; it is not proof that a leaked listener caused refund failure.

The inspected focused 13-purchase log has exactly one listener start and one listener end, so that run does not establish a persistent listener leak. A minimal full-suite diagnostic should record per-client listener start/end and active count at each test boundary, before ledger reset. Require old test-owned listeners to be stopped rather than adding a fixed sleep. The same-process reopen test intentionally keeps original and new managers alive; document this and compare event delivery with one versus two listeners once if the event stream assumptions are disputed.

### Final unfinished transaction: acknowledgement and readback are different observations

The real adapter logs prove all purchases reached finish; the final space transaction was cached, had no in-flight finisher, and finish returned promptly. The unchanged three-second observer nevertheless saw that verified transaction unfinished. No test observer should call finish/sync/clear to erase this failure.

The 13-product loop performs `Transaction.latest(for:)` after each manager purchase/finish. Only the final product remains in the observed failure. That pattern suggests two discriminating public-API experiments, without attributing cause:

1. Rotate the purchase order while retaining all 13 purchase/equip/rig assertions and the same three-second bound. Does the unfinished identity follow the last purchase or remain the space product?
2. In a separate diagnostic reproducer, compare readback with and without test-side `Transaction.latest(for:)`, or read latest before acknowledgement in a minimal public-API adapter probe. Keep the production acceptance test and its ownership verification unchanged. This can detect fixture/readback interaction; it does not authorize omitting verification from the acceptance suite.

The final observer re-enumerates `Transaction.unfinished` and records the immediate snapshot. Its sleep cadence can omit a final exact-deadline sample, but this minor boundary behavior cannot explain a transaction continuously present across the full three seconds. Do not claim the loop alone caused the failure.

## Fresh-process preference proof: test public behavior, not plist timing

The old seed's five-second assertion on a `Library/Preferences/<suite>.plist` physical file imposes a storage-layout/disk-flush deadline that UserDefaults does not promise. Public defaults caching and asynchronous persistence are documented; forcing the underlying file is inappropriate. [Apple UserDefaults](https://developer.apple.com/documentation/foundation/userdefaults), [Apple settings access guide](https://developer.apple.com/documentation/foundation/accessing-settings-from-your-code).

Replace that unsupported physical-file assertion with the **equally strict original business requirement**: immediately launch the fresh process after successful seed purchase/equip; verify its independently recovered signed ledger and actual wardrobe selection via public APIs, with no sleep, repurchase, sync, equip, cache injection or fallback rehydration.

Expected seed PID/verified transaction ID/product ID can reside in the existing diagnostic manifest, solely as comparison metadata. Do not store an ownership list there or copy the expected outfit into the new process's UserDefaults. The seed should exercise the real `wardrobe.equip` preference write rather than mix it with five additional metadata writes in that suite. The new process must instantiate a fresh purchase manager/wardrobe, enumerate or refresh verified current entitlements, and independently check `owns(.cafe)` and `equippedOutfit == .cafe` from the original UUID suite.

Only if this immediate public-behavior check fails is there direct evidence that durable wardrobe equipment recovery is broken. The earlier later-diagnostic PASS remains PARTIAL historical evidence and must not replace immediate repeated acceptance.

## Source references inspected

- `DaylogStoreKitTests/PioStoreKitIntegrationTests.swift`
- `DaylogStoreKitTests/PioStoreKitProcessRelaunchTests.swift`
- `Daylog/Services/PioPurchaseManager.swift`
- `Tools/pio-storekit/process-relaunch.py`
- Installed public SDK files under `/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/Library/Frameworks/StoreKitTest.framework/Headers/SKTestSession.h` and `Modules/StoreKitTest.swiftmodule/arm64-apple-ios.swiftinterface`.
- Prior integration `RESULTS.md`, independent `REVIEW.md`, IDE full-suite summary and focused acknowledgement log.

No 11/11, three-run stability, immediate relaunch, Sandbox, or production-readiness PASS is claimed by this review. Each proposed experiment must produce evidence before any cause is assigned.

## Current-task source and direct-SDK evidence follow-up

### Real immediate restart failure is now distinguished from the old plist assertion

The parent supplied `instant-relaunch-1`: fresh process recovered the same verified Cafe receipt **ID 80**, but its actual wardrobe/public-defaults selection was Basic after seed Cafe. Unlike the unsupported five-second physical plist deadline, this is a failure of the immediate business selection-recovery requirement. It justifies fixing preference persistence while leaving entitlement authority unchanged. The earlier delayed recovery remains historical PARTIAL evidence, not a substitute for this failure.

### Atomic preference-only selection persistence source review

Read `Daylog/Services/PioWardrobeSelection.swift` and its current wardrobe integration. No ownership/security bypass found in the inspected source:

- The file stores only version + outfit preference, never receipt or entitlement. Version/known outfit decoding is validated; corrupt/unknown data falls back to prior preferences.
- `PioWardrobeStore.equip` checks `canWear` first, writes the preference atomically, and only after a successful write updates in-memory selection and the backward-compatible UserDefaults mirror. A thrown save returns false without acknowledging a successful equip.
- Loading a selected paid outfit does not grant access: the existing effective `equippedOutfit`/appearance ownership checks remain in force until the verified ledger grants ownership.
- Main-actor isolation serializes within-process writes. Separate local StoreKit / Sandbox / DEBUG outfit-testing / production profiles avoid test-selection crossover. Ordinary tests do not open the real profile; they must inject their UUID file.
- This writes an application-owned preference JSON in Application Support, not UserDefaults' private backing plist. No direct modification of the underlying defaults file is introduced.

Required meaningful checks: same file reopens in an immediate new OS process; rapid final selection wins; corrupted/version-mismatched/unknown outfits fail safely; a tampered valid paid-outfit preference still cannot unlock ownership; save failure preserves old selection and mirror; all profile paths are separated. The relaunch fixture must inject the same UUID file in both processes and independently verify actual outfit recovery, without reconstructing it from diagnostic metadata.

Remaining practical limitation: UI presently treats equip's false result by doing no success action; a persistence error is safe but may have no visible error explanation. This is a usability follow-up rather than permission to return success when saving failed. Atomic replacement addresses immediate process handoff, not a claimed guarantee against arbitrary power-loss/filesystem failure or cross-process last-writer coordination.

### Direct SDK controls: observed boundary, not blanket blame

Actually read `PioStoreKitSDKContractTests.swift` and `sdk-control.log`. These controls directly call Product/Transaction/StoreKitTest; they do not instantiate the Pio manager, acknowledgement cache, wardrobe or application-owned update stream.

1. **Finish/readback:** space-first transaction **77** is absent from unfinished after awaiting finish; Cafe-last **78** remains throughout the unchanged three-second snapshots. This reproduces the last-purchase pattern with a different product and without test-side Transaction.latest reads or Pio's finisher. It rules out "only astronaut product mapping" and "Pio failed to call finish" as sufficient explanations for this observed control run. It does not prove a universal SDK bug or make the business acceptance pass.
2. **Cancellation:** the control first checks the configured injected error equals public `.generic(.userCancelled)`, then direct `Product.purchase` throws `StoreKitError.unknown`, domain `StoreKit.StoreKitError`, code **2**, underlying nil. Thus Pio's cancellation mapper is not required to reproduce the failed public injection semantics in this environment. Do not map every unknown/private server error to cancellation to make a test green.
3. **Interruption:** direct issue transaction **79** has `hasPurchaseIssue == true`, while direct verified current entitlements already contain **79** before resolution. This reproduces the contradictory test-driver/verified-ledger observation without Pio granting ownership. Do not add StoreKitTest-only transaction issue checks or fixture-controlled ownership exceptions to the production manager. Such fields are test-driver evidence, not a production verification authority.

All three controls preserve strict failures. They are diagnostic controls, not replacements for the 11 application acceptance tests. They localize what can be reproduced below the Pio stack in this installed SDK/configuration; they do not explain every full-suite failure, erase the refund timeout, establish Sandbox behavior, or justify dropping assertions. Further isolated public-API comparison may inform an Apple feedback reproducer, while the required 11/11 × three consecutive runs remains unmet until actually observed.

No runtime session or source mutation outside this QA document was performed by this reviewer for the follow-up.

## Refund-specific control: do not generalize the other SDK controls

Read the newly executed `sdk-refund.log`, direct refund test source, `PioStoreKitRefundOrderingTests.swift`, and `refund-order.log`.

- The direct SDK refund control **PASSes**: transaction **180** produces a raw verified revoked update and no remaining verified entitlement for that product.
- The manager/adapter ordering variants **FAIL** for transactions **181 / 182**. The adapter trace records a raw listener start, initial accepted purchase, and listener end only at teardown, with no raw revoked update in between. This locates the first missing observed signal upstream of Pio's `receive` callback/selection repair; it does not prove why the raw iterator did not deliver it.
- These runs explicitly refute a blanket claim that this environment cannot deliver refund notifications or that the earlier cancellation/interruption/unfinished controls explain refunds. Refund remains a separate application/adapter/fixture ordering investigation.

### Source differences still requiring a controlled comparison

The successful direct control loads one product, starts a raw MainActor Task with a subscription-start expectation, directly purchases/finishes, and refunds; it does not call current entitlements until after the notification. The adapter starts its raw task, then `start()` calls preflight + empty current entitlements + full 13-product loading; purchase performs another AppTransaction preflight. The success control's setup also verifies AppTransaction **before** reset/clear, whereas the ordering fixture verifies it **after** reset/clear and the adapter verifies it repeatedly after subscription.

The `preload:true` ordering test does **not** remove the post-listener product query: `sut.start()` still calls `loadProducts()` again. Therefore its failure cannot rule out an effect from querying products after registration. Similarly, querying AppTransaction once before the listener does not remove the adapter's later AppTransaction calls.

Minimal next factor checks, preserving the original ten-second notification requirement and no manual reconciliation before the expected event:

1. Adapter-only raw stream, no Pio manager/wardrobe; use the same subscription-ready boundary as the direct control.
2. Direct control with acknowledgement executed via the same child-task coalescer, to isolate task/finish context.
3. Direct raw subscription followed by the exact AppTransaction → empty currentEntitlements → full 13-product query sequence used by start, varying one call at a time.
4. Full 13-product query versus one-product query, and AppTransaction preflight before versus after subscription, using a matched setup/reset order.

Log exact transaction IDs, raw iterator entry/exit, subscription identity and active count. Neither absence of an ownership callback nor a successful on-demand ledger refresh is equivalent to receiving the required live revocation update. Do not extend a timeout, poll ownership into passing, or replace the update requirement with explicit refresh.

The bounded stream wrapper/continuation and weak client capture show no clear early termination in the supplied traces: listener end occurs only after the timeout/teardown. No additional source edit is justified solely by assuming that the AsyncStream wrapper lost the revocation. Keep the direct-vs-adapter factors separate until a reproducible minimal difference is measured.

## Final independent report checkpoint

Read the final `RESULTS.md` and cross-checked the supplied `runtime-series.json`, unit log, preservation JSON and the three corrected verify logs. The report's **PARTIAL** verdict is supported, and it does not overclaim end-to-end or release readiness.

- `runtime-series.json` has all three final whole-suite runs and the random-order run at **7 Passed / 4 Failed / 0 Skipped**. The five isolated originals have four failures and only signature-denial passing. The report preserves this instead of substituting passing diagnostic controls.
- Corrected immediate-restart verify logs actually pass **1/1 each**, recover verified receipt IDs **81 / 82 / 83**, and each report `ownedCafe == true` and Cafe equipped. The fixture source checks the preference-only selection file independently, checks the paid selection remains locked before verification, then checks effective Cafe after real ledger reload. It does not restore preference or ownership from diagnostic metadata. This supports the narrow immediate normal new-process persistence PASS, not force-kill or power-loss guarantees.
- `mac-unit-final-v2.log` explicitly reports **77 tests in 7 suites PASS** and `TEST SUCCEEDED`. `preservation-after.json` reports all **723** protected artwork/motion files unchanged with no missing/changed entries. Release build successes are appropriately described as builds, not actual device/App Store acceptance.
- The new persistence feature can recover Cafe even when the backward-compatible UserDefaults mirror has not yet reached the fresh process. That is expected from the new authoritative **preference** file and is not evidence of an entitlement cache or ownership grant.
- Refund evidence is correctly kept separate: direct standalone ID 180 passes; combined-after-manager ID 194 has an empty current ledger but no raw revocation and fails; another fresh standalone ID 195 passes. A matched helper's own positive baseline also failed while an adapter-only matched case passed. These observations do not establish one causal API, Task, wrapper or universal SDK failure. The report labels B as unresolved interaction rather than blaming SDK broadly.

No material factual contradiction or new source-level P1/P2 issue was identified in this final report pass. The unresolved four acceptance failures and absence of **11/11 × three consecutive whole runs** remain decisive. Actual Sandbox/physical-device/offline/forced-termination behavior and previous ASC/icon delivery blockers remain outside the demonstrated completion scope. No runtime session, app/test/art edit, private-error success mapping, extra acknowledgement or assertion weakening was performed by this reviewer.
