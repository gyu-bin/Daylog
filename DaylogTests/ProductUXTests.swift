import Foundation
import Testing
@testable import Daylog

/// 제품 UX 점검에서 넣은 규칙: 휴가 카드의 상태와 달력의 한 주 시작 요일.
@MainActor
struct ProductUXTests {
    private func day(_ month: Int, _ day: Int, year: Int = 2026) -> Day { Day(year: year, month: month, day: day) }
    private func period(_ start: Day, _ end: Day, memo: String = "") -> VacationPeriod {
        VacationPeriod(start: start, end: end, memo: memo)
    }

    // MARK: - 휴가 상태

    @Test func noVacationMeansNone() {
        #expect(VacationStatus.resolve(periods: [], on: day(10, 12), today: day(10, 12)) == .none)
        // 지나간 휴가만 있으면 예정도, 진행 중도 아니다.
        let past = period(day(10, 1), day(10, 3))
        #expect(VacationStatus.resolve(periods: [past], on: day(10, 12), today: day(10, 12)) == .none)
        #expect(VacationStatus.summary(periods: [past], today: day(10, 12)) == "예정 없음")
        #expect(VacationStatus.summary(periods: [], today: day(10, 12)) == "없음")
    }

    @Test func upcomingShowsTheNearestPeriodAndDDay() {
        let near = period(day(10, 15), day(10, 17))
        let far = period(day(11, 1), day(11, 5))
        let status = VacationStatus.resolve(periods: [far, near], on: day(10, 12), today: day(10, 12))
        #expect(status == .upcoming(period: near, daysUntil: 3))
        #expect(VacationStatus.dDayLabel(3) == "D-3")
        #expect(VacationStatus.dDayLabel(1) == "내일")
        #expect(VacationStatus.summary(periods: [far, near], today: day(10, 12)) == "다음 10월 15일 · D-3")
    }

    @Test func activeVacationWinsOverUpcoming() {
        let current = period(day(10, 11), day(10, 13))
        let next = period(day(10, 20), day(10, 21))
        let status = VacationStatus.resolve(periods: [next, current], on: day(10, 12), today: day(10, 12))
        #expect(status == .active(periods: [current], start: day(10, 11), end: day(10, 13), remainingDays: 1))
        #expect(VacationStatus.remainingLabel(1) == "1일 남음")
        #expect(VacationStatus.remainingLabel(0) == "오늘까지")
        #expect(VacationStatus.summary(periods: [next, current], today: day(10, 12)) == "휴가 중 · 10월 13일까지")
    }

    @Test func vacationEndsTheDayAfterItsLastDay() {
        let current = period(day(10, 11), day(10, 13))
        let next = period(day(10, 20), day(10, 21))
        // 마지막 날: 아직 휴가이고 남은 날은 0.
        #expect(VacationStatus.resolve(periods: [current, next], on: day(10, 13), today: day(10, 13))
                == .active(periods: [current], start: day(10, 11), end: day(10, 13), remainingDays: 0))
        // 다음 날: 휴가가 끝났고, 그다음 예정된 휴가를 알려 준다.
        #expect(VacationStatus.resolve(periods: [current, next], on: day(10, 14), today: day(10, 14))
                == .upcoming(period: next, daysUntil: 6))
        // 시작 전날: 내일 시작.
        #expect(VacationStatus.resolve(periods: [current], on: day(10, 10), today: day(10, 10))
                == .upcoming(period: current, daysUntil: 1))
    }

    @Test func overlappingAndAdjacentPeriodsFormOneRun() {
        let a = period(day(10, 10), day(10, 12))
        let b = period(day(10, 12), day(10, 15))   // 겹침
        let c = period(day(10, 16), day(10, 18))   // 하루도 안 띄고 이어짐
        let d = period(day(10, 20), day(10, 21))   // 하루 띄움: 이어지지 않는다
        let status = VacationStatus.resolve(periods: [d, c, b, a], on: day(10, 12), today: day(10, 12))
        #expect(status == .active(periods: [a, b], start: day(10, 10), end: day(10, 18), remainingDays: 6))
    }

    @Test func runCrossesMonthAndYearBoundaries() {
        let yearEnd = period(day(12, 30), Day(year: 2027, month: 1, day: 2))
        let status = VacationStatus.resolve(periods: [yearEnd], on: day(12, 31), today: day(12, 31))
        #expect(status == .active(periods: [yearEnd], start: day(12, 30), end: Day(year: 2027, month: 1, day: 2), remainingDays: 2))
        #expect(VacationStatus.rangeTitle(start: day(12, 30), end: Day(year: 2027, month: 1, day: 2)) == "12월 30일 (수) ~ 1월 2일 (토)")
    }

    @Test func viewingAnotherDayStillCountsDDayFromToday() {
        let next = period(day(10, 15), day(10, 17))
        // 지난 날짜를 보고 있어도 다음 휴가는 오늘 기준.
        #expect(VacationStatus.resolve(periods: [next], on: day(10, 5), today: day(10, 12)) == .upcoming(period: next, daysUntil: 3))
        // 휴가인 미래 날짜를 보면 그날의 상태(휴가)를 보여 준다.
        #expect(VacationStatus.resolve(periods: [next], on: day(10, 16), today: day(10, 12))
                == .active(periods: [next], start: day(10, 15), end: day(10, 17), remainingDays: 1))
    }

    // MARK: - 한 주의 시작 요일

    @Test func weekStartOrdersWeekdays() {
        #expect(WeekStart.monday.orderedWeekdays == [1, 2, 3, 4, 5, 6, 7])
        #expect(WeekStart.sunday.orderedWeekdays == [7, 1, 2, 3, 4, 5, 6])
        #expect(WeekStart.sunday.orderedWeekdays.map(Weekdays.symbol) == ["일", "월", "화", "수", "목", "금", "토"])
    }

    @Test func monthGridLeadingBlanksFollowTheWeekStart() {
        // 2026-10-01은 목요일.
        #expect(MonthGrid(containing: day(10, 11), weekStart: .monday).leadingBlanks == 3)
        #expect(MonthGrid(containing: day(10, 11), weekStart: .sunday).leadingBlanks == 4)
        // 2026-11-01은 일요일: 월요일 시작이면 여섯 칸을 비우고, 일요일 시작이면 비우지 않는다.
        #expect(MonthGrid(containing: day(11, 1), weekStart: .monday).leadingBlanks == 6)
        #expect(MonthGrid(containing: day(11, 1), weekStart: .sunday).leadingBlanks == 0)
        // 2027-02-01은 월요일.
        let february = Day(year: 2027, month: 2, day: 1)
        #expect(MonthGrid(containing: february, weekStart: .monday).leadingBlanks == 0)
        #expect(MonthGrid(containing: february, weekStart: .sunday).leadingBlanks == 1)
        // 어느 쪽이든 여섯 줄을 채운다.
        for start in WeekStart.allCases {
            for month in [day(10, 1), day(11, 1), february, Day(year: 2028, month: 2, day: 1), day(12, 1)] {
                let grid = MonthGrid(containing: month, weekStart: start)
                #expect(grid.leadingBlanks + grid.days.count + grid.trailingBlanks == 42)
                #expect(grid.trailingBlanks >= 0)
            }
        }
    }

    @Test func leapDayLandsInTheRightColumn() {
        let leap = Day(year: 2028, month: 2, day: 29)   // 화요일
        #expect(leap.weekday == 2)
        #expect(WeekStart.monday.column(of: leap) == 1)
        #expect(WeekStart.sunday.column(of: leap) == 2)
        #expect(MonthGrid(containing: leap, weekStart: .sunday).days.count == 29)
    }

    @Test func weekBoundsCrossMonthAndYear() {
        let newYear = Day(year: 2027, month: 1, day: 1)   // 금요일
        #expect(WeekStart.monday.weekStart(containing: newYear) == day(12, 28))
        #expect(WeekStart.monday.weekEnd(containing: newYear) == Day(year: 2027, month: 1, day: 3))
        #expect(WeekStart.sunday.weekStart(containing: newYear) == day(12, 27))
        #expect(WeekStart.sunday.weekEnd(containing: newYear) == Day(year: 2027, month: 1, day: 2))
        // 주의 첫날 자신은 그대로.
        #expect(WeekStart.sunday.weekStart(containing: day(10, 11)) == day(10, 11))   // 일요일
        #expect(WeekStart.monday.weekStart(containing: day(10, 12)) == day(10, 12))   // 월요일
    }

    /// 시간대가 달라도 달력 날짜(`Day`)의 요일은 같다: 격자는 기기의 시간대에 흔들리지 않는다.
    @Test func columnsDoNotDependOnTheDeviceTimeZone() {
        let instant = day(10, 11).anchorDate   // UTC 정오
        for identifier in ["Asia/Seoul", "Pacific/Honolulu", "Pacific/Kiritimati", "UTC"] {
            let restored = Day(anchorDate: instant)
            #expect(restored == day(10, 11), "\(identifier)")
            #expect(WeekStart.sunday.column(of: restored) == 0)
            #expect(WeekStart.monday.column(of: restored) == 6)
        }
        // 서울의 자정 직후는 호놀룰루에서는 전날이다. 오늘을 정할 때만 시간대를 쓰고, 그 뒤 격자는 Day로만 계산한다.
        var seoul = Calendar(identifier: .gregorian); seoul.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let justAfterMidnight = seoul.date(from: DateComponents(year: 2026, month: 10, day: 12, hour: 0, minute: 5))!
        #expect(Day.today(now: justAfterMidnight, timeZone: seoul.timeZone) == day(10, 12))
        #expect(Day.today(now: justAfterMidnight, timeZone: TimeZone(identifier: "Pacific/Honolulu")!) == day(10, 11))
    }

    @Test func heatmapColumnsFollowTheWeekStart() {
        let days = Day.range(from: day(10, 5), to: day(10, 11))   // 월~일
        let outcomes = days.map { DayOutcome(day: $0, status: .rest, done: 0, total: 0) }
        let mondayWeeks = HeatmapLayout.weeks(outcomes, weekStart: .monday)
        #expect(mondayWeeks.count == 1)
        #expect(mondayWeeks[0].compactMap { $0?.day } == days)
        let sundayWeeks = HeatmapLayout.weeks(outcomes, weekStart: .sunday)
        // 일요일 시작이면 10/4(일)부터의 주와 10/11(일)부터의 주, 두 열에 걸친다.
        #expect(sundayWeeks.count == 2)
        #expect(sundayWeeks[0].first! == nil)
        #expect(sundayWeeks[0].compactMap { $0?.day } == Array(days.dropLast()))
        #expect(sundayWeeks[1].first??.day == day(10, 11))
    }

    @Test func weekStartIsStoredPerDeviceAndDefaultsToMonday() throws {
        let suite = "daylog.tests.weekstart.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(DevicePreferences(defaults: defaults, isPhone: false).weekStart == .monday)
        let preferences = DevicePreferences(defaults: defaults, isPhone: false)
        preferences.setWeekStart(.sunday)
        #expect(DevicePreferences(defaults: defaults, isPhone: false).weekStart == .sunday, "다시 실행해도 유지된다.")
        defaults.set("someday", forKey: DevicePreferences.weekStartKey)
        #expect(DevicePreferences(defaults: defaults, isPhone: false).weekStart == .monday, "모르는 값은 기본값으로.")
    }

    // MARK: - 시작 안내와 설정 요약

    @Test func onboardingStepsAlwaysPassThroughReady() {
        #expect(OnboardingStep.introduction.next == .createRoutine)
        #expect(OnboardingStep.createRoutine.next == .ready, "루틴을 만들지 않고 넘겨도 준비 완료 단계로 간다.")
        #expect(OnboardingStep.ready.next == .ready)
        #expect(OnboardingFlow.skipRoutineTitle(hasRoutines: false) == "나중에 설정하기")
        #expect(OnboardingFlow.skipRoutineTitle(hasRoutines: true) == "현재 루틴으로 계속")
    }

    @Test func dashboardLayoutSummaryCountsCards() {
        #expect(DevicePreferenceSections.layoutSummary(visible: 7, hidden: 0) == "카드 7개 표시")
        #expect(DevicePreferenceSections.layoutSummary(visible: 7, hidden: 4) == "카드 7개 표시 · 4개 숨김")
    }

    // MARK: - 메뉴와 설정 갈래

    @Test func vacationMenuIsInTheSidebarButNotInPhoneTabs() throws {
        #expect(AppStore.Section.allCases == [.dashboard, .routines, .meals, .statistics, .calendar, .vacation, .templates, .settings])
        #expect(AppStore.Section.phoneTabs == [.dashboard, .routines, .meals, .statistics, .settings], "iPhone 탭은 다섯 개 그대로.")
        let suite = "daylog.tests.sections.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = DevicePreferences(defaults: defaults, isPhone: false)
        #expect(preferences.navigationSections(phone: false).last == .settings)
        #expect(preferences.navigationSections(phone: false).contains(.vacation))
        #expect(!preferences.navigationSections(phone: true).contains(.vacation))
        #expect(Set(AppStore.Section.allCases.map(\.symbol)).count == AppStore.Section.allCases.count, "메뉴 아이콘은 서로 달라야 한다.")
    }

    @Test func settingsCategoriesCoverEveryExistingSetting() {
        // 예전 한 화면의 설정이 모두 어느 갈래엔가 들어 있어야 한다(없앤 설정이 없다).
        #expect(SettingsCategory.allCases.map(\.title) == ["iCloud", "일반", "오늘 화면", "루틴", "캘린더", "알림", "휴가", "데이터", "정보"])
        #expect(Set(SettingsCategory.allCases.map(\.symbol)).count == SettingsCategory.allCases.count)
        #expect(SettingsCategory.allCases.allSatisfy { !$0.subtitle.isEmpty })
    }

    @Test func syncSummaryDescribesTheStateInOneLine() {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        func make(enabled: Bool = true, account: CloudSyncMonitor.Account = .available, imported: Date? = nil, exported: Date? = nil, error: String? = nil) -> SyncSummary {
            SyncSummary.make(isEnabled: enabled, account: account, lastImportAt: imported, lastExportAt: exported, errorMessage: error, now: now)
        }
        #expect(make(enabled: false).tone == .off)
        #expect(make(account: .checking).title == "확인 중")
        #expect(make(account: .noAccount).tone == .warning)
        #expect(make().title == "대기 중", "연결은 됐지만 아직 주고받은 것이 없다.")
        // 가져오기와 보내기 중 더 최근 것을 기준으로 한다.
        let recent = make(imported: now.addingTimeInterval(-3600), exported: now.addingTimeInterval(-120))
        #expect(recent == SyncSummary(title: "정상", detail: "마지막 동기화 2분 전", tone: .good))
        // 오류가 남아 있으면 시각이 있어도 오류다.
        #expect(make(imported: now, error: "네트워크").title == "오류")
        #expect(SyncSummary.relative(now.addingTimeInterval(-30), now: now) == "방금 전")
        #expect(SyncSummary.relative(now.addingTimeInterval(-7200), now: now) == "2시간 전")
        #expect(SyncSummary.relative(now.addingTimeInterval(-3 * 86400), now: now) == "3일 전")
        #expect(SyncSummary.relative(now.addingTimeInterval(60), now: now) == "방금 전", "시계가 어긋나 미래여도 음수로 적지 않는다.")
    }

    // MARK: - 오늘 화면의 휴가, 기기 목록

    @Test func vacationShowsOnTodayOnlyWhenActiveOrSoon() {
        let today = day(10, 12)
        func status(_ periods: [VacationPeriod]) -> VacationStatus {
            VacationStatus.resolve(periods: periods, on: today, today: today)
        }
        #expect(!status([]).showsOnDashboard)
        #expect(status([period(day(10, 11), day(10, 13))]).showsOnDashboard, "휴가 중")
        #expect(status([period(day(10, 19), day(10, 20))]).showsOnDashboard, "7일 뒤 시작")
        #expect(!status([period(day(10, 20), day(10, 21))]).showsOnDashboard, "8일 뒤 시작은 아직 알리지 않는다.")
        #expect(!status([period(day(10, 1), day(10, 3))]).showsOnDashboard, "지난 휴가")
        #expect(status([period(day(10, 11), day(10, 13))]).isActive)
    }

    @Test func deviceInfoIsRewrittenOnlyWhenNeeded() {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let payload = DeviceEdit.Payload(name: "Mac", kind: .mac, appVersion: "1.5.1 (1)")
        #expect(DeviceEdit.needsWrite(existing: nil, payload: payload, now: now, interval: 21600), "처음")
        #expect(!DeviceEdit.needsWrite(existing: (payload, now.addingTimeInterval(-3600)), payload: payload, now: now, interval: 21600), "한 시간 전에 적었으면 다시 적지 않는다.")
        #expect(DeviceEdit.needsWrite(existing: (payload, now.addingTimeInterval(-7 * 3600)), payload: payload, now: now, interval: 21600), "6시간이 지났다.")
        var updated = payload; updated.appVersion = "1.5.2 (1)"
        #expect(DeviceEdit.needsWrite(existing: (payload, now), payload: updated, now: now, interval: 21600), "버전이 바뀌었다.")
        // 적은 값은 그대로 읽힌다.
        #expect(DeviceEdit.decode(DeviceEdit.encode(payload)) == payload)
        #expect(DeviceEdit.decode("{}") == nil)
        #expect(DeviceEdit.fieldName("abc") == "device:abc")
    }

    @Test func deviceListKeepsOneRowPerDeviceAndHidesRemovedOnes() throws {
        let env = try TestEnv()
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let mine = DeviceService(context: env.context, deviceID: "device-a")
        let other = DeviceService(context: env.context, deviceID: "device-b")
        #expect(try mine.touch(name: "Mac", kind: .mac, appVersion: "1.5.1 (1)", now: now))
        #expect(try other.touch(name: "iPhone", kind: .phone, appVersion: "1.0.0 (2)", now: now.addingTimeInterval(-600)))
        #expect(try !mine.touch(name: "Mac", kind: .mac, appVersion: "1.5.1 (1)", now: now.addingTimeInterval(60)), "같은 내용을 바로 다시 적지 않는다.")
        try env.context.save()
        #expect(try mine.devices().map(\.name) == ["Mac", "iPhone"], "최근에 쓴 기기부터.")
        #expect(try mine.devices().count == 2)

        // 다른 기기를 목록에서 지워도 기록(다른 편집)은 건드리지 않고, 그 기기가 다시 쓰면 돌아온다.
        try mine.remove("device-b")
        #expect(try mine.devices().map(\.id) == ["device-a"])
        #expect(try other.touch(name: "iPhone", kind: .phone, appVersion: "1.0.0 (2)", now: now.addingTimeInterval(120)))
        #expect(try mine.devices().count == 2)

        // 기기 줄은 텍스트·체크·휴가의 편집으로 취급되지 않는다.
        #expect(try FieldEditService(context: env.context, deviceID: "device-a").groups().isEmpty)
        #expect(try FieldEditService(context: env.context, deviceID: "device-a").checkGroups().isEmpty)
        #expect(try VacationService(context: env.context, deviceID: "device-a").periods().isEmpty)
    }
}
