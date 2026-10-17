import Testing
import QuartzCore
@testable import Daylog

@MainActor
struct RoutimoriSplashTests {
    @Test func wardrobeTestingAloneActivatesTheMatchingCharacterSurfaces() {
        #if DEBUG
        #expect(RoutimoriSplashTrial.enabled(character: nil, arguments: ["Daylog", "-pio-wardrobe-testing"]))
        #expect(RoutimoriSplashTrial.enabled(character: "routimori", arguments: []))
        #expect(!RoutimoriSplashTrial.enabled(character: nil, arguments: []))
        #else
        #expect(!RoutimoriSplashTrial.enabled(character: "routimori", arguments: ["-pio-wardrobe-testing"]))
        #endif
    }

    @Test func animationStopsAndRestartsWithoutChangingTheRestingPose() {
        let rig = RoutimoriSplashRig(image: nil)
        let wingPosition = rig.wing.position
        rig.setAnimating(true)
        #expect(rig.wing.animation(forKey: "greeting") != nil)
        #expect(Set(rig.character.animationKeys() ?? []) == ["breathing", "tilt"])
        // Repeated SwiftUI updates must not accumulate extra animation tracks.
        rig.setAnimating(true)
        #expect(rig.wing.animationKeys() == ["greeting"])
        #expect(Set(rig.character.animationKeys() ?? []) == ["breathing", "tilt"])
        rig.setAnimating(false)
        #expect(rig.wing.animationKeys()?.isEmpty ?? true)
        #expect(rig.character.animationKeys()?.isEmpty ?? true)
        #expect(CATransform3DIsIdentity(rig.wing.transform))
        #expect(CATransform3DIsIdentity(rig.character.transform))
        #expect(rig.wing.position == wingPosition)
        rig.setAnimating(true)
        #expect(rig.wing.animation(forKey: "greeting") != nil)
        #expect(Set(rig.character.animationKeys() ?? []) == ["breathing", "tilt"])
        rig.setAnimating(false)
    }

    @Test func independentWaveKeepsItsSourceShoulderFixed() {
        let rig = RoutimoriSplashRig(image: nil)
        let shoulder = RoutimoriSplashRig.point(RoutimoriSplashRig.shoulder)
        for angle: CGFloat in [-10, 0, 8] {
            rig.wing.transform = CATransform3DMakeRotation(angle * .pi / 180, 0, 0, 1)
            let mapped = rig.wing.convert(shoulder, to: rig.character)
            #expect(abs(mapped.x - shoulder.x) < 0.0001)
            #expect(abs(mapped.y - shoulder.y) < 0.0001)
            #expect(CATransform3DIsIdentity(rig.body.transform))
        }
    }
}
