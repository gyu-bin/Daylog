import Foundation

/// 요일 표현. 1 = 월요일 … 7 = 일요일.
enum Weekdays {
    static let all = Array(1...7)
    static let workdays = Array(1...5)
    static let weekend = [6, 7]

    private static let symbols = ["월", "화", "수", "목", "금", "토", "일"]

    static func symbol(_ weekday: Int) -> String {
        guard (1...7).contains(weekday) else { return "" }
        return symbols[weekday - 1]
    }

    static func mask(_ days: [Int]) -> Int {
        days.filter { (1...7).contains($0) }.reduce(0) { $0 | (1 << ($1 - 1)) }
    }

    static func days(mask: Int) -> [Int] {
        all.filter { mask & (1 << ($0 - 1)) != 0 }
    }

    /// "매일", "평일", "주말" 또는 "월·수·금".
    static func summary(_ days: [Int]) -> String {
        let sorted = Array(Set(days)).sorted()
        switch sorted {
        case all: return "매일"
        case workdays: return "평일"
        case weekend: return "주말"
        default: return sorted.map(symbol).joined(separator: "·")
        }
    }
}
