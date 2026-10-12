import Foundation

/// 달력에서 한 주가 시작하는 요일. 화면 배치에만 쓰고, 기록이나 통계의 계산 기간은 바꾸지 않는다.
/// 이 기기에만 저장한다(`DevicePreferences`).
enum WeekStart: String, CaseIterable, Identifiable, Sendable {
    case monday, sunday

    var id: String { rawValue }

    var title: String { self == .monday ? "월요일" : "일요일" }

    /// 왼쪽부터 놓는 요일(1 = 월요일 … 7 = 일요일).
    var orderedWeekdays: [Int] {
        self == .monday ? Weekdays.all : [7] + Weekdays.all.dropLast()
    }

    /// `day`가 그 주의 몇 번째 칸인지(0부터). 달의 1일이면 앞에 비울 칸 수와 같다.
    func column(of day: Day) -> Int {
        self == .monday ? day.weekday - 1 : day.weekday % 7
    }

    /// `day`가 든 주의 첫날과 마지막 날.
    func weekStart(containing day: Day) -> Day { day.adding(days: -column(of: day)) }
    func weekEnd(containing day: Day) -> Day { day.adding(days: 6 - column(of: day)) }
}
