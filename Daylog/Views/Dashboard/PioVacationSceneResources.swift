import Foundation
import CoreGraphics

/// Authored reclining scenes, not standing-costume overlays or an independent rig.
@MainActor
enum PioVacationSceneResources {
    static func assetName(outfit: PioOutfitID, context: PioAppearanceContext) -> String? {
        guard outfit != .basic else { return nil }
        switch context {
        case .vacationDay: return "routimori_vacation_day_\(outfit.rawValue)"
        case .vacationNight: return "routimori_vacation_night_\(outfit.rawValue)"
        default: return nil
        }
    }

    static func sourceAsset(outfit: PioOutfitID, night: Bool) -> String {
        assetName(outfit: outfit, context: night ? .vacationNight : .vacationDay)
            ?? (night ? "routimori_vacation_hammock_night" : "routimori_vacation_hammock")
    }

    static func missingIndependentLayers(outfit: PioOutfitID, context: PioAppearanceContext) -> [String] {
        guard let asset = assetName(outfit: outfit, context: context) else { return [] }
        return ["\(asset)_cleanFace_eyes_eyelids", "\(asset)_arms_props_hiddenRoots",
                "\(asset)_front_back_hammock_occlusion"]
    }

    static func isCandidateAsset(_ name: String) -> Bool {
        PioOutfitID.allCases.contains { outfit in
            assetName(outfit: outfit, context: .vacationDay) == name
                || assetName(outfit: outfit, context: .vacationNight) == name
        }
    }

    static func shouldShowCharacter(access: PioAppearanceAccess) -> Bool {
        access != .checking && access != .verificationUnavailable
    }

    static func shouldAnimate(visible: Bool, sceneActive: Bool, reduceMotion: Bool) -> Bool {
        visible && sceneActive && !reduceMotion
    }

    /// Approximate rope-knot/focus registration read from the composed candidates.
    /// These are conservative preview pivots, NOT artist-approved per-file roots.
    /// Source pixels remain untouched; no blink, sip or cloth deformation is implied.
    static func registration(asset: String, night: Bool) -> RoutimoriVacationRegistration {
        guard isCandidateAsset(asset) else { return night ? .originalNight : .originalDay }
        return RoutimoriVacationRegistration(
            focus: CGPoint(x: 512, y: night ? 870 : 820),
            attachment: CGPoint(x: night ? 58 : 968, y: night ? 225 : 500),
            swingDegrees: 0.55)
    }
}

struct RoutimoriVacationRegistration: Equatable {
    let focus: CGPoint
    let attachment: CGPoint
    let swingDegrees: CGFloat
    static let originalDay = RoutimoriVacationRegistration(focus: CGPoint(x: 512, y: 740),
        attachment: CGPoint(x: 968, y: 484), swingDegrees: 1.5)
    static let originalNight = RoutimoriVacationRegistration(focus: CGPoint(x: 512, y: 845),
        attachment: CGPoint(x: 68, y: 465), swingDegrees: 1.5)
}
