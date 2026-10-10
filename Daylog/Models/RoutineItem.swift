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
    /// 속한 그룹. nil이면 그룹 도입 전(v1.2까지)에 만든 항목으로, "기본 루틴" 그룹에 속한다.
    var groupID: UUID?
    /// 사용자가 삭제한 시각. 레코드는 지우지 않는다(과거 기록·통계가 이 항목을 가리키고, 지운 것은 동기화에서 되돌릴 수 없다).
    /// 삭제한 항목은 목록과 보관함 어디에도 나오지 않고, 되살리는 기능도 없다.
    var deletedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        note: String = "",
        timeLabel: String = "",
        weekdays: [Int] = Weekdays.all,
        order: Int,
        isArchived: Bool = false,
        createdAt: Date = .now,
        groupID: UUID? = nil
    ) {
        self.id = id
        self.groupID = groupID
        self.title = title
        self.note = note
        self.timeLabel = timeLabel
        self.weekdayMask = Weekdays.mask(weekdays)
        self.order = order
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    var effectiveGroupID: UUID { groupID ?? RoutineGroup.defaultID }
    /// `isDeleted`는 SwiftData가 쓰는 이름이라 피한다.
    var isRemoved: Bool { deletedAt != nil }

    /// 1 = 월요일 … 7 = 일요일.
    var weekdays: [Int] {
        get { Weekdays.days(mask: weekdayMask) }
        set { weekdayMask = Weekdays.mask(newValue) }
    }
}
