import Foundation
import SwiftData
import Testing
@testable import Daylog

/// 휴가 중 루틴 정책: 전체 휴식 / 고른 루틴만 유지. 저장 형식, 화면에 보일 목록, 알림, 위젯, 통계.
@MainActor
struct VacationRoutineTests {
    // MARK: - 저장 형식과 호환성

    @Test func fullRestKeepsTheOriginalPayloadShape() throws {
        let period = VacationPeriod(start: monday, end: sunday, memo: "여행")
        let json = try VacationEdit.encode(period)
        // 전체 휴식은 이전 버전이 쓰던 글자와 같다(새 칸을 쓰지 않는다).
        #expect(json == #"{"end":"2026-10-11","isRemoved":false,"memo":"여행","start":"2026-10-05","version":1}"#)
    }

    @Test func legacyVacationsReadAsFullRest() throws {
        let legacy = #"{"end":"2026-10-11","isRemoved":false,"memo":"","start":"2026-10-05","version":1}"#
        let payload = try JSONDecoder().decode(VacationEdit.Payload.self, from: Data(legacy.utf8))
        let period = try #require(payload.period(id: UUID()))
        #expect(period.keptRoutineIDs.isEmpty)
        #expect(!period.keepsRoutines)
        #expect(VacationRoutinePolicy.resolve(periods: [period], on: monday) == .fullRest)
    }

    @Test func keptRoutinesRoundTripAndStayReadableByOlderDecoders() throws {
        let a = UUID(), b = UUID()
        let period = VacationPeriod(start: monday, end: sunday, keptRoutineIDs: [a, b])
        let json = try VacationEdit.encode(period)
        let decoded = try JSONDecoder().decode(VacationEdit.Payload.self, from: Data(json.utf8))
        #expect(decoded.period(id: period.id) == period)
        // 버전은 그대로 1이다: 이 칸을 모르는 이전 앱도 휴가 자체는 읽는다.
        #expect(decoded.version == 1)
        struct OldPayload: Codable { var version: Int; var start: String; var end: String; var memo: String; var isRemoved: Bool }
        let old = try JSONDecoder().decode(OldPayload.self, from: Data(json.utf8))
        #expect(old.start == monday.key && old.end == sunday.key && !old.isRemoved)
    }

    @Test func keptRoutinesPersistAndCanBeClearedWithoutDeletingRows() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(3, today: monday)
        let service = VacationService(context: env.context, deviceID: "phone")
        let saved = try service.save(start: monday, end: sunday, keptRoutineIDs: [routines[0].id, routines[2].id])
        let fresh = VacationService(context: env.freshContext(), deviceID: "reader")
        #expect(try fresh.periods().first?.keptRoutineIDs == [routines[0].id, routines[2].id])
        // 다시 전체 휴식으로.
        try service.save(id: saved.id, start: monday, end: sunday)
        #expect(try fresh.periods().first?.keepsRoutines == false)
        #expect(try env.context.fetchCount(FetchDescriptor<FieldEdit>()) == 1)
    }

    // MARK: - 정책

    @Test func policyIsNormalOutsideVacations() {
        let period = VacationPeriod(start: monday, end: monday, keptRoutineIDs: [UUID()])
        #expect(VacationRoutinePolicy.resolve(periods: [period], on: sunday) == .normal)
        #expect(VacationRoutinePolicy.resolve(periods: [], on: monday) == .normal)
        #expect(VacationRoutinePolicy.normal.shows(UUID()))
    }

    @Test func overlappingPeriodsKeepTheUnionOfKeptRoutines() {
        let a = UUID(), b = UUID(), c = UUID()
        let periods = [
            VacationPeriod(start: monday, end: sunday),
            VacationPeriod(start: monday, end: monday.adding(days: 2), keptRoutineIDs: [a]),
            VacationPeriod(start: monday.adding(days: 2), end: sunday, keptRoutineIDs: [b])
        ]
        #expect(VacationRoutinePolicy.resolve(periods: periods, on: monday) == .keep([a]))
        #expect(VacationRoutinePolicy.resolve(periods: periods, on: monday.adding(days: 2)) == .keep([a, b]))
        #expect(!VacationRoutinePolicy.resolve(periods: periods, on: sunday).shows(c))
        #expect(VacationRoutinePolicy.resolve(periods: [periods[0]], on: monday) == .fullRest)
    }

    // MARK: - 화면에 보일 목록

    @Test func fullRestHidesTheChecklistButKeepsTheRecord() throws {
        let env = try TestEnv()
        try env.addRoutines(3, today: monday)
        try env.log(monday, done: 2)
        let store = AppStore(container: env.container, deviceID: "phone", clock: { monday })
        store.start()
        #expect(store.checkSections.reduce(0) { $0 + $1.total } == 3)

        #expect(store.saveVacation(start: monday, end: monday))
        #expect(store.routinePolicy(on: monday) == .fullRest)
        #expect(store.checkSections.isEmpty)
        #expect(store.todaySections.isEmpty)
        #expect(store.selectedOutcome.status == .vacation)
        // 저장된 체크는 그대로다.
        let record = try #require(try env.records.record(on: monday))
        #expect(record.checkList.count == 3)
        #expect(record.checkList.filter(\.isDone).count == 2)

        // 해제하면 평소 목록과 통계가 돌아온다.
        let period = try #require(store.vacations(on: monday).first)
        #expect(store.removeVacation(period))
        #expect(store.checkSections.reduce(0) { $0 + $1.total } == 3)
        #expect(store.checkSections.reduce(0) { $0 + $1.done } == 2)
        #expect(store.stats.today.percent == 67)
    }

    @Test func keepModeShowsOnlyChosenRoutinesAndTheyCanBeChecked() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(3, today: monday)
        let store = AppStore(container: env.container, deviceID: "phone", clock: { monday })
        store.start()
        #expect(store.saveVacation(start: monday, end: monday, keptRoutineIDs: [routines[1].id]))
        #expect(store.checkSections.flatMap(\.checks).map(\.id) == [routines[1].id])
        #expect(store.todaySections.flatMap(\.checks).map(\.id) == [routines[1].id])

        store.setDone(routineID: routines[1].id, true)
        #expect(store.checkSections.first?.done == 1)
        // 휴가 날짜는 통계에서 빠진다(체크는 남는다).
        #expect(store.stats.today.status == .vacation)
        #expect(store.stats.today.percent == nil)
        #expect(store.selectedOutcome.status == .vacation)
        #expect(store.selectedOutcome.done == 1 && store.selectedOutcome.total == 1)
        #expect(try env.records.record(on: monday)?.checkList.filter(\.isDone).count == 1)

        // 휴가를 해제하면 휴가 중에 한 체크가 통계에 반영된다.
        let period = try #require(store.vacations(on: monday).first)
        #expect(store.removeVacation(period))
        #expect(store.checkSections.reduce(0) { $0 + $1.total } == 3)
        #expect(store.stats.today.percent == 33)
    }

    @Test func routinesReturnTheDayAfterTheVacationEnds() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(2, today: monday)
        let clock = TestClock(monday)
        let store = AppStore(container: env.container, deviceID: "phone", clock: { clock.today })
        store.start()
        #expect(store.saveVacation(start: monday, end: monday, keptRoutineIDs: [routines[0].id]))
        #expect(store.todaySections.reduce(0) { $0 + $1.total } == 1)
        clock.today = monday.adding(days: 1)
        store.refreshToday()
        #expect(store.routinePolicy(on: store.today) == .normal)
        #expect(store.todaySections.reduce(0) { $0 + $1.total } == 2)
        // 지난 휴가 날을 다시 보면 그날의 정책대로 보인다.
        store.select(monday)
        #expect(store.checkSections.reduce(0) { $0 + $1.total } == 1)
    }

    @Test func archivedKeptRoutineSimplyDoesNotAppear() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(2, today: monday)
        let clock = TestClock(monday)
        let store = AppStore(container: env.container, deviceID: "phone", clock: { clock.today })
        store.start()
        let tuesday = monday.adding(days: 1)
        #expect(store.saveVacation(start: tuesday, end: tuesday, keptRoutineIDs: [routines[0].id]))
        store.setArchived(routines[0], true)
        clock.today = tuesday
        store.refreshToday()
        // 유지하기로 한 루틴이 없어졌어도 다른 루틴이 대신 나타나지 않는다.
        #expect(store.routinePolicy(on: tuesday).keepsRoutines)
        #expect(store.todaySections.isEmpty)
    }

    // MARK: - 알림과 위젯

    @Test func upcomingDaysCarryThePolicy() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(3, today: monday)
        let store = AppStore(container: env.container, deviceID: "phone", clock: { monday })
        store.start()
        let tuesday = monday.adding(days: 1), wednesday = monday.adding(days: 2)
        #expect(store.saveVacation(start: tuesday, end: tuesday))
        #expect(store.saveVacation(start: wednesday, end: wednesday, keptRoutineIDs: [routines[2].id]))
        let days = store.upcomingDays(count: 4)
        #expect(days[0].isVacation == false && days[0].sections.reduce(0) { $0 + $1.total } == 3)
        #expect(days[1].isVacation && !days[1].keepsRoutines && days[1].sections.isEmpty)
        #expect(days[2].isVacation && days[2].keepsRoutines)
        #expect(days[2].sections.flatMap(\.checks).map(\.id) == [routines[2].id])
        #expect(days[3].isVacation == false && days[3].sections.reduce(0) { $0 + $1.total } == 3)
    }

    @Test func notificationsOnlyFireForKeptRoutinesDuringVacation() throws {
        let group = GroupSnapshot(id: UUID(), title: "아침", colorKey: "mint", order: 0)
        let kept = CheckValue(id: UUID(), title: "스트레칭", timeLabel: "07:00", note: "", isDone: false)
        let other = CheckValue(id: UUID(), title: "독서", timeLabel: "08:00", note: "", isDone: false)
        let tuesday = monday.adding(days: 1), wednesday = monday.adding(days: 2)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 6)))
        let days = [
            PlannedDay(day: monday, sections: [CheckSection(group: group, checks: [kept, other])]),
            // 전체 휴식: 목록이 남아 있더라도 알리지 않는다.
            PlannedDay(day: tuesday, sections: [CheckSection(group: group, checks: [kept, other])], isVacation: true),
            // 선택 유지: 목록에는 고른 루틴만 들어온다.
            PlannedDay(day: wednesday, sections: [CheckSection(group: group, checks: [kept])], isVacation: true, keepsRoutines: true)
        ]
        let planned = RoutineNotificationPlanner.plan(days: days, now: now, calendar: calendar)
        #expect(planned.map(\.dateKey) == [monday.key, monday.key, wednesday.key])
        #expect(planned.last?.routineID == kept.id)
        // 기기에서 알림을 끈 루틴은 휴가 중에도 울리지 않는다.
        let muted = RoutineNotificationPlanner.plan(days: days, now: now, calendar: calendar, muted: [kept.id.uuidString])
        #expect(muted.map(\.routineID) == [other.id])
    }

    @Test func widgetSnapshotShowsKeptRoutinesWithoutAPercent() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(3, today: monday)
        let store = AppStore(container: env.container, deviceID: "phone", clock: { monday })
        store.start()
        let tuesday = monday.adding(days: 1)
        #expect(store.saveVacation(start: monday, end: monday, keptRoutineIDs: [routines[0].id]))
        #expect(store.saveVacation(start: tuesday, end: tuesday))
        store.setDone(routineID: routines[0].id, true)
        let snapshot = WidgetSnapshot.make(days: store.upcomingDays(count: 3), hasRoutines: true)

        let keepDay = try #require(snapshot.day(monday.key))
        #expect(keepDay.isVacation == true && keepDay.keepsRoutines == true)
        #expect(keepDay.items.map(\.routineID) == [routines[0].id])
        #expect(keepDay.percent == nil)
        #expect(keepDay.keptRatio == 1)
        #expect(!keepDay.isVacationRest)

        let restDay = try #require(snapshot.day(tuesday.key))
        #expect(restDay.isVacation == true && restDay.keepsRoutines == nil)
        #expect(restDay.items.isEmpty && restDay.isVacationRest && restDay.keptRatio == nil)

        let normalDay = try #require(snapshot.day(monday.adding(days: 2).key))
        #expect(normalDay.isVacation == false && normalDay.keepsRoutines == nil && normalDay.total == 3)
        #expect(!normalDay.isVacationRest)
        // 이전에 적어 둔 파일(새 칸 없음)도 읽힌다.
        let legacy = Data(#"{"dateKey":"2026-10-05","groups":[],"isVacation":true}"#.utf8)
        #expect(try JSONDecoder().decode(WidgetDay.self, from: legacy).isVacationRest)
    }

    // MARK: - 주요 지표 카드

    @Test func compactMetricsUseTwoColumnsUnlessTooNarrowForTheTextSize() {
        // iPhone 17 Pro(쓸 수 있는 너비 370)와 작은 iPhone(343): 기본 글자 크기에서는 두 열.
        #expect(StatCardsGrid.compactColumns(availableWidth: 370, minTileWidth: 150) == 2)
        #expect(StatCardsGrid.compactColumns(availableWidth: 343, minTileWidth: 150) == 2)
        // 큰 글씨로 칸에 필요한 너비가 커지면 한 열.
        #expect(StatCardsGrid.compactColumns(availableWidth: 370, minTileWidth: 203) == 1)
        #expect(StatCardsGrid.compactColumns(availableWidth: 300, minTileWidth: 150) == 1)
        // 너비를 재기 전에는 두 열로 시작한다.
        #expect(StatCardsGrid.compactColumns(availableWidth: 0, minTileWidth: 150) == 2)
    }

    // MARK: - 문구

    @Test func labelsDescribeTheMode() {
        #expect(VacationRoutinePolicy.modeLabel(VacationPeriod(start: monday, end: monday)) == "전체 휴식")
        #expect(VacationRoutinePolicy.modeLabel(VacationPeriod(start: monday, end: monday, keptRoutineIDs: [UUID(), UUID()])) == "루틴 2개 유지")
        #expect(AchievementCard.vacationDetail(done: 1, total: 2).contains("유지 루틴 2개 중 1개"))
        #expect(!AchievementCard.vacationDetail(done: 0, total: 0).contains("유지"))
        #expect(VacationRoutinePicker.summary(selected: 0).contains("하나 이상"))
    }
}
