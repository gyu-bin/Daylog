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
        case .cherryBlossom: "봄바람과 벚꽃을 닮은 의상을 준비하고 있어요."
        case .summerVacation: "시원한 여름 휴가를 위한 의상을 준비하고 있어요."
        case .autumn: "포근한 가을빛 의상을 준비하고 있어요."
        case .winter: "추운 날을 따뜻하게 감싸 줄 의상을 준비하고 있어요."
        case .halloween: "귀여운 할로윈 의상을 준비하고 있어요."
        case .christmas: "설레는 크리스마스 의상을 준비하고 있어요."
        case .hanbok: "고운 한복 의상을 준비하고 있어요."
        case .cafe: "느긋한 카페 시간을 위한 의상을 준비하고 있어요."
        case .student: "새로운 배움을 응원하는 의상을 준비하고 있어요."
        case .fitness: "가볍게 몸을 움직이는 날의 의상을 준비하고 있어요."
        case .rainyDay: "비 오는 날도 즐거운 의상을 준비하고 있어요."
        case .pajamas: "편안한 휴식을 위한 잠옷을 준비하고 있어요."
        case .astronaut: "새로운 세상을 탐험할 우주복을 준비하고 있어요."
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

    var artAssetName: String? { self == .basic ? "pio_wardrobe_basic_reference" : nil }
    var plannedPriceText: String { self == .basic ? "무료" : "출시 예정 · 약 ₩1,000" }
}

/// A future verified payment adapter can implement this boundary. V1 never
/// turns these results into production entitlements and has no payment connection.
enum PioWardrobeEntitlementResult: Equatable, Sendable {
    case purchased(PioOutfitID)
    case restored(Set<PioOutfitID>)
    case cancelled
    case pending
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

/// Device-local V1 preferences. Wardrobe selections never touch growth, XP,
/// SwiftData or cloud records. Mock ownership exists only in DEBUG builds.
@MainActor @Observable
final class PioWardrobeStore {
    static let shared = PioWardrobeStore()
    static let equippedKey = "PioWardrobe.equippedOutfit.v1"
    static let selectedIconKey = "PioWardrobe.selectedIcon.v1"
    #if DEBUG
    static let mockOwnershipKey = "PioWardrobe.debugOwnedOutfits.v1"
    private var mockOwnedOutfits: Set<PioOutfitID>
    #endif
    @ObservationIgnored private let defaults: UserDefaults
    private(set) var equippedOutfit: PioOutfitID
    private(set) var selectedIcon: PioOutfitID

    var ownedOutfits: Set<PioOutfitID> {
        #if DEBUG
        mockOwnedOutfits.union([.basic])
        #else
        [.basic]
        #endif
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var owned: Set<PioOutfitID> = [.basic]
        #if DEBUG
        let mock = Set((defaults.stringArray(forKey: Self.mockOwnershipKey) ?? [])
            .compactMap(PioOutfitID.init(rawValue:))).subtracting([.basic])
        mockOwnedOutfits = mock
        owned.formUnion(mock)
        #endif
        func selection(_ key: String) -> PioOutfitID {
            guard let raw = defaults.string(forKey: key), let outfit = PioOutfitID(rawValue: raw),
                  owned.contains(outfit) else { return .basic }
            return outfit
        }
        equippedOutfit = selection(Self.equippedKey)
        selectedIcon = selection(Self.selectedIconKey)
    }

    func owns(_ outfit: PioOutfitID) -> Bool { ownedOutfits.contains(outfit) }

    @discardableResult func equip(_ outfit: PioOutfitID) -> Bool {
        guard owns(outfit) else { return false }
        equippedOutfit = outfit
        defaults.set(outfit.rawValue, forKey: Self.equippedKey)
        return true
    }

    func unequip() { equip(.basic) }

    @discardableResult func selectIcon(_ outfit: PioOutfitID) -> Bool {
        guard owns(outfit) else { return false }
        selectedIcon = outfit
        defaults.set(outfit.rawValue, forKey: Self.selectedIconKey)
        return true
    }

    func restorePurchases() async -> PioWardrobeEntitlementResult {
        await UnavailablePioWardrobeEntitlements().restore()
    }

    #if DEBUG
    @discardableResult func mockPurchase(_ outfit: PioOutfitID) -> Bool {
        guard !owns(outfit) else { return false }
        mockOwnedOutfits.insert(outfit)
        defaults.set(mockOwnedOutfits.map(\.rawValue).sorted(), forKey: Self.mockOwnershipKey)
        return true
    }

    func resetMockPurchases() {
        mockOwnedOutfits.removeAll()
        defaults.removeObject(forKey: Self.mockOwnershipKey)
        if !owns(equippedOutfit) { unequip() }
        if !owns(selectedIcon) { selectIcon(.basic) }
    }
    #endif
}
