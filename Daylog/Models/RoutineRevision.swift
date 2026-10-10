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

    init(routine: RoutineItem, effectiveFrom day: Day, now: Date = .now) {
        self.routineID = routine.id
        self.effectiveFromKey = day.key
        self.title = routine.title
        self.timeLabel = routine.timeLabel
        self.note = routine.note
        self.weekdayMask = routine.weekdayMask
        self.isArchived = routine.isArchived
        self.order = routine.order
        self.updatedAt = now
        self.syncID = UUID()
    }

    func apply(_ routine: RoutineItem, now: Date) {
        title = routine.title
        timeLabel = routine.timeLabel
        note = routine.note
        weekdayMask = routine.weekdayMask
        isArchived = routine.isArchived
        order = routine.order
        updatedAt = now
    }

    func matches(_ routine: RoutineItem) -> Bool {
        title == routine.title
            && timeLabel == routine.timeLabel
            && note == routine.note
            && weekdayMask == routine.weekdayMask
            && isArchived == routine.isArchived
            && order == routine.order
    }
}
