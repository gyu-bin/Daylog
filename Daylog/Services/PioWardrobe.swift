import Foundation
import Observation

enum PioOutfitCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case seasonal, holiday, everyday, special, free

    var id: String { rawValue }
    var title: String {
        switch self {
        case .seasonal: "계절"
        case .holiday: "기념일"
        case .everyday: "일상"
        case .special: "특별"
        case .free: "기본"
        }
    }
}

enum PioOutfitID: String, CaseIterable, Identifiable, Codable, Sendable {
    case basic, cherryBlossom, summerVacation, autumn, winter
    case halloween, christmas, hanbok, cafe, student, fitness, rainyDay, pajamas, astronaut

    var id: String { rawValue }
    var title: String {
        switch self {
        case .basic: "기본 피오"
        case .cherryBlossom: "벚꽃 피오"
        case .summerVacation: "여름 휴가 피오"
        case .autumn: "가을 피오"
        case .winter: "겨울 피오"
        case .halloween: "할로윈 피오"
        case .christmas: "크리스마스 피오"
        case .hanbok: "한복 피오"
        case .cafe: "카페 피오"
        case .student: "학생 피오"
        case .fitness: "운동 피오"
        case .rainyDay: "비 오는 날 피오"
        case .pajamas: "잠옷 피오"
        case .astronaut: "우주인 피오"
        }
    }

    var description: String {
        switch self {
        case .basic: "매일의 작은 성장을 함께하는 피오예요."
        case .cherryBlossom: "봄바람과 벚꽃을 닮은 피오와 산뜻한 하루를 시작해요."
        case .summerVacation: "시원한 여름 휴가를 떠난 피오와 잠시 쉬어가요."
        case .autumn: "포근한 가을빛을 입은 피오와 차분히 하루를 채워요."
        case .winter: "따뜻하게 차려입은 피오가 추운 날에도 함께해요."
        case .halloween: "귀여운 할로윈 차림의 피오와 작은 즐거움을 찾아요."
        case .christmas: "설레는 크리스마스 차림의 피오가 따뜻한 마음을 전해요."
        case .hanbok: "고운 한복을 입은 피오와 특별한 하루를 맞이해요."
        case .cafe: "카페에 들른 피오와 느긋한 여유를 즐겨요."
        case .student: "새로운 배움을 시작하는 피오가 오늘의 도전을 응원해요."
        case .fitness: "운동복을 입은 피오와 가볍게 몸을 움직여요."
        case .rainyDay: "비 오는 날에도 피오와 즐겁게 한 걸음 나아가요."
        case .pajamas: "포근한 잠옷 차림의 피오와 편안하게 하루를 마무리해요."
        case .astronaut: "우주복을 입은 피오와 새로운 세상을 꿈꿔요."
        }
    }

    var category: PioOutfitCategory {
        switch self {
        case .basic: .free
        case .cherryBlossom, .summerVacation, .autumn, .winter: .seasonal
        case .halloween, .christmas, .hanbok: .holiday
        case .cafe, .student, .fitness, .rainyDay, .pajamas: .everyday
        case .astronaut: .special
        }
    }

    var symbol: String {
        switch self {
        case .basic: "leaf.fill"
        case .cherryBlossom: "camera.macro"
        case .summerVacation: "beach.umbrella.fill"
        case .autumn: "leaf"
        case .winter: "snowflake"
        case .halloween: "moon.stars.fill"
        case .christmas: "gift.fill"
        case .hanbok: "sparkles"
        case .cafe: "cup.and.saucer.fill"
        case .student: "graduationcap.fill"
        case .fitness: "dumbbell.fill"
        case .rainyDay: "umbrella.fill"
        case .pajamas: "bed.double.fill"
        case .astronaut: "moon.fill"
        }
    }

    /// Static full-body reference art; these names do not imply animated growth-stage rigs.
    var artAssetName: String? {
        self == .basic ? "pio_wardrobe_basic_reference" : "pio_outfit_\(rawValue)"
    }
    var plannedPriceText: String { self == .basic ? "무료" : "App Store에서 가격 확인" }
}

/// User-facing outcomes shared by the verified StoreKit flow and disabled builds.
enum PioWardrobeEntitlementResult: Equatable, Sendable {
    case purchased(PioOutfitID)
    case restored(Set<PioOutfitID>)
    case cancelled
    case pending
    case unverified
    case unavailable(message: String)
    case failed(message: String)
}

@MainActor
protocol PioWardrobeEntitlementProviding {
    func purchase(_ outfit: PioOutfitID) async -> PioWardrobeEntitlementResult
    func restore() async -> PioWardrobeEntitlementResult
}

struct UnavailablePioWardrobeEntitlements: PioWardrobeEntitlementProviding {
    func purchase(_ outfit: PioOutfitID) async -> PioWardrobeEntitlementResult {
        .unavailable(message: "의상 구매는 아직 준비 중이에요. 실제 결제는 진행되지 않아요.")
    }
    func restore() async -> PioWardrobeEntitlementResult {
        .unavailable(message: "아직 App Store 구매에 연결되어 있지 않아 구매를 복원할 수 없어요.")
    }
}

/// Device-local selections are preferences, never proof of purchase.
@MainActor @Observable
final class PioWardrobeStore {
    static let localTestingPreferencesSuite = "com.mungyubin.daylog.pio-storekit-local-testing"
    static let sandboxPreferencesSuite = "com.mungyubin.daylog.pio-storekit-sandbox"
    static let outfitTestingPreferencesSuite = "com.mungyubin.daylog.pio-wardrobe-testing"
    static let shared = PioWardrobeStore(
        defaults: preferences(for: PioPurchaseManager.shared.availability), purchases: .shared,
        isOutfitTestingEnabled: outfitTestingEnabled(arguments: ProcessInfo.processInfo.arguments),
        selectionPersistence: PioWardrobeSelectionFile.current(for: PioPurchaseManager.shared.availability,
            outfitTesting: outfitTestingEnabled(arguments: ProcessInfo.processInfo.arguments))
    )

    static func outfitTestingEnabled(arguments: [String]) -> Bool {
        #if DEBUG
        arguments.contains("-pio-wardrobe-testing")
        #else
        false
        #endif
    }

    /// Local StoreKit sessions must never replace the user's normal wardrobe
    /// selections, even when the test build shares the installed app's bundle ID.
    static func preferences(for availability: PioPurchaseAvailability,
                            production: UserDefaults = .standard,
                            localTesting: UserDefaults? = nil) -> UserDefaults {
        switch availability {
        case .localTesting: return localTesting ?? UserDefaults(suiteName: localTestingPreferencesSuite)!
        case .sandbox: return UserDefaults(suiteName: sandboxPreferencesSuite)!
        default: return production
        }
    }
    static let equippedKey = "PioWardrobe.equippedOutfit.v1"
    static let selectedIconKey = "PioWardrobe.selectedIcon.v1"
    static let previewStageKey = "PioWardrobe.previewStage.v2"
    let purchases: PioPurchaseManager
    /// A Debug display permission, never an entitlement or app-icon permission.
    let isOutfitTestingEnabled: Bool
    /// Only the explicit isolated DEBUG wardrobe playground may wear unowned art.
    /// Store unavailability must never unlock paid outfits in normal builds.
    var isFreeWearing: Bool { isOutfitTestingEnabled }
    #if DEBUG
    static let mockOwnershipKey = "PioWardrobe.debugOwnedOutfits.v1"
    private var mockOwnedOutfits: Set<PioOutfitID> = []
    @ObservationIgnored private var legacyMockMode = false
    #endif
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let selectionPersistence: (any PioWardrobeSelectionPersisting)?
    private var preferredOutfit: PioOutfitID
    private var preferredIcon: PioOutfitID
    private(set) var previewStage: Int

    var ownedOutfits: Set<PioOutfitID> {
        #if DEBUG
        if legacyMockMode { return mockOwnedOutfits.union([.basic]) }
        #endif
        return purchases.ownedOutfits
    }
    /// Preference only, never entitlement. The global appearance coordinator
    /// checks verified ownership or explicit Debug wear permission separately.
    var preferredAppearanceOutfit: PioOutfitID { preferredOutfit }
    var equippedOutfit: PioOutfitID { canWear(preferredOutfit) ? preferredOutfit : .basic }
    var selectedIcon: PioOutfitID { owns(preferredIcon) ? preferredIcon : .basic }
    var availableOutfits: Set<PioOutfitID> {
        isOutfitTestingEnabled || isFreeWearing ? Set(PioOutfitID.allCases) : ownedOutfits
    }

    init(defaults: UserDefaults = .standard, purchases: PioPurchaseManager? = nil,
         isOutfitTestingEnabled: Bool = false, outfitTestingDefaults: UserDefaults? = nil,
         selectionPersistence: (any PioWardrobeSelectionPersisting)? = nil) {
        #if DEBUG
        self.isOutfitTestingEnabled = isOutfitTestingEnabled
        #else
        self.isOutfitTestingEnabled = false
        #endif
        // Even explicit mode injection cannot write testing selections into the
        // supplied production or StoreKit profile. Tests inject a separate suite.
        let defaults = self.isOutfitTestingEnabled
            ? (outfitTestingDefaults ?? UserDefaults(suiteName: Self.outfitTestingPreferencesSuite)!)
            : defaults
        self.defaults = defaults
        self.selectionPersistence = selectionPersistence
        self.purchases = purchases ?? PioPurchaseManager()
        let storedStage = defaults.integer(forKey: Self.previewStageKey)
        previewStage = (1...4).contains(storedStage) ? storedStage : 1
        preferredOutfit = selectionPersistence?.load()
            ?? defaults.string(forKey: Self.equippedKey).flatMap(PioOutfitID.init(rawValue:)) ?? .basic
        preferredIcon = defaults.string(forKey: Self.selectedIconKey).flatMap(PioOutfitID.init(rawValue:)) ?? .basic
        self.purchases.ownershipDidChange = { [weak self] invalidated in
            self?.repairSelections(invalidated: invalidated)
        }
    }

    func owns(_ outfit: PioOutfitID) -> Bool { ownedOutfits.contains(outfit) }
    func canWear(_ outfit: PioOutfitID) -> Bool { isOutfitTestingEnabled || isFreeWearing || owns(outfit) }

    @discardableResult func equip(_ outfit: PioOutfitID) -> Bool {
        guard canWear(outfit) else { return false }
        do { try selectionPersistence?.save(outfit) }
        catch { return false }
        preferredOutfit = outfit
        defaults.set(outfit.rawValue, forKey: Self.equippedKey)
        return true
    }

    func unequip() { equip(.basic) }

    /// A local preview preference only; never changes XP, level or ownership.
    func selectPreviewStage(_ stage: Int) {
        guard (1...4).contains(stage) else { return }
        previewStage = stage
        defaults.set(stage, forKey: Self.previewStageKey)
    }

    /// This selects a theme preference; the UI separately checks that an actual
    /// alternate icon is registered before calling the operating-system API.
    @discardableResult func selectIcon(_ outfit: PioOutfitID) -> Bool {
        guard owns(outfit) else { return false }
        preferredIcon = outfit
        defaults.set(outfit.rawValue, forKey: Self.selectedIconKey)
        return true
    }

    func start() async { await purchases.start() }
    @discardableResult func refreshEntitlements() async -> Bool { await purchases.refreshEntitlements() }
    func purchase(_ outfit: PioOutfitID) async -> PioWardrobeEntitlementResult {
        await purchases.purchase(outfit)
    }
    func restorePurchases() async -> PioWardrobeEntitlementResult {
        await purchases.restore()
    }

    private func repairSelections(invalidated: Set<PioOutfitID>? = nil) {
        if !canWear(preferredOutfit), invalidated == nil || invalidated!.contains(preferredOutfit) { unequip() }
        if !owns(preferredIcon), invalidated == nil || invalidated!.contains(preferredIcon) { selectIcon(.basic) }
    }

    #if DEBUG
    /// Explicit isolated legacy fixtures only. The app's shared store never opts
    /// in and no mock ownership is imported into PioPurchaseManager.
    convenience init(defaults: UserDefaults, legacyMockMode: Bool) {
        self.init(defaults: defaults)
        self.legacyMockMode = legacyMockMode
        if legacyMockMode {
            mockOwnedOutfits = Set((defaults.stringArray(forKey: Self.mockOwnershipKey) ?? [])
                .compactMap(PioOutfitID.init(rawValue:))).subtracting([.basic])
        }
    }

    @discardableResult func mockPurchase(_ outfit: PioOutfitID) -> Bool {
        guard legacyMockMode, !owns(outfit) else { return false }
        mockOwnedOutfits.insert(outfit)
        defaults.set(mockOwnedOutfits.map(\.rawValue).sorted(), forKey: Self.mockOwnershipKey)
        return true
    }

    func resetMockPurchases() {
        guard legacyMockMode else { return }
        mockOwnedOutfits.removeAll()
        defaults.removeObject(forKey: Self.mockOwnershipKey)
        repairSelections()
    }
    #endif
}
