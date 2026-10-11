import Foundation

/// 달성률 계산. UI와 통계가 모두 이 함수만 사용한다.
enum Achievement {
    /// 원시 비율(0...1). 루틴이 0개면 nil.
    static func ratio(done: Int, total: Int) -> Double? {
        guard total > 0 else { return nil }
        return Double(min(max(done, 0), total)) / Double(total)
    }

    /// 정수로 반올림한 백분율. 루틴이 0개면 nil.
    static func percent(done: Int, total: Int) -> Int? {
        ratio(done: done, total: total).map(percent(ratio:))
    }

    static func percent(ratio: Double) -> Int {
        Int((ratio * 100).rounded())
    }
}
