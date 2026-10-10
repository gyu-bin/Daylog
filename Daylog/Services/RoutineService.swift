import Foundation
import SwiftData

/// 루틴 그룹과 항목의 변경. 모든 변경은 정의 + 변경 이력 + 오늘 기록 동기화를 한 번의 저장으로 묶는다.
///
/// 적용 범위: 과거 기록은 건드리지 않고, 오늘 기록에는 즉시 반영하며, 미래는 새 설정을 따른다.
/// 그룹을 바꾸면(이름·색·순서·보관) 그 그룹에 속한 항목들의 "유효 상태"가 바뀐 것이므로
/// 항목마다 이력을 남긴다. 그래야 기록이 없던 과거 날짜도 당시의 그룹 모습으로 복원된다.
@MainActor
struct RoutineService {
    static let maxTitleLength = 60
    static let maxGroupTitleLength = 40
    static let maxTimeLabelLength = 12

    let context: ModelContext

    // MARK: - 조회

    /// 보관된 그룹을 포함한 전체 그룹. 표시 순서대로. 삭제한 그룹은 `includingRemoved`일 때만 나온다.
    ///
    /// 같은 `id`가 둘 이상 들어와 있으면(두 기기가 각자 "기본 루틴"을 만든 경우 등) 하나만 돌려준다.
    /// 그중 하나라도 삭제됐으면 삭제된 쪽을 고른다. 그래야 한 기기에서 지운 그룹이 다른 기기의 사본 때문에 되살아나지 않는다.
    func groups(includingRemoved: Bool = false) throws -> [RoutineGroup] {
        let all = try context.fetch(FetchDescriptor<RoutineGroup>())
        return Dictionary(grouping: all, by: \.id)
            .values
            .compactMap { duplicates in
                duplicates.max {
                    ($0.isRemoved ? 1 : 0, $0.updatedAt ?? $0.createdAt, $0.createdAt, $0.title)
                        < ($1.isRemoved ? 1 : 0, $1.updatedAt ?? $1.createdAt, $1.createdAt, $1.title)
                }
            }
            .filter { includingRemoved || !$0.isRemoved }
            .sorted { ($0.order, $0.createdAt, $0.id.uuidString) < ($1.order, $1.createdAt, $1.id.uuidString) }
    }

    /// 보관된 루틴을 포함한 전체 루틴. 그룹 순서 → 그룹 안의 순서.
    /// 삭제한 항목과 삭제한 그룹에 속한 항목은 `includingRemoved`일 때만 나온다.
    /// 같은 `id`가 둘 이상이면 하나만 돌려주고, 하나라도 삭제됐으면 삭제된 쪽을 고른다.
    func routines(includingRemoved: Bool = false) throws -> [RoutineItem] {
        let allGroups = try groups(includingRemoved: true)
        let groupOrder = Dictionary(uniqueKeysWithValues: allGroups.enumerated().map { ($1.id, $0) })
        let removedGroups = Set(allGroups.filter(\.isRemoved).map(\.id))
        let all = try context.fetch(FetchDescriptor<RoutineItem>())
        return Dictionary(grouping: all, by: \.id)
            .values
            .compactMap { duplicates in
                duplicates.max {
                    ($0.isRemoved ? 1 : 0, $0.updatedAt ?? $0.createdAt, $0.createdAt)
                        < ($1.isRemoved ? 1 : 0, $1.updatedAt ?? $1.createdAt, $1.createdAt)
                }
            }
            .filter { includingRemoved || !($0.isRemoved || removedGroups.contains($0.effectiveGroupID)) }
            .sorted { lhs, rhs in
                let left = groupOrder[lhs.effectiveGroupID] ?? Int.max
                let right = groupOrder[rhs.effectiveGroupID] ?? Int.max
                if left != right { return left < right }
                return (lhs.order, lhs.createdAt, lhs.id.uuidString) < (rhs.order, rhs.createdAt, rhs.id.uuidString)
            }
    }

    private func groupsByID() throws -> [UUID: RoutineGroup] {
        Dictionary(uniqueKeysWithValues: try groups(includingRemoved: true).map { ($0.id, $0) })
    }

    private func state(of routine: RoutineItem, in groups: [UUID: RoutineGroup]) -> RoutineState {
        RoutineState(routine: routine, group: groups[routine.effectiveGroupID])
    }

    // MARK: - 그룹

    @discardableResult
    func addGroup(title: String, colorKey: String? = nil, now: Date = .now) throws -> RoutineGroup {
        let title = try Self.validatedGroupTitle(title)
        return try transaction {
            let existing = try groups()
            let group = RoutineGroup(
                title: title,
                colorKey: colorKey ?? GroupColor.next(after: existing.map(\.colorKey)).rawValue,
                order: (existing.map(\.order).max() ?? -1) + 1,
                createdAt: now
            )
            context.insert(group)
            return group
        }
    }

    /// nil인 항목은 바꾸지 않는다.
    func updateGroup(
        _ group: RoutineGroup, title: String? = nil, colorKey: String? = nil, today: Day, now: Date = .now
    ) throws {
        let title = try title.map(Self.validatedGroupTitle)
        try transaction {
            if let title { group.title = title }
            if let colorKey { group.colorKey = colorKey }
            group.updatedAt = now
            try applyGroupChange(group, today: today, now: now)
        }
    }

    /// 그룹을 보관하면 속한 항목은 예정에서 빠진다. 항목 자체와 과거 기록은 그대로 남고, 복원하면 돌아온다.
    func setGroupArchived(_ group: RoutineGroup, _ isArchived: Bool, today: Day, now: Date = .now) throws {
        try transaction {
            group.isArchived = isArchived
            group.updatedAt = now
            try applyGroupChange(group, today: today, now: now)
        }
    }

    /// 그룹과 그 안의 항목(보관된 것 포함)을 삭제한다. 레코드는 지우지 않고 삭제 시각만 남긴다.
    /// 오늘부터 예정에서 빠지고, 지난 기록·변경 이력·통계는 그대로다. 삭제한 항목 수를 돌려준다.
    @discardableResult
    func deleteGroup(_ group: RoutineGroup, today: Day, now: Date = .now) throws -> Int {
        try transaction {
            let members = try routines().filter { $0.effectiveGroupID == group.id }
            group.deletedAt = now
            group.updatedAt = now
            for routine in members {
                routine.deletedAt = now
                routine.updatedAt = now
                try applyChange(to: routine, today: today, now: now)
            }
            return members.count
        }
    }

    /// `ordered` 순서대로 그룹 번호를 다시 매긴다. 목록에 없는 그룹(보관된 그룹 등)은 기존 순서를 유지한 채 뒤에 둔다.
    func reorderGroups(_ ordered: [RoutineGroup], today: Day, now: Date = .now) throws {
        try transaction {
            let listed = Set(ordered.map(\.id))
            let rest = try groups().filter { !listed.contains($0.id) }
            for (index, group) in (ordered + rest).enumerated() where group.order != index {
                group.order = index
                group.updatedAt = now
                try applyGroupChange(group, today: today, now: now)
            }
        }
    }

    /// v1.2까지 그룹 없이 만든 항목이 있는데 "기본 루틴" 그룹이 아직 없으면 만든다. 만들었으면 true.
    /// 저장은 호출한 쪽에서 한다.
    @discardableResult
    func ensureDefaultGroup(now: Date = .now) throws -> Bool {
        let needsDefault = try context.fetch(FetchDescriptor<RoutineItem>())
            .contains { $0.effectiveGroupID == RoutineGroup.defaultID }
        guard needsDefault else { return false }
        let existing = try context.fetch(FetchDescriptor<RoutineGroup>())
        guard !existing.contains(where: { $0.id == RoutineGroup.defaultID }) else { return false }
        context.insert(RoutineGroup(
            id: RoutineGroup.defaultID,
            title: RoutineGroup.defaultTitle,
            colorKey: RoutineGroup.defaultColorKey,
            order: (existing.map(\.order).min() ?? 0) - (existing.isEmpty ? 0 : 1),
            createdAt: now
        ))
        return true
    }

    // MARK: - 항목

    /// `group`이 nil이면 "기본 루틴" 그룹에 넣는다(없으면 만든다).
    @discardableResult
    func add(
        title: String,
        note: String = "",
        timeLabel: String = "",
        weekdays: [Int] = Weekdays.all,
        group: RoutineGroup? = nil,
        today: Day,
        now: Date = .now
    ) throws -> RoutineItem {
        let title = try Self.validatedTitle(title)
        let weekdays = try Self.validatedWeekdays(weekdays)
        return try transaction {
            let groupID = group?.id ?? RoutineGroup.defaultID
            let siblings = try routines().filter { $0.effectiveGroupID == groupID }
            let routine = RoutineItem(
                title: title,
                note: Self.trimmed(note),
                timeLabel: Self.validatedTimeLabel(timeLabel),
                weekdays: weekdays,
                order: (siblings.map(\.order).max() ?? -1) + 1,
                createdAt: now,
                groupID: groupID
            )
            context.insert(routine)
            try ensureDefaultGroup(now: now)

            let settings = try SettingsService(context: context).settings()
            if settings.firstRoutineDate == nil {
                settings.firstRoutineDate = today.anchorDate
            }
            try applyChange(to: routine, today: today, now: now)
            return routine
        }
    }

    /// nil인 항목은 바꾸지 않는다.
    func update(
        _ routine: RoutineItem,
        title: String? = nil,
        note: String? = nil,
        timeLabel: String? = nil,
        weekdays: [Int]? = nil,
        group: RoutineGroup? = nil,
        today: Day,
        now: Date = .now
    ) throws {
        let title = try title.map(Self.validatedTitle)
        let weekdays = try weekdays.map(Self.validatedWeekdays)
        try transaction {
            if let title { routine.title = title }
            if let note { routine.note = Self.trimmed(note) }
            if let timeLabel { routine.timeLabel = Self.validatedTimeLabel(timeLabel) }
            if let weekdays { routine.weekdays = weekdays }
            // 편집 시트에서 그룹까지 바꾼 경우: 한 번의 저장으로 함께 옮긴다(새 그룹의 맨 뒤로).
            if let group, group.id != routine.effectiveGroupID {
                let siblings = try routines().filter { $0.effectiveGroupID == group.id }
                routine.groupID = group.id
                routine.order = (siblings.map(\.order).max() ?? -1) + 1
            }
            routine.updatedAt = now
            try applyChange(to: routine, today: today, now: now)
        }
    }

    func setArchived(_ routine: RoutineItem, _ isArchived: Bool, today: Day, now: Date = .now) throws {
        try transaction {
            routine.isArchived = isArchived
            routine.updatedAt = now
            try applyChange(to: routine, today: today, now: now)
        }
    }

    /// 항목을 삭제한다. 레코드는 지우지 않고 삭제 시각만 남긴다.
    /// 오늘부터 예정에서 빠지고(오늘 이미 완료했으면 오늘 기록에는 남는다), 지난 기록·통계는 그대로다.
    func delete(_ routine: RoutineItem, today: Day, now: Date = .now) throws {
        try transaction {
            routine.deletedAt = now
            routine.updatedAt = now
            try applyChange(to: routine, today: today, now: now)
        }
    }

    /// 항목을 다른 그룹의 맨 뒤로 옮긴다. 항목의 ID와 과거 기록은 그대로다.
    func move(_ routine: RoutineItem, to group: RoutineGroup, today: Day, now: Date = .now) throws {
        guard routine.effectiveGroupID != group.id else { return }
        try transaction {
            let siblings = try routines().filter { $0.effectiveGroupID == group.id }
            routine.groupID = group.id
            routine.order = (siblings.map(\.order).max() ?? -1) + 1
            routine.updatedAt = now
            try applyChange(to: routine, today: today, now: now)
        }
    }

    /// `ordered` 순서대로 번호를 다시 매긴다(한 그룹의 항목들을 넘긴다). 목록에 없는 항목은 건드리지 않는다.
    func reorder(_ ordered: [RoutineItem], today: Day, now: Date = .now) throws {
        try transaction {
            for (index, routine) in ordered.enumerated() where routine.order != index {
                routine.order = index
                routine.updatedAt = now
                try applyChange(to: routine, today: today, now: now)
            }
        }
    }

    /// 오늘 기록을 현재 그룹·항목 정의에 맞춘다. 다른 기기의 변경이 들어온 뒤에 호출한다.
    func syncTodayRecord(today: Day) throws {
        let groups = try groupsByID()
        // 다른 기기에서 삭제한 항목도 오늘 목록에서 빠지도록, 삭제된 것까지 포함해 맞춘다.
        for routine in try routines(includingRemoved: true) {
            try syncTodayRecord(routineID: routine.id, state: state(of: routine, in: groups), weekdays: routine.weekdays, today: today)
        }
    }

    // MARK: - 변경 적용

    /// 이미 대기 중인 변경(입력 중이던 텍스트 등)을 먼저 저장한 뒤 `body`를 한 번에 저장한다.
    /// 실패하면 `body`의 변경만 되돌린다.
    private func transaction<T>(_ body: () throws -> T) throws -> T {
        try context.saveIfNeeded()
        do {
            let result = try body()
            try context.save()
            return result
        } catch {
            context.rollback()
            throw error
        }
    }

    private func applyChange(to routine: RoutineItem, today: Day, now: Date) throws {
        let state = state(of: routine, in: try groupsByID())
        try recordRevision(routineID: routine.id, state: state, today: today, now: now)
        try syncTodayRecord(routineID: routine.id, state: state, weekdays: routine.weekdays, today: today)
    }

    /// 그룹이 바뀌면 그 그룹에 속한 모든 항목의 유효 상태가 바뀐 것이다.
    private func applyGroupChange(_ group: RoutineGroup, today: Day, now: Date) throws {
        for routine in try routines() where routine.effectiveGroupID == group.id {
            try applyChange(to: routine, today: today, now: now)
        }
    }

    private func recordRevision(routineID: UUID, state: RoutineState, today: Day, now: Date) throws {
        let todayKey = today.key
        let revisions = try context.fetch(FetchDescriptor<RoutineRevision>(predicate: #Predicate { $0.routineID == routineID }))
        // 가장 최근 이력 = 적용 시작일이 가장 늦고, 같은 날이면 나중에 고친 것.
        let latest = revisions.max {
            ($0.effectiveFromKey, $0.updatedAt) < ($1.effectiveFromKey, $1.updatedAt)
        }

        if let latest {
            // 오늘(또는 시간대가 앞선 다른 기기 기준으로 이미 내일) 날짜의 이력이 있으면 그 이력을 고쳐 쓴다.
            // 새로 만들면 그 날짜가 됐을 때 예전 설정이 되살아나고, 지우면 다른 기기의 이력을 잃는다.
            if latest.effectiveFromKey >= todayKey {
                latest.apply(state, now: now)
                return
            }
            if latest.state == state { return }
        }
        context.insert(RoutineRevision(routineID: routineID, state: state, effectiveFrom: today, now: now))
    }

    /// 오늘 기록이 이미 있으면 루틴의 현재 상태를 반영한다. 없으면 나중에 이력으로부터 만들어진다.
    private func syncTodayRecord(routineID: UUID, state: RoutineState, weekdays: [Int], today: Day) throws {
        guard let record = try DayRecordService(context: context).record(on: today) else { return }
        let isScheduled = !state.isArchived && weekdays.contains(today.weekday)
        let checks = record.physicalChecks.filter { $0.routineID == routineID }

        guard !checks.isEmpty else {
            if isScheduled {
                record.attach(DayCheck(routineID: routineID, state: state))
            }
            return
        }

        // 오늘 대상에서 빠진 항목은 지우지 않고 숨긴다. 이미 완료한 항목은 숨김이어도 기록으로 남아 보인다.
        for check in checks {
            check.apply(state)
            if check.isHidden == isScheduled { check.isHidden = !isScheduled }
        }
    }
}
