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

/// 그룹 색상 팔레트의 식별자. 저장소에는 이 문자열만 들어가고, 실제 색은 화면 쪽(`Theme`)에서 정한다.
enum GroupColor: String, CaseIterable, Sendable {
    case orange, blue, mint, purple, coral, yellow, green

    /// 모르는 값(나중 버전에서 추가된 색 등)은 기본색으로 본다.
    init(key: String) {
        self = GroupColor(rawValue: key) ?? .green
    }

    var label: String {
        switch self {
        case .orange: return "주황"
        case .blue: return "파랑"
        case .mint: return "민트"
        case .purple: return "보라"
        case .coral: return "코랄"
        case .yellow: return "노랑"
        case .green: return "초록"
        }
    }

    struct RGB: Equatable, Sendable {
        var red: Double
        var green: Double
        var blue: Double

        init(red: Double, green: Double, blue: Double) {
            self.red = red
            self.green = green
            self.blue = blue
        }

        init(hex: UInt32) {
            self.init(
                red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255
            )
        }

        /// WCAG 상대 휘도.
        var luminance: Double {
            func linear(_ channel: Double) -> Double {
                channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        }
    }

    /// 라이트 모드는 명세의 파스텔 팔레트, 다크 모드는 어두운 배경에서 묻히지 않게 한 단계 밝힌 색.
    func rgb(isDark: Bool) -> RGB {
        switch (self, isDark) {
        case (.orange, false): return RGB(hex: 0xF59E63)
        case (.orange, true): return RGB(hex: 0xFFB07A)
        case (.blue, false): return RGB(hex: 0x6395E8)
        case (.blue, true): return RGB(hex: 0x7FAAF5)
        case (.mint, false): return RGB(hex: 0x43BFA6)
        case (.mint, true): return RGB(hex: 0x5AD3BA)
        case (.purple, false): return RGB(hex: 0xA78BFA)
        case (.purple, true): return RGB(hex: 0xB9A2FF)
        case (.coral, false): return RGB(hex: 0xEF8B80)
        case (.coral, true): return RGB(hex: 0xFF948C)
        case (.yellow, false): return RGB(hex: 0xF4C65E)
        case (.yellow, true): return RGB(hex: 0xFFD675)
        case (.green, false): return RGB(hex: 0x36A879)
        case (.green, true): return RGB(hex: 0x55C98A)
        }
    }

    /// 새 그룹에 줄 색: 아직 안 쓴 색 중 첫 번째, 다 썼으면 돌아가며.
    static func next(after used: [String]) -> GroupColor {
        let usedColors = Set(used.map(GroupColor.init(key:)))
        return allCases.first { !usedColors.contains($0) } ?? allCases[used.count % allCases.count]
    }
}
