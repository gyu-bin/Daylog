import Foundation

/// 루틴 추가·수정·보관·순서 변경.
extension AppStore {
    /// 이름이 비어 있으면 아무것도 하지 않고 false를 돌려준다.
    @discardableResult
    func addRoutine(title: String) -> Bool {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return mutateRoutines { try $0.add(title: title, today: today) }
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

    /// 끌어다 놓기: `id` 루틴이 `targetID` 루틴의 자리를 차지한다.
    func moveActiveRoutine(id: UUID, to targetID: UUID) {
        var ordered = activeRoutines
        guard id != targetID,
              let from = ordered.firstIndex(where: { $0.id == id }),
              let to = ordered.firstIndex(where: { $0.id == targetID })
        else { return }
        ordered.insert(ordered.remove(at: from), at: to)
        mutateRoutines { try $0.reorder(ordered, today: today) }
    }

    /// 드래그 대신 쓰는 위/아래 이동.
    func moveActiveRoutine(_ routine: RoutineItem, by offset: Int) {
        var ordered = activeRoutines
        guard let index = ordered.firstIndex(where: { $0.id == routine.id }) else { return }
        let target = index + offset
        guard ordered.indices.contains(target) else { return }
        ordered.swapAt(index, target)
        mutateRoutines { try $0.reorder(ordered, today: today) }
    }
}
