import Foundation

enum DayStatus: Equatable, Sendable {
    /// 사용자가 지정한 휴가. 기존 기록은 보존하고 모든 달성률·연속 일수에서 제외.
    case vacation
    /// 사용자가 실제로 기록한 날.
    case recorded
    /// 예정된 루틴이 있었지만 기록하지 않은 날. 통계상 0%.
    case unrecorded
    /// 예정된 루틴이 없던 날. 통계에서 제외.
    case rest
    /// 첫 루틴을 만들기 전.
    case preStart
    case future
}

/// 하루의 통계 결과. 카드·표·캘린더·차트가 모두 이 값을 쓴다.
struct DayOutcome: Equatable, Identifiable, Sendable {
    let day: Day
    let status: DayStatus
    let done: Int
    let total: Int
    /// 그날 건너뛴 루틴 수. 달성률에는 쓰이지 않는다(건너뛴 루틴은 미완료와 같다). "아무것도 하지 않은 날"과 구분할 때만 본다.
    var skipped: Int = 0

    var id: Day { day }

    /// 통계에 반영되는 원시 비율(0...1). 휴식일·시작 전·미래는 nil.
    var ratio: Double? {
        switch status {
        case .recorded, .unrecorded: return Achievement.ratio(done: done, total: total)
        case .vacation, .rest, .preStart, .future: return nil
        }
    }

    var percent: Int? {
        ratio.map(Achievement.percent(ratio:))
    }

    func isAchieved(threshold: Int) -> Bool {
        guard let percent else { return false }
        return percent >= threshold
    }
}

/// 통계 순수 함수. SwiftData에 의존하지 않는다.
enum StatsCalculator {
    /// 유효한 날의 원시 비율을 평균낸 뒤 마지막에 한 번만 반올림한다.
    static func averagePercent(_ outcomes: [DayOutcome]) -> Int? {
        let ratios = outcomes.compactMap(\.ratio)
        guard !ratios.isEmpty else { return nil }
        return Achievement.percent(ratio: ratios.reduce(0, +) / Double(ratios.count))
    }

    /// 오늘부터 거꾸로 센 연속 달성일. 오늘이 아직 기준 미만이면 어제부터 센다.
    /// 휴식일은 건너뛰고, 미기록일(0%)은 끊는다.
    static func currentStreak(_ outcomes: [DayOutcome], today: Day, threshold: Int) -> Int {
        var streak = 0
        for outcome in outcomes.sorted(by: { $0.day > $1.day }) where outcome.day <= today {
            if outcome.status == .preStart { break }
            guard outcome.ratio != nil else { continue }
            if outcome.isAchieved(threshold: threshold) {
                streak += 1
            } else if outcome.day != today {
                break
            }
        }
        return streak
    }

    static func longestStreak(_ outcomes: [DayOutcome], threshold: Int) -> Int {
        var longest = 0
        var current = 0
        for outcome in outcomes.sorted(by: { $0.day < $1.day }) {
            guard outcome.ratio != nil else { continue }
            current = outcome.isAchieved(threshold: threshold) ? current + 1 : 0
            longest = max(longest, current)
        }
        return longest
    }
}
