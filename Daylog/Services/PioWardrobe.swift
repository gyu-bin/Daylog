import CryptoKit
import Foundation
import Observation
#if os(iOS)
import WidgetKit
#endif

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
            outfitTesting: outfitTestingEnabled(arguments: ProcessInfo.processInfo.arguments)),
        cloudSelection: PioWardrobeCloudSelection.current(for: PioPurchaseManager.shared.availability,
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
    /// DEBUG 옷장 시험 모드, 또는 옷장의 숨은 해금(2026-10-26, 사용자 결정: 출시 빌드 포함).
    /// 숨은 해금은 이 기기에서 입히기만 연다(구매 내역·아이콘 선택권은 만들지 않는다). 상점을 못 열어도 자동으로 풀리지는 않는다.
    var isFreeWearing: Bool { isOutfitTestingEnabled || isSecretUnlocked }
    static let secretUnlockKey = "pio.wardrobe.secretUnlock.v1"
    private(set) var isSecretUnlocked = UserDefaults.standard.bool(forKey: PioWardrobeStore.secretUnlockKey)
    /// 비밀번호는 앱에 넣지 않고 소금을 친 SHA-256 값만 둔다(앱 파일을 열어도 비밀번호를 알 수 없다).
    static let secretSalt = "routimori.wardrobe.v1:"
    static let secretDigest = "d43a9769cbad81d66da53f72f1d9e67dac7c7ba70db003dd632ac17b0bcec7c0"
    static let secretFailuresKey = "pio.wardrobe.secretFailures.v1"
    static let secretLockedUntilKey = "pio.wardrobe.secretLockedUntil.v1"
    static let secretMaxFailures = 3
    static let secretLockout: TimeInterval = 10 * 60

    enum SecretUnlockResult: Equatable { case unlocked, wrong(remaining: Int), lockedOut(until: Date) }

    /// 옷장 미리보기 피오를 다섯 번 누른 뒤 비밀번호를 넣으면 호출한다. 세 번 틀리면 10분 동안 받지 않는다.
    static func secretMatches(_ password: String, digest: String) -> Bool {
        SHA256.hash(data: Data((secretSalt + password).utf8)).map { String(format: "%02x", $0) }.joined() == digest
    }

    @discardableResult func trySecretUnlock(password: String, now: Date = Date(),
                                            expectedDigest: String = PioWardrobeStore.secretDigest) -> SecretUnlockResult {
        let defaults = UserDefaults.standard
        if let until = defaults.object(forKey: Self.secretLockedUntilKey) as? Date, until > now { return .lockedOut(until: until) }
        guard Self.secretMatches(password, digest: expectedDigest) else {
            let failures = defaults.integer(forKey: Self.secretFailuresKey) + 1
            if failures >= Self.secretMaxFailures {
                defaults.set(0, forKey: Self.secretFailuresKey)
                let until = now.addingTimeInterval(Self.secretLockout)
                defaults.set(until, forKey: Self.secretLockedUntilKey)
                return .lockedOut(until: until)
            }
            defaults.set(failures, forKey: Self.secretFailuresKey)
            return .wrong(remaining: Self.secretMaxFailures - failures)
        }
        defaults.set(0, forKey: Self.secretFailuresKey)
        defaults.removeObject(forKey: Self.secretLockedUntilKey)
        isSecretUnlocked = true
        defaults.set(true, forKey: Self.secretUnlockKey)
        return .unlocked
    }
    func secretLock() {
        isSecretUnlocked = false
        UserDefaults.standard.set(false, forKey: Self.secretUnlockKey)
        if !owns(preferredOutfit) { equipLocally(.basic) }
    }
    #if DEBUG
    static let mockOwnershipKey = "PioWardrobe.debugOwnedOutfits.v1"
    private var mockOwnedOutfits: Set<PioOutfitID> = []
    @ObservationIgnored private var legacyMockMode = false
    #endif
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let selectionPersistence: (any PioWardrobeSelectionPersisting)?
    /// 다른 기기에서 입힌 옷(iCloud). 이 기기에서 소유가 확인되면 입힌다.
    @ObservationIgnored private let cloudSelection: PioWardrobeCloudSelection?
    @ObservationIgnored private var pendingRemoteOutfit: PioOutfitID?
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
         selectionPersistence: (any PioWardrobeSelectionPersisting)? = nil,
         cloudSelection: PioWardrobeCloudSelection? = nil) {
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
        self.cloudSelection = cloudSelection
        self.purchases = purchases ?? PioPurchaseManager()
        let storedStage = defaults.integer(forKey: Self.previewStageKey)
        previewStage = (1...4).contains(storedStage) ? storedStage : 1
        preferredOutfit = selectionPersistence?.load()
            ?? defaults.string(forKey: Self.equippedKey).flatMap(PioOutfitID.init(rawValue:)) ?? .basic
        preferredIcon = defaults.string(forKey: Self.selectedIconKey).flatMap(PioOutfitID.init(rawValue:)) ?? .basic
        self.purchases.ownershipDidChange = { [weak self] invalidated in
            self?.repairSelections(invalidated: invalidated)
            self?.applyPendingRemoteOutfit()
        }
        cloudSelection?.observe { [weak self] outfit in self?.receiveRemote(outfit) }
    }

    func owns(_ outfit: PioOutfitID) -> Bool { ownedOutfits.contains(outfit) }
    func canWear(_ outfit: PioOutfitID) -> Bool { isOutfitTestingEnabled || isFreeWearing || owns(outfit) }

    /// 사용자가 입힌 옷. 같은 계정의 다른 기기에도 알린다(받는 기기는 소유가 확인돼야 입힌다).
    @discardableResult func equip(_ outfit: PioOutfitID) -> Bool {
        guard equipLocally(outfit) else { return false }
        pendingRemoteOutfit = nil
        cloudSelection?.push(outfit)
        return true
    }

    @discardableResult private func equipLocally(_ outfit: PioOutfitID) -> Bool {
        guard canWear(outfit) else { return false }
        do { try selectionPersistence?.save(outfit) }
        catch { return false }
        preferredOutfit = outfit
        defaults.set(outfit.rawValue, forKey: Self.equippedKey)
        #if os(iOS)
        if !isOutfitTestingEnabled {
            RoutineLiveActivityOutfit.set(outfit.rawValue)
            AppRuntime.shared?.scheduleRefresh()
            // 잠금 화면 위젯의 피오도 바로 갈아입힌다. 입은 옷은 위젯 데이터에 없어서, 그것만으로는 위젯을 다시 그리지 않는다.
            WidgetCenter.shared.reloadAllTimelines()
        }
        #endif
        return true
    }

    func unequip() { equip(.basic) }

    private func receiveRemote(_ outfit: PioOutfitID) {
        guard outfit != preferredOutfit else { pendingRemoteOutfit = nil; return }
        if canWear(outfit) { equipLocally(outfit); pendingRemoteOutfit = nil }
        else { pendingRemoteOutfit = outfit }
    }

    private func applyPendingRemoteOutfit() {
        if pendingRemoteOutfit == nil, let remote = cloudSelection?.remoteOutfit, remote != preferredOutfit { pendingRemoteOutfit = remote }
        guard let outfit = pendingRemoteOutfit, canWear(outfit) else { return }
        equipLocally(outfit)
        pendingRemoteOutfit = nil
    }

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
        let result = await purchases.purchase(outfit)
        // 산 옷은 바로 입힌다(2026-10-26). 다른 기기에도 함께 바뀐다.
        if case .purchased(let bought) = result { equip(bought) }
        return result
    }
    func restorePurchases() async -> PioWardrobeEntitlementResult {
        await purchases.restore()
    }

    private func repairSelections(invalidated: Set<PioOutfitID>? = nil) {
        if !canWear(preferredOutfit), invalidated == nil || invalidated!.contains(preferredOutfit) { equipLocally(.basic) }
        if !owns(preferredIcon), invalidated == nil || invalidated!.contains(preferredIcon) { selectIcon(.basic) }
        // 환불되면 홈 화면 아이콘도 기본으로 돌린다(검증된 구매 내역 기준).
        Task { @MainActor [weak self] in
            guard let self else { return }
            await PioAppIconService.reconcile(store: self)
        }
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
