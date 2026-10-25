import SwiftUI

/// 캘린더: 달력에서 날짜를 고르면 그날의 루틴과 식사를 옆(좁으면 아래)에서 보고 고친다.
struct CalendarView: View {
    @Environment(AppStore.self) private var store
    @Environment(DevicePreferences.self) private var preferences

    var body: some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width >= 820
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacing) {
                    PageTitle(title: "캘린더", subtitle: preferences.mealsEnabled ? "날짜를 누르면 그날의 루틴과 식사를 보고 고칠 수 있어요." : "날짜를 누르면 그날의 루틴을 보고 고칠 수 있어요.", pio: PioLines.calendar)
                    if isWide {
                        HStack(alignment: .top, spacing: Theme.spacing) {
                            MonthCalendarCard()
                                .frame(width: min(420, proxy.size.width * 0.42))
                            dayDetail
                        }
                    } else {
                        MonthCalendarCard()
                        dayDetail
                    }
                }
                .pagePadding()
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var dayDetail: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            HStack(spacing: 8) {
                Text(store.selectedDay.longTitle)
                    .font(.headline)
                    .monospacedDigit()
                StatusBadge(text: statusText, tint: statusTint)
                Spacer(minLength: 8)
                if !store.isViewingToday {
                    Button("오늘") { store.goToToday() }
                        .controlSize(.small)
                }
            }
            VacationDayCard(day: store.selectedDay)
            RoutineCard()
            if preferences.mealsEnabled { MealCard() }
        }
    }

    /// 고른 날짜의 상태를 글자로 알려 준다(색만으로 구분하지 않는다).
    private var statusText: String {
        let outcome = store.selectedOutcome
        if outcome.status == .vacation { return "휴가" }
        guard outcome.total > 0 else { return "휴식일" }
        guard store.record?.isRecorded == true else { return "미기록" }
        return outcome.isAchieved(threshold: store.threshold) ? "달성 \(outcome.percentLabel)" : "미달 \(outcome.percentLabel)"
    }

    private var statusTint: Color {
        let outcome = store.selectedOutcome
        guard outcome.total > 0, store.record?.isRecorded == true else { return .secondary }
        return outcome.isAchieved(threshold: store.threshold) ? Theme.accent : GroupColor.orange.color
    }
}
