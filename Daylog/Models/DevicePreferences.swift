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
    /// "다시 시작하기" 안내를 닫은 날(날짜 키). 그 뒤로 다시 실천하기 전까지는 같은 쉬는 기간으로 보고 띄우지 않는다.
    static let restartDismissedKey = "device.restartPrompt.dismissedDay"
    /// 사용자가 고른 주간 목표(일). 없으면 루틴 일정에 맞춘 추천값을 쓴다.
    static let weeklyGoalKey = "device.weeklyGoalDays"
    /// 알림 안내(iPhone·iPad)를 이 기기에서 이미 보여 줬는지.
    static let notificationGuideKey = "device.notificationGuideCompleted"
    /// 사용자가 대시보드 배치(순서·숨김·열)를 직접 바꿨는지. 바꿨으면 원격 기본값이 덮어쓰지 않는다.
    static let customizedKey = "device.dashboard.customized"
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
    /// 알림 안내를 이미 보여 줬거나 보여 줄 필요가 없다고 정했다. 다시 띄우지 않는다.
    private(set) var notificationGuideCompleted: Bool
    /// 사용자가 배치를 직접 바꾼 적이 있다. 이 값이 false인 동안에만 기본 배치(내장·원격)가 그대로 따라온다.
    private(set) var isLayoutCustomized: Bool
    /// 원격 설정이 준 기본 배치(iPhone·iPad). 없으면 내장 기본값을 쓴다.
    @ObservationIgnored private var remoteDefaultOrder: [DashboardCard]?
    @ObservationIgnored private var remoteDefaultHidden: Set<DashboardCard>?
    /// 달력의 한 주가 시작하는 요일. 기본은 월요일.
    private(set) var weekStart: WeekStart
    /// 이번 주의 성장 카드의 목표(1~7일). 고르지 않았으면 nil이고 추천값을 쓴다. 이 기기에만 저장한다.
    private(set) var weeklyGoal: Int?
    /// "다시 시작하기" 안내를 닫은 날. 닫은 적이 없으면 nil. 이 기기에만 저장한다.
    private(set) var restartDismissedDay: Day?

    init(defaults: UserDefaults = .standard, isPhone: Bool = Platform.isPhone) {
        self.defaults = defaults
        self.isPhone = isPhone
        mealsEnabled = defaults.object(forKey: Self.mealsKey) as? Bool ?? true
        onboardingCompleted = defaults.object(forKey: Self.onboardingKey) as? Bool ?? false
        notificationGuideCompleted = defaults.bool(forKey: Self.notificationGuideKey)
        weekStart = defaults.string(forKey: Self.weekStartKey).flatMap(WeekStart.init(rawValue:)) ?? .monday
        weeklyGoal = (defaults.object(forKey: Self.weeklyGoalKey) as? Int).flatMap { (1...7).contains($0) ? $0 : nil }
        restartDismissedDay = defaults.string(forKey: Self.restartDismissedKey).flatMap(Day.init(key:))
        isLayoutCustomized = false
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
            return
        }
        // 저장된 순서에 없는 기본 카드(앱이 새로 얻은 카드) 가운데 처음에 숨기는 카드.
        let savedNames = Set(defaults.stringArray(forKey: Self.orderKey) ?? [])
        let newcomers = DashboardCard.allCases.filter { !savedNames.contains($0.rawValue) && DashboardCard.defaultHidden.contains($0) }
        if let stored = defaults.object(forKey: Self.customizedKey) as? Bool {
            isLayoutCustomized = stored
        } else {
            // 이 표시가 생기기 전에 저장된 배치: 내장 기본 배치와 다르면 사용자가 바꾼 것으로 본다.
            // 그 뒤에 생긴 기본 숨김 카드는 저장된 숨김 목록에 없을 수밖에 없으니 비교에서 뺀다.
            isLayoutCustomized = cardOrder != DashboardCard.defaultOrder(phone: isPhone)
                || hiddenCards != DashboardCard.defaultHidden.subtracting(newcomers) || leftCards != DashboardCard.defaultLeft
            defaults.set(isLayoutCustomized, forKey: Self.customizedKey)
        }
        // 배치를 바꾼 사용자: 그 사람이 고른 카드의 표시·순서·열은 그대로이고, 본 적 없는 새 카드만 기본값(숨김)으로 들인다.
        // 배치를 바꾸지 않은 사용자는 아래에서 기본 배치를 그대로 따른다.
        if isLayoutCustomized, !newcomers.isEmpty {
            hiddenCards.formUnion(newcomers)
            saveLayout()
        }
        if !isLayoutCustomized {
            // 배치를 바꾼 적이 없으면 지금 앱의 기본 배치를 따른다. 앱이 새 기본 카드를 얻었을 때 그 카드가 맨 아래가 아니라
            // 제자리에 놓인다. 배치를 바꾼 사람은 위에서 읽은 그대로이고, 새 카드는 맨 뒤에 붙는다(`normalizedOrder`).
            let order = DashboardCard.defaultOrder(phone: isPhone) + cardOrder.filter(\.isCustom)
            let hidden = DashboardCard.defaultHidden.union(hiddenCards.filter(\.isCustom))
            let left = DashboardCard.defaultLeft.union(leftCards.filter(\.isCustom))
            if order != cardOrder || hidden != hiddenCards || left != leftCards {
                cardOrder = order
                hiddenCards = hidden
                leftCards = left
                saveLayout()
            }
        }
    }

    /// 기본 배치: 원격 설정이 준 것이 있으면 그것, 없으면 내장값. 순서는 iPhone(한 열)에서만 원격 값을 따른다.
    private var defaultOrder: [DashboardCard] {
        isPhone ? (remoteDefaultOrder ?? DashboardCard.defaultOrder(phone: true)) : DashboardCard.defaultOrder(phone: false)
    }

    private var defaultHidden: Set<DashboardCard> { remoteDefaultHidden ?? DashboardCard.defaultHidden }

    /// 원격 설정의 기본 배치를 받는다. 사용자가 배치를 바꾼 적이 없을 때만 지금 배치에 반영한다.
    /// 사용자가 바꾼 배치는 건드리지 않고, [기본 배치 복원]을 누를 때 쓸 기본값으로만 기억한다.
    func applyRemoteDefaults(order: [String]?, hidden: [String]?) {
        remoteDefaultOrder = order.map(DashboardCard.remoteOrder)
        // 설정이 모르는 나중 카드(순서에도 숨김에도 적히지 않은 것)는 앱의 기본값을 따른다. 예: 주간 회고는 숨긴 채로.
        let named = Set((order ?? []) + (hidden ?? []))
        let lateHidden = DashboardCard.lateAdditions.filter { !named.contains($0.rawValue) && DashboardCard.defaultHidden.contains($0) }
        remoteDefaultHidden = hidden.map { Set($0.compactMap(DashboardCard.init(rawValue:))).subtracting([.routines]).union(lateHidden) }
        guard !isLayoutCustomized else { return }
        // 기본 배치는 기본 카드만 정한다. 꾸미기 카드는 그 뒤에 그대로 둔다.
        let order = defaultOrder + cardOrder.filter(\.isCustom)
        let hidden = defaultHidden.union(hiddenCards.filter(\.isCustom))
        guard order != cardOrder || hidden != hiddenCards else { return }
        cardOrder = order
        hiddenCards = hidden
        saveLayout()
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

    /// "다시 시작하기" 안내를 닫는다. nil이면 닫은 기록을 지운다(검증용).
    func setRestartDismissedDay(_ day: Day?) {
        restartDismissedDay = day
        if let day {
            defaults.set(day.key, forKey: Self.restartDismissedKey)
        } else {
            defaults.removeObject(forKey: Self.restartDismissedKey)
        }
    }

    /// 주간 목표를 정한다(1~7일). nil이면 추천값으로 되돌린다.
    func setWeeklyGoal(_ days: Int?) {
        weeklyGoal = days.map { min(max($0, 1), 7) }
        if let weeklyGoal {
            defaults.set(weeklyGoal, forKey: Self.weeklyGoalKey)
        } else {
            defaults.removeObject(forKey: Self.weeklyGoalKey)
        }
    }

    func setVisible(_ visible: Bool, card: DashboardCard) {
        guard card != .routines else { return }
        if visible { hiddenCards.remove(card) } else { hiddenCards.insert(card) }
        markCustomized()
        saveLayout()
    }

    /// 전체 순서에서 한 칸 옮긴다(설정 화면의 위/아래 단추).
    func move(_ card: DashboardCard, by offset: Int) {
        guard let index = cardOrder.firstIndex(of: card), cardOrder.indices.contains(index + offset) else { return }
        cardOrder.swapAt(index, index + offset)
        markCustomized()
        saveLayout()
    }

    /// 목록에 보이는 카드끼리 한 칸 옮긴다. 이 기기에 내용이 없는 카드(다른 기기에서 지운 텍스트 카드 등)는
    /// 순서에는 남아 있어도 목록에 없으므로, 그 카드와 자리를 바꾸면 눌러도 아무 일도 없는 것처럼 보인다.
    func move(_ card: DashboardCard, by offset: Int, among listed: [DashboardCard]) {
        guard let index = listed.firstIndex(of: card), listed.indices.contains(index + offset),
              let from = cardOrder.firstIndex(of: card),
              let to = cardOrder.firstIndex(of: listed[index + offset]) else { return }
        cardOrder.swapAt(from, to)
        markCustomized()
        saveLayout()
    }

    func setColumn(_ column: DashboardColumn, for card: DashboardCard) {
        guard !card.spansFullWidth else { return }
        if column == .left { leftCards.insert(card) } else { leftCards.remove(card) }
        markCustomized()
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
        markCustomized()
        saveLayout()
    }

    /// 카드를 그 열의 맨 아래로 보낸다(열의 빈 자리에 놓기).
    func place(_ card: DashboardCard, atEndOf column: DashboardColumn) {
        guard !card.spansFullWidth else { return }
        cardOrder = cardOrder.filter { $0 != card } + [card]
        if column == .left { leftCards.insert(card) } else { leftCards.remove(card) }
        markCustomized()
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

    /// 기본 배치로 되돌린다. 이후로는 다시 기본 배치(원격 설정이 바꾸면 그것)를 따른다.
    /// 꾸미기 카드는 지우지 않는다: 기본 카드 뒤(각자 있던 열의 아래쪽)로 보내고 다시 보이게 한다.
    func restoreDashboard() {
        let custom = cardOrder.filter(\.isCustom)
        cardOrder = defaultOrder + custom
        hiddenCards = defaultHidden
        leftCards = DashboardCard.defaultLeft.union(leftCards.filter(\.isCustom))
        isLayoutCustomized = false
        saveLayout()
    }

    /// 꾸미기 카드를 맨 위에 더한다. 두 열 화면에서는 오른쪽 열의 맨 위라서, 왼쪽 열의 오늘 루틴은 밀리지 않는다.
    func addCustom(_ card: DashboardCard, column: DashboardColumn = .right) {
        guard card.isCustom, !cardOrder.contains(card) else { return }
        cardOrder.insert(card, at: 0)
        if column == .left { leftCards.insert(card) }
        markCustomized()
        saveLayout()
    }

    /// 꾸미기 카드를 배치에서 뺀다. 내용을 지우는 일은 부른 쪽이 한다.
    func removeCustom(_ card: DashboardCard) {
        guard card.isCustom else { return }
        cardOrder.removeAll { $0 == card }
        hiddenCards.remove(card)
        leftCards.remove(card)
        markCustomized()
        saveLayout()
    }

    private func markCustomized() {
        isLayoutCustomized = true
    }

    func completeNotificationGuide() {
        guard !notificationGuideCompleted else { return }
        notificationGuideCompleted = true
        defaults.set(true, forKey: Self.notificationGuideKey)
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
        defaults.set(isLayoutCustomized, forKey: Self.customizedKey)
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

/// 대시보드 카드. 기본 카드는 선언 순서가 기본 순서다.
enum DashboardCard: Hashable, Identifiable, RawRepresentable, CaseIterable {
    case summary, nextRoutine, vacation, routines, weeklyGrowth, saessagiGrowth, weeklyReview, meals, achievement, recentDays, tomorrow
    case calendar, trend, routineRates
    /// 사용자가 더한 꾸미기 카드(이미지·텍스트·섹션 제목·구분선). 내용은 `DashboardDecor`와 `AppStore.dashboardTexts`에 있다.
    case custom(CustomCardKind, UUID)

    var id: String { rawValue }

    /// 앱이 제공하는 기본 카드. 꾸미기 카드는 들어 있지 않다(원격 설정의 허용 목록도 이 값을 쓴다).
    /// 이번 주의 성장은 두 열 화면에서 오른쪽 열의 맨 위이고, 새싹이 성장과 새싹이의 주간 회고는 왼쪽 열의 오늘 루틴 아래다.
    static let allCases: [DashboardCard] = [
        .summary, .nextRoutine, .vacation, .routines, .weeklyGrowth, .saessagiGrowth, .weeklyReview, .meals, .achievement,
        .recentDays, .tomorrow, .calendar, .trend, .routineRates
    ]

    static let defaultOrder: [DashboardCard] = allCases

    /// iPhone의 기본 순서: 오늘의 진행률이 맨 위(예전 iPhone 오늘 화면과 같다). 나머지는 같다.
    static func defaultOrder(phone: Bool) -> [DashboardCard] {
        // iPhone: 달성 현황 → 이번 주의 성장 → 다음 루틴 → 루틴 → 새싹이 성장 → 주간 회고 → 식사 → 최근 7일 → 내일 할 일 → 휴가.
        // 휴가는 가끔 보는 카드라 아래에 둔다. 새싹이 성장은 오늘 루틴을 체크한 바로 아래에서 반응이 보이게 둔다.
        let phoneFirst: [DashboardCard] = [
            .achievement, .weeklyGrowth, .nextRoutine, .routines, .saessagiGrowth, .weeklyReview, .meals, .recentDays, .tomorrow,
            .vacation
        ]
        return phone ? phoneFirst + allCases.filter { !phoneFirst.contains($0) } : defaultOrder
    }
    /// 통계 화면에 있는 카드와 지표 띠는 처음에는 숨긴다. 시안의 구성(휴가·루틴 | 식사·달성 현황·7일·내일)을 따른다.
    /// 새싹이의 주간 회고도 처음에는 숨긴다(카드 편집에서 켠다).
    static let defaultHidden: Set<DashboardCard> = [.summary, .calendar, .trend, .routineRates, .weeklyReview]
    /// 두 열 화면의 왼쪽 열: 오늘 루틴 아래에 새싹이 성장과 주간 회고를 둔다. 오른쪽 열(이번 주의 성장·식사·달성 현황·7일·내일)만
    /// 길어지지 않게 하고, 루틴을 체크하면 바로 아래의 성장 카드가 반응하는 것이 보이게 한다.
    /// 배치를 바꾼 적 없는 사용자만 이 값을 따른다(바꾼 사용자의 열은 그대로다).
    static let defaultLeft: Set<DashboardCard> = [.nextRoutine, .vacation, .routines, .saessagiGrowth, .weeklyReview]

    var title: String {
        switch self {
        case .summary: return "주요 지표"
        case .nextRoutine: return "다음 루틴"
        case .vacation: return "휴가 설정"
        case .routines: return "오늘 루틴"
        case .weeklyGrowth: return "이번 주의 성장"
        case .saessagiGrowth: return "새싹이 성장"
        case .weeklyReview: return "새싹이의 주간 회고"
        case .meals: return "식사 기록"
        case .achievement: return "오늘의 달성 현황"
        case .recentDays: return "최근 7일 기록"
        case .tomorrow: return "내일 오전 할 일"
        case .calendar: return "월간 캘린더"
        case .trend: return "달성률 추이"
        case .routineRates: return "루틴별 달성률"
        case .custom(let kind, _): return kind.title
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

    /// 원격 설정의 형식이 정해진 뒤에 생긴 기본 카드. 게시된 설정의 순서에는 이 카드가 없을 수 있다
    /// (Tools/mobile-config.sh의 OPTIONAL_CARDS와 같다).
    static let lateAdditions: [DashboardCard] = [.weeklyGrowth, .saessagiGrowth, .weeklyReview]

    /// 원격 설정이 준 iPhone 기본 순서를 전체 순서로 만든다. 적히지 않은 카드는 뒤에 붙이되(예전과 같다),
    /// 나중에 생긴 카드는 맨 아래로 밀리지 않게 내장 순서에서 바로 앞에 있던 카드 뒤에 둔다.
    static func remoteOrder(_ names: [String]) -> [DashboardCard] {
        let named = names.compactMap(Self.init(rawValue:))
        var result = normalizedOrder(names)
        let reference = defaultOrder(phone: true)
        for card in lateAdditions where !named.contains(card) {
            guard let index = reference.firstIndex(of: card), index > 0,
                  let anchor = result.firstIndex(of: reference[index - 1]) else { continue }
            result.removeAll { $0 == card }
            // 앞의 카드가 지워진 자리 뒤에 있었으면 한 칸 당겨졌다.
            let position = result.firstIndex(of: reference[index - 1]) ?? anchor
            result.insert(card, at: position + 1)
        }
        return result
    }
}

enum OnboardingStep: Int, CaseIterable {
    case introduction, createRoutine, ready
    var next: OnboardingStep { Self(rawValue: rawValue + 1) ?? .ready }
}
