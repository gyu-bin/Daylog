import Foundation
import SwiftData

/// 루틴 항목을 묶는 그룹. 사용자가 자유롭게 만들고, 삭제하지 않고 보관만 한다.
///
/// 항목과는 관계가 아니라 `RoutineItem.groupID` 값으로 연결한다. 그룹이 바뀌어도 과거 스냅샷이
/// 따라 바뀌지 않게 하기 위함이고, CloudKit이 관계 변경을 원자적으로 처리해 주지 않기 때문이기도 하다.
@Model
final class RoutineGroup {
    var id: UUID = UUID()
    var title: String = ""
    /// `GroupColor`의 식별자("orange", "blue" …). 모르는 값은 기본색으로 보인다.
    var colorKey: String = "green"
    var order: Int = 0
    var isArchived: Bool = false
    var createdAt: Date = Date.distantPast
    var updatedAt: Date?
    /// 사용자가 삭제한 시각. 레코드는 지우지 않는다. 삭제한 그룹은 어디에도 나오지 않고 되살릴 수 없다.
    var deletedAt: Date?

    var isRemoved: Bool { deletedAt != nil }

    init(
        id: UUID = UUID(),
        title: String,
        colorKey: String,
        order: Int,
        isArchived: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.colorKey = colorKey
        self.order = order
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    /// v1.2까지 그룹 없이 만들어진 항목이 속하는 그룹의 ID.
    ///
    /// 값이 고정되어 있어서, 두 Mac이 각자 이 그룹을 만들어도 같은 그룹으로 취급된다.
    static let defaultID = UUID(uuid: (0xD0, 0xA1, 0x10, 0x60, 0x00, 0x00, 0x40, 0x00, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01))
    static let defaultTitle = "기본 루틴"
    static let defaultColorKey = "green"
}

/// 어느 시점의 그룹 모습. 날짜별 체크와 변경 이력에 복사해 둔다.
struct GroupSnapshot: Equatable, Hashable, Sendable {
    var id: UUID
    var title: String
    var colorKey: String
    var order: Int

    /// 그룹 정보 없이 저장된 v1.2까지의 기록은 "기본 루틴"으로 본다.
    static let legacy = GroupSnapshot(
        id: RoutineGroup.defaultID, title: RoutineGroup.defaultTitle, colorKey: RoutineGroup.defaultColorKey, order: 0
    )

    init(id: UUID, title: String, colorKey: String, order: Int) {
        self.id = id
        self.title = title
        self.colorKey = colorKey
        self.order = order
    }

    init(_ group: RoutineGroup) {
        self.init(id: group.id, title: group.title, colorKey: group.colorKey, order: group.order)
    }

    /// 저장된 값에서 복원한다. `storedID`가 없으면 그룹 도입 전의 기록이다.
    init(storedID: UUID?, title: String, colorKey: String, order: Int) {
        guard let storedID else {
            self = .legacy
            return
        }
        self.init(id: storedID, title: title, colorKey: colorKey, order: order)
    }
}

/// 루틴 항목의 "그 시점의 유효 상태". 변경 이력과 오늘 기록 동기화가 이 값을 기준으로 한다.
struct RoutineState: Equatable, Sendable {
    var title: String
    var timeLabel: String
    var note: String
    var weekdayMask: Int
    /// 항목이 보관됐거나, 속한 그룹이 보관된 상태.
    var isArchived: Bool
    var order: Int
    var group: GroupSnapshot
}
