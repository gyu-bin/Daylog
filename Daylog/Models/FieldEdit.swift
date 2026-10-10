import Foundation
import SwiftData

/// 하루 기록의 텍스트 칸.
enum DayTextField: String, CaseIterable, Sendable {
    case breakfast, lunch, dinner, snack, mealMemo, tomorrowTask

    var keyPath: ReferenceWritableKeyPath<DayRecord, String> {
        switch self {
        case .breakfast: return \.breakfast
        case .lunch: return \.lunch
        case .dinner: return \.dinner
        case .snack: return \.snack
        case .mealMemo: return \.mealMemo
        case .tomorrowTask: return \.tomorrowTask
        }
    }

    var label: String {
        switch self {
        case .breakfast: return "아침"
        case .lunch: return "점심"
        case .dinner: return "저녁"
        case .snack: return "간식"
        case .mealMemo: return "식사 메모"
        case .tomorrowTask: return "내일 오전 할 일"
        }
    }

    /// 서로 다른 내용을 함께 남길 때 사이에 넣는 구분자. 한 줄짜리 칸은 줄바꿈을 쓰지 않는다.
    var separator: String {
        self == .tomorrowTask ? " / " : "\n"
    }

    init?(keyPath: KeyPath<DayRecord, String>) {
        guard let match = Self.allCases.first(where: { $0.keyPath == keyPath }) else { return nil }
        self = match
    }
}

/// 한 기기가 어떤 날짜의 텍스트 칸에 마지막으로 쓴 내용.
///
/// 실측 결과 iCloud는 같은 칸을 두 기기가 다르게 고치면 나중에 동기화한 쪽의 값으로 덮어쓰고,
/// 다른 쪽 내용은 흔적 없이 사라진다. 이 기록은 (날짜, 칸, 기기)마다 따로 있어서 기기끼리 서로
/// 덮어쓰지 않는다. `seenState`에는 이 값을 쓸 때 이미 보고 있던 다른 기기들의 편집 시각을 적어 두어,
/// "상대 내용을 보고 고친 것"과 "못 본 채 동시에 쓴 것"을 구분한다. 뒤의 경우에는 두 내용을 모두 남긴다.
@Model
final class FieldEdit {
    var dateKey: String = ""
    var field: String = ""
    var deviceID: String = ""
    var value: String = ""
    var editedAt: Date = Date.distantPast
    /// [기기 ID: 그 기기 편집의 `editedAt`(기준 시각으로부터의 초)]의 JSON.
    var seenState: Data?
    var syncID: UUID?

    init(dateKey: String, field: String, deviceID: String) {
        self.dateKey = dateKey
        self.field = field
        self.deviceID = deviceID
        self.syncID = UUID()
    }

    var seen: [String: Double] {
        get {
            guard let seenState else { return [:] }
            return (try? JSONDecoder().decode([String: Double].self, from: seenState)) ?? [:]
        }
        set {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            seenState = try? encoder.encode(newValue)
        }
    }
}
