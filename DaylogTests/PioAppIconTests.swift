import Testing
@testable import Daylog

@MainActor
struct PioAppIconTests {
    @Test func missingPremiumIconFilesCannotBeSelected() {
        #expect(PioAppIconService.registeredThemes.isEmpty)
        for outfit in PioOutfitID.allCases where outfit != .basic {
            #expect(!PioAppIconService.isAvailable(outfit, info: [:]))
            #expect(!PioAppIconService.canSelect(outfit, store: PioWardrobeStore()))
        }
    }

    @Test func cancellationIsSilentAndPendingNeverSaysOwned() {
        #expect(PioWardrobeEntitlementResult.cancelled.wardrobeMessage == nil)
        #expect(PioWardrobeEntitlementResult.pending.wardrobeMessage?.contains("승인") == true)
        #expect(PioWardrobeEntitlementResult.unverified.wardrobeMessage?.contains("잠겨") == true)
    }
}
