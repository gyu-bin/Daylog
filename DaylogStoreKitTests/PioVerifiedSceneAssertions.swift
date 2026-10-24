#if DEBUG
import XCTest
@testable import Daylog

/// Used only after the local fixtures verify Apple's Xcode receipts. This is
/// programmatic integration evidence, not wardrobe taps or payment UI evidence.
@MainActor
func assertEquippedSceneConsistency(_ wardrobe: PioWardrobeStore, expected: PioOutfitID,
                                   file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertFalse(wardrobe.isOutfitTestingEnabled, file: file, line: line)
    XCTAssertTrue(wardrobe.owns(expected), file: file, line: line)
    let coordinator = PioAppearanceCoordinator(wardrobe: wardrobe)
    let contexts: [PioAppearanceContext] = [.dashboard, .cloudDownloading, .cloudCompleted,
                                           .cloudFailed, .vacationDay, .vacationNight]
    for context in contexts {
        let appearance = coordinator.resolve(context: context)
        XCTAssertEqual(appearance.outfit, expected, "\(context)", file: file, line: line)
        XCTAssertEqual(appearance.requestedOutfit, expected, file: file, line: line)
        XCTAssertEqual(appearance.access, expected == .basic ? .free : .verified, file: file, line: line)
        XCTAssertFalse(appearance.isPreview, file: file, line: line)
        XCTAssertFalse(appearance.isAwaitingVerification, file: file, line: line)
        if PioOverhaulTrial.isEnabled || context == .dashboard || context == .vacationDay || context == .vacationNight {
            XCTAssertTrue(appearance.outfitApplied, "\(expected)/\(context)", file: file, line: line)
            XCTAssertNotNil(appearance.artwork.assetName, file: file, line: line)
        }
        // Previewing another costume must not change ownership or selection.
        let owned = wardrobe.ownedOutfits
        _ = coordinator.preview(outfit: expected == .astronaut ? .basic : .astronaut, stage: 4, context: context)
        XCTAssertEqual(wardrobe.ownedOutfits, owned, file: file, line: line)
        XCTAssertEqual(wardrobe.equippedOutfit, expected, file: file, line: line)
    }
    print("PIO_VERIFIED_SCENES outfit=\(expected.rawValue) contexts=\(contexts.map(\.rawValue).joined(separator: ",")) layeredTrial=\(PioOverhaulTrial.isEnabled) ownership=verified-Xcode-fixture previewMutation=false")
}
#endif
