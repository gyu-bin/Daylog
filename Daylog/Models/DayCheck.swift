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

    init(routineID: UUID, title: String, timeLabel: String, note: String, order: Int, isDone: Bool = false) {
        self.routineID = routineID
        self.title = title
        self.timeLabel = timeLabel
        self.note = note
        self.order = order
        self.isDone = isDone
        self.syncID = UUID()
    }

    convenience init(routine: RoutineItem) {
        self.init(
            routineID: routine.id,
            title: routine.title,
            timeLabel: routine.timeLabel,
            note: routine.note,
            order: routine.order
        )
    }

    convenience init(snapshot: RevisionSnapshot) {
        self.init(
            routineID: snapshot.routineID,
            title: snapshot.title,
            timeLabel: snapshot.timeLabel,
            note: snapshot.note,
            order: snapshot.order
        )
    }
}
