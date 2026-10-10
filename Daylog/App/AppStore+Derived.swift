import Foundation

extension AppStore {
    // MARK: - 파생 상태

    var isViewingToday: Bool { selectedDay == today }
    var canGoToNextDay: Bool { selectedDay < today }
    var canShowNextMonth: Bool { calendarMonth < today.firstOfMonth }
    var activeRoutines: [RoutineItem] { routines.filter { !$0.isArchived } }
    var archivedRoutines: [RoutineItem] { routines.filter(\.isArchived) }
    var hasRoutines: Bool { !routines.isEmpty }
    var threshold: Int { stats.threshold }

    /// 보고 있는 날짜의 체크 목록. 표시 순서대로.
    var checks: [DayCheck] {
        record?.checkList ?? []
    }

    /// 보고 있는 날짜의 달성 결과. 오늘이면 통계와 같은 값이다.
    var selectedOutcome: DayOutcome {
        let checks = checks
        let done = checks.filter(\.isDone).count
        return DayOutcome(day: selectedDay, status: checks.isEmpty ? .rest : .recorded, done: done, total: checks.count)
    }

    /// 추천 칩은 첫 루틴을 만든 당일까지만, 아직 만들지 않은 것만 보여 준다.
    var suggestions: [String] {
        guard isViewingToday, stats.firstDay == nil || stats.firstDay == today else { return [] }
        return RoutineSuggestions.available(existingTitles: routines.map(\.title))
    }
}
