#if DEBUG
import Testing
import QuartzCore
@testable import Daylog

@MainActor
struct PioOverhaulRigTests {
    @Test func allFourteenOutfitsResolveWithoutReplacingOriginalPilots() throws {
        #expect(PioOutfitID.allCases.count == 14)
        for outfit in PioOutfitID.allCases {
            let manifest = try #require(PioOverhaulResources.manifest(outfit))
            #expect(manifest.canvas == 1254)
            #expect(manifest.outfit == outfit.rawValue)
            for part in manifest.parts {
                let image = try #require(PioOverhaulResources.image(part.asset))
                #expect(image.width == Int(part.rect[2]))
                #expect(image.height == Int(part.rect[3]))
                #expect(part.rect[0] >= 0 && part.rect[1] >= 0)
                #expect(part.rect[0] + part.rect[2] <= 1254)
                #expect(part.rect[1] + part.rect[3] <= 1254)
            }
        }
        #expect(PioLayeredTrial.approvedOutfits.count == 4)
    }

    @Test func heldPropsShareTheirHandJointAndAnimation() throws {
        let groups: [(PioOutfitID,[String])] = [
            (.christmas,["gift","handLeft","handRight"]),
            (.pajamas,["pillow","wingLeft","wingRight"]),
            (.rainyDay,["umbrellaCanopy","umbrellaShaft","wingRight"]),
            (.summerVacation,["drink","wingRight"]),
            (.student,["prop","wingLeft"]),(.cafe,["prop","wingLeft"]),
            (.halloween,["bag","wingRight"]),(.fitness,["dumbbellLeft","wingLeft"])
        ]
        for (outfit,ids) in groups {
            let rig = PioOverhaulRig();rig.configure(outfit,action:.celebrate);rig.setActive(true)
            let first = try #require(rig.layers[ids[0]])
            let firstAnimation = try #require(first.animation(forKey:"transform.rotation.z") as? CAKeyframeAnimation)
            for id in ids.dropFirst() {
                let layer = try #require(rig.layers[id])
                let animation = try #require(layer.animation(forKey:"transform.rotation.z") as? CAKeyframeAnimation)
                #expect(layer.position == first.position)
                #expect(animation.values as? [Double] == firstAnimation.values as? [Double])
                #expect(animation.keyTimes == firstAnimation.keyTimes)
                #expect(animation.duration == firstAnimation.duration)
            }
            rig.setActive(false)
        }
    }

    @Test func eyeStatesAreExclusiveAndStayBehindOpticalLayers() throws {
        for outfit in PioOutfitID.allCases {
            let rig = PioOverhaulRig();rig.configure(outfit,action:.greet);rig.setActive(true)
            for side in ["Left","Right"] {
                // Explicit loop avoids relying on dictionary iteration order.
                var tracks: [[Double]] = []
                for prefix in ["eye","half","lid","happy"] {
                    guard let layer = rig.layers[prefix+side] else { continue }
                    let a = try #require(layer.animation(forKey:"opacity") as? CAKeyframeAnimation)
                    tracks.append(try #require(a.values as? [Double]))
                    for optical in ["glasses","sunglasses","visor"] {
                        if let glass = rig.layers[optical] { #expect(layer.zPosition < glass.zPosition) }
                    }
                }
                for n in 0..<(tracks.first?.count ?? 0) { #expect(tracks.reduce(0) { $0 + $1[n] } == 1) }
            }
            rig.setActive(false)
        }
    }

    @Test func motionChangesDoNotRebuildLayersAndStoppingRemovesAllTracks() throws {
        let rig = PioOverhaulRig();rig.configure(.basic,action:.jump);rig.layout(CGRect(x:0,y:0,width:220,height:220));rig.setActive(true)
        let original = try #require(rig.layers["body"])
        for action in PioOverhaulAction.allCases {
            rig.configure(.basic,action:action)
            #expect(rig.layers["body"] === original)
            rig.setActive(true);#expect(!(rig.movement.animationKeys() ?? []).isEmpty)
            rig.setActive(false)
            #expect(rig.movement.animationKeys() == nil)
            #expect(rig.layers.values.allSatisfy { $0.animationKeys() == nil })
        }
    }

    @Test func jumpBounceAndGreetingHaveDifferentVisibleTrajectories() throws {
        let rig = PioOverhaulRig()
        func trajectory(_ action:PioOverhaulAction) throws -> [Double] {
            rig.configure(.basic,action:action);rig.setActive(true)
            return try #require((rig.movement.animation(forKey:"transform.translation.y") as? CAKeyframeAnimation)?.values as? [Double])
        }
        let jump = try trajectory(.jump), bounce = try trajectory(.bounce), greet = try trajectory(.greet)
        #expect(jump != bounce && jump != greet && bounce != greet)
        #expect((jump.max()! - jump.min()!) > (bounce.max()! - bounce.min()!)*2)
        rig.setActive(false)
    }

    @Test func landingRecoversWithoutStartingAnotherJump() throws {
        #expect(PioOverhaulAction.resolve(motion: .landing, pose: .standing) == .landing)
        let rig = PioOverhaulRig(); rig.configure(.basic, action: .landing); rig.setActive(true)
        let y = try #require((rig.movement.animation(forKey: "transform.translation.y") as? CAKeyframeAnimation)?.values as? [Double])
        // Mac uses upward-positive coordinates; landing only compresses downwards.
        #if os(macOS)
        #expect(y.allSatisfy { $0 <= 0 })
        #else
        #expect(y.allSatisfy { $0 >= 0 })
        #endif
        #expect(y.first == 0 && y.last == 0)
        rig.setActive(false)
    }

    @Test func twoHandedPropsStayWithinValidatedRotation() throws {
        for (outfit, part) in [(PioOutfitID.christmas, "gift"), (.pajamas, "pillow")] {
            let rig = PioOverhaulRig()
            for action in PioOverhaulAction.allCases {
                rig.configure(outfit, action: action); rig.setActive(true)
                let angles = try #require((rig.layers[part]?.animation(forKey: "transform.rotation.z") as? CAKeyframeAnimation)?.values as? [Double])
                #expect(angles.allSatisfy { abs($0) <= 2 * .pi / 180 + 0.000001 })
            }
            rig.setActive(false)
        }
    }
}
#endif
