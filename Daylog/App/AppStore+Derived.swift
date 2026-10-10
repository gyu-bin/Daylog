import Foundation

extension AppStore {
    // MARK: - 파생 상태

    var isViewingToday: Bool { selectedDay == today }
    var canGoToNextDay: Bool { selectedDay < today }
    var canShowNextMonth: Bool { calendarMonth < today.firstOfMonth }
    var activeRoutines: [RoutineItem] { routines.filter { !$0.isArchived } }
    var archivedRoutines: [RoutineItem] { routines.filter(\.isArchived) }
    var hasRoutines: Bool { !routines.isEmpty }
    var activeGroups: [RoutineGroup] { groups.filter { !$0.isArchived } }
    var archivedGroups: [RoutineGroup] { groups.filter(\.isArchived) }

    func activeRoutines(inGroup groupID: UUID) -> [RoutineItem] {
        activeRoutines.filter { $0.effectiveGroupID == groupID }
    }

    func archivedRoutines(inGroup groupID: UUID) -> [RoutineItem] {
        archivedRoutines.filter { $0.effectiveGroupID == groupID }
    }

    /// ⌘N과 추천 칩이 항목을 넣을 그룹: 마지막으로 쓴 그룹, 없으면 첫 그룹.
    var quickAddGroup: RoutineGroup? {
        activeGroups.first { $0.id == lastUsedGroupID } ?? activeGroups.first
    }
    var threshold: Int { stats.threshold }

    func text(_ keyPath: KeyPath<DayRecord, String>) -> String {
        record?[keyPath: keyPath] ?? ""
    }

    /// 추천 칩은 첫 루틴을 만든 당일까지만, 아직 만들지 않은 것만 보여 준다.
    var suggestions: [String] {
        guard isViewingToday, stats.firstDay == nil || stats.firstDay == today else { return [] }
        return RoutineSuggestions.available(existingTitles: routines.map(\.title))
    }
}
