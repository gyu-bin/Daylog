import Foundation

/// 시간대와 무관한 달력 날짜(연·월·일).
///
/// `key`("yyyy-MM-dd")가 날짜별 기록의 안정적인 식별자다. "오늘"을 정할 때만 시스템 시간대를 쓰고,
/// 그 뒤의 모든 날짜 연산은 UTC 달력으로 수행해 서머타임·시간대 변경의 영향을 받지 않는다.
struct Day: Hashable, Comparable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    /// 날짜 연산 전용 달력. 월요일 시작.
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        calendar.firstWeekday = 2
        return calendar
    }()

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// `date`가 `timeZone`에서 속하는 달력 날짜.
    init(date: Date, timeZone: TimeZone) {
        var local = Calendar(identifier: .gregorian)
        local.timeZone = timeZone
        let parts = local.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    /// `anchorDate`로 저장해 둔 값에서 달력 날짜를 복원한다.
    init(anchorDate: Date) {
        self.init(date: anchorDate, timeZone: .gmt)
    }

    /// "yyyy-MM-dd" 형식만 받는다. 존재하지 않는 날짜(예: 2월 30일)는 nil.
    init?(key: String) {
        let parts = key.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else { return nil }
        let candidate = Day(year: year, month: month, day: day)
        guard Day(anchorDate: candidate.anchorDate) == candidate else { return nil }
        self = candidate
    }

    static func today(now: Date = .now, timeZone: TimeZone = .autoupdatingCurrent) -> Day {
        Day(date: now, timeZone: timeZone)
    }

    var key: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// 해당 날짜의 UTC 정오. 어느 시간대에서 읽어도 같은 달력 날짜로 복원된다.
    var anchorDate: Date {
        let components = DateComponents(year: year, month: month, day: day, hour: 12)
        return Self.calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }

    /// 1 = 월요일 … 7 = 일요일.
    var weekday: Int {
        let sundayBased = Self.calendar.component(.weekday, from: anchorDate)
        return (sundayBased + 5) % 7 + 1
    }

    var firstOfMonth: Day {
        Day(year: year, month: month, day: 1)
    }

    var daysInMonth: Int {
        Self.calendar.range(of: .day, in: .month, for: anchorDate)?.count ?? 30
    }

    func adding(days: Int) -> Day {
        guard let date = Self.calendar.date(byAdding: .day, value: days, to: anchorDate) else { return self }
        return Day(anchorDate: date)
    }

    /// `months`개월 뒤(음수면 앞) 달의 1일.
    func addingMonths(_ months: Int) -> Day {
        guard let date = Self.calendar.date(byAdding: .month, value: months, to: firstOfMonth.anchorDate) else {
            return firstOfMonth
        }
        return Day(anchorDate: date)
    }

    func days(until other: Day) -> Int {
        Self.calendar.dateComponents([.day], from: anchorDate, to: other.anchorDate).day ?? 0
    }

    /// `from`부터 `to`까지(양 끝 포함) 오름차순. `from > to`면 빈 배열.
    static func range(from: Day, to: Day) -> [Day] {
        let count = from.days(until: to)
        guard count >= 0 else { return [] }
        return (0...count).map { from.adding(days: $0) }
    }

    static func < (lhs: Day, rhs: Day) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

// MARK: - 표시용 문자열

extension Day {
    var weekdaySymbol: String { Weekdays.symbol(weekday) }

    /// 2026년 10월 10일 (토)
    var longTitle: String { "\(year)년 \(month)월 \(day)일 (\(weekdaySymbol))" }

    /// 10월 10일
    var shortTitle: String { "\(month)월 \(day)일" }

    /// 2026년 10월
    var monthTitle: String { "\(year)년 \(month)월" }

    /// 10/10
    var axisLabel: String { "\(month)/\(day)" }
}
