#if DEBUG
import Testing
import QuartzCore
@testable import Daylog

@MainActor
struct PioLayeredRigTests {
    @Test func approvedResourcesResolveWithPackedGeometryAndHonestScope() throws {
        for outfit in PioLayeredTrial.approvedOutfits {
            let manifest = try #require(PioLayeredResources.manifest(for: outfit))
            #expect(manifest.canvas == 1254)
            #expect(!manifest.supportsGrowthStages)
            #expect(manifest.stageArtID == "pilot-neutral-only")
            #expect(Set(manifest.parts.map(\.id)).count == manifest.parts.count)
            for part in manifest.parts {
                let image = try #require(PioLayeredResources.image(named: part.asset))
                #expect(image.width == Int(part.rect[2]))
                #expect(image.height == Int(part.rect[3]))
                #expect(part.rect[0] >= 0 && part.rect[1] >= 0)
                #expect(part.rect[0] + part.rect[2] <= manifest.canvas)
                #expect(part.rect[1] + part.rect[3] <= manifest.canvas)
            }
            let reference = try #require(PioLayeredResources.image(named: "pio_layered_\(outfit.rawValue)_reference"))
            #expect(reference.width == 1254 && reference.height == 1254)
        }
        #expect(PioLayeredResources.manifest(for: .autumn) == nil)
        let christmas = try #require(PioLayeredResources.manifest(for: .christmas))
        let right = try #require(christmas.parts.first { $0.id == "handRight" })
        #expect(right.pivot == [1050,790])
        #expect(right.neutralAngleDegrees == -60)
        #expect(!christmas.parts.contains { $0.id == "sprout" })
        #expect(PioLayeredTrial.supportedMotions(for: .christmas).contains(.flap))
    }

    @Test func isolatedMotionsKeepBodyAndAllAncestorsFixed() throws {
        for outfit in PioLayeredTrial.approvedOutfits {
            let rig = PioLayeredRig()
            #expect(rig.configure(outfit: outfit, motion: .blink))
            rig.layout(in: CGRect(x: 0,y: 0,width: 220,height: 220), displayScale: 2)
            rig.setAnimating(true)
            #expect(rig.trackCount(category: "eyes") == 6)
            for side in ["Left", "Right"] {
                #expect(rig.layers["half" + side]?.opacity == 0)
                var states: [[Double]] = []
                var sharedTimes: [NSNumber]?
                for prefix in ["eye", "half", "lid"] {
                    let layer = try #require(rig.layers[prefix + side])
                    let track = try #require(layer.animation(forKey: "layered.opacity") as? CAKeyframeAnimation)
                    #expect(track.calculationMode == .discrete)
                    if let sharedTimes { #expect(track.keyTimes == sharedTimes) }
                    else { sharedTimes = track.keyTimes }
                    states.append(try #require(track.values as? [Double]))
                }
                for segment in states[0].indices {
                    #expect(states.reduce(0) { $0 + $1[segment] } == 1)
                    #expect(states.allSatisfy { $0[segment] == 0 || $0[segment] == 1 })
                }
            }
            #expect(rig.trackCount(category: "body") == 0)
            #expect(rig.trackCount(category: "wings") == 0)
            let body = try #require(rig.layers["body"])
            let before = body.transform
            rig.configure(outfit: outfit, motion: .wave)
            #expect(rig.trackCount(category: "body") == 0)
            #expect(rig.trackCount(category: "eyes") == 0)
            #expect(rig.trackCount(category: "wings") == 1)
            #expect(CATransform3DEqualToTransform(body.transform, before))
            #expect(rig.root.animationKeys() == nil && rig.canvas.animationKeys() == nil && rig.movement.animationKeys() == nil)
            let right = try #require(rig.layers[rig.layers["wingRight"] != nil ? "wingRight" : "handRight"])
            let track = try #require(right.animation(forKey: "layered.transform.rotation.z") as? CAKeyframeAnimation)
            let angles = try #require(track.values as? [Double])
            #expect((angles.max()! - angles.min()!) <= 24.00001 * .pi/180)
            rig.setAnimating(false)
        }
    }

    @Test func lifecycleStopsEveryTrackAndKeepsSameConfigurationStable() throws {
        let rig = PioLayeredRig()
        for motion in PioLayeredMotion.allCases {
            #expect(rig.configure(outfit: .basic, motion: motion))
            rig.setAnimating(true)
            #expect(rig.animationCount > 0)
            let count = rig.animationCount
            rig.setAnimating(true)
            #expect(rig.animationCount == count)
            rig.setAnimating(true, reduceMotion: true)
            #expect(rig.animationCount == 0 && !rig.isAnimating)
            rig.setAnimating(true)
            #expect(rig.animationCount == count)
            rig.setAnimating(false)
            #expect(rig.animationCount == 0)
        }
        rig.configure(outfit: .basic, motion: .idle)
        let configurations = rig.configurationCount
        let loads = PioLayeredResources.sourceLoads
        rig.configure(outfit: .basic, motion: .idle)
        rig.layout(in: CGRect(x:0,y:0,width:64,height:64), displayScale: 3)
        let layout = PioLayeredMetrics.snapshot["effectiveLayouts"]
        rig.layout(in: CGRect(x:0,y:0,width:64,height:64), displayScale: 3)
        #expect(PioLayeredMetrics.snapshot["effectiveLayouts"] == layout)
        #expect(rig.configurationCount == configurations)
        rig.configure(outfit: .basic, motion: .wave)
        #expect(PioLayeredResources.sourceLoads == loads)
        rig.configure(outfit: .basic, motion: .wave, flatReference: true)
        rig.setAnimating(true)
        #expect(!rig.isAnimating && rig.animationCount == 0)
        #expect(rig.layers.count == 1 && rig.layers["reference"] != nil)
    }

    @Test func christmasGripTracksStayCoupledAndNeutralAngleIsPreserved() throws {
        let rig = PioLayeredRig()
        rig.configure(outfit: .christmas, motion: .attachment)
        rig.setAnimating(true)
        let group = try #require(rig.leftGrip)
        let left = try #require(rig.layers["handLeft"])
        let gift = try #require(rig.layers["gift"])
        #expect(left.superlayer === group && gift.superlayer === group)
        #expect(left.animationKeys() == nil && gift.animationKeys() == nil)
        #expect(group.animationKeys()?.count == 2)
        let leftPosition = left.position, giftPosition = gift.position
        rig.configure(outfit: .christmas, motion: .flap)
        let flap = try #require(group.animation(forKey: "layered.transform.rotation.z") as? CAKeyframeAnimation)
        let angles = try #require(flap.values as? [Double])
        #expect(abs(angles.max()! - angles.min()! - 12 * .pi/180) < 0.00001)
        #expect(left.position == leftPosition && gift.position == giftPosition)
        #expect(rig.trackCount(category: "wings") == 2)
        #expect(rig.trackCount(category: "accessory") == 1)
        #expect(rig.trackCount(category: "body") == 0)
        rig.configure(outfit: .christmas, motion: .celebration)
        #expect(rig.layers["handLeft"]?.animationKeys() == nil)
        #expect(rig.layers["gift"]?.animationKeys() == nil)
        rig.configure(outfit: .christmas, motion: .wave)
        let right = try #require(rig.layers["handRight"])
        let neutral = right.transform
        rig.setAnimating(false)
        #expect(CATransform3DEqualToTransform(right.transform, neutral))
        #expect(abs(atan2(neutral.m12, neutral.m11)) > 1)
    }

    @Test func diagnosticsDoNotRetainRigsAndResetPreservesActiveTruth() {
        let initial = PioLayeredMetrics.snapshot["liveRigs", default: 0]
        weak var weakRig: PioLayeredRig?
        do {
            let rig = PioLayeredRig(); weakRig = rig
            rig.configure(outfit: .basic, motion: .idle); rig.setAnimating(true)
            #expect(rig.trackCount(category: "body") > 0)
            let active = PioLayeredMetrics.snapshot["activeAnimationTracks"]
            PioLayeredMetrics.reset()
            #expect(PioLayeredMetrics.snapshot["activeAnimationTracks"] == active)
            rig.setAnimating(false)
        }
        #expect(weakRig == nil)
        #expect(PioLayeredMetrics.snapshot["liveRigs", default: 0] == initial)
    }
}
#endif
