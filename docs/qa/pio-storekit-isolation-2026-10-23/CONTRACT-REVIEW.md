# Independent StoreKit contract review — residual four failures

Scope: read-only source/evidence review and official Apple documentation/installed SDK interfaces, 2026-10-23. No runtime session, app/test/art edit, purchase, reset, timeout change or acceptance-assertion change was performed by this reviewer. Previous results/reviews are preserved.

## Classification rules

- **APP_BUG:** evidence isolates incorrect application behavior against a public requirement.
- **TEST_BUG:** fixture/assertion imposes an invalid requirement, mislabels its evidence or uses an unsupported API. A project-specific stricter criterion is not automatically a test bug.
- **SDK_DEPENDENT:** the disputed behavior reproduces through direct public Apple APIs without requiring the Pio implementation in this installed configuration. This does **not** mean Apple acknowledged a defect or all SDKs behave the same way.
- **UNRESOLVED:** current controls do not isolate the responsible layer/interaction.

## Residual classification at this checkpoint

| Residual failure | Primary label | What supports it | What is not established |
|---|---|---|---|
| Public cancellation error injection | **SDK_DEPENDENT** | Configured `.generic(.userCancelled)` is read back, but direct `Product.purchase()` throws public `StoreKitError.unknown` without a public underlying cancellation. Pio is unnecessary to reproduce the mismatch. | Actual purchase-sheet Cancel UX and other OS/SDK behavior. Calling the injected path an actual user cancellation is an evidence-labeling error. |
| Interrupted purchase / resolve | **SDK_DEPENDENT** | Direct issue transaction 79 already appears verified in `currentEntitlements` while the driver reports an unresolved purchase issue; app-level runs also observe an early verified update. | A production business rule allowing an uncompleted payment, or a valid production field that lets Pio override a verified entitlement using test-driver issue state. |
| Live refund notification | **UNRESOLVED** | Direct standalone 180/195 pass; same direct operation after manager activity 194 fails despite an empty current ledger. Matched helper baseline itself fails while another adapter-only variant passes. | One causal API, wrapper, child Task, collection type, listener leak, universal SDK defect, or exclusion of application/fixture interactions. |
| Last transaction remains in `unfinished` after awaited finish | **SDK_DEPENDENT** | Direct space-first 77 clears; direct Cafe-last 78 remains within the same three-second observation without Pio manager/finisher or test-side `latest` reads. The symptom follows final position rather than the astronaut mapping. | A documented three-second visibility guarantee, every finished transaction's eventual behavior, or successful completion of the project's original acceptance test. |

None of these four is currently isolated as a new **APP_BUG**. That is an evidence boundary, not a declaration that the app is production-ready. The previously confirmed immediate selection-persistence defect was an APP_BUG and was separately fixed/tested. The four original failures and 11/11 × three-run acceptance remain failures until actual criteria are met.

## Public contract, with limits

### `finish()` and `unfinished`

Apple describes `finish()` as acknowledging delivery/enabling the purchased content or service. The app should finish after delivery. `unfinished` identifies transactions still needing processing. Neither reviewed StoreKit 2 page specifies that a subsequent independent enumeration must become empty within **three seconds**, or a numeric cross-sequence cache-propagation deadline. [finish()](https://developer.apple.com/documentation/storekit/transaction/finish()), [unfinished](https://developer.apple.com/documentation/storekit/transaction/unfinished).

The three-second bound is therefore a **project acceptance policy**, not a quoted Apple SLA. Preserve it as requested. A claim that exceeding exactly three seconds alone proves an Apple contract violation would be a review/test-interpretation error; it does not make the practical unfinished observation pass. Do not finish twice from the test, clear the ledger, add a dummy purchase, increase the deadline or omit the final product to hide the result.

### Current ownership and transaction notifications

For non-consumables, `currentEntitlements` provides current entitlement transactions; refunded/revoked products are excluded. This supports independent reconciliation, not treating a missing notification as proof that a refund never happened. [currentEntitlements](https://developer.apple.com/documentation/storekit/transaction/currententitlements).

Apple describes `updates` as delivering transactions created/updated outside the app or on other devices, and asks apps to establish the listener at launch. Successful same-device purchases are returned through purchase success; unfinished launch deliveries have distinct behavior. The reviewed page does not promise a ten-second bound, arbitrary per-test re-registration as a fresh process, or a particular multi-subscriber broadcast policy. A test-owned start marker just before `for await` is useful ordering evidence but not an Apple subscription-acknowledgement API. [updates](https://developer.apple.com/documentation/storekit/transaction/updates).

The test-session refund API models a refund completed outside the app. Coupled with `updates` and entitlement semantics, the notification test is a reasonable integration test; no reviewed source guarantees latency or proves that every session reset fully resets iterator/client state. Do not confuse local transaction updates with server `REFUND` webhook timing. [SKTestSession](https://developer.apple.com/documentation/storekittest/sktestsession), [refundTransaction(identifier:)](https://developer.apple.com/documentation/storekittest/sktestsession/refundtransaction(identifier:)).

### Error injection versus cancellation UI

Installed `StoreKitTest.swiftinterface` defines purchase failures as either a generic `StoreKitError` or a `Product.PurchaseError`. Apple demonstrates configuring a public error for a selected API and removing the injection with nil. This gives a supported injection experiment; it does not make injection identical to a person cancelling a purchase sheet. [setSimulatedError](https://developer.apple.com/documentation/storekittest/sktestsession/setsimulatederror(_:forapi:)), [WWDC23 StoreKit testing](https://developer.apple.com/videos/play/wwdc2023/10140/).

`failureError` and `failTransactionsEnabled` are explicitly deprecated/no longer supported in the installed header and current documentation. Their old supported error list is not a general StoreKit 2 cancellation-injection facility. Reverting to them, using unsupported codes or reclassifying private 907/unknown as cancellation would not establish correct behavior. [failureError](https://developer.apple.com/documentation/storekittest/sktestsession/failureerror), [failTransactionsEnabled](https://developer.apple.com/documentation/storekittest/sktestsession/failtransactionsenabled).

### Interrupted issue and resolution

The property documentation says enabling interrupted purchases makes purchases fail until interruption is resolved/disabled. The resolution method models a user completing an action outside the app and explicitly states the app receives a new transaction through `updates` or transaction observers. The installed header also identifies transactions created under interruption as issue transactions. No reviewed source provides a numeric notification deadline. [interruptedPurchasesEnabled](https://developer.apple.com/documentation/storekittest/sktestsession/interruptedpurchasesenabled), [resolveIssueForTransaction(identifier:)](https://developer.apple.com/documentation/storekittest/sktestsession/resolveissuefortransaction(identifier:)).

Thus early verified entitlement evidence is in tension with the intended test scenario, not a reason to teach production ownership code about `SKTestTransaction.hasPurchaseIssue`. Preserve exact driver/verified IDs and pre-/post-resolve event ordering; a signed entitlement returned by the real API cannot safely be denied on an invented test-specific rule.

### Reset and clear are different operations

Apple documents a single shared test environment controlled by every SKTestSession, so environment-changing tests must run serially. `resetToDefaultState()` restores property settings from configuration; `clearTransactions()` deletes test transactions and produces an empty receipt. They are not documented to restart StoreKit services, create a fresh process, purge all SDK caches, or synchronously terminate old async iterators. [SKTestSession](https://developer.apple.com/documentation/storekittest/sktestsession), [resetToDefaultState](https://developer.apple.com/documentation/storekittest/sktestsession/resettodefaultstate()), [clearTransactions](https://developer.apple.com/documentation/storekittest/sktestsession/cleartransactions()).

Neither function should be interpreted as refund-notification proof. A synchronous empty driver list is an appropriate setup assertion, but does not establish a public readiness barrier for every other sequence. Await test-owned listeners' termination and preserve full reset/query order in reproductions.

## Bounded discriminators before changing application behavior

1. **Set versus Array, without confounding cardinality/order.** `Product.products(for:)` publicly accepts any `Collection<String>`; both Set and Array conform. Set is valid caller input. Capture one Set and its Array iteration order, log both, hold all 13 IDs and chosen winter ID fixed, and compare the concrete collection types. Test sorted Array separately to distinguish order. One-element Array versus 13-element Set changes two variables and cannot isolate collection type. Always select returned products by ID, not first element; response order is not documented to match input order. [products(for:)](https://developer.apple.com/documentation/storekit/product/products(for:)).
2. **Refund controls require an in-run positive baseline.** Compare a direct raw subscriber and Pio adapter only with the same preflight, all-products lookup, current-entitlements query, task context, finish, reset and refund sequence. Run direct baseline alone in a fresh OS process as well as after the application path. If the matched baseline fails, do not assign the difference to one adapter feature.
3. **Readiness/timeline evidence.** Retain exact transaction IDs, raw iterator start/end and active count, monotonic purchase/finish/refund/resolve marks, and same public deadlines. A post-timeout current ledger read is diagnosis, not a substitute for the required event.
4. **Cancellation and completion minimal reproducers.** Keep direct API reproductions and the original application assertions. Actual UI Cancel can be a separately named proof, never an invisible replacement for the injection test. Rotate final purchase identity to separate product mapping from completion/readback state.

No experiment here authorizes a second concurrent StoreKit session, extra sleeps, real account interaction, hidden ownership revocation, public-error assertion removal, polling into a pass or different completion thresholds. Cross-runtime/Sandbox evidence remains missing; file an Apple feedback only with the exact public reproducer and observed configuration, without claiming a universal diagnosis.

## Local evidence and installed interface reference

Read the previous integration/stabilization `RESULTS.md` and `REVIEW.md`, original acceptance source, direct SDK controls and recorded logs, including direct refund 180, combined refund 194 and fresh standalone 195 outcomes. Latest previous whole-suite evidence is 7/4 in each of three runs and random ordering; immediate corrected restart 3/3 and 77 unit tests are separate passing evidence.

Installed interfaces inspected:

- `.../Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/System/Library/Frameworks/StoreKit.framework/Modules/StoreKit.swiftmodule/arm64e-apple-ios.swiftinterface`: `finish() async`, `currentEntitlements`, `unfinished`, `updates`, generic `products<Identifiers: Collection>`.
- `.../Platforms/iPhoneOS.platform/Developer/Library/Frameworks/StoreKitTest.framework/Headers/SKTestSession.h`: reset/issue handling declarations and unsupported legacy failure-property annotations.
- The matching public `StoreKitTest.swiftinterface`: typed generic/purchase simulated failures.

Classification is provisional and evidence-specific. New properly controlled execution may change it; this document does not change any recorded PASS/FAIL acceptance result.

## New isolation evidence checkpoint

Read `PioStoreKitIsolationTests.swift`, the matched timeline/summary JSONs, readback-factor summaries, the interactive final-state attachment source and the actual review log. No runtime action was performed by this reviewer. The classifications above remain provisional; no result below converts the original 11-case run into PASS.

### Finish: fresh-process observation narrows the cache hypothesis

The direct seed purchases/awaits finish for space **198** and Cafe **199**. Its next OS process checks verified entitlements and unfinished **before constructing/resetting a new SKTestSession**. It finds the same verified IDs and still sees Cafe **199** unfinished. The direct seed and fresh verify both fail their diagnostic empty-unfinished assertions. Therefore this observation is not explained solely by one application's retained transaction object or an old process-local unfinished iterator.

The manager two-purchase seed/verify control for **202 / 203** passes with empty unfinished in its new process. That pass does not prove Pio universally fixes the direct result; the original full 13-product application test still fails, and the direct versus manager conditions/timing remain distinct. Preserve the primary SDK_DEPENDENT classification for observed readback and the UNRESOLVED cause. No new numerical Apple latency guarantee was found.

The harness uses saved transaction IDs solely to compare independently verified receipts. Fresh verification does not repurchase, sync, acknowledge, reinitialize or clear the session before its snapshot. Clearing in teardown occurs after the observation; it must not be counted as making unfinished pass.

### Refund: all new positive controls pass, so no single-query cause is established

Matched instrumented direct refund **197** and manager refund **201** both PASS in their supplied summaries/timelines. Four readback variants—no pre-refund readback, current-entitlements only, unfinished only, and both—also all PASS. These successes show that neither simply querying `currentEntitlements` nor simply querying `unfinished` is sufficient to force the prior notification failure under the new conditions.

They do not erase the earlier original full-suite refund failure, standalone application failures, or mixed direct controls. Instrumentation/setup differences and timing remain possible interaction factors. B remains **UNRESOLVED**. Neither a universal SDK notification defect nor a specific Pio wrapper/query fix follows from four positive runs whose no-readback control also passes. Set-versus-Array/order/cardinality remains a separate unproven hypothesis unless controlled evidence is added.

### Actual Cancel interaction is now distinct passing evidence

`ui-local/review.log` records the first interactive session's typed final state:

- purchase state completed with **cancelled**;
- ownership contains **Basic only**;
- equipped is Basic;
- busy is false.

The parent observed an Xcode/no-charge banner and used the actual Cancel control in that session. This reviewer independently read the typed state log, but did not operate or independently screenshot the UI. This supports **actual local Cancel → no unlock / busy cleared PASS** for that interaction. It does not make the public simulated-error injection test pass or certify purchase confirmation. The later reopened confirmation attempt had UI-coordinate/tool errors and remains **NOT_TESTED**, not a successful purchase or cancel proof.

The source addition to the existing review harness attaches the final manager state; a passing interactive test alone remains insufficient evidence without the observed action and corresponding state. Do not count elapsed harness waiting as an automated acceptance assertion.

### Result boundary

The newly rerun original eleven remain **7 PASS / 4 FAIL**. Core manager/wardrobe/catalog/application UI sources are reported unchanged for this isolation work; diagnostic tests and the final-state attachment do not constitute a production fix. No new APP_BUG or TEST_BUG is isolated by these positive controls. Overall completion remains **PARTIAL** with remaining contract/evidence gaps explicitly retained.
