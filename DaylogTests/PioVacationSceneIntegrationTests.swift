import Foundation
import Testing
import QuartzCore
#if os(macOS)
import AppKit
#else
import UIKit
#endif
@testable import Daylog

@MainActor
struct PioVacationSceneIntegrationTests {
    @Test func allThirteenOutfitsHaveNativeDayAndNightArtworkWithTransparentPixels() throws {
        var names = Set<String>()
        for outfit in PioOutfitID.allCases where outfit != .basic {
            for night in [false, true] {
                let context: PioAppearanceContext = night ? .vacationNight : .vacationDay
                let name = try #require(PioVacationSceneResources.assetName(outfit: outfit, context: context))
                names.insert(name)
                #expect(PioVacationSceneResources.sourceAsset(outfit: outfit, night: night) == name)
                #expect(PioVacationSceneResources.isCandidateAsset(name))
                #expect(PioVacationSceneResources.missingIndependentLayers(outfit: outfit, context: context).count == 3)
                #if os(macOS)
                let native = try #require(NSImage(named: name))
                let image = try #require(native.cgImage(forProposedRect: nil, context: nil, hints: nil))
                #else
                let image = try #require(UIImage(named: name)?.cgImage)
                #endif
                #expect(image.width == 1024 && image.height == 1536)
                #expect([CGImageAlphaInfo.premultipliedFirst, .premultipliedLast, .first, .last].contains(image.alphaInfo))
            }
        }
        #expect(names.count == 26)
        #expect(PioVacationSceneResources.assetName(outfit: .basic, context: .vacationDay) == nil)
        #expect(PioVacationSceneResources.assetName(outfit: .christmas, context: .dashboard) == nil)
        #expect(PioVacationSceneResources.sourceAsset(outfit: .basic, night: true) == "routimori_vacation_hammock_night")
        #expect(PioVacationSceneResources.missingIndependentLayers(outfit: .basic, context: .vacationNight).isEmpty)
    }

    @Test func everyCandidateRegistrationKeepsPivotFixedAndBeachStationaryAtSwayExtremes() throws {
        for outfit in PioOutfitID.allCases where outfit != .basic {
            let rig = RoutimoriVacationRig(outfit: outfit)
            for night in [false, true] {
                let name = PioVacationSceneResources.sourceAsset(outfit: outfit, night: night)
                let registration = PioVacationSceneResources.registration(asset: name, night: night)
                let slot = CGRect(x: 20, y: 250, width: 350, height: 250)
                rig.layout(in: CGRect(x: 0, y: 0, width: 390, height: 780), slot: slot, isDark: night, displayScale: 3)
                #expect(rig.currentRegistration == registration)
                #expect(registration.swingDegrees == 0.55)
                #expect(rig.hammock.position == registration.attachment)
                let mappedFocus = rig.canvas.convert(registration.focus, to: rig.root)
                #expect(abs(mappedFocus.x - slot.midX) < 0.001 && abs(mappedFocus.y - slot.midY) < 0.001)
                for angle in [-registration.swingDegrees, registration.swingDegrees] {
                    rig.hammock.transform = CATransform3DMakeRotation(angle * .pi / 180, 0, 0, 1)
                    let mapped = rig.hammock.convert(registration.attachment, to: rig.canvas)
                    #expect(abs(mapped.x - registration.attachment.x) < 0.001)
                    #expect(abs(mapped.y - registration.attachment.y) < 0.001)
                    #expect(CATransform3DIsIdentity(rig.beach.transform))
                }
                rig.hammock.transform = CATransform3DIdentity
                rig.setAnimating(true)
                let animation = try #require(rig.hammock.animation(forKey: "hammockSway") as? CAKeyframeAnimation)
                let boxedValues = try #require(animation.values as? [NSNumber])
                #expect(boxedValues.count == 5)
                #expect(abs(boxedValues[1].doubleValue - Double(registration.swingDegrees * .pi / 180)) < 0.0001)
                #expect(rig.beach.animationKeys()?.isEmpty ?? true)
                rig.setAnimating(false)
                #expect(rig.hammock.animationKeys()?.isEmpty ?? true)
                #expect(CATransform3DIsIdentity(rig.hammock.transform))
            }
        }
        // Mathematical pivot invariance does NOT approve the painted rope roots.
    }

    @Test func pendingVerificationShowsOnlyBeachAndStopsAnyPreviousForegroundMotion() {
        let rig = RoutimoriVacationRig(background: nil, foreground: nil)
        for pending in [PioAppearanceAccess.checking, .verificationUnavailable] {
            rig.setCharacterVisible(true)
            rig.setAnimating(true)
            rig.setCharacterVisible(PioVacationSceneResources.shouldShowCharacter(access: pending))
            #expect(rig.hammock.isHidden)
            #expect(rig.hammock.animationKeys()?.isEmpty ?? true)
            rig.setAnimating(true)
            #expect(rig.hammock.animationKeys()?.isEmpty ?? true)
            #expect(!rig.beach.isHidden)
        }
        for ready in [PioAppearanceAccess.free, .verified, .testing, .notOwned, .unavailable] {
            #expect(PioVacationSceneResources.shouldShowCharacter(access: ready))
        }
    }

    @Test func reduceMotionAndInactiveOrInvisibleScenesRemoveForegroundAnimation() throws {
        let rig = RoutimoriVacationRig(background: nil, foreground: nil)
        for visible in [true, false] {
            for active in [true, false] {
                for reduce in [false, true] {
                    let animates = PioVacationSceneResources.shouldAnimate(visible: visible, sceneActive: active, reduceMotion: reduce)
                    #expect(animates == (visible && active && !reduce))
                    rig.setAnimating(animates)
                    #expect((rig.hammock.animation(forKey: "hammockSway") != nil) == animates)
                    if !animates { #expect(CATransform3DIsIdentity(rig.hammock.transform)) }
                }
            }
        }
    }
}
