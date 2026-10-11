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
    static let onboardingKey = "device.onboardingCompleted"

    @ObservationIgnored private let defaults: UserDefaults
    private(set) var mealsEnabled: Bool
    private(set) var cardOrder: [DashboardCard]
    private(set) var hiddenCards: Set<DashboardCard>
    private(set) var onboardingCompleted: Bool

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        mealsEnabled = defaults.object(forKey: Self.mealsKey) as? Bool ?? true
        onboardingCompleted = defaults.object(forKey: Self.onboardingKey) as? Bool ?? false
        cardOrder = DashboardCard.normalizedOrder(defaults.stringArray(forKey: Self.orderKey) ?? [])
        hiddenCards = Set((defaults.stringArray(forKey: Self.hiddenKey) ?? []).compactMap(DashboardCard.init(rawValue:)))
            .subtracting([.routines])
    }

    var visibleCards: [DashboardCard] {
        cardOrder.filter { !hiddenCards.contains($0) && ($0 != .meals || mealsEnabled) }
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

    func setVisible(_ visible: Bool, card: DashboardCard) {
        guard card != .routines else { return }
        if visible { hiddenCards.remove(card) } else { hiddenCards.insert(card) }
        saveLayout()
    }

    func move(_ card: DashboardCard, by offset: Int) {
        guard let index = cardOrder.firstIndex(of: card), cardOrder.indices.contains(index + offset) else { return }
        cardOrder.swapAt(index, index + offset)
        saveLayout()
    }

    func restoreDashboard() {
        cardOrder = DashboardCard.allCases
        hiddenCards = []
        saveLayout()
    }

    func completeOnboarding() {
        onboardingCompleted = true
        defaults.set(true, forKey: Self.onboardingKey)
    }

    private func saveLayout() {
        defaults.set(cardOrder.map(\.rawValue), forKey: Self.orderKey)
        defaults.set(hiddenCards.map(\.rawValue).sorted(), forKey: Self.hiddenKey)
    }
}

enum DashboardCard: String, CaseIterable, Identifiable {
    case summary, nextRoutine, routines, meals, recentDays, calendar, trend, routineRates
    var id: String { rawValue }
    var title: String {
        switch self {
        case .summary: return "진행률과 주요 지표"
        case .nextRoutine: return "다음 루틴"
        case .routines: return "오늘 루틴"
        case .meals: return "식사 기록"
        case .recentDays: return "최근 7일 기록"
        case .calendar: return "월간 캘린더"
        case .trend: return "달성률 추이"
        case .routineRates: return "루틴별 달성률"
        }
    }

    static func normalizedOrder(_ saved: [String]) -> [DashboardCard] {
        var result: [DashboardCard] = []
        for card in saved.compactMap(Self.init(rawValue:)) + allCases where !result.contains(card) {
            result.append(card)
        }
        return result
    }

    /// Reading order is identical in both layouts; summary and next action use the full row.
    static func rows(_ cards: [DashboardCard], wide: Bool) -> [[DashboardCard]] {
        guard wide else { return cards.map { [$0] } }
        var rows: [[DashboardCard]] = []
        var pair: [DashboardCard] = []
        for card in cards {
            if card == .summary || card == .nextRoutine {
                if !pair.isEmpty { rows.append(pair); pair = [] }
                rows.append([card])
            } else {
                pair.append(card)
                if pair.count == 2 { rows.append(pair); pair = [] }
            }
        }
        if !pair.isEmpty { rows.append(pair) }
        return rows
    }
}

enum OnboardingStep: Int, CaseIterable {
    case introduction, createRoutine, ready
    var next: OnboardingStep { Self(rawValue: rawValue + 1) ?? .ready }
}
