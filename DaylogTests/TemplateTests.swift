import Foundation
import SwiftData
import Testing
@testable import Daylog

/// Phase 5-C: 공식 루틴 템플릿. 목록의 검사, 검색과 분류, 가져오기(중복·겹침·실패), 기존 기록 보존.
@MainActor
struct TemplateTests {
    private let catalog = TemplateCatalog.official

    private func makeStore(_ env: TestEnv, today: Day) -> (AppStore, TestClock) {
        let clock = TestClock(today)
        let store = AppStore(container: env.container, deviceID: thisMac, clock: { clock.today })
        store.start()
        return (store, clock)
    }

    private func template(_ id: String) throws -> RoutineTemplate {
        try #require(catalog.templates.first { $0.id == "official.\(id)" })
    }

    private func sample(
        id: String = "test.sample", title: String = "시험 템플릿", category: TemplateCategory = .lifestyle,
        groups: [RoutineTemplate.Group] = [.init(title: "시험 그룹", routines: [.init(title: "시험 루틴")])]
    ) -> RoutineTemplate {
        RoutineTemplate(
            id: id, title: title, summary: "", category: category, tags: [],
            thumbnail: TemplateThumbnail(symbol: "star.fill", colorKey: "mint"), groups: groups
        )
    }

    // MARK: - 공식 목록

    @Test func everyOfficialTemplateIsValidAndImportable() {
        #expect(OfficialTemplates.all.count >= 10)
        // 검사를 통과하지 못해 목록에서 빠진 것이 없다.
        #expect(catalog.templates.count == OfficialTemplates.all.count)
        #expect(Set(catalog.templates.map(\.id)).count == catalog.templates.count)
        for template in catalog.templates {
            #expect(template.validationError == nil, "\(template.id)")
            #expect(template.source == .official && template.author == nil)
            #expect(template.id.hasPrefix("official."))
            #expect(!template.summary.isEmpty && !template.tags.isEmpty)
            #expect(GroupColor(rawValue: template.thumbnail.colorKey) != nil)
            #expect(!template.thumbnail.symbol.isEmpty && template.thumbnail.imageName == nil)
            // 파일 가져오기와 같은 줄 검사를 그대로 통과한다.
            #expect(template.transferRoutines.allSatisfy { RoutineTransferFormat.validation($0) == nil })
            #expect(template.transferRoutines.count == template.routineCount)
        }
    }

    @Test func everyCategoryHasTemplates() {
        #expect(catalog.categories == TemplateCategory.allCases)
        #expect(TemplateCategory.allCases.map(\.title) == ["아침 루틴", "운동·건강", "독서·공부", "생산성·집중", "생활 습관"])
    }

    /// 템플릿에는 루틴 정의만 있다: 체크·식사·휴가·사진 같은 개인 기록의 칸이 없다.
    @Test func templatesCarryRoutineDefinitionsOnly() throws {
        let json = try #require(try JSONSerialization.jsonObject(with: catalog.encoded()) as? [String: Any])
        let first = try #require((json["templates"] as? [[String: Any]])?.first)
        #expect(Set(first.keys).isSubset(of: ["id", "source", "title", "summary", "category", "tags", "thumbnail", "author", "groups"]))
        let group = try #require((first["groups"] as? [[String: Any]])?.first)
        #expect(Set(group.keys) == ["title", "routines"])
        let routine = try #require((group["routines"] as? [[String: Any]])?.first)
        #expect(Set(routine.keys) == ["title", "weekdays", "time", "note"])
    }

    // MARK: - 문서 형식 (향후 공개 템플릿과 공용)

    @Test func catalogRoundTripsThroughItsDocumentFormat() throws {
        let data = try catalog.encoded()
        #expect(try TemplateCatalog(data: data) == catalog)
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains(#""format" : "daylog.templates""#) && text.contains(#""version" : 1"#))
    }

    @Test func unsupportedDocumentsAndInvalidTemplatesAreRejected() throws {
        let wrong = Data(#"{"format":"daylog.routines","version":1,"templates":[]}"#.utf8)
        #expect(throws: RoutineTransferError.self) { try TemplateCatalog(data: wrong) }
        let future = Data(#"{"format":"daylog.templates","version":2,"templates":[]}"#.utf8)
        #expect(throws: RoutineTransferError.self) { try TemplateCatalog(data: future) }

        let good = sample(id: "a")
        let untitled = sample(id: "b", title: "  ")
        let empty = sample(id: "c", groups: [.init(title: "빈 그룹", routines: [])])
        let badWeekday = sample(id: "d", groups: [.init(title: "그룹", routines: [.init(title: "루틴", weekdays: [8])])])
        let badTime = sample(id: "e", groups: [.init(title: "그룹", routines: [.init(title: "루틴", time: "25:99")])])
        let sameName = sample(id: "f", groups: [.init(title: "그룹", routines: [.init(title: "루틴"), .init(title: "루틴")])])
        let tooMany = sample(id: "g", groups: [.init(
            title: "그룹", routines: (0...RoutineTemplate.maximumRoutines).map { .init(title: "루틴 \($0)") }
        )])
        for invalid in [untitled, empty, badWeekday, badTime, sameName, tooMany] {
            #expect(invalid.validationError != nil, "\(invalid.id)")
        }
        // 검사를 통과한 것만, ID가 겹치면 먼저 온 것만 목록에 남는다.
        let merged = TemplateCatalog(templates: [good, untitled, empty, badWeekday, badTime, sameName, tooMany, sample(id: "a", title: "나중 것")])
        #expect(merged.templates == [good])
    }

    @Test func unknownCategoriesFromANewerVersionAreKept() throws {
        var document = try JSONSerialization.jsonObject(with: try TemplateCatalog(templates: [sample()]).encoded()) as? [String: Any]
        var templates = try #require(document?["templates"] as? [[String: Any]])
        templates[0]["category"] = "travel"
        document?["templates"] = templates
        let data = try JSONSerialization.data(withJSONObject: try #require(document))
        #expect(try TemplateCatalog(data: data).templates.first?.category == .lifestyle)
    }

    // MARK: - 검색과 분류

    @Test func filtersByCategoryAndSearchesTitleTagsAndRoutineNames() throws {
        #expect(catalog.filtered(category: nil, query: "").count == catalog.templates.count)
        #expect(catalog.filtered(category: nil, query: "   ").count == catalog.templates.count)
        let fitness = catalog.filtered(category: .fitness, query: "")
        #expect(!fitness.isEmpty && fitness.allSatisfy { $0.category == .fitness })

        // 제목, 태그, 루틴 이름, 분류 이름으로 찾는다.
        #expect(catalog.filtered(category: nil, query: "미라클").map(\.id) == ["official.morning-miracle"])
        #expect(catalog.filtered(category: nil, query: "딥워크").map(\.id) == ["official.focus-deepwork"])
        #expect(catalog.filtered(category: nil, query: "가계부").map(\.id) == ["official.life-tidy"])
        #expect(Set(catalog.filtered(category: nil, query: "운동·건강").map(\.category)) == [.fitness])
        // 분류와 검색어를 함께 쓰면 둘 다 맞는 것만.
        #expect(catalog.filtered(category: .morning, query: "러닝").isEmpty)
        #expect(catalog.filtered(category: .fitness, query: "러닝").map(\.id) == ["official.fitness-running"])
        #expect(catalog.filtered(category: nil, query: "없는 낱말").isEmpty)
        // 대소문자와 앞뒤 공백은 가리지 않는다.
        let english = sample(id: "en", title: "Deep Work")
        #expect(english.matches("  deep ") && english.matches("WORK") && !english.matches("shallow"))
    }

    // MARK: - 가져오기

    @Test func importingIntoAnEmptyStoreCreatesTheGroupAndRoutines() throws {
        let env = try TestEnv()
        let (store, _) = makeStore(env, today: monday)
        let template = try template("morning-light")

        let preview = try store.previewTemplateImport(template)
        #expect((preview.createdCount, preview.duplicateCount, preview.errorCount) == (3, 0, 0))
        #expect(preview.newGroupCount == 1 && preview.canSave)
        // 미리보기는 저장소를 건드리지 않는다.
        #expect(store.routines.isEmpty && store.groups.isEmpty)
        #expect(TemplateImportResult.previewTitle(preview) == "추가 3개")

        #expect(store.confirmRoutineImport(preview))
        #expect(store.groups.map(\.title) == ["아침 루틴"])
        #expect(store.routines.map(\.title) == ["기상 후 물 한 잔", "가벼운 스트레칭", "오늘 할 일 3가지 적기"])
        #expect(store.routines.map(\.timeLabel) == ["07:00", "07:10", "07:30"])
        #expect(store.routines[1].note == "5분")
        // 오늘의 체크 목록에 바로 나온다.
        #expect(store.checkSections.flatMap(\.checks).map(\.title) == store.routines.map(\.title))
        #expect(store.stats.firstDay == monday)
    }

    @Test func weekdaysFromTheTemplateAreKept() throws {
        let env = try TestEnv()
        let (store, _) = makeStore(env, today: monday)
        #expect(store.confirmRoutineImport(try store.previewTemplateImport(try template("fitness-strength"))))
        let strength = try #require(store.routines.first { $0.title == "근력 운동" })
        #expect(strength.weekdays == [1, 3, 5] && strength.timeLabel == "19:00")
        // 월요일에는 나오고, 화요일에는 매일 하는 것만 나온다.
        #expect(store.checkSections.flatMap(\.checks).contains { $0.title == "근력 운동" })
        let tuesday = store.upcomingDays(count: 2)[1].sections.flatMap(\.checks).map(\.title)
        #expect(tuesday == ["마무리 스트레칭", "단백질 챙기기"])
    }

    @Test func importingTheSameTemplateAgainAddsNothing() throws {
        let env = try TestEnv()
        let (store, _) = makeStore(env, today: monday)
        let template = try template("study-reading")
        #expect(store.confirmRoutineImport(try store.previewTemplateImport(template)))
        let before = store.routines.map(\.id)

        let again = try store.previewTemplateImport(template)
        #expect((again.createdCount, again.duplicateCount, again.errorCount) == (0, 2, 0))
        #expect(!again.canSave)
        #expect(again.rows.allSatisfy { $0.action == .duplicate })
        // 그래도 저장을 시도하면 아무것도 추가되지 않는다.
        #expect(!store.confirmRoutineImport(again))
        #expect(store.routines.map(\.id) == before)
        #expect(store.groups.count == 1)
    }

    /// 같은 그룹에 이름이 같은 루틴이 이미 있으면(설정이 달라도) 그 줄만 건너뛰고 나머지를 기존 그룹에 넣는다.
    @Test func existingRoutinesAreSkippedAndNeverChanged() throws {
        let env = try TestEnv()
        let (store, _) = makeStore(env, today: monday)
        let group = try #require(store.addGroup(title: "아침 루틴"))
        store.addRoutine(title: "기상 후 물 한 잔", in: group)
        let mine = try #require(store.routines.first)
        store.updateRoutine(mine, timeLabel: "06:30")
        store.setDone(routineID: mine.id, true)

        let preview = try store.previewTemplateImport(try template("morning-light"))
        #expect((preview.createdCount, preview.duplicateCount, preview.errorCount) == (2, 1, 0))
        #expect(preview.rows[0].action == .conflict("이름이 같은 루틴이 이미 있어요"))
        #expect(preview.rows[0].action.label == "이름이 같은 루틴이 이미 있어요 · 건너뜀")
        #expect(preview.newGroupCount == 0 && preview.reusedGroupCount == 1)
        #expect(TemplateImportResult.previewTitle(preview) == "추가 2개 · 건너뜀 1개")

        #expect(store.confirmRoutineImport(preview))
        #expect(store.groups.count == 1)
        #expect(store.routines.map(\.title) == ["기상 후 물 한 잔", "가벼운 스트레칭", "오늘 할 일 3가지 적기"])
        // 내 루틴의 시간과 오늘의 체크는 그대로다.
        #expect(store.routines[0].id == mine.id && store.routines[0].timeLabel == "06:30")
        #expect(store.checkSections.flatMap(\.checks).map(\.isDone) == [true, false, false])
    }

    @Test func archivedNamesakesAreSkippedWithoutBlockingTheFileImportRules() throws {
        let env = try TestEnv()
        let (store, _) = makeStore(env, today: monday)
        let group = try #require(store.addGroup(title: "독서"))
        store.setGroupArchived(group, true)
        let template = try template("study-reading")

        // 템플릿: 보관한 그룹과 이름이 겹치면 건너뛴다(되살리거나 같은 이름의 그룹을 또 만들지 않는다).
        let lenient = try store.previewTemplateImport(template)
        #expect((lenient.createdCount, lenient.duplicateCount, lenient.errorCount) == (0, 2, 0))
        #expect(!lenient.canSave)
        // 파일 가져오기는 전과 같이 오류로 세운다.
        let strict = try RoutineTransferService(context: env.context).preview(template.transferRoutines, today: monday)
        #expect(strict.policy == .strict && strict.errorCount == 2 && strict.duplicateCount == 0)
    }

    /// 새 루틴은 오늘부터다. 지난 날짜의 기록과 통계에는 들어가지 않는다.
    @Test func importedRoutinesAreNotAppliedToPastDays() throws {
        let env = try TestEnv()
        try env.addRoutines(2, today: monday)
        try env.log(monday, done: 1)
        try env.log(monday.adding(days: 1), done: 2)
        let (store, _) = makeStore(env, today: monday.adding(days: 3))
        let before = try store.stats.trend.suffix(4).map { ($0.day, $0.done, $0.total) }.map { "\($0)" }
        let pastChecks = try #require(try env.records.record(on: monday)).checkList.map(\.title)

        #expect(store.confirmRoutineImport(try store.previewTemplateImport(try template("life-evening"))))

        let after = store.stats.trend.suffix(4)
        // 월·화(기록한 날)와 수(열지 않은 날)는 그대로이고, 오늘만 예정이 늘었다.
        #expect(after.prefix(3).map { "\(($0.day, $0.done, $0.total))" } == Array(before.prefix(3)))
        #expect(after.last?.total == 5)
        #expect(try #require(try env.records.record(on: monday)).checkList.map(\.title) == pastChecks)
        store.select(monday)
        #expect(store.checkSections.flatMap(\.checks).count == 2)
        store.select(monday.adding(days: 2))
        #expect(store.checkSections.flatMap(\.checks).count == 2)
    }

    @Test func importLeavesRecordsMealsVacationsSkipsAndDashboardTextsAlone() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(2, today: monday)
        let (store, _) = makeStore(env, today: monday)
        store.setDone(routineID: routines[0].id, true)
        store.setSkipped(routineID: routines[1].id, true)
        store.setText("토스트", at: \.breakfast)
        store.flush()
        #expect(store.saveVacation(start: monday.adding(days: 5), end: monday.adding(days: 6)))
        let textID = UUID()
        #expect(store.saveDashboardText(id: textID, title: "목표", body: "걷기"))
        let vacations = store.vacationPeriods, texts = store.dashboardTexts

        #expect(store.confirmRoutineImport(try store.previewTemplateImport(try template("fitness-walk"))))

        #expect(store.checkSections.flatMap(\.checks).prefix(2).map(\.status) == [.done, .skipped])
        #expect(store.text(\.breakfast) == "토스트")
        #expect(store.vacationPeriods == vacations)
        #expect(store.dashboardTexts == texts)
        #expect(store.routines.prefix(2).map(\.id) == routines.map(\.id))
        #expect(store.routines.count == 5)
    }

    /// 저장에 실패하면 그룹도 루틴도 남지 않는다(절반만 들어가지 않는다).
    @Test func aFailedImportAddsNothing() throws {
        let env = try TestEnv()
        try env.addRoutines(1, today: monday)
        struct Failure: Error {}
        let service = RoutineTransferService(context: env.context) { _ in throw Failure() }
        let preview = try service.preview(try template("focus-deepwork").transferRoutines, today: monday, policy: .skipConflicts)
        #expect(preview.createdCount == 3)
        #expect(throws: Failure.self) { try service.commit(preview, today: monday) }

        let fresh = RoutineService(context: env.freshContext())
        #expect(try fresh.routines().map(\.title) == ["루틴 1"])
        #expect(try fresh.groups().allSatisfy { $0.title != "집중 작업" })
        #expect(try env.routines.routines().count == 1)
        #expect(!env.context.hasChanges)
    }

    /// 미리본 뒤 루틴이 바뀌었으면 그 미리보기로는 저장하지 않는다.
    @Test func aStalePreviewIsNotCommitted() throws {
        let env = try TestEnv()
        let (store, _) = makeStore(env, today: monday)
        let preview = try store.previewTemplateImport(try template("study-language"))
        let group = try #require(store.addGroup(title: "외국어 공부"))
        store.addRoutine(title: "듣기 15분", in: group)
        #expect(!store.confirmRoutineImport(preview))
        #expect(store.routines.map(\.title) == ["듣기 15분"])
        // 새로 미리보면 겹치는 줄만 건너뛰고 저장된다.
        let fresh = try store.previewTemplateImport(try template("study-language"))
        #expect((fresh.createdCount, fresh.duplicateCount) == (2, 1))
        #expect(store.confirmRoutineImport(fresh))
        #expect(store.routines.count == 3)
    }

    @Test func resultWordingCoversAddedSkippedAndFailed() {
        #expect(TemplateImportResult(created: 3, skipped: 0, failed: 0).title == "루틴 3개를 추가했어요")
        #expect(TemplateImportResult(created: 2, skipped: 1, failed: 0).title == "루틴 2개를 추가했어요 · 1개는 이미 있어 건너뛰었어요")
        #expect(TemplateImportResult(created: 1, skipped: 1, failed: 2).title == "루틴 1개를 추가했어요 · 1개는 이미 있어 건너뛰었어요 · 오류 2개")
    }

    // MARK: - 메뉴

    @Test func templatesAreInTheSidebarBeforeSettingsAndNotInPhoneTabs() {
        let sections = AppStore.Section.allCases
        // 템플릿 다음에 피오 옷장, 설정은 늘 마지막이다.
        #expect(sections.suffix(3) == [.templates, .wardrobe, .settings])
        // 기존 메뉴의 순서(= ⌘1~⌘6)는 그대로다.
        #expect(sections.prefix(6) == [.dashboard, .routines, .meals, .statistics, .calendar, .vacation])
        #expect(!AppStore.Section.phoneTabs.contains(.templates))
        #expect(AppStore.Section.templates.title == "템플릿")
        let preferences = DevicePreferences(defaults: testDefaults(), isPhone: false)
        #expect(preferences.navigationSections(phone: false).contains(.templates))
        #expect(!preferences.navigationSections(phone: true).contains(.templates))
    }
}
