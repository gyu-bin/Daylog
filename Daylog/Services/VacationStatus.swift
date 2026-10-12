import Foundation

/// 어떤 날짜에서 본 휴가 상태. 대시보드·캘린더의 휴가 카드와 설정의 요약이 같은 규칙을 쓴다.
/// 기록은 건드리지 않고, 등록된 기간에서 계산만 한다.
enum VacationStatus: Equatable {
    /// 그날은 휴가가 아니고, 앞으로 예정된 휴가도 없다.
    case none
    /// 그날은 휴가가 아니지만 예정된 휴가가 있다. `daysUntil`은 오늘부터 시작일까지의 날 수(1 이상).
    case upcoming(period: VacationPeriod, daysUntil: Int)
    /// 그날이 휴가다. 겹치거나 이어 붙은 기간은 하나로 이어서 시작·끝을 낸다.
    /// `periods`는 그날을 포함하는 기간들(수정·해제 대상), `remainingDays`는 그날 뒤로 남은 휴가 날 수(0이면 그날이 마지막).
    case active(periods: [VacationPeriod], start: Day, end: Day, remainingDays: Int)

    static func resolve(periods: [VacationPeriod], on day: Day, today: Day) -> VacationStatus {
        let containing = periods.filter { $0.contains(day) }.sorted { ($0.start, $0.end) < ($1.start, $1.end) }
        if !containing.isEmpty {
            let run = continuousRun(periods: periods, around: day)
            return .active(periods: containing, start: run.start, end: run.end, remainingDays: day.days(until: run.end))
        }
        // 지나간 날짜를 보고 있어도 "다음 휴가"는 오늘 기준으로 알려 준다.
        let reference = max(day, today)
        guard let next = nextPeriod(periods: periods, after: reference) else { return .none }
        return .upcoming(period: next, daysUntil: today.days(until: next.start))
    }

    /// 오늘 화면에 휴가를 알릴 만한가: 휴가 중이거나, 시작이 `soonDays`일 안으로 다가왔을 때만.
    /// 그 밖에는 매일 보는 화면에서 자리를 차지하지 않는다(등록·관리는 휴가 메뉴에서).
    static let soonDays = 7

    var showsOnDashboard: Bool {
        switch self {
        case .none: return false
        case .upcoming(_, let daysUntil): return daysUntil <= Self.soonDays
        case .active: return true
        }
    }

    var isActive: Bool {
        if case .active = self { return true }
        return false
    }

    /// `day` 뒤에 시작하는 휴가 가운데 가장 가까운 것.
    static func nextPeriod(periods: [VacationPeriod], after day: Day) -> VacationPeriod? {
        periods.filter { $0.start > day }.min { ($0.start, $0.end) < ($1.start, $1.end) }
    }

    /// `day`를 포함해 끊기지 않고 이어지는 휴가 구간. 겹친 기간과 하루도 안 띄고 이어진 기간을 합친다.
    static func continuousRun(periods: [VacationPeriod], around day: Day) -> (start: Day, end: Day) {
        var start = day
        var end = day
        var changed = true
        while changed {
            changed = false
            for period in periods where period.start <= end.adding(days: 1) && period.end >= start.adding(days: -1) {
                if period.start < start { start = period.start; changed = true }
                if period.end > end { end = period.end; changed = true }
            }
        }
        return (start, end)
    }

    /// "D-3" 같은 짧은 표시.
    static func dDayLabel(_ daysUntil: Int) -> String {
        daysUntil <= 0 ? "오늘" : daysUntil == 1 ? "내일" : "D-\(daysUntil)"
    }

    /// "3일 남음" / "오늘까지".
    static func remainingLabel(_ remainingDays: Int) -> String {
        remainingDays <= 0 ? "오늘까지" : "\(remainingDays)일 남음"
    }

    /// 날짜 범위: 하루면 "10월 12일 (월)", 기간이면 "10월 12일 (월) ~ 10월 14일 (수)".
    static func rangeTitle(start: Day, end: Day) -> String {
        start == end
            ? "\(start.shortTitle) (\(start.weekdaySymbol))"
            : "\(start.shortTitle) (\(start.weekdaySymbol)) ~ \(end.shortTitle) (\(end.weekdaySymbol))"
    }

    /// 설정 화면 같은 곳에 쓰는 한 줄 요약(오늘 기준).
    static func summary(periods: [VacationPeriod], today: Day) -> String {
        switch resolve(periods: periods, on: today, today: today) {
        case .none:
            return periods.isEmpty ? "없음" : "예정 없음"
        case .upcoming(let period, let daysUntil):
            return "다음 \(period.start.shortTitle) · \(dDayLabel(daysUntil))"
        case .active(_, _, let end, let remainingDays):
            return remainingDays <= 0 ? "휴가 중 · 오늘까지" : "휴가 중 · \(end.shortTitle)까지"
        }
    }
}
