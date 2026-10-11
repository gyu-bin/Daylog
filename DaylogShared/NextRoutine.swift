import Foundation

/// "다음 루틴"을 고르는 규칙. 앱의 오늘 화면과 위젯이 같은 규칙을 쓴다.
enum NextRoutine {
    struct Pick: Equatable {
        let index: Int
        let minutes: Int
        /// 예정 시간이 이미 지났다.
        let isOverdue: Bool
    }

    /// 아직 하지 않은, 시간이 정해진 항목 가운데 지금 이후로 가장 이른 것.
    /// 남은 것이 모두 지난 시간이면 그중 가장 이른 것(밀린 것부터). 같은 시각이면 목록에서 앞에 있는 것.
    /// 시간이 없거나 시각으로 읽히지 않는 항목은 고르지 않는다.
    static func pick(timeLabels: [String], isDone: [Bool], nowMinutes: Int) -> Pick? {
        let pending = zip(timeLabels, isDone).enumerated().compactMap { index, item -> Pick? in
            guard !item.1, let minutes = TimeLabel.minutes(item.0) else { return nil }
            return Pick(index: index, minutes: minutes, isOverdue: minutes < nowMinutes)
        }
        let ordered = pending.sorted { ($0.minutes, $0.index) < ($1.minutes, $1.index) }
        return ordered.first { !$0.isOverdue } ?? ordered.first
    }
}
