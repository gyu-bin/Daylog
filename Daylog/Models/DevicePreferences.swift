import Foundation
import Observation

/// Presentation choices belong to this device. They never alter SwiftData or CloudKit records.
@MainActor
@Observable
final class DevicePreferences {
    static let shared = DevicePreferences()
    static let mealsKey = "device.mealsEnabled"
    static let orderKey = "device.dashboard.order"
    static let hiddenKey = "device.dashboard.hidden"
    static let leftKey = "device.dashboard.left"
    static let layoutVersionKey = "device.dashboard.layoutVersion"
    static let onboardingKey = "device.onboardingCompleted"
    static let weekStartKey = "device.weekStart"
    /// 대시보드 배치의 형식 번호. 2 = 두 열 배치(휴가·달성 현황·내일 할 일 카드가 생김).
    /// 이보다 낮은(또는 없는) 저장값은 예전 한 열 배치라 기본 배치로 되돌린다.
    static let layoutVersion = 2

    @ObservationIgnored private let defaults: UserDefaults
    /// iPhone은 한 열뿐이라 진행률을 맨 위에 두는 순서를 기본으로 쓴다.
    @ObservationIgnored private let isPhone: Bool
    private(set) var mealsEnabled: Bool
    /// 전체 카드의 순서. 한 열일 때는 이 순서대로, 두 열일 때는 이 순서를 열별로 나눠 보여 준다.
    private(set) var cardOrder: [DashboardCard]
    private(set) var hiddenCards: Set<DashboardCard>
    /// 두 열 배치에서 왼쪽 열에 두는 카드. 나머지는 오른쪽.
    private(set) var leftCards: Set<DashboardCard>
    private(set) var onboardingCompleted: Bool
    /// 달력의 한 주가 시작하는 요일. 기본은 월요일.
    private(set) var weekStart: WeekStart

    init(defaults: UserDefaults = .standard, isPhone: Bool = Platform.isPhone) {
        self.defaults = defaults
        self.isPhone = isPhone
        mealsEnabled = defaults.object(forKey: Self.mealsKey) as? Bool ?? true
        onboardingCompleted = defaults.object(forKey: Self.onboardingKey) as? Bool ?? false
        weekStart = defaults.string(forKey: Self.weekStartKey).flatMap(WeekStart.init(rawValue:)) ?? .monday
        if defaults.integer(forKey: Self.layoutVersionKey) >= Self.layoutVersion {
            cardOrder = DashboardCard.normalizedOrder(defaults.stringArray(forKey: Self.orderKey) ?? [])
            hiddenCards = Set((defaults.stringArray(forKey: Self.hiddenKey) ?? []).compactMap(DashboardCard.init(rawValue:)))
                .subtracting([.routines])
            leftCards = Set((defaults.stringArray(forKey: Self.leftKey) ?? []).compactMap(DashboardCard.init(rawValue:)))
        } else {
            cardOrder = DashboardCard.defaultOrder(phone: isPhone)
            hiddenCards = DashboardCard.defaultHidden
            leftCards = DashboardCard.defaultLeft
            saveLayout()
        }
    }

    var visibleCards: [DashboardCard] {
        cardOrder.filter { !hiddenCards.contains($0) && ($0 != .meals || mealsEnabled) }
    }

    /// 숨긴 카드 중 지금 다시 보일 수 있는 것(식사가 꺼져 있으면 식사 카드는 제외).
    var hiddenChoices: [DashboardCard] {
        cardOrder.filter { hiddenCards.contains($0) && ($0 != .meals || mealsEnabled) }
    }

    func column(of card: DashboardCard) -> DashboardColumn {
        leftCards.contains(card) ? .left : .right
    }

    /// 보이는 카드를 두 열 배치로 나눈다. 띠 카드(주요 지표)는 열 위에 가로로 놓인다.
    func layout(of cards: [DashboardCard]) -> DashboardLayout {
        DashboardLayout(
            band: cards.filter(\.spansFullWidth),
            left: cards.filter { !$0.spansFullWidth && leftCards.contains($0) },
            right: cards.filter { !$0.spansFullWidth && !leftCards.contains($0) }
        )
    }

    func navigationSections(phone: Bool) -> [AppStore.Section] {
        (phone ? AppStore.Section.phoneTabs : AppStore.Section.allCases).filter { $0 != .meals || mealsEnabled }
    }

    func safeSelection(_ section: AppStore.Section) -> AppStore.Section {
        section == .meals && !mealsEnabled ? .dashboard : section
    }

    /// Call through AppStore when hiding meals so outstanding edits finish saving first.
    func setMealsEnabled(_ enabled: Bool) {
        mealsEnabled = enabled
        defaults.set(enabled, forKey: Self.mealsKey)
    }

    func setWeekStart(_ value: WeekStart) {
        weekStart = value
        defaults.set(value.rawValue, forKey: Self.weekStartKey)
    }

    func setVisible(_ visible: Bool, card: DashboardCard) {
        guard card != .routines else { return }
        if visible { hiddenCards.remove(card) } else { hiddenCards.insert(card) }
        saveLayout()
    }

    /// 전체 순서에서 한 칸 옮긴다(설정 화면의 위/아래 단추).
    func move(_ card: DashboardCard, by offset: Int) {
        guard let index = cardOrder.firstIndex(of: card), cardOrder.indices.contains(index + offset) else { return }
        cardOrder.swapAt(index, index + offset)
        saveLayout()
    }

    func setColumn(_ column: DashboardColumn, for card: DashboardCard) {
        guard !card.spansFullWidth else { return }
        if column == .left { leftCards.insert(card) } else { leftCards.remove(card) }
        saveLayout()
    }

    /// 카드를 다른 카드 바로 앞에 놓는다(끌어서 놓기). 놓인 카드와 같은 열이 된다.
    func place(_ card: DashboardCard, before target: DashboardCard) {
        guard card != target, !card.spansFullWidth, !target.spansFullWidth else { return }
        var order = cardOrder.filter { $0 != card }
        guard let index = order.firstIndex(of: target) else { return }
        order.insert(card, at: index)
        cardOrder = order
        if leftCards.contains(target) { leftCards.insert(card) } else { leftCards.remove(card) }
        saveLayout()
    }

    /// 카드를 그 열의 맨 아래로 보낸다(열의 빈 자리에 놓기).
    func place(_ card: DashboardCard, atEndOf column: DashboardColumn) {
        guard !card.spansFullWidth else { return }
        cardOrder = cardOrder.filter { $0 != card } + [card]
        if column == .left { leftCards.insert(card) } else { leftCards.remove(card) }
        saveLayout()
    }

    /// 같은 열 안에서 한 칸 위로. 열의 맨 위면 아무것도 하지 않는다.
    func moveUp(_ card: DashboardCard, in column: [DashboardCard]) {
        guard let index = column.firstIndex(of: card), index > 0 else { return }
        place(card, before: column[index - 1])
    }

    /// 같은 열 안에서 한 칸 아래로. 열의 맨 아래면 아무것도 하지 않는다.
    func moveDown(_ card: DashboardCard, in column: [DashboardCard]) {
        guard let index = column.firstIndex(of: card), index + 1 < column.count else { return }
        place(column[index + 1], before: card)
    }

    func restoreDashboard() {
        cardOrder = DashboardCard.defaultOrder(phone: isPhone)
        hiddenCards = DashboardCard.defaultHidden
        leftCards = DashboardCard.defaultLeft
        saveLayout()
    }

    func completeOnboarding() {
        onboardingCompleted = true
        defaults.set(true, forKey: Self.onboardingKey)
    }

    private func saveLayout() {
        defaults.set(cardOrder.map(\.rawValue), forKey: Self.orderKey)
        defaults.set(hiddenCards.map(\.rawValue).sorted(), forKey: Self.hiddenKey)
        defaults.set(leftCards.map(\.rawValue).sorted(), forKey: Self.leftKey)
        defaults.set(Self.layoutVersion, forKey: Self.layoutVersionKey)
    }
}

enum DashboardColumn: String, CaseIterable {
    case left, right

    var title: String { self == .left ? "왼쪽" : "오른쪽" }
}

/// 두 열 배치: 열 위의 띠, 왼쪽 열, 오른쪽 열. 각 목록은 전체 순서를 따른다.
struct DashboardLayout: Equatable {
    var band: [DashboardCard]
    var left: [DashboardCard]
    var right: [DashboardCard]

    func cards(in column: DashboardColumn) -> [DashboardCard] {
        column == .left ? left : right
    }
}

/// 대시보드 카드. 선언 순서가 기본 순서다.
enum DashboardCard: String, CaseIterable, Identifiable {
    case summary, nextRoutine, vacation, routines, meals, achievement, recentDays, tomorrow, calendar, trend, routineRates
    var id: String { rawValue }

    static let defaultOrder: [DashboardCard] = allCases

    /// iPhone의 기본 순서: 오늘의 진행률이 맨 위(예전 iPhone 오늘 화면과 같다). 나머지는 같다.
    static func defaultOrder(phone: Bool) -> [DashboardCard] {
        // iPhone: 달성 현황 → 다음 루틴 → 루틴 → 식사 → 최근 7일 → 내일 할 일 → 휴가. 휴가는 가끔 보는 카드라 아래에 둔다.
        let phoneFirst: [DashboardCard] = [.achievement, .nextRoutine, .routines, .meals, .recentDays, .tomorrow, .vacation]
        return phone ? phoneFirst + allCases.filter { !phoneFirst.contains($0) } : defaultOrder
    }
    /// 통계 화면에 있는 카드와 지표 띠는 처음에는 숨긴다. 시안의 구성(휴가·루틴 | 식사·달성 현황·7일·내일)을 따른다.
    static let defaultHidden: Set<DashboardCard> = [.summary, .calendar, .trend, .routineRates]
    static let defaultLeft: Set<DashboardCard> = [.nextRoutine, .vacation, .routines]

    var title: String {
        switch self {
        case .summary: return "주요 지표"
        case .nextRoutine: return "다음 루틴"
        case .vacation: return "휴가 설정"
        case .routines: return "오늘 루틴"
        case .meals: return "식사 기록"
        case .achievement: return "오늘의 달성 현황"
        case .recentDays: return "최근 7일 기록"
        case .tomorrow: return "내일 오전 할 일"
        case .calendar: return "월간 캘린더"
        case .trend: return "달성률 추이"
        case .routineRates: return "루틴별 달성률"
        }
    }

    /// 두 열 배치에서 열에 들어가지 않고 위에 가로로 놓이는 카드.
    var spansFullWidth: Bool { self == .summary }

    static func normalizedOrder(_ saved: [String]) -> [DashboardCard] {
        var result: [DashboardCard] = []
        for card in saved.compactMap(Self.init(rawValue:)) + allCases where !result.contains(card) {
            result.append(card)
        }
        return result
    }
}

enum OnboardingStep: Int, CaseIterable {
    case introduction, createRoutine, ready
    var next: OnboardingStep { Self(rawValue: rawValue + 1) ?? .ready }
}
