import Foundation
import SwiftData
import Testing
@testable import Daylog

/// v1.3: 루틴 그룹 (명세 18절 TEST 1~9, 11, 19, 21, 22)
@MainActor
struct RoutineGroupTests {
    private let tuesday = monday.adding(days: 1)

    private func check(_ record: DayRecord, _ title: String) throws -> DayCheck {
        try #require(record.physicalChecks.first { $0.title == title })
    }

    /// TEST 1
    @Test func itemBelongsToItsGroup() throws {
        let env = try TestEnv()
        let morning = try env.routines.addGroup(title: "아침 루틴", colorKey: "orange")
        let today = try env.records.fetchOrCreate(day: monday, today: monday)
        let item = try env.routines.add(title: "물 한 잔", group: morning, today: monday)

        #expect(item.groupID == morning.id)
        #expect(try env.routines.routines().map(\.title) == ["물 한 잔"])
        #expect(today.checkList.first?.group == GroupSnapshot(id: morning.id, title: "아침 루틴", colorKey: "orange", order: 0))
        // 그룹만 만들고 항목이 없어도 그룹은 남는다. "기본 루틴"은 필요할 때만 생긴다.
        try env.routines.addGroup(title: "빈 그룹")
        #expect(try env.routines.groups().map(\.title) == ["아침 루틴", "빈 그룹"])
        #expect(try env.routines.groups().contains { $0.id == RoutineGroup.defaultID } == false)
    }

    /// TEST 2·3
    @Test func renamingAndRecoloringKeepPastSnapshots() throws {
        let env = try TestEnv()
        let group = try env.routines.addGroup(title: "아침 루틴", colorKey: "orange")
        try env.routines.add(title: "스트레칭", group: group, today: monday)
        let past = try env.log(monday, done: 1)
        let today = try env.records.fetchOrCreate(day: tuesday.adding(days: 1), today: tuesday.adding(days: 1))

        try env.routines.updateGroup(group, title: "모닝 루틴", colorKey: "blue", today: tuesday.adding(days: 1))

        #expect(group.title == "모닝 루틴")
        #expect(today.checkList.first?.group.title == "모닝 루틴")
        #expect(today.checkList.first?.group.colorKey == "blue")
        #expect(past.checkList.first?.group.title == "아침 루틴")
        #expect(past.checkList.first?.group.colorKey == "orange")
        #expect(past.checkList.first?.isDone == true)

        // 기록이 없던 화요일을 나중에 열어도 당시(이름을 바꾸기 전)의 그룹 모습으로 만들어진다.
        let unrecorded = try env.records.fetchOrCreate(day: tuesday, today: tuesday.adding(days: 3))
        #expect(unrecorded.checkList.first?.group.title == "아침 루틴")
        #expect(unrecorded.checkList.first?.group.colorKey == "orange")
    }

    /// TEST 4
    @Test func movingAnItemChangesOnlyTodayAndLater() throws {
        let env = try TestEnv()
        let morning = try env.routines.addGroup(title: "아침 루틴")
        let workout = try env.routines.addGroup(title: "운동 루틴")
        let item = try env.routines.add(title: "운동", group: morning, today: monday)
        let past = try env.log(monday, done: 1)
        let wednesday = monday.adding(days: 2)
        let today = try env.records.fetchOrCreate(day: wednesday, today: wednesday)

        try env.routines.move(item, to: workout, today: wednesday)

        #expect(item.id == past.checkList.first?.routineID) // UUID 유지
        #expect(item.groupID == workout.id)
        #expect(today.checkList.first?.group.title == "운동 루틴")
        #expect(past.checkList.first?.group.title == "아침 루틴")
        #expect(try env.records.fetchOrCreate(day: tuesday, today: wednesday).checkList.first?.group.title == "아침 루틴")
        let thursday = try env.records.fetchOrCreate(day: wednesday.adding(days: 1), today: wednesday.adding(days: 1))
        #expect(thursday.checkList.first?.group.title == "운동 루틴")
    }

    /// TEST 5·6
    @Test func archivingAndRestoringAGroup() throws {
        let env = try TestEnv()
        let group = try env.routines.addGroup(title: "저녁 루틴")
        let other = try env.routines.addGroup(title: "아침 루틴")
        let diary = try env.routines.add(title: "일기", group: group, today: monday)
        try env.routines.add(title: "내일 준비", group: group, today: monday)
        try env.routines.add(title: "물", group: other, today: monday)
        let past = try env.log(monday, done: 3)
        let today = try env.records.fetchOrCreate(day: tuesday, today: tuesday)
        try env.records.setDone(try check(today, "일기"), true)

        try env.routines.setGroupArchived(group, true, today: tuesday)

        // 오늘: 완료한 항목은 남고, 미완료 항목은 숨는다. 항목 자체는 보관되지 않는다.
        #expect(today.checkList.map(\.title).sorted() == ["물", "일기"])
        #expect(diary.isArchived == false)
        #expect(past.checkList.count == 3)
        #expect(try env.records.fetchOrCreate(day: tuesday.adding(days: 1), today: tuesday.adding(days: 1)).checkList.map(\.title) == ["물"])

        try env.routines.setGroupArchived(group, false, today: tuesday)
        try env.routines.setGroupArchived(group, false, today: tuesday)

        #expect(today.checkList.count == 3)
        #expect(today.physicalChecks.count == 3) // 중복 없음
        #expect(try check(today, "일기").isDone)
        #expect(try env.routines.routines().count == 3)
    }

    /// TEST 7
    @Test func groupProgressAndOverallRate() throws {
        let env = try TestEnv()
        let store = AppStore(container: env.container, clock: { saturday })
        store.start()
        let morning = try #require(store.addGroup(title: "아침", colorKey: "orange"))
        let work = try #require(store.addGroup(title: "작업", colorKey: "blue"))
        let evening = try #require(store.addGroup(title: "저녁", colorKey: "purple"))
        for title in ["물", "스트레칭", "필사"] { store.addRoutine(title: title, in: morning) }
        for title in ["오전 작업", "오후 작업"] { store.addRoutine(title: title, in: work) }
        for title in ["일기", "내일 준비"] { store.addRoutine(title: title, in: evening) }
        for title in ["물", "스트레칭", "오전 작업", "일기", "내일 준비"] {
            store.setDone(routineID: try #require(store.checks.first { $0.title == title }?.routineID), true)
        }

        let sections = store.checkSections
        #expect(sections.map(\.group.title) == ["아침", "작업", "저녁"])
        #expect(sections.map { "\($0.done)/\($0.total)" } == ["2/3", "1/2", "2/2"])
        #expect(sections.map(\.percent) == [67, 50, 100])
        // 전체는 그룹 평균(72%)이 아니라 항목 수 기준이다.
        #expect(store.stats.today == DayOutcome(day: saturday, status: .recorded, done: 5, total: 7))
        #expect(store.stats.today.percent == 71)
        #expect(store.stats.groupRates.map(\.percent) == [67, 50, 100])
        #expect(store.stats.groupRates.map(\.colorKey) == ["orange", "blue", "purple"])
    }

    /// TEST 8
    @Test func renamedGroupIsOneEntryInStats() throws {
        let env = try TestEnv()
        let group = try env.routines.addGroup(title: "아침 루틴")
        try env.routines.add(title: "물", group: group, today: monday)
        try env.log(monday, done: 1)
        try env.routines.updateGroup(group, title: "모닝 루틴", today: tuesday)
        try env.log(tuesday, done: 0)

        let rates = try env.stats.dashboard(today: tuesday).groupRates
        #expect(rates.count == 1)
        #expect(rates.first?.title == "모닝 루틴")
        #expect(rates.first?.done == 1)
        #expect(rates.first?.scheduled == 2)
    }

    /// TEST 9
    @Test func movedItemCountsUnderTheGroupOfEachDay() throws {
        let env = try TestEnv()
        let morning = try env.routines.addGroup(title: "아침 루틴")
        let workout = try env.routines.addGroup(title: "운동 루틴")
        let item = try env.routines.add(title: "운동", group: morning, today: monday)
        try env.log(monday, done: 1)
        // 화요일은 앱을 열지 않음(미기록): 당시 그룹(아침)의 예정 항목으로 센다.
        let wednesday = monday.adding(days: 2)
        try env.routines.move(item, to: workout, today: wednesday)
        try env.log(wednesday, done: 1)

        let rates = try env.stats.dashboard(today: wednesday).groupRates
        #expect(rates.map(\.title) == ["아침 루틴", "운동 루틴"])
        #expect(rates.map { "\($0.done)/\($0.scheduled)" } == ["1/2", "1/1"])
        // 전체 달성률은 그룹과 무관하게 그대로다.
        #expect(try env.stats.dashboard(today: wednesday).week.suffix(3).map(\.percent) == [100, 0, 100])
    }

    /// TEST 11·22
    @Test func duplicateDefaultGroupFromAnotherDeviceIsOneGroup() throws {
        let env = try TestEnv()
        // v1.2까지의 항목: 그룹 정보가 없다.
        let legacy = RoutineItem(title: "운동", order: 0)
        env.context.insert(legacy)
        env.context.insert(RoutineRevision(routine: legacy, effectiveFrom: monday))
        try env.settings.settings().firstRoutineDate = monday.anchorDate
        try env.context.save()

        _ = try reconcile(env, today: monday)
        #expect(try env.routines.groups().map(\.title) == ["기본 루틴"])
        #expect(try env.routines.groups().first?.id == RoutineGroup.defaultID)

        // 다른 Mac도 같은 이전을 하고 이름까지 바꿨다: 같은 ID의 그룹이 하나 더 들어온다.
        let remote = RoutineGroup(id: RoutineGroup.defaultID, title: "나의 루틴", colorKey: "blue", order: 0, createdAt: later)
        env.context.insert(remote)
        try env.context.save()

        for _ in 0..<3 { _ = try reconcile(env, today: monday) }

        let groups = try env.routines.groups()
        #expect(groups.count == 1)
        #expect(groups.first?.title == "나의 루틴") // 나중에 수정된 쪽
        #expect(try env.context.fetchCount(FetchDescriptor<RoutineGroup>()) == 2) // 지우지 않는다
        #expect(try env.routines.routines().count == 1)
        #expect(try env.context.fetchCount(FetchDescriptor<RoutineItem>()) == 1)
        #expect(legacy.groupID == nil) // 기존 항목은 고쳐 쓰지 않는다
        #expect(try reconcile(env, today: monday).changed == false)
        #expect(try env.stats.dashboard(today: monday).groupRates.map(\.title) == ["나의 루틴"])
    }

    /// TEST 19
    @Test func firstLaunchHasNoGroups() throws {
        let env = try TestEnv()
        let store = AppStore(container: env.container, clock: { saturday })
        store.start()
        store.handleExternalChanges()

        #expect(store.groups.isEmpty)
        #expect(store.routines.isEmpty)
        #expect(store.checkSections.isEmpty)
        #expect(store.stats.groupRates.isEmpty)
        #expect(try env.context.fetchCount(FetchDescriptor<RoutineGroup>()) == 0)
        #expect(store.addGroup(title: "   ") == nil)
        #expect(store.errorMessage == nil)
    }

    /// TEST 21
    @Test func groupsSurviveRelaunch() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DaylogGroups-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Daylog.store")

        do {
            let store = AppStore(container: try DaylogStore.makeContainer(.file(url)), clock: { saturday })
            store.start()
            let morning = try #require(store.addGroup(title: "아침 루틴", colorKey: "orange"))
            let work = try #require(store.addGroup(title: "작업 루틴", colorKey: "blue"))
            store.addRoutine(title: "물", in: morning)
            store.addRoutine(title: "오전 작업", in: work)
            store.setDone(routineID: try #require(store.checks.first?.routineID), true)
            store.setText("그릭요거트", at: \.breakfast)
            store.moveGroup(work, by: -1)
            store.flush()
        }

        let store = AppStore(container: try DaylogStore.makeContainer(.file(url)), clock: { saturday })
        store.start()
        #expect(store.groups.map(\.title) == ["작업 루틴", "아침 루틴"])
        #expect(store.groups.map(\.colorKey) == ["blue", "orange"])
        #expect(store.checkSections.map(\.group.title) == ["작업 루틴", "아침 루틴"])
        #expect(store.checkSections.map { "\($0.done)/\($0.total)" } == ["0/1", "1/1"])
        #expect(store.text(\.breakfast) == "그릭요거트")
    }

    @Test func reorderingGroupsAndMovingItemsAcrossGroups() throws {
        let env = try TestEnv()
        let store = AppStore(container: env.container, clock: { saturday })
        store.start()
        let first = try #require(store.addGroup(title: "가"))
        let second = try #require(store.addGroup(title: "나"))
        ["가1", "가2"].forEach { store.addRoutine(title: $0, in: first) }
        ["나1", "나2"].forEach { store.addRoutine(title: $0, in: second) }
        #expect(store.checks.map(\.title) == ["가1", "가2", "나1", "나2"])

        store.moveGroup(id: second.id, to: first.id)
        #expect(store.activeGroups.map(\.title) == ["나", "가"])
        #expect(store.checks.map(\.title) == ["나1", "나2", "가1", "가2"])

        // 끌어다 놓기: "가2"를 다른 그룹의 "나1" 자리에 놓는다.
        let moving = try #require(store.routines.first { $0.title == "가2" })
        let target = try #require(store.routines.first { $0.title == "나1" })
        store.moveActiveRoutine(id: moving.id, to: target.id)
        #expect(store.activeRoutines(inGroup: second.id).map(\.title) == ["가2", "나1", "나2"])
        #expect(store.activeRoutines(inGroup: first.id).map(\.title) == ["가1"])
        #expect(store.checks.map(\.title) == ["가2", "나1", "나2", "가1"])
        #expect(store.checkSections.map { $0.checks.count } == [3, 1])

        // 위/아래 이동은 그룹 안에서만.
        store.moveActiveRoutine(moving, by: 1)
        #expect(store.activeRoutines(inGroup: second.id).map(\.title) == ["나1", "가2", "나2"])
        store.moveActiveRoutine(try #require(store.routines.first { $0.title == "가1" }), by: 1)
        #expect(store.activeRoutines(inGroup: first.id).map(\.title) == ["가1"])

        store.moveRoutine(moving, to: first)
        #expect(store.activeRoutines(inGroup: first.id).map(\.title) == ["가1", "가2"])
        #expect(try env.context.fetchCount(FetchDescriptor<DayCheck>()) == 4) // 옮겨도 체크가 늘지 않는다
    }

    @Test func invalidGroupInput() throws {
        let env = try TestEnv()
        #expect(throws: DaylogError.emptyTitle) { try env.routines.addGroup(title: "  ") }
        let group = try env.routines.addGroup(title: String(repeating: "가", count: 100))
        #expect(group.title.count == RoutineService.maxGroupTitleLength)
        // 새 그룹은 아직 쓰지 않은 색부터 받는다.
        let colors = try (0..<8).map { try env.routines.addGroup(title: "그룹 \($0)").colorKey }
        #expect(Set(colors.prefix(6)).count == 6)
        #expect(!colors.prefix(6).contains(group.colorKey))
    }
}
