# Sandbox preparation — 2026-10-23

Status: **PARTIAL**. Build preparation and read-only device/signing inspection are recorded here. Genuine Apple Sandbox purchase, restoration, refund, cancellation and interruption are **NOT_TESTED**. Existing local unit/regression and restart evidence remains separate; it does not establish Sandbox readiness or release approval.

## Current application gates

Inspected `PioPurchaseManager.swift`, `PioProductRegistry.swift`, ordinary iOS Info.plist, project build settings and shared schemes.

| Environment | Selection | Accepted receipt environment | Current safety boundary |
| --- | --- | --- | --- |
| Xcode local | DEBUG `-pio-storekit-testing`, `Routimori.storekit` attached | `.xcode` | Existing dedicated schemes and test fixtures |
| Apple Sandbox | Bundle string `PioStoreKitEnvironment=sandbox`, Boolean `PioStoreKitCatalogConfirmed=true`, confirmed registry | `.sandbox` only | Ordinary build contains neither opt-in key; purchasing remains disabled |
| App Store/TestFlight policy | Explicit `appStore` bundle configuration | `.production` or `.sandbox` | Not enabled by this preparation |
| macOS nonlocal | Not available | None | Mac purchasing remains disabled outside explicit DEBUG local testing |

Nonlocal adapter preflight also requires a verified `AppTransaction`, matching signed app bundle and `Bundle.main.bundleIdentifier`. Each accepted purchase additionally needs a verified non-consumable receipt, expected environment, bundle and registered product. The registry's `isAppStoreConnectVerified=true` proves catalog identity only, not successful Sandbox QA. Never bypass these checks to resolve a local fixture failure.

The signed app receipt preflight does **not** guarantee SDK payment-sheet routing. Earlier local CLI evidence showed a local app receipt while the payment request went to a different environment. Inspect the actual scheme and returned transaction environment; do not infer Sandbox success from a label.

## Confirmed catalog, unchanged

App Store Connect app `6821788787`, bundle `com.mungyubin.daylog.ios`. The read-only evidence is [asc-products-confirmed.json](../pio-storekit-integration-2026-10-23/asc-products-confirmed.json). All thirteen are non-consumables, KOR configured price **₩2,500**; UI must use fetched `Product.displayPrice`.

```text
outfit.cherryblossom
outfit.summer
outfit.autumn
outfit.winter
outfit.halloween
outfit.christmas
outfit.hanbok
outfit.cafe
outfit.student
outfit.workout
outfit.rainy
outfit.pajamas
outfit.space
```

Captured ASC status was `MISSING_METADATA`, specifically review screenshots. No registration, price, screenshot, account or contract was changed. This status is not evidence that Sandbox product lookup must fail: Apple does not require submitting purchases for review before Sandbox testing. [Apple TN3186](https://developer.apple.com/documentation/technotes/tn3186-troubleshooting-in-app-purchases-availability-in-the-sandbox)

## Read-only workstation checks

- `security find-identity -v -p codesigning`: **1 valid Apple Development identity** visible with the required read access. This does not establish that its provisioning profile matches this app/team/device.
- `xcrun devicectl list devices`: paired physical **iPhone 14 Pro** available; simulators listed separately. Developer Mode, installed production app, test-device permission and Sandbox account status were not inspected.
- Restricted-shell probes initially reported zero identities/CoreDevice initialization timeout. The read-only elevated probes resolved this visibility limitation; do not report certificates/device absent from those first results.
- Project signing uses Automatic style, team `6YASPU77L7`, iOS deployment target 17.0. No signing/provisioning operation was performed.

## Reproducible build-only preparation

Run from the repository with a **new** evidence directory:

```sh
python3 Tools/pio-storekit/prepare-sandbox-build.py \
  --evidence docs/qa/pio-storekit-isolation-2026-10-23/sandbox-build \
  --package-cache /tmp/PioStoreKit-20261023-ios/SourcePackages
```

The helper refuses an existing output directory. It copies the ordinary Info.plist into a unique system temporary `pio-sandbox-build-*` directory and inserts a typed Boolean and Sandbox-only string there. It builds **Debug, generic iOS, unsigned**, with isolated DerivedData. Target-selected Info overrides preserve the widget extension's original plist. Nothing is installed or launched. No local-testing/free-wearing launch flag is introduced.

**Build preparation: PASS.** The unsigned generic-iOS build completed, both emitted plist checks passed, and protected normal configuration hashes remained unchanged. See [build evidence](sandbox-build/result.json) and [command](sandbox-build/command.json). Success requires the emitted app's original bundle ID, Boolean `true` (not string `YES`), Sandbox-only string, intact widget extension and identical protected-source hashes. A compiled unsigned app is **not runnable Sandbox verification**. It needs a correctly development-signed rebuild, not post-signing plist modification.

No new executable scheme was added: a scheme alone cannot supply the required typed bundle keys, and enabling normal Info/project defaults would erase the requested environment separation.

## Next steps for an authorized dedicated-device run — not performed

1. Use a dedicated device that does not contain the production app or production records. The confirmed bundle ID must stay unchanged; installing it over an existing copy could replace that app. A second fake bundle ID cannot access this verified catalog.
2. Verify the Apple Developer membership, active Paid Apps agreement, banking/tax information, explicit App ID with IAP capability, valid development provisioning and authorized device. Those account-side facts remain unverified. Product metadata changes can take up to an hour to propagate. [Apple TN3186](https://developer.apple.com/documentation/technotes/tn3186-troubleshooting-in-app-purchases-availability-in-the-sandbox)
3. Create/use a Sandbox Apple Account under the same developer membership. In ASC: Users and Access → Sandbox → Add, choose South Korea. An Account Holder, Admin, App Manager or Developer can create it; use an email never registered as an ordinary Apple Account. The human enters credentials directly on the dedicated device; do not store them in this repository or logs. [Create a Sandbox Apple Account](https://developer.apple.com/help/app-store-connect/test-in-app-purchases/create-a-sandbox-apple-account/)
4. Prepare an explicitly separate **Debug Sandbox** build configuration, using the generated temporary plist only for `DaylogiOS` and the unchanged widget plist for `DaylogWidgets`. Keep the original bundle, entitlements and CloudKit configuration. Verify the emitted plist again after rebuilding with valid development signing. Do not change the ordinary Debug/Release Info defaults or use `appStore` policy.
5. Duplicate the ordinary iOS Run scheme for this authorized run, select that separate configuration, and set Run → Options → **StoreKit Configuration: None**. Remove `-pio-storekit-testing` and `-pio-wardrobe-testing` from all enabled arguments. A synced `.storekit` file is still local testing, not Apple Sandbox. [Apple Xcode setup](https://developer.apple.com/documentation/xcode/setting-up-storekit-testing-in-xcode)
6. Set Debug launch arguments `-DaylogStoreName pio-sandbox-review`. The existing runtime routes this to a separate local store and disables runtime CloudKit participation; this does not modify its schema or configured entitlements. Sandbox wardrobe defaults and durable selection use their own profile. These safeguards do not make overwriting an installed production app acceptable.
7. Enable Developer Mode and, only with permission for this dedicated device, run the development-signed app from Xcode. Apple does not require a binary upload for this path. Sign in using the device's **Sandbox Apple Account** controls when available after the first purchase attempt; do not sign the Sandbox tester into the device's main iCloud account. Confirm the system sheet identifies Sandbox before proceeding. No TestFlight upload is part of this plan. [Apple Sandbox testing](https://developer.apple.com/documentation/storekit/testing-in-app-purchases-with-sandbox)

The user authorized genuine Sandbox work when a test-only account and suitable configuration are available. The temporary plist and unsigned build are prepared; dedicated-device status, absence of an installed production app, usable provisioning and test-account readiness remain unconfirmed. No signing, installation, account entry or launch was performed, to preserve the explicit no-production-replacement boundary. An available paired device or valid certificate alone does not establish these prerequisites. If a suitable device or tester account is unavailable, leave runtime status **NOT_TESTED** and retain the compiled artifact. Account creation and use of the currently paired device were not performed.

## Required genuine Sandbox evidence

Record device/OS, Xcode version, build/source identity, actual receipt `.sandbox` environment and product IDs. Never record credentials or signed receipt payloads.

| Check | Required observation | Current status |
| --- | --- | --- |
| Catalog | All 13 IDs fetched, KOR prices from Apple | NOT_TESTED |
| Unowned paid wear | Fresh account without verified ownership cannot equip any paid outfit; preview grants nothing | NOT_TESTED |
| Cancel | Human dismisses Apple's sheet; no unlock; retry works | NOT_TESTED |
| Interrupted purchase | Observe actual Sandbox resolution/receipt delivery; no test-driver assumptions | NOT_TESTED |
| Verified purchase | One expected product unlocks and equips only after verification | NOT_TESTED |
| Finish | Await acknowledgement; retain timestamped SDK unfinished readback | NOT_TESTED |
| Refund | Genuine Sandbox revocation delivery and effective Basic selection; compare fresh entitlement snapshot | NOT_TESTED |
| Restore | Explicit restore and fresh verified entitlement reconciliation | NOT_TESTED |
| Immediate relaunch | Different OS process, same verified entitlement, retained final selection; no injected ownership | NOT_TESTED |

For missing products, inspect identity, capability, provisioning and active agreements using TN3186; retain the actual error rather than adding aliases. Do not classify private server codes such as 907/3504 as user cancellation. A Simulator local-test result or direct `SKTestSession` ledger mutation must never be relabeled genuine Sandbox evidence.

## Ordered Sandbox acceptance run

After the prerequisites above are confirmed, use one dedicated Sandbox account with its initial ownership state recorded:

1. Fetch all thirteen products. Verify the system Sandbox environment and reject paid equipping while genuinely unowned; retain an independent preview/ownership check.
2. Open a paid product's system sheet and **cancel**. Assert no unlock, then immediately retry the same product.
3. Complete the retried **purchase**. Require a verified Sandbox receipt for that exact registered ID before ownership/equipment changes; record acknowledgement and unfinished readback separately.
4. Select Cafe → Basic → Cafe with Cafe genuinely owned, terminate the app process immediately, and **relaunch**. Record different PIDs, the same verified entitlement and the durable final preference; inject no ownership cache.
5. Exercise the explicit **restore** control and verify current entitlements and equipment after reconciliation. Do not erase app/device data merely to force this scenario.
6. Perform a test-account **refund** using the supported Sandbox workflow. Check live revoked receipt delivery, effective Basic and rejected paid re-equip; evaluate a later explicit entitlement reconciliation separately, retaining failure if live delivery is absent.
7. Repeat cancellation/retry, interruption and all thirteen product flows as needed within the same recorded test environment. Distinguish account purchase-history reset from refund: clearing Sandbox history is not itself proof of a refund notification.

No step in this acceptance sequence was executed by the build-preparation helper. This is the planned order for a genuine Sandbox run, not a relabeling of prior Xcode-local evidence.
