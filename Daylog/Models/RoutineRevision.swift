import Foundation
import SwiftData

/// 루틴 설정의 변경 이력. `effectiveFromKey` 날짜부터 다음 이력의 시작일 전날까지 유효하다.
///
/// 한 기기에서는 (routineID, effectiveFromKey)당 한 건만 만든다. 같은 날 여러 번 수정하면 그날의 이력을
/// 덮어쓴다. 두 기기가 같은 날 각자 수정하면 같은 날짜의 이력이 둘 생길 수 있는데, 지우지 않고
/// `updatedAt`이 나중인 쪽을 그날의 유효 상태로 본다.
@Model
final class RoutineRevision {
    var routineID: UUID = UUID()
    var effectiveFromKey: String = ""
    var title: String = ""
    var timeLabel: String = ""
    var note: String = ""
    var weekdayMask: Int = 127
    var isArchived: Bool = false
    var order: Int = 0
    var updatedAt: Date = Date.distantPast
    /// 기기 간에 같은 값으로 동기화되는 식별자. 순서를 정할 때 동률을 깨는 데 쓴다.
    var syncID: UUID?
    /// 당시 속해 있던 그룹. `groupID`가 nil이면 그룹 도입 전의 이력이다.
    var groupID: UUID?
    var groupTitle: String = ""
    var groupColorKey: String = ""
    var groupOrder: Int = 0

    init(routineID: UUID, state: RoutineState, effectiveFrom day: Day, now: Date = .now) {
        self.routineID = routineID
        self.effectiveFromKey = day.key
        self.syncID = UUID()
        apply(state, now: now)
    }

    /// 그룹 정보 없이 항목만으로 만든다(항목의 그룹을 모를 때는 "기본 루틴"으로 남는다).
    convenience init(routine: RoutineItem, effectiveFrom day: Day, now: Date = .now) {
        self.init(routineID: routine.id, state: RoutineState(routine: routine, group: nil), effectiveFrom: day, now: now)
    }

    var group: GroupSnapshot {
        GroupSnapshot(storedID: groupID, title: groupTitle, colorKey: groupColorKey, order: groupOrder)
    }

    var state: RoutineState {
        RoutineState(
            title: title, timeLabel: timeLabel, note: note, weekdayMask: weekdayMask,
            isArchived: isArchived, order: order, group: group
        )
    }

    func apply(_ state: RoutineState, now: Date) {
        title = state.title
        timeLabel = state.timeLabel
        note = state.note
        weekdayMask = state.weekdayMask
        isArchived = state.isArchived
        order = state.order
        groupID = state.group.id
        groupTitle = state.group.title
        groupColorKey = state.group.colorKey
        groupOrder = state.group.order
        updatedAt = now
    }
}

extension RoutineState {
    /// `group`이 nil이면 항목의 그룹 ID만으로 채운다(그룹 레코드가 아직 없을 때).
    init(routine: RoutineItem, group: RoutineGroup?) {
        let snapshot: GroupSnapshot
        if let group {
            snapshot = GroupSnapshot(group)
        } else if routine.effectiveGroupID == RoutineGroup.defaultID {
            snapshot = .legacy
        } else {
            snapshot = GroupSnapshot(id: routine.effectiveGroupID, title: "", colorKey: RoutineGroup.defaultColorKey, order: 0)
        }
        self.init(
            title: routine.title, timeLabel: routine.timeLabel, note: routine.note,
            weekdayMask: routine.weekdayMask,
            isArchived: routine.isArchived || (group?.isArchived ?? false),
            order: routine.order, group: snapshot
        )
    }
}
