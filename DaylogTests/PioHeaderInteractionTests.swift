import XCTest
import QuartzCore
@testable import Daylog

@MainActor final class PioHeaderInteractionTests: XCTestCase {
    func testResponsesAreBoundedAndDoNotOverlap() throws {
        let interaction = PioHeaderInteraction()
        XCTAssertNil(interaction.respond())
        interaction.setActive(true)
        for expected in PioHeaderGesture.tapGestures {
            let run = try XCTUnwrap(interaction.respond())
            XCTAssertEqual(run.gesture, expected)
            XCTAssertNil(interaction.respond())
            XCTAssertTrue(interaction.complete(run))
            XCTAssertNil(interaction.run)
        }
    }
    func testLeavingScreenCancelsAndRejectsStaleCompletion() throws {
        let interaction = PioHeaderInteraction(); interaction.setActive(true)
        let old = try XCTUnwrap(interaction.respond())
        interaction.setActive(false)
        XCTAssertNil(interaction.run);XCTAssertNil(interaction.respond())
        interaction.setActive(true)
        let current = try XCTUnwrap(interaction.respond())
        XCTAssertNotEqual(current.token,old.token)
        XCTAssertFalse(interaction.complete(old));XCTAssertEqual(interaction.run,current)
        interaction.resetResponse();XCTAssertNil(interaction.run)
    }
    func testProgressReactionDoesNotConsumeTapSequence() throws {
        let interaction = PioHeaderInteraction(); interaction.setActive(true)
        let rest = try XCTUnwrap(interaction.respond(to: .rest))
        XCTAssertEqual(rest.gesture, .rest);XCTAssertTrue(interaction.complete(rest))
        let tap = try XCTUnwrap(interaction.respond())
        XCTAssertEqual(tap.gesture, .greet);interaction.setActive(false)
    }
    func testProductionFallbackUsesOnlyAvailableMotionsForAllOutfits() {
        for outfit in PioOutfitID.allCases {
            for gesture in PioHeaderGesture.allCases {
                let motion = gesture.motion(for: outfit, independent: false)
                XCTAssertTrue(PioOutfitCapabilities(outfit: outfit).supportedMotions.contains(motion))
                XCTAssertNotEqual(motion, .idle)
            }
        }
        XCTAssertEqual(PioHeaderGesture.greet.motion(for: .basic, independent: false), .wave)
        XCTAssertEqual(PioHeaderGesture.greet.motion(for: .hanbok, independent: false), .bounce)
        XCTAssertEqual(PioHeaderGesture.greet.motion(for: .hanbok, independent: true), .wave)
    }
    #if DEBUG
    func testNativeHeaderReusesJointsWithTinyIdleAndFiniteTapTracks() throws {
        let stage = PioHeaderMotionStage()
        let bounds = CGRect(x:0,y:0,width:80,height:80)
        stage.update(outfit:.christmas,gesture:nil,active:true,bounds:bounds)
        for id in ["gift","handLeft","handRight"] {
            let track = try XCTUnwrap(stage.rig.layers[id]?.animation(forKey:"transform.rotation.z") as? CAKeyframeAnimation)
            let values = try XCTUnwrap(track.values as? [NSNumber]).map(\.doubleValue)
            XCTAssertLessThanOrEqual(values.map(abs).max() ?? 0,0.13 * .pi / 180)
        }
        stage.update(outfit:.christmas,gesture:.greet,active:true,bounds:bounds)
        for layer in [stage.rig.movement]+Array(stage.rig.layers.values) {
            for key in layer.animationKeys() ?? [] { XCTAssertEqual(layer.animation(forKey:key)?.repeatCount,0) }
        }
        stage.halt();XCTAssertEqual(stage.animationCount,0)
        stage.update(outfit:.hanbok,gesture:nil,active:false,bounds:bounds)
        XCTAssertFalse(stage.isActive);XCTAssertEqual(stage.animationCount,0)
    }
    #endif
}
