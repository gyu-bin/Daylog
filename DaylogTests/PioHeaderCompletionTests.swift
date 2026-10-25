import XCTest
import Observation
@testable import Daylog

@MainActor final class PioHeaderCompletionTests: XCTestCase {
    func testGestureAutomaticallyReturnsToIdleWithoutAnotherTap() async throws {
        let interaction = PioHeaderInteraction()
        interaction.setActive(true)
        let run = try XCTUnwrap(interaction.respond())
        XCTAssertEqual(run.gesture, .greet)
        let returned = expectation(description: "The real gesture completion task returns to idle")
        withObservationTracking {
            _ = interaction.run
        } onChange: {
            Task { @MainActor in
                if interaction.run == nil { returned.fulfill() }
            }
        }
        await fulfillment(of: [returned], timeout: 5)
        XCTAssertNil(interaction.run)
        XCTAssertTrue(interaction.isActive)
        XCTAssertEqual(interaction.respond()?.gesture, .jump)
        interaction.setActive(false)
    }
}
