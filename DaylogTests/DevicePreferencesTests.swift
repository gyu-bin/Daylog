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
        preferences.setVisible(false, card: .trend)
        let reopened = DevicePreferences(defaults: defaults)
        #expect(reopened.cardOrder == preferences.cardOrder)
        #expect(reopened.hiddenCards == [.trend])
        preferences.setMealsEnabled(false)
        preferences.restoreDashboard()
        #expect(preferences.cardOrder == DashboardCard.allCases)
        #expect(preferences.hiddenCards.isEmpty)
        #expect(!preferences.mealsEnabled)
        #expect(!preferences.visibleCards.contains(.meals))
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

    @Test func narrowAndWideLayoutsPreserveSameOrder() {
        let cards: [DashboardCard] = [.meals, .routines, .summary, .trend, .calendar, .nextRoutine, .routineRates]
        #expect(DashboardCard.rows(cards, wide: false).flatMap { $0 } == cards)
        #expect(DashboardCard.rows(cards, wide: true).flatMap { $0 } == cards)
        #expect(DashboardCard.rows(cards, wide: true).contains([.summary]))
        #expect(DashboardCard.rows(cards, wide: true).contains([.nextRoutine]))
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
