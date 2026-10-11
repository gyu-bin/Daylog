import SwiftUI

/// Both layouts render the same ordered choices, with platform-appropriate card contents.
struct DashboardCards: View {
    @Environment(AppStore.self) private var store
    @Environment(DevicePreferences.self) private var preferences
    let compact: Bool
    let wide: Bool

    private var cards: [DashboardCard] {
        preferences.visibleCards.filter { card in
            card != .nextRoutine || (store.isViewingToday && !store.isVacation(on: store.today)
                && NextCheck.pick(from: store.checkSections, nowMinutes: 0) != nil)
        }
    }

    var body: some View {
        let rows = DashboardCard.rows(cards, wide: wide)
        VStack(alignment: .leading, spacing: Theme.spacing) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                AdaptiveRow(isWide: wide && row.count > 1) {
                    ForEach(row) { card in
                        content(card).frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func content(_ card: DashboardCard) -> some View {
        switch card {
        case .summary:
            if compact { TodayProgressCard() } else { StatCardsGrid(columns: wide ? 4 : 2) }
        case .nextRoutine: NextRoutineCard()
        case .routines:
            VStack(spacing: Theme.spacing) {
                VacationDayCard(day: store.selectedDay)
                RoutineCard()
            }
        case .meals:
            if compact { MealSummaryCard() } else { MealCard() }
        case .recentDays: RecentDaysCard(title: "최근 7일 기록", outcomes: store.stats.week.reversed())
        case .calendar: MonthCalendarCard()
        case .trend: TrendChartCard()
        case .routineRates: RoutineRatesCard()
        }
    }
}
