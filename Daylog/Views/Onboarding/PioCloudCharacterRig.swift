import SwiftUI
import QuartzCore
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Candidate-only opt-in until the new Basic clean-face composition has passed
/// native visual approval. Existing approved artwork remains the default.
enum PioCloudBasicEyesTrial {
    static var isEnabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-PioCloudBasicEyesV1")
        #else
        false
        #endif
    }
    static var handsEnabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-PioCloudHandsV2")
        #else
        false
        #endif
    }
}

/// Promoted textures use the same loader/cache in Debug and Release. Candidate
/// textures keep their opt-in loader; production never needs the trial catalog.
@MainActor private enum PioCloudImageResources {
    private static let cache: NSCache<NSString, CGImage> = {
        let cache = NSCache<NSString, CGImage>(); cache.totalCostLimit = 48 * 1024 * 1024; return cache
    }()
    static func image(_ name: String) -> CGImage? {
        #if DEBUG
        if !name.hasPrefix("pio_cloud_prod_v2_") && !name.hasPrefix("pio_cloud_basic_prod_v1_") {
            return PioOverhaulResources.image(name)
        }
        #endif
        // Source PNGs remain intact. Byte-identical approved textures share a
        // named-image lookup as well as our cache, avoiding one decode per alias.
        let canonical = PioCloudTextureAliases.canonicalName(for: name)
        if let image = cache.object(forKey: canonical as NSString) { return image }
        #if os(macOS)
        let image = NSImage(named: canonical)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        #else
        let image = UIImage(named: canonical)?.cgImage
        #endif
        if let image { cache.setObject(image, forKey: canonical as NSString, cost: image.bytesPerRow * image.height) }
        return image
    }
}

/// Generated from exact source PNG byte equality. Canonicalization changes no
/// registration, sampler, pivot, layer order or costume artwork. A missing or
/// malformed metadata pack safely retains the pre-existing named-image path.
@MainActor enum PioCloudTextureAliases {
    private struct Manifest: Decodable {
        let version: Int
        let aliases: [String: String]
        let sourceSHA256: [String: String]
    }
    static let aliases: [String: String] = {
        guard let data = NSDataAsset(name: "pio_cloud_production_texture_aliases")?.data,
              let manifest = try? JSONDecoder().decode(Manifest.self, from: data),
              manifest.version == 1,
              !manifest.aliases.isEmpty,
              manifest.aliases.allSatisfy({ name, canonical in
                  isProductionName(name) && isProductionName(canonical)
                      && manifest.aliases[canonical] == canonical
                      && manifest.sourceSHA256[name]?.count == 64
                      && manifest.sourceSHA256[name] == manifest.sourceSHA256[canonical]
              }) else { return [:] }
        return manifest.aliases
    }()
    static func canonicalName(for name: String) -> String { aliases[name] ?? name }
    private static func isProductionName(_ name: String) -> Bool {
        name.hasPrefix("pio_cloud_prod_v2_") || name.hasPrefix("pio_cloud_basic_prod_v1_")
    }
}

struct PioCloudLayerRegistration: Decodable {
    struct HoldGroup: Decodable {
        let ids: [String]
        let pivot: [Double]
        let degrees: Double
    }
    struct Part: Decodable {
        let id: String
        let asset: String
        /// Full donor image placement in top-left canonical canvas coordinates.
        let rect: [Double]
        let pivot: [Double]
        let z: Int
        let contentsRect: [Double]?
    }
    let outfit: String
    let canvas: Double
    let revision: String
    let parts: [Part]
    let holdGroup: HoldGroup?
}

/// Authored seated cloud layers. Tablet/hands remain baked together unless a
/// separate validated reconstruction is explicitly registered.
@MainActor enum PioCloudSceneResources {
    private static var candidates: [PioOutfitID: PioCloudLayerRegistration] = [:]
    private static var productionBasic: PioCloudLayerRegistration?
    private static var production: [PioOutfitID: PioCloudLayerRegistration] = [:]
    /// Only registrations promoted after native component QA exist in this
    /// catalog. Decode/texture validation failure retains the earlier fallback.
    static func productionRegistration(outfit: PioOutfitID) -> PioCloudLayerRegistration? {
        if let registration = production[outfit] { return registration }
        guard let data = NSDataAsset(name: "pio_cloud_\(outfit.rawValue)_prod_v2_registration")?.data,
              let registration = try? JSONDecoder().decode(PioCloudLayerRegistration.self, from: data),
              registration.outfit == outfit.rawValue, registration.canvas == 1254,
              registration.revision == "\(outfit.rawValue)-production-hands-v2",
              registration.parts.allSatisfy({ $0.asset.hasPrefix("pio_cloud_prod_v2_") }),
              registration.holdGroup != nil, validRegistration(registration) else { return nil }
        production[outfit] = registration
        return registration
    }
    static func hasProductionLayers(_ outfit: PioOutfitID) -> Bool {
        productionRegistration(outfit: outfit) != nil || hasProductionBasicEyes(outfit)
    }
    /// Render-only adaptation of an already authorized coordinator result.
    /// Never consults preferences, changes ownership, or substitutes the
    /// requested outfit for the coordinator's authorized outfit.
    static func productionAppearance(from appearance: PioResolvedAppearance) -> PioResolvedAppearance {
        guard !appearance.isAwaitingVerification, appearance.outfit == appearance.requestedOutfit,
              [.free, .verified, .testing, .preview].contains(appearance.access) else { return appearance }
        let asset: String
        switch appearance.context {
        case .cloudDownloading, .cloudFailed:
            guard let registration = productionRegistration(outfit: appearance.outfit)
                    ?? (appearance.outfit == .basic ? productionBasicRegistration() : nil),
                  let body = registration.parts.first(where: { $0.id == "body" }) else { return appearance }
            asset = body.asset
        case .cloudCompleted:
            // Success needs no tablet pose. Reuse the approved complete outfit
            // with the scene's existing bounded celebration, without trial rigs.
            let name = appearance.outfit == .basic ? "routimori_sync_success" : appearance.outfit.artAssetName
            guard let name, PioAppearanceResources.hasImage(name) else { return appearance }
            asset = name
        default: return appearance
        }
        let oldScene = appearance.context.originalSceneAsset ?? ""
        let missing = appearance.missingArtwork.filter {
            $0 != oldScene && $0 != "\(oldScene)_\(appearance.outfit.rawValue)"
                && $0 != "pio_cloud_\(appearance.outfit.rawValue)_separate_hands_tablet_roots"
        }
        let obsoleteNote = "\(appearance.outfit.title)의 이 장면 전용 원화가 없어 기본 장면을 유지해요. 착장 선택은 바뀌지 않아요."
        let note = appearance.compatibilityNote?.replacingOccurrences(of: obsoleteNote, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return PioResolvedAppearance(context: appearance.context, outfit: appearance.outfit,
            requestedOutfit: appearance.requestedOutfit, stage: appearance.stage, pose: appearance.pose,
            motion: appearance.motion, artwork: .existingScene(asset: asset), renderer: .originalScene,
            access: appearance.access, outfitApplied: true, growthCompatible: appearance.growthCompatible,
            animationPreserved: true, missingArtwork: missing,
            compatibilityNote: note?.isEmpty == true ? nil : note)
    }
    static func productionBasicRegistration() -> PioCloudLayerRegistration? {
        if let productionBasic { return productionBasic }
        guard let data = NSDataAsset(name: "pio_cloud_basic_prod_v1_registration")?.data,
              let registration = try? JSONDecoder().decode(PioCloudLayerRegistration.self, from: data),
              registration.outfit == "basic", registration.canvas == 1254,
              registration.revision == "basic-production-eyes-v1", registration.holdGroup == nil,
              validRegistration(registration) else { return nil }
        productionBasic = registration; return registration
    }
    static func hasProductionBasicEyes(_ outfit: PioOutfitID) -> Bool {
        outfit == .basic && productionBasicRegistration() != nil
    }
    static func selectedRegistration(outfit: PioOutfitID) -> PioCloudLayerRegistration? {
        candidate(outfit: outfit) ?? productionRegistration(outfit: outfit)
            ?? (outfit == .basic ? productionBasicRegistration() : nil)
    }
    static func basicEyeCandidate() -> PioCloudLayerRegistration? {
        candidate(outfit: .basic)
    }
    static func candidate(outfit: PioOutfitID) -> PioCloudLayerRegistration? {
        let version: String
        let revision: String
        if PioCloudBasicEyesTrial.handsEnabled {
            version = "v2"; revision = "\(outfit.rawValue)-hands-v2"
        } else if outfit == .basic && PioCloudBasicEyesTrial.isEnabled {
            version = "v1"; revision = "basic-eyes-v1"
        } else { return nil }
        if let candidate = candidates[outfit] { return candidate }
        guard
              let data = NSDataAsset(name: "pio_cloud_\(outfit.rawValue)_\(version)_registration")?.data,
              let registration = try? JSONDecoder().decode(PioCloudLayerRegistration.self, from: data),
              registration.outfit == outfit.rawValue, registration.canvas == 1254,
              registration.revision == revision,
              validRegistration(registration), version != "v2" || registration.holdGroup != nil else { return nil }
        candidates[outfit] = registration
        return registration
    }
    private static func validRegistration(_ registration: PioCloudLayerRegistration) -> Bool {
        Set(registration.parts.map(\.id)).count == registration.parts.count
            && Set(["body", "eyeLeft", "eyeRight", "lidLeft", "lidRight"]).isSubset(of: Set(registration.parts.map(\.id)))
            && registration.parts.allSatisfy({ part in
                  part.rect.count == 4 && part.pivot.count == 2 && part.rect.allSatisfy(\.isFinite)
                      && part.pivot.allSatisfy(\.isFinite) && part.rect[2] > 0 && part.rect[3] > 0
                      && validContentsRect(part.contentsRect)
                      && PioCloudImageResources.image(part.asset) != nil
              }) && validHoldGroup(registration.holdGroup, parts: registration.parts)
    }
    private static func validHoldGroup(_ hold: PioCloudLayerRegistration.HoldGroup?, parts: [PioCloudLayerRegistration.Part]) -> Bool {
        guard let hold else { return true }
        let forbidden: Set<String> = ["body", "eyeLeft", "eyeRight", "lidLeft", "lidRight", "halfLeft", "halfRight"]
        return hold.ids.count >= 3 && Set(hold.ids).count == hold.ids.count
            && Set(hold.ids).isSubset(of: Set(parts.map(\.id))) && forbidden.isDisjoint(with: hold.ids)
            && hold.pivot.count == 2 && hold.pivot.allSatisfy(\.isFinite)
            && hold.degrees.isFinite && (0...2).contains(hold.degrees)
    }
    private static func validContentsRect(_ rect: [Double]?) -> Bool {
        guard let rect else { return true }
        return rect.count == 4 && rect.allSatisfy(\.isFinite) && rect[0] >= 0 && rect[1] >= 0
            && rect[2] > 0 && rect[3] > 0 && rect[0] + rect[2] <= 1 && rect[1] + rect[3] <= 1
    }
    static func assetName(outfit: PioOutfitID, context: PioAppearanceContext) -> String? {
        #if DEBUG
        guard PioOverhaulTrial.isEnabled else { return nil }
        #endif
        switch context {
        case .cloudCompleted:
            #if DEBUG
            return PioOverhaulResources.manifest(outfit) != nil ? outfit.artAssetName : nil
            #else
            return nil
            #endif
        case .cloudDownloading, .cloudFailed:
            if let registration = selectedRegistration(outfit: outfit) {
                return registration.parts.first { $0.id == "body" }?.asset
            }
            let name = "pio_cloud_\(outfit.rawValue)_body"
            return PioAppearanceResources.hasImage(name) ? name : nil
        default: return nil
        }
    }
    static func hasSeatedLayers(_ outfit: PioOutfitID) -> Bool {
        if selectedRegistration(outfit: outfit) != nil { return true }
        return PioAppearanceResources.hasImage("pio_cloud_\(outfit.rawValue)_body")
    }
    static func missingIndependentLayers(outfit: PioOutfitID, context: PioAppearanceContext) -> [String] {
        guard context == .cloudDownloading || context == .cloudFailed else { return [] }
        if selectedRegistration(outfit: outfit)?.holdGroup != nil { return [] }
        return ["pio_cloud_\(outfit.rawValue)_separate_hands_tablet_roots"]
    }
}

@MainActor final class PioCloudCharacterRig {
    let root = CALayer()
    let accessoryHold = CALayer()
    private(set) var parts: [String: CALayer] = [:]
    private var outfit: PioOutfitID?
    private var kind: SyncSceneKind = .receiving
    private(set) var active = false
    private var targetBounds = CGRect.zero
    private var registration: PioCloudLayerRegistration?
    var animationCount: Int { (accessoryHold.animationKeys()?.count ?? 0) + parts.values.reduce(0) { $0 + ($1.animationKeys()?.count ?? 0) } }

    func configure(outfit: PioOutfitID, kind: SyncSceneKind, bounds: CGRect) {
        let changed = self.outfit != outfit || self.kind != kind
        self.kind = kind
        if self.outfit != outfit {
            self.outfit = outfit
            parts.values.forEach { $0.removeFromSuperlayer() }; parts.removeAll()
            accessoryHold.removeAllAnimations(); accessoryHold.removeFromSuperlayer()
            registration = PioCloudSceneResources.selectedRegistration(outfit: outfit)
            let ids = ["body", "eyeLeft", "eyeRight", "lidLeft", "lidRight", "halfLeft", "halfRight", "browLeft", "browRight", "optics"]
            let definitions = registration?.parts.sorted { $0.z < $1.z }
                ?? ids.enumerated().map { z, id in
                    PioCloudLayerRegistration.Part(id: id, asset: "pio_cloud_\(outfit.rawValue)_\(id)",
                        rect: [0, 0, 1254, 1254], pivot: [627, 627], z: z, contentsRect: nil)
                }
            CATransaction.begin(); CATransaction.setDisableActions(true)
            if let hold = registration?.holdGroup {
                accessoryHold.zPosition = CGFloat(definitions.filter { hold.ids.contains($0.id) }.map(\.z).min() ?? 1)
                root.addSublayer(accessoryHold)
            }
            for part in definitions {
                guard let image = PioCloudImageResources.image(part.asset) else { continue }
                let layer = CALayer(); layer.name = part.id; layer.contents = image
                if let rect = part.contentsRect {
                    #if os(macOS)
                    // The manifest uses PNG top-left coordinates. AppKit's
                    // unflipped layer samples this texture from the bottom.
                    layer.contentsRect = CGRect(x: rect[0], y: 1 - rect[1] - rect[3], width: rect[2], height: rect[3])
                    #else
                    layer.contentsRect = CGRect(x: rect[0], y: rect[1], width: rect[2], height: rect[3])
                    #endif
                    // Registration matches the selected genuine texture subrect's
                    // aspect ratio; no flattened face is scaled into an eye slot.
                    layer.contentsGravity = .resize
                } else { layer.contentsGravity = .resizeAspect }
                layer.zPosition = CGFloat(part.z)
                layer.minificationFilter = .trilinear; layer.frame = root.bounds
                if registration?.holdGroup?.ids.contains(part.id) == true { accessoryHold.addSublayer(layer) }
                else { root.addSublayer(layer) }
                parts[part.id] = layer
            }
            // Keep painter order consistent with compositor z order. Native
            // render(in:) snapshots do not reliably sort nested group z values.
            root.sublayers = root.sublayers?.sorted { $0.zPosition < $1.zPosition }
            CATransaction.commit()
            // New donor frames must be laid out even if the host size is unchanged.
            targetBounds = .null
        }
        layout(bounds)
        if changed { let resume = active; setActive(false); neutral(); if resume { setActive(true) } }
    }
    func layout(_ bounds: CGRect) {
        guard targetBounds != bounds else { return }; targetBounds = bounds
        CATransaction.begin(); CATransaction.setDisableActions(true)
        root.frame = bounds
        if let registration {
            let sx = bounds.width / registration.canvas, sy = bounds.height / registration.canvas
            if let hold = registration.holdGroup {
                accessoryHold.bounds = root.bounds
                #if os(macOS)
                accessoryHold.anchorPoint = CGPoint(x: hold.pivot[0] / registration.canvas, y: 1 - hold.pivot[1] / registration.canvas)
                accessoryHold.position = CGPoint(x: hold.pivot[0] * sx, y: bounds.height - hold.pivot[1] * sy)
                #else
                accessoryHold.anchorPoint = CGPoint(x: hold.pivot[0] / registration.canvas, y: hold.pivot[1] / registration.canvas)
                accessoryHold.position = CGPoint(x: hold.pivot[0] * sx, y: hold.pivot[1] * sy)
                #endif
            }
            for part in registration.parts {
                guard let layer = parts[part.id] else { continue }
                let rect = part.rect, pivot = part.pivot
                layer.bounds = CGRect(x: 0, y: 0, width: rect[2] * sx, height: rect[3] * sy)
                let ay = (pivot[1] - rect[1]) / rect[3]
                #if os(macOS)
                layer.anchorPoint = CGPoint(x: (pivot[0] - rect[0]) / rect[2], y: 1 - ay)
                layer.position = CGPoint(x: pivot[0] * sx, y: bounds.height - pivot[1] * sy)
                #else
                layer.anchorPoint = CGPoint(x: (pivot[0] - rect[0]) / rect[2], y: ay)
                layer.position = CGPoint(x: pivot[0] * sx, y: pivot[1] * sy)
                #endif
            }
        } else {
            for layer in parts.values { layer.frame = root.bounds }
        }
        CATransaction.commit()
    }
    private func neutral() {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        accessoryHold.transform = CATransform3DIdentity
        for (id, layer) in parts {
            layer.transform = CATransform3DIdentity
            layer.opacity = id.hasPrefix("lid") || id.hasPrefix("half") || (id.hasPrefix("brow") && kind != .trouble) ? 0 : 1
        }
        CATransaction.commit()
    }
    func setActive(_ value: Bool) {
        guard active != value else { return }; active = value
        accessoryHold.removeAllAnimations()
        parts.values.forEach { $0.removeAllAnimations() }; neutral()
        guard value else { return }
        if let hold = registration?.holdGroup, hold.degrees > 0 {
            let angle = hold.degrees * .pi / 180
            let animation = CAKeyframeAnimation(keyPath: "transform.rotation.z")
            animation.values = [0, angle, 0, -angle, 0]
            animation.keyTimes = [0, 0.25, 0.5, 0.75, 1]
            animation.duration = 6.4
            animation.repeatCount = .infinity
            animation.timingFunctions = Array(repeating: CAMediaTimingFunction(name: .easeInEaseOut), count: 4)
            accessoryHold.add(animation, forKey: "cloud.independentHeldGroup")
        }
        let times: [NSNumber] = [0, 0.48, 0.52, 0.57, 0.62, 0.83, 0.88, 1]
        for side in ["Left", "Right"] {
            // Seated tablet pose stays intact; attention is a short blink.
            let open = kind == .trouble ? [1.0,1,0,0,1,1,1,1] : [1,1,0,0,1,1,0,1]
            let closed = open.map { 1 - $0 }
            for (id, values) in [("eye"+side, open), ("lid"+side, closed)] {
                let animation = CAKeyframeAnimation(keyPath: "opacity")
                animation.values = values; animation.keyTimes = times
                animation.duration = kind == .trouble ? 5.2 : 3.6
                animation.calculationMode = .discrete; animation.repeatCount = .infinity
                parts[id]?.add(animation, forKey: "cloud.independentBlink")
            }
            if kind == .trouble {
                let brow = CAKeyframeAnimation(keyPath: "transform.translation.y")
                #if os(macOS)
                brow.values = [0, 0.8, 0]
                #else
                brow.values = [0, -0.8, 0]
                #endif
                brow.duration = 2.3; brow.repeatCount = 0
                parts["brow"+side]?.add(brow, forKey: "cloud.concernSettle")
            }
        }
    }
}
