import Foundation
import SwiftData

extension AppStore {
    // MARK: - 파생 상태

    var isViewingToday: Bool { selectedDay == today }
    var canGoToNextDay: Bool { selectedDay < today }
    var canShowNextMonth: Bool { calendarMonth < today.firstOfMonth }
    var activeRoutines: [RoutineItem] { routines.filter { !$0.isArchived } }
    var archivedRoutines: [RoutineItem] { routines.filter(\.isArchived) }
    var hasRoutines: Bool { !routines.isEmpty }

    /// 사용자가 남긴 것이 하나라도 있는가: 그룹·루틴, 또는 체크·식사·휴가·메모 같은 편집 기록.
    /// 앱이 스스로 만드는 것(오늘의 빈 기록, 기기 정보, 설정)은 세지 않는다. 새 기기의 첫 동기화 안내가 쓴다.
    var hasUserRecords: Bool {
        if !groups.isEmpty || !routines.isEmpty { return true }
        // 기기 정보도 편집 기록과 같은 표에 있다(`DeviceEdit`). 이 기기가 켜지자마자 자기 줄을 쓰므로 빼고 센다.
        let deviceKey = DeviceEdit.dateKey
        var descriptor = FetchDescriptor<FieldEdit>(predicate: #Predicate { $0.dateKey != deviceKey })
        descriptor.fetchLimit = 1
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }
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
