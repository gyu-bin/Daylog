import Foundation
import SwiftData

/// 특정 날짜에 수행할 루틴의 스냅샷. 생성 시점의 루틴 정보를 복사해 두며,
/// 이후 루틴이 바뀌어도 과거 날짜의 스냅샷은 그대로 둔다.
@Model
final class DayCheck {
    var routineID: UUID = UUID()
    var title: String = ""
    var timeLabel: String = ""
    var note: String = ""
    var order: Int = 0
    var isDone: Bool = false
    var record: DayRecord?
    /// 그날의 대상에서 빠진 항목. 지우는 대신 숨긴다(다른 기기가 그 사이 완료했을 수 있다).
    /// 완료한 항목은 숨김이어도 기록으로 남아 보인다.
    var isHidden: Bool = false
    /// 기기 간에 같은 값으로 동기화되는 식별자. 같은 루틴의 체크가 둘이면 어느 기기에서든 같은 쪽을 대표로 고른다.
    var syncID: UUID?
    /// 그날 속해 있던 그룹의 모습. `groupID`가 nil이면 그룹 도입 전의 기록이다.
    var groupID: UUID?
    var groupTitle: String = ""
    var groupColorKey: String = ""
    var groupOrder: Int = 0

    init(routineID: UUID, state: RoutineState, isDone: Bool = false) {
        self.routineID = routineID
        self.isDone = isDone
        self.syncID = UUID()
        apply(state)
    }

    convenience init(snapshot: RevisionSnapshot) {
        self.init(routineID: snapshot.routineID, state: snapshot.state)
    }

    /// 그룹 정보 없이 항목만으로 만든다.
    convenience init(routine: RoutineItem) {
        self.init(routineID: routine.id, state: RoutineState(routine: routine, group: nil))
    }

    var group: GroupSnapshot {
        GroupSnapshot(storedID: groupID, title: groupTitle, colorKey: groupColorKey, order: groupOrder)
    }

    /// 이름·시간·순서·그룹을 `state`에 맞춘다. 완료 여부와 숨김은 건드리지 않는다. 바뀐 것이 있으면 true.
    @discardableResult
    func apply(_ state: RoutineState) -> Bool {
        var changed = false
        func set<T: Equatable>(_ keyPath: ReferenceWritableKeyPath<DayCheck, T>, _ value: T) {
            guard self[keyPath: keyPath] != value else { return }
            self[keyPath: keyPath] = value
            changed = true
        }
        set(\.title, state.title)
        set(\.timeLabel, state.timeLabel)
        set(\.note, state.note)
        set(\.order, state.order)
        set(\.groupID, Optional(state.group.id))
        set(\.groupTitle, state.group.title)
        set(\.groupColorKey, state.group.colorKey)
        set(\.groupOrder, state.group.order)
        return changed
    }

    /// 표시 순서: 그룹 순서 → 그룹 안의 항목 순서.
    static func displayOrder(_ lhs: DayCheck, _ rhs: DayCheck) -> Bool {
        let left = lhs.group, right = rhs.group
        if left.id != right.id {
            return (left.order, left.title, left.id.uuidString) < (right.order, right.title, right.id.uuidString)
        }
        return (lhs.order, lhs.title, lhs.routineID.uuidString) < (rhs.order, rhs.title, rhs.routineID.uuidString)
    }
}
