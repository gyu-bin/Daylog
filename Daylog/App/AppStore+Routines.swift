import Foundation

/// 루틴 그룹과 항목의 추가·수정·보관·순서 변경.
extension AppStore {
    // MARK: - 그룹

    /// 이름이 비어 있으면 아무것도 하지 않고 nil을 돌려준다.
    @discardableResult
    func addGroup(title: String, colorKey: String? = nil) -> RoutineGroup? {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        var created: RoutineGroup?
        mutateRoutines { created = try $0.addGroup(title: title, colorKey: colorKey) }
        if let created { lastUsedGroupID = created.id }
        return created
    }

    @discardableResult
    func updateGroup(_ group: RoutineGroup, title: String? = nil, colorKey: String? = nil) -> Bool {
        mutateRoutines { try $0.updateGroup(group, title: title, colorKey: colorKey, today: today) }
    }

    func setGroupArchived(_ group: RoutineGroup, _ isArchived: Bool) {
        mutateRoutines { try $0.setGroupArchived(group, isArchived, today: today) }
    }

    /// 드래그 대신 쓰는 위/아래 이동.
    func moveGroup(_ group: RoutineGroup, by offset: Int) {
        var ordered = activeGroups
        guard let index = ordered.firstIndex(where: { $0.id == group.id }) else { return }
        let target = index + offset
        guard ordered.indices.contains(target) else { return }
        ordered.swapAt(index, target)
        mutateRoutines { try $0.reorderGroups(ordered, today: today) }
    }

    /// 끌어다 놓기: `id` 그룹이 `targetID` 그룹의 자리를 차지한다.
    func moveGroup(id: UUID, to targetID: UUID) {
        var ordered = activeGroups
        guard id != targetID,
              let from = ordered.firstIndex(where: { $0.id == id }),
              let to = ordered.firstIndex(where: { $0.id == targetID })
        else { return }
        ordered.insert(ordered.remove(at: from), at: to)
        mutateRoutines { try $0.reorderGroups(ordered, today: today) }
    }

    // MARK: - 항목

    /// 이름이 비어 있으면 아무것도 하지 않고 false를 돌려준다. `group`이 nil이면 "기본 루틴" 그룹에 넣는다.
    @discardableResult
    func addRoutine(title: String, in group: RoutineGroup? = nil) -> Bool {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        if let group { lastUsedGroupID = group.id }
        return mutateRoutines { try $0.add(title: title, group: group, today: today) }
    }

    @discardableResult
    func updateRoutine(
        _ routine: RoutineItem,
        title: String? = nil,
        note: String? = nil,
        timeLabel: String? = nil,
        weekdays: [Int]? = nil
    ) -> Bool {
        mutateRoutines {
            try $0.update(routine, title: title, note: note, timeLabel: timeLabel, weekdays: weekdays, today: today)
        }
    }

    func setArchived(_ routine: RoutineItem, _ isArchived: Bool) {
        mutateRoutines { try $0.setArchived(routine, isArchived, today: today) }
    }

    /// 항목을 다른 그룹의 맨 뒤로 옮긴다.
    func moveRoutine(_ routine: RoutineItem, to group: RoutineGroup) {
        mutateRoutines { try $0.move(routine, to: group, today: today) }
    }

    /// 끌어다 놓기: `id` 항목이 `targetID` 항목의 자리를 차지한다. 다른 그룹의 항목 위에 놓으면 그 그룹으로 옮겨진다.
    func moveActiveRoutine(id: UUID, to targetID: UUID) {
        guard id != targetID,
              let moving = activeRoutines.first(where: { $0.id == id }),
              let target = activeRoutines.first(where: { $0.id == targetID })
        else { return }
        var ordered = activeRoutines(inGroup: target.effectiveGroupID).filter { $0.id != id }
        guard let index = ordered.firstIndex(where: { $0.id == targetID }) else { return }
        let wasBelowInSameGroup = moving.effectiveGroupID == target.effectiveGroupID
            && (activeRoutines(inGroup: target.effectiveGroupID).firstIndex { $0.id == id } ?? 0)
                < (activeRoutines(inGroup: target.effectiveGroupID).firstIndex { $0.id == targetID } ?? 0)
        ordered.insert(moving, at: wasBelowInSameGroup ? index + 1 : index)
        let destination = groups.first { $0.id == target.effectiveGroupID }
        mutateRoutines { service in
            if moving.effectiveGroupID != target.effectiveGroupID, let destination {
                try service.move(moving, to: destination, today: today)
            }
            try service.reorder(ordered, today: today)
        }
    }

    /// 드래그 대신 쓰는 위/아래 이동. 같은 그룹 안에서 움직인다.
    func moveActiveRoutine(_ routine: RoutineItem, by offset: Int) {
        var ordered = activeRoutines(inGroup: routine.effectiveGroupID)
        guard let index = ordered.firstIndex(where: { $0.id == routine.id }) else { return }
        let target = index + offset
        guard ordered.indices.contains(target) else { return }
        ordered.swapAt(index, target)
        mutateRoutines { try $0.reorder(ordered, today: today) }
    }
}
