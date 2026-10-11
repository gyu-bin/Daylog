import SwiftUI

/// 날짜 결과를 화면 문자열과 색으로 바꾸는 규칙. 표·캘린더·카드가 같은 표현을 쓴다.
extension DayOutcome {
    /// "4 / 5", "미기록", "휴식"
    var countLabel: String {
        switch status {
        case .recorded: return "\(done) / \(total)"
        case .unrecorded: return "미기록"
        case .vacation: return "휴가"
        case .rest: return "휴식"
        case .preStart: return "—"
        case .future: return ""
        }
    }

    /// "80%". 달성률이 없는 날은 "—".
    var percentLabel: String {
        status == .vacation ? "휴가" : percent.map { "\($0)%" } ?? "—"
    }

    func tint(threshold: Int) -> Color {
        isAchieved(threshold: threshold) ? Theme.accent : Theme.accentSoft
    }

    /// VoiceOver용 한 줄 요약. 색에 의존하지 않고 상태를 말로 전달한다.
    func spokenSummary(threshold: Int) -> String {
        switch status {
        case .recorded:
            let achieved = isAchieved(threshold: threshold) ? "기준 달성" : "기준 미달"
            return "\(day.shortTitle) \(day.weekdaySymbol)요일, \(total)개 중 \(done)개 완료, 달성률 \(percentLabel), \(achieved)"
        case .unrecorded:
            return "\(day.shortTitle) \(day.weekdaySymbol)요일, 미기록, 달성률 0%"
        case .vacation:
            return "\(day.shortTitle) \(day.weekdaySymbol)요일, 휴가, 통계 제외"
        case .rest:
            return "\(day.shortTitle) \(day.weekdaySymbol)요일, 휴식일"
        case .preStart:
            return "\(day.shortTitle) \(day.weekdaySymbol)요일, 통계 시작 전"
        case .future:
            return "\(day.shortTitle) \(day.weekdaySymbol)요일, 아직 오지 않은 날"
        }
    }
}
