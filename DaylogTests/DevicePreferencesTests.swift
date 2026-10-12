import Foundation
import SwiftData
import Testing
@testable import Daylog

@MainActor
struct DevicePreferencesTests {
    @Test func defaultsAndPersistenceAreDeviceLocal() {
        let local = testDefaults()
        let remote = testDefaults()
        let preferences = DevicePreferences(defaults: local)
        #expect(preferences.mealsEnabled)
        #expect(!preferences.onboardingCompleted)
        preferences.setMealsEnabled(false)
        preferences.completeOnboarding()
        let reopened = DevicePreferences(defaults: local)
        #expect(!reopened.mealsEnabled)
        #expect(reopened.onboardingCompleted)
        #expect(DevicePreferences(defaults: remote).mealsEnabled)
        #expect(!DevicePreferences(defaults: remote).onboardingCompleted)
    }

    @Test func malformedLayoutRepairsMissingDuplicateAndMandatoryCards() {
        let defaults = testDefaults()
        defaults.set(DevicePreferences.layoutVersion, forKey: DevicePreferences.layoutVersionKey)
        defaults.set(["meals", "routines", "unknown", "routines"], forKey: DevicePreferences.orderKey)
        defaults.set(["routines", "trend", "unknown"], forKey: DevicePreferences.hiddenKey)
        defaults.set("invalid", forKey: DevicePreferences.mealsKey)
        let preferences = DevicePreferences(defaults: defaults)
        #expect(preferences.cardOrder.prefix(2) == [.meals, .routines])
        #expect(preferences.cardOrder.count == DashboardCard.allCases.count)
        #expect(Set(preferences.cardOrder).count == preferences.cardOrder.count)
        #expect(preferences.visibleCards.contains(.routines))
        #expect(!preferences.visibleCards.contains(.trend))
        #expect(preferences.mealsEnabled)
        preferences.setVisible(false, card: .routines)
        #expect(preferences.visibleCards.contains(.routines))
    }

    @Test func orderAndVisibilityPersistAndRestoreKeepsMealPreference() {
        let defaults = testDefaults()
        let preferences = DevicePreferences(defaults: defaults)
        preferences.move(.meals, by: -1)
        preferences.setVisible(false, card: .recentDays)
        preferences.setColumn(.right, for: .vacation)
        let reopened = DevicePreferences(defaults: defaults)
        #expect(reopened.cardOrder == preferences.cardOrder)
        // 처음부터 숨겨 둔 카드에 방금 숨긴 카드가 더해진다.
        #expect(reopened.hiddenCards == DashboardCard.defaultHidden.union([.recentDays]))
        #expect(reopened.leftCards == [.nextRoutine, .routines])
        preferences.setMealsEnabled(false)
        preferences.restoreDashboard()
        #expect(preferences.cardOrder == DashboardCard.defaultOrder)
        #expect(preferences.hiddenCards == DashboardCard.defaultHidden)
        #expect(preferences.leftCards == DashboardCard.defaultLeft)
        #expect(!preferences.mealsEnabled)
        #expect(!preferences.visibleCards.contains(.meals))
    }

    /// 예전 한 열 배치(형식 번호 없음)는 새 기본 배치로 바뀐다. 식사 표시·안내 완료 같은 다른 설정은 그대로다.
    @Test func legacyLayoutIsReplacedByTheTwoColumnDefault() {
        let defaults = testDefaults()
        defaults.set(["trend", "routines", "meals"], forKey: DevicePreferences.orderKey)
        defaults.set(["calendar"], forKey: DevicePreferences.hiddenKey)
        defaults.set(false, forKey: DevicePreferences.mealsKey)
        let preferences = DevicePreferences(defaults: defaults)
        #expect(preferences.cardOrder == DashboardCard.defaultOrder)
        #expect(preferences.hiddenCards == DashboardCard.defaultHidden)
        #expect(!preferences.mealsEnabled)
        #expect(defaults.integer(forKey: DevicePreferences.layoutVersionKey) == DevicePreferences.layoutVersion)
        // 한 번 바뀐 뒤에는 저장된 배치를 그대로 읽는다.
        preferences.place(.tomorrow, atEndOf: .left)
        #expect(DevicePreferences(defaults: defaults).leftCards.contains(.tomorrow))
    }

    /// 시안의 기본 배치: 왼쪽은 휴가·루틴, 오른쪽은 식사·달성 현황·7일·내일 할 일. 지표 띠와 통계 카드는 숨긴다.
    @Test func defaultLayoutFollowsTheDesign() {
        let preferences = DevicePreferences(defaults: testDefaults())
        let layout = preferences.layout(of: preferences.visibleCards)
        #expect(layout.band.isEmpty)
        #expect(layout.left == [.nextRoutine, .vacation, .routines])
        #expect(layout.right == [.meals, .achievement, .recentDays, .tomorrow])
        preferences.setVisible(true, card: .summary)
        #expect(preferences.layout(of: preferences.visibleCards).band == [.summary])
    }

    /// iPhone은 진행률이 맨 위에 오는 순서로 시작하고, 기본 배치 복원도 그 순서로 돌아간다.
    @Test func phoneStartsWithProgressOnTop() {
        let preferences = DevicePreferences(defaults: testDefaults(), isPhone: true)
        #expect(preferences.visibleCards == [.achievement, .vacation, .routines, .meals, .nextRoutine, .recentDays, .tomorrow])
        preferences.move(.achievement, by: 1)
        preferences.restoreDashboard()
        #expect(preferences.visibleCards.first == .achievement)
        #expect(Set(preferences.cardOrder) == Set(DashboardCard.allCases))
    }

    /// 끌어 놓기: 다른 카드 앞에 놓으면 그 열로 옮겨지고, 한 열 순서도 같이 바뀐다.
    @Test func droppingBeforeACardMovesItIntoThatColumn() {
        let preferences = DevicePreferences(defaults: testDefaults())
        preferences.place(.tomorrow, before: .routines)
        var layout = preferences.layout(of: preferences.visibleCards)
        #expect(layout.left == [.nextRoutine, .vacation, .tomorrow, .routines])
        #expect(layout.right == [.meals, .achievement, .recentDays])
        #expect(preferences.visibleCards.firstIndex(of: .tomorrow)! < preferences.visibleCards.firstIndex(of: .routines)!)

        preferences.place(.vacation, atEndOf: .right)
        layout = preferences.layout(of: preferences.visibleCards)
        #expect(layout.left == [.nextRoutine, .tomorrow, .routines])
        #expect(layout.right == [.meals, .achievement, .recentDays, .vacation])
        #expect(preferences.visibleCards.last == .vacation)

        // 자기 자신 앞이나 띠 카드 앞에는 놓을 수 없다.
        let before = preferences.cardOrder
        preferences.place(.routines, before: .routines)
        preferences.place(.routines, before: .summary)
        preferences.place(.summary, before: .routines)
        #expect(preferences.cardOrder == before)
    }

    /// 메뉴·키보드로 한 칸씩: 같은 열 안에서만 움직이고 열 끝에서는 멈춘다.
    @Test func stepMovesStayWithinTheColumn() {
        let preferences = DevicePreferences(defaults: testDefaults())
        let right = preferences.layout(of: preferences.visibleCards).right
        preferences.moveDown(.meals, in: right)
        #expect(preferences.layout(of: preferences.visibleCards).right == [.achievement, .meals, .recentDays, .tomorrow])
        preferences.moveUp(.achievement, in: preferences.layout(of: preferences.visibleCards).right)
        #expect(preferences.layout(of: preferences.visibleCards).right == [.achievement, .meals, .recentDays, .tomorrow])
        preferences.moveDown(.tomorrow, in: preferences.layout(of: preferences.visibleCards).right)
        #expect(preferences.layout(of: preferences.visibleCards).right.last == .tomorrow)
        preferences.setColumn(.left, for: .tomorrow)
        #expect(preferences.layout(of: preferences.visibleCards).left.last == .tomorrow)
    }

    @Test func mealSuppressionDoesNotErasePersonalCardChoice() {
        let preferences = DevicePreferences(defaults: testDefaults())
        preferences.setVisible(false, card: .meals)
        preferences.setMealsEnabled(false)
        preferences.setMealsEnabled(true)
        #expect(!preferences.visibleCards.contains(.meals))
        preferences.setVisible(true, card: .meals)
        preferences.setMealsEnabled(false)
        #expect(!preferences.visibleCards.contains(.meals))
        preferences.setMealsEnabled(true)
        #expect(preferences.visibleCards.contains(.meals))
    }

    /// 한 열(좁은 창·iPhone)은 전체 순서 그대로, 두 열은 그 순서를 열별로 나눈 것이라 어느 쪽에서도 순서가 바뀌지 않는다.
    @Test func narrowAndWideLayoutsPreserveSameOrder() {
        let preferences = DevicePreferences(defaults: testDefaults())
        preferences.setVisible(true, card: .trend)
        preferences.setColumn(.left, for: .trend)
        let cards = preferences.visibleCards
        let layout = preferences.layout(of: cards)
        #expect(layout.band + layout.left + layout.right == cards.filter(\.spansFullWidth) + cards.filter { !$0.spansFullWidth && preferences.leftCards.contains($0) } + cards.filter { !$0.spansFullWidth && !preferences.leftCards.contains($0) })
        for column in [layout.left, layout.right] {
            #expect(column == cards.filter(column.contains))
        }
    }

    @Test func disablingMealsSavesDraftAndSafelyLeavesMealMenu() throws {
        let env = try CompanionEnv()
        env.store.section = .meals
        env.store.setText("김밥과 우유", at: \.breakfast)
        let preferences = DevicePreferences(defaults: testDefaults())
        let recordID = env.store.record?.syncID
        #expect(env.store.setMealsEnabled(false, preferences: preferences))
        #expect(env.store.section == .dashboard)
        #expect(!preferences.navigationSections(phone: false).contains(.meals))
        #expect(!preferences.navigationSections(phone: true).contains(.meals))
        #expect(preferences.safeSelection(.meals) == .dashboard)
        let saved = try #require(try DayRecordService(context: env.env.freshContext()).record(on: monday))
        #expect(saved.breakfast == "김밥과 우유")
        #expect(saved.syncID == recordID)
        #expect(env.store.setMealsEnabled(true, preferences: preferences))
        #expect(preferences.navigationSections(phone: true).contains(.meals))
        #expect(env.store.text(\.breakfast) == "김밥과 우유")
        #expect(try env.env.records.physicalRecords(on: monday).count == 1)
    }
}

@MainActor
struct OnboardingTests {
    @Test func threeStepsAndSkipOnlyChangeLocalCompletion() throws {
        let env = try CompanionEnv()
        let routine = env.addRoutine("기존 운동")
        env.store.setDone(routineID: routine.id, true)
        env.store.setText("보존할 식사", at: \.lunch)
        env.store.flush()
        let before = env.store.stats
        let preferences = DevicePreferences(defaults: testDefaults())
        #expect(OnboardingStep.introduction.next == .createRoutine)
        #expect(OnboardingStep.createRoutine.next == .ready)
        #expect(OnboardingStep.ready.next == .ready)
        // Opening a preferences model and finishing/skipping never creates a routine or resets records.
        preferences.completeOnboarding()
        #expect(env.store.routines.map(\.id) == [routine.id])
        #expect(env.store.stats == before)
        #expect(env.store.text(\.lunch) == "보존할 식사")
        #expect(env.store.checkSections.flatMap(\.checks).first?.isDone == true)
    }

    @Test func emptyInputDoesNotCreateGroupOrRoutine() throws {
        let env = try CompanionEnv()
        #expect(!env.store.createOnboardingRoutine(OnboardingRoutineDraft(groupTitle: "아침", routineTitle: "  ")))
        #expect(!env.store.createOnboardingRoutine(OnboardingRoutineDraft(groupTitle: "  ", routineTitle: "물")))
        #expect(!env.store.createOnboardingRoutine(OnboardingRoutineDraft(groupTitle: "아침", routineTitle: String(repeating: "물", count: 61))))
        #expect(env.store.routines.isEmpty)
        #expect(env.store.groups.isEmpty)
    }

    @Test func explicitCreationReusesLateArrivingDataWithoutOverwrite() throws {
        let env = try CompanionEnv()
        let draft = OnboardingRoutineDraft(groupTitle: "아침", routineTitle: "물 마시기")
        // Represent data reaching the local context while the person is on the onboarding screen.
        let group = try env.env.routines.addGroup(title: "아침")
        let original = try env.env.routines.add(title: "물 마시기", note: "다른 기기의 메모", timeLabel: "08:00", group: group, today: monday)
        #expect(env.store.createOnboardingRoutine(draft))
        #expect(try env.env.routines.groups().count == 1)
        #expect(try env.env.routines.routines().count == 1)
        #expect(original.note == "다른 기기의 메모")
        #expect(original.timeLabel == "08:00")
        #expect(env.store.createOnboardingRoutine(OnboardingRoutineDraft(groupID: group.id, routineTitle: "스트레칭")))
        #expect(try env.env.routines.routines().map(\.title) == ["물 마시기", "스트레칭"])
    }

    @Test func archivedNameCollisionDoesNotPretendToCreateAnActiveRoutine() throws {
        let env = try CompanionEnv()
        let existing = env.addRoutine("물 마시기", group: "아침")
        env.store.setArchived(existing, true)
        #expect(!env.store.createOnboardingRoutine(OnboardingRoutineDraft(groupTitle: "아침", routineTitle: "물 마시기")))
        #expect(env.store.errorMessage?.contains("보관") == true)
        #expect(env.store.activeRoutines.isEmpty)
        #expect(try env.env.routines.routines().count == 1)
        #expect(existing.isArchived)
        #expect(env.store.createOnboardingRoutine(OnboardingRoutineDraft(groupTitle: "아침", routineTitle: "스트레칭")))
        #expect(env.store.activeRoutines.map(\.title) == ["스트레칭"])
    }

    @Test func ambiguousNewGroupNameRequiresSelection() throws {
        let env = try CompanionEnv()
        try env.env.routines.addGroup(title: "아침")
        try env.env.routines.addGroup(title: "아침")
        #expect(!env.store.createOnboardingRoutine(OnboardingRoutineDraft(groupTitle: "아침", routineTitle: "물")))
        #expect(try env.env.routines.routines().isEmpty)
        #expect(try env.env.routines.groups().count == 2)
    }
}
