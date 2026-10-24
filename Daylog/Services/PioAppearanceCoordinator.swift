import Foundation
import Observation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Context describes the authored scene, not a second equipped-outfit setting.
enum PioAppearanceContext: String, CaseIterable, Sendable {
    case dashboard, growth, splash, vacationDay, vacationNight
    case cloudDownloading, cloudCompleted, cloudFailed
    case weeklyReview, welcome, celebration, wardrobe, settingsPreview, generic
    case widget, menuBar

    var originalSceneAsset: String? {
        switch self {
        case .vacationDay: "routimori_vacation_hammock"
        case .vacationNight: "routimori_vacation_hammock_night"
        case .cloudDownloading: "routimori_sync_loading"
        case .cloudCompleted: "routimori_sync_success"
        case .cloudFailed: "routimori_sync_failure"
        default: nil
        }
    }

    var isComposedScene: Bool { originalSceneAsset != nil }
    var hasCharacterSurface: Bool { self != .widget && self != .menuBar }
}

enum PioAppearancePose: String, Sendable {
    case standing, walking, greeting, jumping, celebrating, reclining, sleeping
    case cloudDownloading, cloudCompleted, cloudFailed
}

enum PioAppearanceAccess: String, Sendable {
    case free, verified, testing, checking, verificationUnavailable, unavailable, notOwned, preview
}

enum PioAppearanceArtwork: Equatable, Sendable {
    case outfitReference(asset: String)
    /// The complete, approved scene layer must stay in its original composition.
    /// For an unsupported premium pose this contains Basic, explicitly reported
    /// by outfitApplied=false; it must never masquerade as the selected outfit.
    case existingScene(asset: String)
    case unavailable

    var assetName: String? {
        switch self {
        case .outfitReference(let asset), .existingScene(let asset): asset
        case .unavailable: nil
        }
    }
}

enum PioAppearanceRenderer: String, Sendable {
    case referenceMotion, layeredPilot, originalScene, unavailable
}

struct PioResolvedAppearance: Equatable, Sendable {
    let context: PioAppearanceContext
    /// Authorized appearance only. Unknown preferences never unlock this value.
    let outfit: PioOutfitID
    /// A local selection request, useful for explaining pending verification.
    let requestedOutfit: PioOutfitID
    let stage: Int
    let pose: PioAppearancePose
    let motion: PioOutfitMotion
    let artwork: PioAppearanceArtwork
    let renderer: PioAppearanceRenderer
    let access: PioAppearanceAccess
    let outfitApplied: Bool
    let growthCompatible: Bool
    let animationPreserved: Bool
    let missingArtwork: [String]
    let compatibilityNote: String?

    var isPreview: Bool { access == .preview }
    var isAwaitingVerification: Bool { access == .checking || access == .verificationUnavailable }
    var accessibilityDescription: String {
        var parts = ["\(stage)단계", outfit.title]
        if isPreview { parts.append("미리보기") }
        if let compatibilityNote { parts.append(compatibilityNote) }
        return parts.joined(separator: ". ")
    }
}

/// One live coordinator reads wardrobe display permission and the application's live
/// growth source. No per-screen preferences, ownership cache or extra persistence.
@MainActor @Observable
final class PioAppearanceCoordinator {
    static let shared = PioAppearanceCoordinator(wardrobe: .shared)
    let wardrobe: PioWardrobeStore
    @ObservationIgnored private var levelSource: @MainActor () -> Int
    @ObservationIgnored private let assetExists: @MainActor (String) -> Bool
    @ObservationIgnored private let layeredAvailable: @MainActor (PioOutfitID) -> Bool
    @ObservationIgnored private let motionAvailable: @MainActor () -> Bool
    private var growthSourceRevision = 0

    init(wardrobe: PioWardrobeStore,
         levelSource: @escaping @MainActor () -> Int = { 1 },
         assetExists: (@MainActor (String) -> Bool)? = nil,
         layeredAvailable: (@MainActor (PioOutfitID) -> Bool)? = nil,
         motionAvailable: (@MainActor () -> Bool)? = nil) {
        self.wardrobe = wardrobe
        self.levelSource = levelSource
        self.assetExists = assetExists ?? PioAppearanceResources.hasImage
        self.layeredAvailable = layeredAvailable ?? PioAppearanceResources.hasEnabledLayeredArtwork
        self.motionAvailable = motionAvailable ?? { PioOutfitMotionView.isTrialEnabled }
    }

    /// Bind once to AppStore.growth.level. The closure reads the original
    /// observable source inside SwiftUI tracking, so XP/level updates propagate.
    func bindGrowthSource(_ source: @escaping @MainActor () -> Int) {
        levelSource = source
        growthSourceRevision &+= 1
    }

    var currentLevel: Int {
        _ = growthSourceRevision
        return max(1, levelSource())
    }
    var currentStage: Int { Self.stage(forLevel: currentLevel) }
    var ownedOutfits: Set<PioOutfitID> { wardrobe.purchases.ownedOutfits }
    var equippedOutfit: PioOutfitID {
        let requested = wardrobe.preferredAppearanceOutfit
        return wardrobe.canWear(requested)
            && (wardrobe.isOutfitTestingEnabled || wardrobe.isFreeWearing || ownedOutfits.contains(requested)) ? requested : .basic
    }

    static func stage(forLevel level: Int) -> Int {
        if level >= 50 { return 4 }
        if level >= 25 { return 3 }
        if level >= 10 { return 2 }
        return 1
    }

    func resolve(level: Int? = nil, context: PioAppearanceContext,
                 motion: PioOutfitMotion = .idle, pose: PioAppearancePose? = nil) -> PioResolvedAppearance {
        let requested = wardrobe.preferredAppearanceOutfit
        let access: PioAppearanceAccess
        if requested == .basic { access = .free }
        else if wardrobe.purchases.owns(requested) { access = .verified }
        else if wardrobe.isOutfitTestingEnabled && wardrobe.canWear(requested) { access = .testing }
        else if wardrobe.isFreeWearing { access = .free }
        else if !wardrobe.purchases.availability.isEnabled { access = .unavailable }
        else {
            switch wardrobe.purchases.entitlementState {
            case .unknown, .loading: access = .checking
            case .failed: access = .verificationUnavailable
            case .verified: access = .notOwned
            }
        }
        let authorized = access == .verified || access == .free || access == .testing ? requested : .basic
        // 구매를 지원하지 않는 배포판에는 장면 원화 관련 개발용 안내를 띄우지 않는다.
        // 유료 의상 권한은 위에서 확인하며, 전용 원화가 없는 장면은 기존 기본 피오 장면을 유지한다.
        return resolveArtwork(outfit: authorized, requested: requested, stage: Self.stage(forLevel: level ?? currentLevel),
                              context: context, requestedMotion: motion, requestedPose: pose, access: access,
                              showsNotes: access != .unavailable && !(access == .free && requested != .basic))
    }

    /// Shop previews explicitly bypass display authorization only. They cannot
    /// equip, grant ownership, change the app icon or change the global stage.
    func preview(outfit: PioOutfitID, stage: Int, context: PioAppearanceContext = .wardrobe,
                 motion: PioOutfitMotion = .idle, pose: PioAppearancePose? = nil) -> PioResolvedAppearance {
        resolveArtwork(outfit: outfit, requested: outfit, stage: min(max(stage, 1), 4), context: context,
                       requestedMotion: motion, requestedPose: pose, access: .preview)
    }

    private func resolveArtwork(outfit: PioOutfitID, requested: PioOutfitID, stage: Int,
                                context: PioAppearanceContext, requestedMotion: PioOutfitMotion,
                                requestedPose: PioAppearancePose?, access: PioAppearanceAccess,
                                showsNotes: Bool = true) -> PioResolvedAppearance {
        let pose = requestedPose ?? Self.pose(for: context, motion: requestedMotion)
        let intendedMotion: PioOutfitMotion
        if requestedMotion == .idle {
            switch pose {
            case .greeting: intendedMotion = .wave
            case .celebrating: intendedMotion = .celebration
            case .jumping: intendedMotion = .jump
            default: intendedMotion = requestedMotion
            }
        } else { intendedMotion = requestedMotion }
        var missing: [String] = []
        var notes: [String] = []
        if access == .testing { notes.append("의상 테스트 모드로 착용 중이에요. 구매한 의상은 아니에요.") }
        if access == .checking { notes.append("선택한 \(requested.title)의 구매 내역을 확인 중이에요.") }
        if access == .verificationUnavailable { notes.append("선택한 \(requested.title)의 구매 확인을 기다리고 있어요. 선택은 유지돼요.") }
        if access == .unavailable { notes.append("의상 구매가 아직 열리지 않아 기본 피오로 보여요.") }
        if access == .notOwned { notes.append("선택한 의상의 구매 권한이 없어 기본 피오를 표시해요.") }

        var artwork: PioAppearanceArtwork = .unavailable
        var renderer: PioAppearanceRenderer = .unavailable
        var applied = false
        var resolvedMotion = intendedMotion
        var animation = false

        if !context.hasCharacterSurface {
            notes.append("이 화면에는 현재 피오 표시 영역이 없어요.")
        } else if let original = context.originalSceneAsset {
            let registeredScene: String?
            #if DEBUG
            registeredScene = PioCloudSceneResources.assetName(outfit: outfit, context: context)
                ?? PioVacationSceneResources.assetName(outfit: outfit, context: context)
            #else
            registeredScene = PioVacationSceneResources.assetName(outfit: outfit, context: context)
            #endif
            if let scene = registeredScene, assetExists(scene) {
                artwork = .existingScene(asset: scene)
                renderer = .originalScene
                applied = outfit == requested
                animation = true
                #if DEBUG
                missing += PioCloudSceneResources.missingIndependentLayers(outfit: outfit, context: context)
                #endif
                missing += PioVacationSceneResources.missingIndependentLayers(outfit: outfit, context: context)
            } else if assetExists(original) {
                artwork = .existingScene(asset: original)
                renderer = .originalScene
                applied = requested == .basic
                animation = true // Caller retains the existing scene's animation.
            } else {
                missing.append(original)
                notes.append("이 장면의 원화를 불러오지 못했어요.")
            }
            if requested != .basic && outfit == requested && !(registeredScene.map(assetExists) ?? false) {
                let expected = "\(original)_\(requested.rawValue)"
                missing.append(expected)
                notes.append("\(requested.title)의 이 장면 전용 원화가 없어 기본 장면을 유지해요. 착장 선택은 바뀌지 않아요.")
            }
        } else if ![PioAppearancePose.standing, .walking, .greeting, .jumping, .celebrating].contains(pose) {
            // Standing artwork cannot stand in for authored reclining, sleeping,
            // or cloud-interaction poses outside their registered scene.
            missing.append("pio_\(pose.rawValue)_\(outfit.rawValue)")
            notes.append("이 자세에 맞는 피오 원화가 아직 없어요.")
        } else if let asset = outfit.artAssetName, assetExists(asset) {
            artwork = .outfitReference(asset: asset)
            applied = outfit == requested
            if layeredAvailable(outfit) {
                renderer = .layeredPilot
                animation = true
            } else {
                renderer = .referenceMotion
                let capabilities = PioOutfitCapabilities(outfit: outfit)
                resolvedMotion = capabilities.supportedMotions.contains(intendedMotion) ? intendedMotion : .idle
                animation = motionAvailable() && resolvedMotion == intendedMotion && pose != .walking
                if pose == .walking {
                    missing.append("pio_layered_\(outfit.rawValue)_walk")
                    resolvedMotion = .idle
                    notes.append("이 의상은 걷기 원화가 없어 제자리 모습으로 보여요.")
                } else if intendedMotion == .wave && !capabilities.hasIndependentWingWave {
                    missing.append("pio_layered_\(outfit.rawValue)_wave")
                    notes.append("이 의상은 날개 인사 대신 제자리 모습으로 보여요.")
                }
            }
        } else {
            missing.append(outfit.artAssetName ?? "pio_outfit_\(outfit.rawValue)")
            notes.append("선택한 의상의 원화를 불러오지 못했어요.")
        }

        // 피오는 레벨과 상관없이 한 가지 모습이다(단계별 원화를 만들지 않기로 했다). 레벨·단계 값은 그대로 두고,
        // 사용자에게 "단계별 원화 준비 중" 같은 안내는 보이지 않는다(내부 기록용 목록에만 남긴다).
        let growthCompatible = false
        if context.hasCharacterSurface { missing.append("pio_outfit_\(outfit.rawValue)_stage\(stage)") }
        return PioResolvedAppearance(context: context, outfit: outfit, requestedOutfit: requested, stage: stage,
                                     pose: pose, motion: resolvedMotion, artwork: artwork, renderer: renderer,
                                     access: access, outfitApplied: applied, growthCompatible: growthCompatible,
                                     animationPreserved: animation, missingArtwork: missing,
                                     compatibilityNote: notes.isEmpty || !showsNotes ? nil : notes.joined(separator: " "))
    }

    private static func pose(for context: PioAppearanceContext, motion: PioOutfitMotion) -> PioAppearancePose {
        switch context {
        case .vacationDay: return .reclining
        case .vacationNight: return .reclining
        case .cloudDownloading: return .cloudDownloading
        case .cloudCompleted: return .cloudCompleted
        case .cloudFailed: return .cloudFailed
        case .welcome: return .greeting
        case .celebration: return .celebrating
        default: break
        }
        switch motion {
        case .wave: return .greeting
        case .jump, .bounce, .landing: return .jumping
        case .celebration: return .celebrating
        case .idle, .rest: return .standing
        }
    }
}

@MainActor
enum PioAppearanceResources {
    private static var imageAvailability: [String: Bool] = [:]
    static func hasImage(_ name: String) -> Bool {
        if let cached = imageAvailability[name] { return cached }
        #if os(macOS)
        let available = NSImage(named: name) != nil
        #else
        let available = UIImage(named: name) != nil
        #endif
        imageAvailability[name] = available
        return available
    }
    static func hasEnabledLayeredArtwork(_ outfit: PioOutfitID) -> Bool {
        #if DEBUG
        return (PioOverhaulTrial.isEnabled && PioOverhaulResources.manifest(outfit) != nil)
            || (PioLayeredTrial.isEnabled && PioLayeredResources.manifest(for: outfit) != nil)
        #else
        return false
        #endif
    }
}
