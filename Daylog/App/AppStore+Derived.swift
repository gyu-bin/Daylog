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

    /// 보고 있는 날짜의 체크를 그날의 그룹별로 묶은 것. 그룹 순서 → 항목 순서.
    var checkSections: [CheckSection] {
        var sections: [CheckSection] = []
        for check in checks {
            let value = CheckValue(
                id: check.routineID, title: check.title, timeLabel: check.timeLabel, note: check.note, isDone: check.isDone
            )
            if let index = sections.firstIndex(where: { $0.group.id == check.group.id }) {
                sections[index].checks.append(value)
            } else {
                sections.append(CheckSection(group: check.group, checks: [value]))
            }
        }
        return sections
    }
}

/// 뷰가 모델 객체를 붙잡지 않도록 값으로 넘기는 체크 한 줄.
struct CheckValue: Identifiable, Equatable {
    let id: UUID
    let title: String
    let timeLabel: String
    let note: String
    let isDone: Bool
}

/// 하루의 체크 목록에서 한 그룹에 해당하는 부분. 그룹 모습은 그날의 스냅샷이다.
struct CheckSection: Identifiable, Equatable {
    let group: GroupSnapshot
    var checks: [CheckValue]

    var id: UUID { group.id }
    var done: Int { checks.filter(\.isDone).count }
    var total: Int { checks.count }
    var ratio: Double? { Achievement.ratio(done: done, total: total) }
    var percent: Int? { Achievement.percent(done: done, total: total) }
}
