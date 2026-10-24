# Wardrobe split and explicit test wear review

2026-10-16. Read-only source review; no app/test edits, builds or test runs by reviewer. This scope is the new standalone wardrobe navigation, split catalog/preview, explicit Debug wear permission and dedicated playground harness. Earlier dirty artwork/StoreKit/global-renderer work is not attributed to this task.

## Findings

### Resolved P2 — direct wardrobe route is not represented in compact navigation

`AppSection.phoneTabs` excludes `.wardrobe`, but `TabNavigation.tab(for:)` in `RootView.swift` returns `.wardrobe` unchanged through its default case. The new iOS playground launch script and interactive test both set `app.section = .wardrobe`. On an iPhone this selects a TabView tag with no content; a wide iPad resized to compact while on wardrobe reaches the same mismatch. Home's existing iOS sheet path remains valid, but it does not implement this direct section route. Handle wardrobe in compact navigation through a supported tab or explicit sheet presentation and return a represented selection.

### Resolved P2 — standalone wear flag can promise a home change that is not rendered

`AppSection.isAvailable` accepts the Debug `-pio-wardrobe-testing` flag by itself, and `PioWardrobeStore.canWear` then permits every costume. Home presentation still requires `PioOutfitMotionView.isTrialEnabled` (the separate Routimori opt-in). `PioWardrobeView` unconditionally says applying updates home and reports successful home application. Thus launching Debug with the explicit wear flag alone exposes a successful apply flow while the old home character remains. The dedicated schemes set both flags, so their intended path is unaffected. Align the effective rendering condition or the availability/success wording.

## Verified source properties

- The wear flag parser and initializer are both DEBUG guarded; Release forces the permission false even under explicit injection. `canWear` is separate from `owns` and verified transaction state; actual entitlement and app-icon checks are not bypassed. Coordinator uses a distinct `.testing` access value and explains that wear is not purchase.
- Test outfit selections use a separate suite from production and local StoreKit preferences. DevicePreferences.shared switches to a test suite only in explicit Debug wear mode. Entitlement reconciliation retains authorized test wear without granting icon ownership.
- Dedicated playground schemes are Debug-only, have no StoreKit configuration or purchase flag, and explicitly whitelist the playground test. The test host uses existing in-memory/nil-CloudKit XCTest rules; ordinary scheme launches use a separately named local store. No payment-session/transaction seeding is performed by the new test.
- Catalog selection changes only local preview state. The explicit wear action persists selection. A wide layout at 760pt or more divides available width approximately equally; narrow/accessibility layouts stack preview and catalog. Actual clipping, Dynamic Type and interaction require native verification.
- Existing Settings shortcut stays Command-8; Wardrobe uses Command-9. Existing phone tabs retain their five-item structure. Settings no longer embeds the wardrobe, and the Mac home button routes to the new section.
- Artwork is referenced by existing asset names; no cropping/splitting or new fully rigged/four-stage claim is introduced. Stage control explicitly states the same art is used at stages1–4 and does not change XP. Premium icon changes remain unavailable.

## Evidence scope

Independently read parent-supplied `mac-build-tests.log`: **70 tests in five suites passed**, with `TEST SUCCEEDED` and result bundle `/tmp/Routimori-wardrobe-split-unit.xcresult`. This verifies the executed focused tests, not the untested direct compact-navigation route, native pixel layout or Release compilation. The source-reviewed new fixtures distinguish test wear from entitlement/icon ownership and check isolated preference persistence. Parent owns runtime and remaining build verification.

## Follow-up: both navigation/rendering findings resolved

The compact RootView now explicitly hosts the available wardrobe section inside a NavigationStack with a “오늘로 돌아가기” action. The tab mapper additionally maps `.wardrobe` to `.dashboard`, so no unsupported TabView tag is selected. The explicit branch also covers switching a wide iPad wardrobe into compact navigation. This resolves the first finding by source inspection; native iPhone/resize verification is still owned by the parent.

`RoutimoriSplashTrial.enabled(character:arguments:)` now activates the shared character condition for the exact Debug wardrobe-testing flag alone, and always returns false in Release. `PioOutfitMotionView.isTrialEnabled` consumes that shared condition, aligning wardrobe availability, test wear and home rendering. A focused test covers the flag alone, ordinary-off behavior and the Release-false branch. This resolves the second finding by source inspection; the parent is compiling both platforms and running the new test.

The explicit Apply button now has a full-width accent background, plain button style and at least48pt height, retains its availability/current-outfit disable rules, and remains the only catalog flow that equips. Selection accessibility traits are explicitly removed from unselected cards. No additional material source finding was found in this correction.

Parent reports actual Mac50/50 layout, Cherry Blossom selection changing preview only, purchase-free Apply, and home accessibility evidence showing Cherry Blossom in testing mode. This reviewer did not operate or disturb the live app and treats those as parent-provided native evidence, separate from the independently read70-test log above. No application source edits or build/test executions by reviewer.
