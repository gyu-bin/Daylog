import Foundation

/// 히트맵 한 칸의 상태. 색과 함께 모양·문구로도 전달한다.
enum HeatLevel: Equatable, Sendable {
    case vacation
    /// 통계 시작 전이거나 아직 오지 않은 날. 칸을 그리지 않는다.
    case none
    /// 예정된 루틴이 없던 날.
    case rest
    /// 예정이 있었지만 기록하지 않은 날(0%).
    case unrecorded
    /// 기록했고 50% 미만.
    case low
    /// 50% 이상이지만 기준 미만.
    case mid
    /// 기준 이상.
    case achieved

    init(_ outcome: DayOutcome, threshold: Int) {
        switch outcome.status {
        case .vacation: self = .vacation
        case .preStart, .future: self = .none
        case .rest: self = .rest
        case .unrecorded: self = .unrecorded
        case .recorded:
            let percent = outcome.percent ?? 0
            if percent >= threshold {
                self = .achieved
            } else if percent >= 50 {
                self = .mid
            } else {
                self = .low
            }
        }
    }

    var label: String {
        switch self {
        case .vacation: return "휴가"
        case .none: return ""
        case .rest: return "휴식"
        case .unrecorded: return "미기록"
        case .low: return "50% 미만"
        case .mid: return "기준 미만"
        case .achieved: return "기준 달성"
        }
    }
}

/// 날짜들을 "주(열) × 요일(행, 월~일)" 격자로 배치한다. 최근 날짜가 오른쪽이다.
enum HeatmapLayout {
    /// 각 열은 월요일부터 일요일까지 7칸. 범위 밖의 칸은 nil.
    static func weeks(_ outcomes: [DayOutcome]) -> [[DayOutcome?]] {
        guard let first = outcomes.first, let last = outcomes.last else { return [] }
        let byDay = Dictionary(uniqueKeysWithValues: outcomes.map { ($0.day, $0) })
        let gridStart = first.day.adding(days: -(first.day.weekday - 1))
        let gridEnd = last.day.adding(days: 7 - last.day.weekday)
        let days = Day.range(from: gridStart, to: gridEnd)
        return stride(from: 0, to: days.count, by: 7).map { offset in
            days[offset..<min(offset + 7, days.count)].map { byDay[$0] }
        }
    }

    /// 열마다 그 주에 새 달이 시작하면 "10월" 같은 머리글, 아니면 nil.
    static func monthLabels(_ weeks: [[DayOutcome?]]) -> [String?] {
        var previousMonth: Int?
        return weeks.map { week in
            guard let firstDay = week.compactMap({ $0?.day }).first else { return nil }
            defer { previousMonth = firstDay.month }
            return firstDay.month == previousMonth ? nil : "\(firstDay.month)월"
        }
    }
}
