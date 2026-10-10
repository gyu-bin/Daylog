import Foundation
import SwiftData

/// 사용자가 만든 루틴의 정체성. 삭제하지 않고 보관만 한다.
///
/// CloudKit 동기화 조건: 고유 제약을 쓸 수 없고, 모든 속성은 기본값이 있거나 optional이어야 한다.
/// `id`의 유일성은 저장소가 아니라 코드(`RoutineService`)가 보장한다.
@Model
final class RoutineItem {
    var id: UUID = UUID()
    var title: String = ""
    var note: String = ""
    var timeLabel: String = ""
    var weekdayMask: Int = 127
    var order: Int = 0
    var isArchived: Bool = false
    var createdAt: Date = Date.distantPast
    /// 마지막으로 수정한 시각. 두 기기에서 같은 루틴이 다르게 들어오면 나중 것을 따른다.
    var updatedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        note: String = "",
        timeLabel: String = "",
        weekdays: [Int] = Weekdays.all,
        order: Int,
        isArchived: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.note = note
        self.timeLabel = timeLabel
        self.weekdayMask = Weekdays.mask(weekdays)
        self.order = order
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    /// 1 = 월요일 … 7 = 일요일.
    var weekdays: [Int] {
        get { Weekdays.days(mask: weekdayMask) }
        set { weekdayMask = Weekdays.mask(newValue) }
    }
}
