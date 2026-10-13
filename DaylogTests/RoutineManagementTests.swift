import Foundation
import SwiftData
import Testing
@testable import Daylog

/// v1.3.1: 루틴 관리 화면의 동작(빠른 추가, 삭제 확인 문구, 순서 변경, 보관과 삭제의 차이)
@MainActor
struct RoutineManagementTests {
    private func makeStore(_ env: TestEnv, today: Day) -> AppStore {
        let clock = TestClock(today)
        let store = AppStore(container: env.container, clock: { clock.today })
        store.start()
        return store
    }

    /// ⌘N: 루틴 관리 화면에서는 그 화면에 머물고, 다른 화면에서는 오늘의 대시보드로 간다.
    @Test func quickAddStaysOnRoutineManagement() throws {
        let env = try TestEnv()
        let store = makeStore(env, today: monday)
        let token = store.quickAddFocusToken

        store.section = .routines
        store.requestQuickAddFocus()
        #expect(store.section == .routines)
        #expect(store.quickAddFocusToken == token + 1)

        store.section = .statistics
        store.requestQuickAddFocus()
        #expect(store.section == .dashboard)
        #expect(store.isViewingToday)
        #expect(store.quickAddFocusToken == token + 2)
    }

    /// iPad에서 창을 두 개 열면 두 창이 같은 화면 선택을 따른다. 어느 창에든 편집 시트가 떠 있는 동안에는
    /// 어떤 경로로도 화면 선택이 바뀌지 않는다(그 창의 시트가 닫히며 저장하지 않은 내용이 사라지지 않게).
    @Test func sectionStaysWhileAWindowAmongSeveralShowsASheet() throws {
        let env = try TestEnv()
        let store = makeStore(env, today: monday)
        store.addGroup(title: "아침")
        let group = try #require(store.activeGroups.first { $0.title == "아침" })
        #expect(store.addRoutine(title: "물", in: group))
        #expect(store.saveVacation(start: monday, end: monday, memo: "", keptRoutineIDs: []))
        store.section = .vacation
        var sheetWindows = 1
        store.sheetWindowsAmongSeveral = { sheetWindows }

        store.section = .statistics
        store.go(to: .settings, isShowingSheet: false)
        store.open(store.today)
        store.requestQuickAddFocus()
        #expect(store.section == .vacation)
        #expect(store.pendingQuickAddGroupID == nil && !store.pendingDashboardQuickAdd)
        // 보는 날짜도 그대로다(날짜가 바뀌면 그날의 휴가 카드가 사라져 거기서 띄운 시트가 닫힌다).
        let yesterday = monday.adding(days: -1)
        store.select(yesterday)
        store.goToPreviousDay()
        store.open(yesterday)
        #expect(store.selectedDay == monday && store.section == .vacation)

        // 시트 안의 단추가 자기 시트를 닫으며 옮기는 것은 된다. 다른 창에도 시트가 있으면 안 된다.
        sheetWindows = 2
        store.leaveSheet(to: .routines)
        #expect(store.section == .vacation)
        sheetWindows = 1
        store.leaveSheet(to: .routines)
        #expect(store.section == .routines)

        // 시트가 모두 닫히면 전처럼 움직인다.
        sheetWindows = 0
        store.section = .statistics
        #expect(store.section == .statistics)
        store.requestQuickAddFocus()
        #expect(store.section == .routines && store.pendingQuickAddGroupID == group.id)
    }

    /// 편집 시트가 떠 있을 때는 메뉴 명령(⌘N, ⌘1…)이 화면을 바꾸지 않는다(시트가 닫히며 적던 내용이 사라지지 않게).
    @Test func menuCommandsDoNotSwitchScreensUnderASheet() throws {
        let env = try TestEnv()
        let store = makeStore(env, today: monday)
        store.addGroup(title: "아침")
        let group = try #require(store.activeGroups.first { $0.title == "아침" })
        #expect(store.addRoutine(title: "물", in: group))
        #expect(store.saveVacation(start: monday, end: monday, memo: "", keptRoutineIDs: []))
        store.section = .dashboard
        let token = store.quickAddFocusToken

        store.requestQuickAddFocus(isShowingSheet: true)
        store.go(to: .statistics, isShowingSheet: true)
        #expect(store.section == .dashboard)
        #expect(store.quickAddFocusToken == token)
        #expect(store.pendingQuickAddGroupID == nil)

        store.go(to: .statistics, isShowingSheet: false)
        #expect(store.section == .statistics)
        // 시트가 없으면 휴가인 날의 빠른 추가는 루틴 관리로 간다.
        store.requestQuickAddFocus(isShowingSheet: false)
        #expect(store.section == .routines)
        #expect(store.pendingQuickAddGroupID == group.id)
    }

    /// 오늘 화면에 그 그룹의 입력칸이 없으면(오늘 해당하는 항목이 없는 그룹, 휴가인 날, 루틴 카드를 숨긴 경우)
    /// 빠른 추가가 아무 일도 하지 않던 문제: 루틴 관리 화면의 그 그룹으로 보낸다.
    @Test func quickAddGoesToRoutineManagementWhenTheDashboardHasNoField() throws {
        let env = try TestEnv()
        let store = makeStore(env, today: monday)
        store.addGroup(title: "주말 정리")
        let weekend = try #require(store.activeGroups.first { $0.title == "주말 정리" })
        #expect(store.addRoutine(title: "방 청소", in: weekend))
        let routine = try #require(store.activeRoutines.first { $0.title == "방 청소" })
        store.updateRoutine(routine, weekdays: Weekdays.weekend)
        #expect(store.quickAddGroup?.id == weekend.id, "방금 쓴 그룹이 빠른 추가의 대상이다.")
        #expect(!store.dashboardCanAdd(to: weekend), "월요일에는 이 그룹이 오늘 화면에 나오지 않는다.")

        // 오늘 해당하는 항목이 없는 그룹: 루틴 관리 화면으로 가고, 그 그룹의 입력칸을 열라고 넘긴다.
        store.section = .statistics
        store.requestQuickAddFocus()
        #expect(store.section == .routines)
        #expect(store.pendingQuickAddGroupID == weekend.id)

        // 오늘 해당하는 항목이 있는 그룹은 전처럼 오늘 화면에서 받는다.
        store.pendingQuickAddGroupID = nil
        store.addGroup(title: "매일")
        let daily = try #require(store.activeGroups.first { $0.title == "매일" })
        #expect(store.addRoutine(title: "매일 하는 일", in: daily))
        #expect(store.dashboardCanAdd(to: daily))
        store.section = .statistics
        store.requestQuickAddFocus()
        #expect(store.section == .dashboard && store.pendingQuickAddGroupID == nil)

        // 다른 화면에서 오늘 화면으로 왔으면, 새로 뜨는 루틴 카드가 입력칸을 열도록 요청을 남긴다.
        #expect(store.pendingDashboardQuickAdd)
        // 오늘 화면에 있을 때는 남기지 않는다(카드가 이미 떠 있어 바로 받는다). 오늘 화면을 떠나면 버린다.
        store.requestQuickAddFocus()
        #expect(!store.pendingDashboardQuickAdd)
        store.section = .statistics
        store.requestQuickAddFocus()
        store.section = .calendar
        #expect(!store.pendingDashboardQuickAdd)

        // 루틴 카드를 숨겨 둔 기기: 오늘 화면에 입력칸이 없으니 루틴 관리 화면으로.
        store.section = .statistics
        store.requestQuickAddFocus(dashboardShowsRoutines: false)
        #expect(store.section == .routines && store.pendingQuickAddGroupID == daily.id)

        // 휴가인 날: 오늘 화면은 항목 추가를 열지 않는다.
        store.pendingQuickAddGroupID = nil
        #expect(store.saveVacation(start: monday, end: monday, memo: "", keptRoutineIDs: []))
        #expect(!store.dashboardCanAdd(to: daily))
        store.section = .dashboard
        store.requestQuickAddFocus()
        #expect(store.section == .routines && store.pendingQuickAddGroupID == daily.id)
    }

    /// 빠른 추가는 마지막으로 쓴 그룹으로 간다. 그 그룹을 삭제하면 남은 첫 그룹으로 돌아간다.
    @Test func quickAddTargetsTheLastUsedGroup() throws {
        let env = try TestEnv()
        let store = makeStore(env, today: monday)
        #expect(store.quickAddGroup == nil)

        let morning = try #require(store.addGroup(title: "아침"))
        let evening = try #require(store.addGroup(title: "저녁"))
        #expect(store.quickAddGroup?.id == evening.id)

        store.addRoutine(title: "물", in: morning)
        #expect(store.quickAddGroup?.id == morning.id)

        store.deleteGroup(morning)
        #expect(store.quickAddGroup?.id == evening.id)
    }

    /// 삭제 확인 문구는 함께 삭제되는 항목 수와, 지난 기록이 남는다는 점을 알린다.
    @Test func deletionMessages() {
        #expect(RoutineDeletion.groupMessage(itemCount: 3).contains("루틴 3개도 함께 삭제"))
        #expect(RoutineDeletion.groupMessage(itemCount: 3).contains("지난 기록과 통계는 유지"))
        #expect(!RoutineDeletion.groupMessage(itemCount: 0).contains("함께 삭제"))
        #expect(RoutineDeletion.groupMessage(itemCount: 0).contains("지난 기록과 통계는 유지"))
        #expect(RoutineDeletion.itemMessage.contains("되돌릴 수 없"))
        #expect(RoutineDeletion.itemMessage.contains("지난 기록과 통계는 유지"))
    }

    /// 보관은 복원할 수 있고 보관함에 보인다. 삭제는 목록과 보관함 어디에도 보이지 않는다.
    @Test func archiveIsReversibleButDeleteIsNot() throws {
        let env = try TestEnv()
        let store = makeStore(env, today: monday)
        let group = try #require(store.addGroup(title: "아침"))
        store.addRoutine(title: "물", in: group)
        store.addRoutine(title: "스트레칭", in: group)
        let water = try #require(store.routines.first { $0.title == "물" })
        let stretch = try #require(store.routines.first { $0.title == "스트레칭" })

        store.setArchived(water, true)
        #expect(store.archivedRoutines(inGroup: group.id).map(\.title) == ["물"])
        store.setArchived(water, false)
        #expect(store.activeRoutines(inGroup: group.id).map(\.title).sorted() == ["물", "스트레칭"])

        store.deleteRoutine(stretch)
        #expect(store.activeRoutines(inGroup: group.id).map(\.title) == ["물"])
        #expect(store.archivedRoutines(inGroup: group.id).isEmpty)
        // 레코드는 지우지 않고 삭제 시각만 남긴다.
        #expect(try env.context.fetchCount(FetchDescriptor<RoutineItem>()) == 2)
    }

    /// 메뉴의 위/아래 이동과 "다른 그룹으로 이동".
    @Test func menuMovesReorderAndRegroup() throws {
        let env = try TestEnv()
        let store = makeStore(env, today: monday)
        let morning = try #require(store.addGroup(title: "아침"))
        let evening = try #require(store.addGroup(title: "저녁"))
        for title in ["가", "나", "다"] { store.addRoutine(title: title, in: morning) }
        let last = try #require(store.routines.first { $0.title == "다" })

        store.moveActiveRoutine(last, by: -1)
        #expect(store.activeRoutines(inGroup: morning.id).map(\.title) == ["가", "다", "나"])
        store.moveActiveRoutine(last, by: -5)
        #expect(store.activeRoutines(inGroup: morning.id).map(\.title) == ["가", "다", "나"])

        store.moveRoutine(last, to: evening)
        #expect(store.activeRoutines(inGroup: morning.id).map(\.title) == ["가", "나"])
        #expect(store.activeRoutines(inGroup: evening.id).map(\.title) == ["다"])

        store.moveGroup(evening, by: -1)
        #expect(store.activeGroups.map(\.title) == ["저녁", "아침"])
    }

    /// 추천 항목은 한 번만 추가된다. 추가한 항목은 추천 목록에서 빠진다.
    @Test func suggestionIsAddedOnlyOnce() throws {
        let env = try TestEnv()
        let store = makeStore(env, today: monday)
        let group = try #require(store.addGroup(title: "아침"))
        let suggestion = try #require(store.suggestions.first)

        #expect(store.addSuggestion(suggestion, in: group))
        #expect(!store.addSuggestion(suggestion, in: group))
        #expect(store.routines.filter { $0.title == suggestion }.count == 1)
        #expect(!store.suggestions.contains(suggestion))
        #expect(store.checkSections.flatMap(\.checks).map(\.title) == [suggestion])
        // 목록에 없는 이름은 추천 경로로 추가되지 않는다.
        #expect(!store.addSuggestion("추천에 없는 이름", in: group))
    }

    /// 기간 선택 버튼의 이름과, 식사 종류별 표시가 서로 겹치지 않는다.
    @Test func periodTitlesAndMealKinds() {
        #expect(StatsPeriod.allCases.map(\.title) == ["7일", "30일", "90일", "전체"])
        #expect(MealPeriod.allCases.map(\.shortTitle) == ["7일", "30일", "전체"])
        #expect(MealKind.allCases.map(\.title) == ["아침", "점심", "저녁", "간식"])
        #expect(Set(MealKind.allCases.map(\.symbol)).count == 4)
        #expect(MealKind.allCases.map(\.field) == [.breakfast, .lunch, .dinner, .snack])
    }
}
