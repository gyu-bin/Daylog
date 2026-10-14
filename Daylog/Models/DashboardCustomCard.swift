import Foundation

/// 사용자가 대시보드에 더하는 꾸미기 카드의 종류.
enum CustomCardKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case image, text, sectionTitle, divider

    var id: String { rawValue }

    /// 새로 만들 수 있는 종류. 이미지 카드는 새로 만들지 않는다(이미 만든 것은 계속 보이고 고치고 지울 수 있다).
    /// 사진으로 꾸미는 자리는 상단 배경 하나만 둔다.
    static let addable: [CustomCardKind] = [.text, .sectionTitle, .divider]

    var title: String {
        switch self {
        case .image: return "이미지 카드"
        case .text: return "텍스트 카드"
        case .sectionTitle: return "섹션 제목"
        case .divider: return "구분선"
        }
    }

    /// 편집 막대의 [카드 추가] 단추에 쓰는 짧은 이름.
    var shortTitle: String {
        switch self {
        case .image: return "이미지"
        case .text: return "텍스트"
        case .sectionTitle: return "섹션 제목"
        case .divider: return "구분선"
        }
    }

    var symbol: String {
        switch self {
        case .image: return "photo"
        case .text: return "text.quote"
        case .sectionTitle: return "textformat.size"
        case .divider: return "minus"
        }
    }
}

/// 꾸미기 카드의 크기. 기기마다 따로 고른다. 루틴·식사 같은 기능 카드에는 없다.
enum CustomCardSize: String, Codable, CaseIterable, Identifiable, Sendable {
    case small, regular, large

    var id: String { rawValue }

    var title: String {
        switch self {
        case .small: return "작게"
        case .regular: return "보통"
        case .large: return "크게"
        }
    }

    /// 이미지 카드의 높이. 좁은 화면(iPhone)은 첫 루틴이 멀어지지 않게 한 단계씩 낮고 상한이 있다.
    func imageHeight(compact: Bool) -> CGFloat {
        switch self {
        case .small: return compact ? 84 : 104
        case .regular: return compact ? 116 : 156
        case .large: return compact ? Self.compactImageLimit : 220
        }
    }

    /// iPhone에서 이미지 카드가 차지하는 최대 높이.
    static let compactImageLimit: CGFloat = 152
}

/// 여러 기기가 함께 보는 텍스트 카드의 내용.
struct DashboardText: Equatable, Sendable {
    static let titleLimit = 40
    static let bodyLimit = 500

    var title: String
    var body: String

    var isEmpty: Bool { title.isEmpty && body.isEmpty }

    /// 앞뒤 공백을 떼고 길이를 제한한 값.
    static func cleaned(title: String, body: String) -> DashboardText {
        DashboardText(
            title: String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(titleLimit)),
            body: String(body.trimmingCharacters(in: .whitespacesAndNewlines).prefix(bodyLimit))
        )
    }
}

extension DashboardCard {
    private static let customPrefix = "custom:"

    /// 저장하는 이름. 기본 카드는 예전과 같은 글자이고, 꾸미기 카드는 "custom:<종류>:<ID>"다.
    /// 이 형식을 모르는 예전 앱은 그 이름을 건너뛰므로 기본 카드의 배치는 그대로 읽힌다.
    ///
    /// 카드의 해시와 비교가 이 값을 쓴다(RawRepresentable의 기본 구현). 그래서 여기서 카드를 키로 하는 표를 찾으면 안 된다.
    var rawValue: String {
        switch self {
        case .summary: return "summary"
        case .nextRoutine: return "nextRoutine"
        case .vacation: return "vacation"
        case .routines: return "routines"
        case .weeklyGrowth: return "weeklyGrowth"
        case .meals: return "meals"
        case .achievement: return "achievement"
        case .recentDays: return "recentDays"
        case .tomorrow: return "tomorrow"
        case .calendar: return "calendar"
        case .trend: return "trend"
        case .routineRates: return "routineRates"
        case .custom(let kind, let id): return "\(Self.customPrefix)\(kind.rawValue):\(id.uuidString)"
        }
    }

    init?(rawValue: String) {
        if rawValue.hasPrefix(Self.customPrefix) {
            let parts = rawValue.dropFirst(Self.customPrefix.count).split(separator: ":", maxSplits: 1)
            guard parts.count == 2, let kind = CustomCardKind(rawValue: String(parts[0])),
                  let id = UUID(uuidString: String(parts[1])) else { return nil }
            self = .custom(kind, id)
        } else if let match = Self.allCases.first(where: { $0.rawValue == rawValue }) {
            self = match
        } else {
            return nil
        }
    }

    var isCustom: Bool { customKind != nil }

    var customKind: CustomCardKind? {
        if case .custom(let kind, _) = self { return kind }
        return nil
    }

    var customID: UUID? {
        if case .custom(_, let id) = self { return id }
        return nil
    }
}
