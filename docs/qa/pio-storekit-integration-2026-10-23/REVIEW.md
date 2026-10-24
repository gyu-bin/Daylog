# Independent StoreKit integration review — initial source checkpoint

Verdict: **PARTIAL / NOT PRODUCTION READY**. Reviewed source and existing evidence only. No application code was edited; no app was launched, no build/test was run, no Apple purchase was initiated, and no production preferences/data were modified by this reviewer. Other workers are implementing fixes concurrently; the findings below describe the inspected checkpoint, not future changes.

Scope: `PioProductRegistry`, `PioPurchaseManager` and real StoreKit adapter, `PioWardrobeStore`, wardrobe purchase/equip/restore UI, fixture purchase/wardrobe tests, `DaylogStoreKitTests/PioStoreKitIntegrationTests.swift`, and the existing 2026-10-16 StoreKit results report.

## Concrete correctness findings

### P2 — Restore can accept a pre-sync entitlement snapshot

`PioPurchaseManager.restore()` awaits `client.sync()` then calls `refreshEntitlements()`. That function coalesces with any existing `refreshTask`. A refresh begun before sync can already have captured an empty/stale snapshot. If no transaction update increments `entitlementRevision`, the pre-sync snapshot is still accepted and Restore can return `.restored([])` despite the newly synchronized ownership.

Meaningful regression: suspend a pre-sync empty snapshot; sync makes an external purchase available without emitting an updates event; call Restore; release the earlier snapshot; expect a fresh post-sync ledger and the purchased outfit. Existing `restoreJoiningRefreshWaitsForStableSnapshotAfterUpdate` covers only the revision-changing update case.

Recommendation: invalidate the entitlement revision after successful explicit sync before joining refresh, or require a new post-sync snapshot. Retain the existing serialized purchase/restore busy guard.

### P2 — A verified purchase result can report success without effective ownership

`purchase()` accepts a non-revoked matching transaction, awaits `receive`, and unconditionally returns `.purchased(outfit)`. `receive` deliberately refuses an ID already present in `revokedTransactionIDs`. Thus replaying a previously revoked transaction as a nominally non-revoked purchase result produces a purchased-success outcome while access remains locked. A concurrent revocation/unverified update during `finish` can similarly change effective ownership before the success result is returned.

Meaningful regression: record a revoked transaction ID, then make the purchase fixture return that ID with `revoked == false`; assert no unlock **and no purchased-success result**. Also suspend acknowledgement, deliver revocation, then complete acknowledgement. Do not weaken revoked-ID protection to make the test pass.

## Production blockers / configuration checks

- `PioPurchaseAvailability.current` currently enables only an explicit DEBUG local-testing flag; all ordinary and Release launches return disabled. The real adapter's preflight and accepted transaction filter require `.xcode`. This is intentional protection in the existing implementation and also means Sandbox/production are not implemented at this checkpoint. Do not remove the local no-real-charge guard from local testing while adding separate production policy.
- Registry IDs are currently mechanically derived from outfit raw values. Their equality to actual App Store Connect non-consumable IDs has not been verified by this reviewer. Parent is checking the authoritative account separately. Local configuration agreement alone cannot establish ASC agreement.
- `PioWardrobeStore.isFreeWearing` intentionally allows all costumes while the shop is disabled, including ordinary Release launches. This matches the earlier free-wear phase, but it must be an explicit distribution policy during the paid-shop transition; do not silently let a production configuration failure select a disabled state that also unlocks paid wear. Fixture tests default this behavior off through `RuntimeEnvironment.isRunningTests`, so they do not by themselves verify normal-launch free-wear policy.
- Local StoreKit and wardrobe-preview selections use isolated preference suites; purchase ownership is not read from UserDefaults. Production-enabled policy should be tested independently of both local testing flags and the free-wear phase. App icon permission remains ownership-gated, separate from wear permission.

## Existing positive structure

- Product loading filters real `Product` values to non-consumables. UI uses StoreKit `displayPrice`, and unavailable products cannot start purchase.
- Only verified, allow-listed transactions grant ownership; unverified payload IDs are used to deny/report, not to grant.
- Purchase/restore are mutually excluded by busy state. Pending, cancellation and failures have distinct outcomes; owned non-consumables do not purchase again.
- Transaction updates have a cancellable listener. Finish operations coalesce by transaction ID and joining callers await acknowledgement.
- The ledger tracks active transaction identities and revoked tombstones; a late old refund is reconciled before permanently resetting an otherwise valid preference.
- Refresh errors preserve already verified in-memory ownership; unknown initial ownership does not trust saved outfit/icon selections or legacy mock ownership. Stored preference can survive temporary inability to verify.
- Purchase completion and equipping are distinct UI actions. Test/UI evidence must therefore cover both rather than treating unlock as automatic equip.

## Evidence and meaningful validation gaps

Existing `STOREKIT-RESULTS.md` is explicit about the earlier failures: latest historical full iOS run **7/11 PASS, 4 FAIL**, historical full Mac run **8/11 PASS, 3 FAIL**, and separate 13-outfit/finish-observation runs passed. Those historical isolated passes do not replace a clean full-suite pass for the current code. The report also records actual local iPhone purchase/cancel/equip/relaunch/restore for one Cherry Blossom product; Mac Apple purchase-sheet verification remained incomplete. This reviewer read that report and test source, not every historical result bundle.

Fixture tests meaningfully cover verified grant, cancellation/pending/rejection, duplicate operations, refresh failure, preference repair, manager reload, explicit restore, verification denial, updates/refunds, old-refund/new-purchase ordering, finish coalescing and isolated defaults. They cannot verify Apple signature/environment handling or transaction delivery behavior.

The real StoreKitTest suite has source cases for 13-product load and price display, purchase/equip/reloaded manager, Ask to Buy, refund, restore, injected errors, verification failure and interruption. The test named relaunch creates a fresh manager in the same process; it is not actual application-process restart evidence.

Required current acceptance evidence:

1. Authoritative ASC IDs and non-consumable configuration for all 13 products; missing/unavailable product UI.
2. Verified local purchase → unlock → explicit equip → new process → entitlement reload → retained selection → explicit restore, on isolated test data.
3. Pending approval, cancel, fail/retry, refund, repurchase/late old refund, interruption, verification denial and no unfinished verified transaction leaks.
4. Restore pre-sync-snapshot and stale/revoked purchase-success races described above.
5. Cold offline launch versus already-running offline refresh, with preserved preference and no unsupported ownership grant; cached StoreKit ledger behavior must be observed through the real adapter rather than inferred from the fixture error test.
6. Normal launch, local StoreKit flag, wardrobe free-preview flag, and production policy: no unintended crossover of ownership or saved preferences.
7. Sandbox/real-device validation remains separately NOT_TESTED until actually performed. No actual charge is authorized by this review.

Do not describe the system as production-ready based on local configuration, source review, fixture tests, or the historical partial runs.

## Follow-up source review — concurrency fixes

Both concrete P2 findings are **CLOSED AT SOURCE LEVEL; current execution evidence pending**.

- Restore now increments `entitlementRevision` immediately after successful explicit sync. An in-flight pre-sync snapshot is rejected/retried. The refresh join path also compares `lastRefreshRevision` and uses a task token when clearing the coalesced task, preventing a retained completed pre-sync result from being reused or a newer task from being erased by an older waiter. Read the new held-empty-snapshot/no-update regression test; it requires a third snapshot and restored Cafe ownership.
- Snapshot-observed revoked transaction IDs are now tombstoned, not merely filtered. After `receive` and acknowledgement, purchase success requires effective ownership and a non-tombstoned transaction ID. New test source covers a stale formerly revoked ID and revocation while acknowledgement is suspended. This preserves refusal of stale grants instead of weakening verification to force success.

The adapter now has an explicit local/sandbox/App Store environment policy and a verified app-transaction preflight. Local mode remains Xcode-only; Apple modes reject Xcode transactions. Release cannot use the local-testing adapter path. The production gate remains conditional on separate catalog confirmation, and root-owned registry/config updates were in progress during this source re-review. Therefore the initial environment-policy blocker is structurally addressed, **but actual ASC configuration, App Store/Sandbox execution, and release activation remain unverified** by this reviewer.

No tests were executed by the reviewer. Read source changes do not supersede the earlier full StoreKitTest failures or establish new runtime results.

## Final integration source re-review

Status: **PARTIAL / production activation remains blocked**. No new actionable P1/P2 implementation defect was identified in this final source pass; the release blockers below remain material. No builds, tests or payments were run by the reviewer.

### Catalog and environment identity

Independently parsed the recorded read-only ASC evidence (`asc-products-confirmed.json`), the current explicit Swift registry, and `Routimori.storekit`: all **13 product IDs match**, and every local entry is non-consumable with `displayPrice` configuration `2500.00`. Recorded ASC Korean price is **KRW 2,500**, superseding the earlier KRW 2,000 target. This is a check against the parent's recorded live ASC evidence, not a second reviewer login or Sandbox product fetch.

The explicit raw-value→product-ID mapping correctly handles differing names such as `fitness → outfit.workout`, `astronaut → outfit.space`, `summerVacation → outfit.summer`. The prior mechanically-derived-ID blocker is closed at recorded catalog/configuration level.

Ordinary Mac real IAP is intentionally disabled because the verified catalog belongs to the iOS bundle. Apple-mode preflight checks both verified AppTransaction bundle identity and running bundle identity, and accepted transactions check their app bundle identity as well as environment, product type and allow-list. Xcode mode remains separately gated; sandbox/App Store policy rejects Xcode receipts. iOS activation remains closed because no commercial configuration gate was enabled. These are deliberate safeguards, not evidence that enabled Sandbox purchases passed.

### Ownership/UI policy

Normal-launch free wearing no longer follows store unavailability: `isFreeWearing` is now restricted to the explicit isolated DEBUG wardrobe playground. The earlier fail-open transition concern is closed. Missing products remain locked and purchase-disabled. Purchase presentation uses Apple `displayName` and `displayPrice` after product loading; fallback catalog titles do not invent a purchasable price.

The mutable selected-outfit purchase callback snapshots `requestedOutfit` before spawning its task. A completion for an outfit no longer selected is routed to a notice rather than mislabelled as the new selection's result. The separate preview sheet uses an immutable outfit. Busy-state disabling and manager serialization remain in place. These are source observations, not UI interaction evidence.

### Cross-process proof script safety

Read `Tools/pio-storekit/process-relaunch.py`, its dedicated scheme, and `PioStoreKitProcessRelaunchTests` without executing them. The script uses a dedicated `com.daylog.verify` build identity and verify entitlements, refuses to overwrite an existing output directory, creates UUID-named preference evidence, runs distinct seed/verify invocations, restricts each invocation to the intended test method, and requires actual Passed test nodes rather than accepting a skipped harness. Tests require explicit local flags plus UUID/phase and verified `.xcode` AppTransaction before resetting or purchasing. Verify compares OS PIDs and the same verified transaction identity before clearing the local ledger. It does not inject a persisted ownership list.

Execution still must be serial because the local StoreKit ledger is shared; the script does not acquire a machine-wide coordination lock. If interrupted between phases, the UUID preference suite/local fixture can remain for diagnosis. That is not production-data mutation, but cleanup should be recorded after an aborted run. No process-relaunch PASS follows from source inspection.

### Remaining release blockers

- **P1 commercial readiness:** recorded ASC evidence reports all 13 products in `MISSING_METADATA`, specifically lacking required App Store review screenshots. Product identity correctness does not make the products approved or commercially available.
- **P1 delivery/description consistency:** `APP_STORE_CONNECT_PRODUCTS.md` records that the original seven ASC descriptions promise dedicated alternate app icons. `PioAppIconService.registeredThemes` remains empty. Before sale, provide the promised registered icon themes or obtain a deliberate metadata correction. Do not claim purchase delivers icon switching today. This review changed neither artwork nor ASC metadata.
- **P2 validation:** final unit/build results were still running at this checkpoint; real current local StoreKit full-suite, cross-process reload, cold offline, pending/refund/interruption behavior and iOS Sandbox remain separate acceptance evidence. Historical partial failures remain preserved above.

Only this QA review document was changed by the reviewer during the integration review.

## Current executed-evidence checkpoint and relaunch-script update

Independently read the supplied execution records (reviewer did not run another session):

- `mac-unit-v4.log` explicitly reports **69 tests in 7 suites PASS** and `TEST SUCCEEDED`.
- `mac-release-build.log` and `ios-release-build.log` end in **BUILD SUCCEEDED**. This is build evidence, not sale/Sandbox approval.
- `ios-ide-local-v1-summary.json` records the isolated `Pio StoreKit Local 2026-10-23` simulator, **7 PASS / 4 FAIL / 8 skipped**. The four failures are cancellation-error injection, final verified unfinished `outfit.space` readback, interrupted-purchase early grant, and refund-update timeout. The eight skipped tests are not acceptance passes. Do not collapse this into an all-green purchase system.
- In the focused finish diagnostic log, the final `outfit.space` transaction (`id=32` in that run) is cached when requested, has `inFlight=0`, logs finish begin and finish returned approximately 1ms apart. That shows the app called/awaited the real adapter acknowledgement; it does not explain why StoreKit's unfinished readback remains nonempty, prove an SDK defect, or close the failed acceptance test. Keep raw failure evidence.

The new diagnostic ring is DEBUG-only and exact-local-flag gated, bounded to 256 entries. It records transaction identity/product/revocation and acknowledgement timing, not signed payloads or account credentials. No new production logging risk was found in this source pass. Tests are not weakened by mapping private cancellation code 907 to public cancellation or by acknowledging transactions from the test observer.

### Relaunch script: optional iOS destination

The updated script validates a literal simulator UUID and requires its inventoried name to start `Pio StoreKit Local `, uses that exact destination throughout, enables only the explicit two-phase test method, and keeps per-run UUID preferences. Mac still uses the separate verification build identity. It requires explicit `--seed-method` selection, distinguishing the real `Product.purchase` result from `SKTestSession.buyProduct` setup. This distinction must remain in the final report.

**Known routing limitation remains:** the iOS branch invokes CLI build/test on the StoreKit scheme. The documented empirical observation that CLI Product.purchase can route to Sandbox despite a verified Xcode AppTransaction is not solved by UUID/name guards. Those guards isolate the device; they do not bind Apple's payment UI routing. Run it only as a bounded diagnostic with the active local configuration correctly bound, stop on unexpected account/Sandbox prompts, and never enter real credentials. A failed or hanging Product.purchase seed is not a relaunch pass. A passing test-driver seed can establish ledger/process persistence but not application purchase-flow/UI success.

This checkpoint has no additional actionable source P1/P2 finding beyond the unresolved integration failures and previously documented release blockers. Core purchase UI/ownership code remains source-reviewed; actual rendered UI and process-relaunch results must be attached separately when available. The final verdict is still **PARTIAL**, not production-ready.

## Final evidence follow-up — delayed cross-process proof

Overall verdict remains **PARTIAL**. Independently read `ios-process-relaunch-v3/diagnostic-verify.log`:

- A fresh OS process **PID 76629** differs from seed **PID 73700**.
- The seed method is recorded as **`product-purchase`**, not a StoreKitTest driver grant.
- The same verified Xcode Cafe transaction **ID 36** is recovered; fresh manager owns Cafe and the wardrobe is equipped with Cafe.
- The diagnostic records the UUID preference keys present on disk by this later run.
- `testVerifyLedgerAndEquipmentInFreshProcess` actually **PASSed 1/1**, followed by explicit fixture cleanup.

This is meaningful executed evidence for verified ledger and selection persistence across OS processes. It occurred roughly five minutes after the seed. It does **not** turn the earlier bounded five-second disk-persistence assertion or the automated seed→verify runner into PASS. The immediate two-phase flow remains incomplete: v1 seed actual purchase passed but its new process lacked preference metadata; v2/v3 bounded flush checks failed despite in-process UserDefaults/CFPreferences keys. The later v3 verify ran separately without repurchase, explicit sync or injected ownership. Therefore label cross-process acceptance **PARTIAL: delayed ledger + preferences proof PASS; immediate automated two-phase proof FAIL**. Do not attribute the fixture's delayed disk visibility to a confirmed production UserDefaults defect.

The separate fresh-process refund test also passed, while the latest full actual StoreKit run remains **7 PASS / 4 FAIL**. A single isolated refund pass does not erase the full-suite update timeout. The ledger proof does not resolve cancellation-injection behavior, interruption, final unfinished-transaction readback, cold offline, or Sandbox/physical-device acceptance.

### RESULTS.md consistency check

At review time `RESULTS.md` still described cross-process status as plain FAIL in its table and several narrative sentences. Parent was notified to revise those statements to the precise PARTIAL distinction above. Historical seed/runner failures must remain visible alongside the later successful diagnostic. No reviewer runtime session was launched and no application/test source was edited for this follow-up.
