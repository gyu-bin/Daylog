import Foundation
import SwiftData

/// 루틴 그룹의 추가·수정·보관·삭제·순서 변경.
extension RoutineService {
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
}
