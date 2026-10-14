import CoreGraphics
import Foundation
import ImageIO
import SwiftData
import Testing
import UniformTypeIdentifiers
@testable import Daylog

/// Phase 5-B: 대시보드 꾸미기. 카드 이름과 배치, 원격 기본값과의 우선순위, 사진 처리, 텍스트 카드의 저장과 기기 간 판정.
@MainActor
struct DashboardCustomizationTests {
    // MARK: - 도구

    /// 가로 `width`, 세로 `height`의 시험용 그림. 사진처럼 압축이 잘 되지 않게 칸마다 색을 바꾼다.
    private func imageData(width: Int, height: Int, type: UTType = .png, alpha: Bool = false) throws -> Data {
        let info = alpha ? CGImageAlphaInfo.premultipliedLast : CGImageAlphaInfo.noneSkipLast
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: info.rawValue
        ))
        let step = max(width / 24, 1)
        for x in stride(from: 0, to: width, by: step) {
            for y in stride(from: 0, to: height, by: step) {
                let shade = CGFloat((x / step * 37 + y / step * 91) % 255) / 255
                context.setFillColor(CGColor(red: shade, green: 1 - shade, blue: 0.4, alpha: 1))
                context.fill(CGRect(x: x, y: y, width: step, height: step))
            }
        }
        if alpha { context.clear(CGRect(x: 0, y: 0, width: width / 2, height: height)) }
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    private func temporaryImages() -> DashboardImageStore {
        DashboardImageStore(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("daylog-tests-\(UUID().uuidString)", isDirectory: true))
    }

    private func files(in store: DashboardImageStore) -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: store.directory.path)) ?? []
    }

    private func makeStore(_ env: TestEnv, device: String = thisMac) -> AppStore {
        let clock = TestClock(monday)
        let store = AppStore(container: env.container, deviceID: device, clock: { clock.today })
        store.start()
        return store
    }

    // MARK: - 카드 이름과 배치

    @Test func customCardNamesRoundTripAndBuiltInNamesAreUnchanged() {
        // 기본 카드는 예전에 저장한 글자 그대로다.
        #expect(DashboardCard.allCases.map(\.rawValue) == [
            "summary", "nextRoutine", "vacation", "routines", "weeklyGrowth", "meals", "achievement", "recentDays", "tomorrow",
            "calendar", "trend", "routineRates"
        ])
        let id = UUID()
        for kind in CustomCardKind.allCases {
            let card = DashboardCard.custom(kind, id)
            #expect(card.rawValue == "custom:\(kind.rawValue):\(id.uuidString)")
            #expect(DashboardCard(rawValue: card.rawValue) == card)
            #expect(card.isCustom && card.customID == id && card.customKind == kind)
            #expect(!card.spansFullWidth)
        }
        #expect(DashboardCard(rawValue: "custom:image:not-a-uuid") == nil)
        #expect(DashboardCard(rawValue: "custom:sticker:\(id.uuidString)") == nil)
        #expect(!DashboardCard.allCases.contains { $0.isCustom })
    }

    /// Phase 5-B 정리: 이미지 카드는 새로 만들지 않는다. 이미 만든 것은 배치에 남고 계속 보인다.
    @Test func imageCardsAreNoLongerAddableButExistingOnesStay() throws {
        #expect(CustomCardKind.addable == [.text, .sectionTitle, .divider])
        #expect(!CustomCardKind.addable.contains(.image))

        let defaults = testDefaults(), images = temporaryImages()
        let decor = DashboardDecor(defaults: defaults, images: images)
        let id = UUID(), card = DashboardCard.custom(.image, id)
        try decor.setImage(try DashboardImageStore.process(try imageData(width: 400, height: 300)), for: id)
        let preferences = DevicePreferences(defaults: defaults, isPhone: false)
        preferences.addCustom(card)

        // 다시 켜도 예전 이미지 카드는 그대로 읽히고, 고치고(크기) 지울 수 있다.
        let reopened = DevicePreferences(defaults: defaults, isPhone: false)
        let reopenedDecor = DashboardDecor(defaults: defaults, images: images)
        #expect(reopened.visibleCards.contains(card))
        #expect(reopenedDecor.isAvailable(card, texts: [:]) && reopenedDecor.image(for: id) != nil)
        reopenedDecor.setSize(.small, for: id)
        #expect(reopenedDecor.entry(id).size == .small)
        reopened.removeCustom(card)
        reopenedDecor.remove(id)
        #expect(!reopened.cardOrder.contains(card) && files(in: images).isEmpty)
    }

    @Test func addingACardPutsItOnTopAndSurvivesARelaunch() {
        let defaults = testDefaults()
        let preferences = DevicePreferences(defaults: defaults, isPhone: false)
        let text = DashboardCard.custom(.text, UUID()), image = DashboardCard.custom(.image, UUID())
        preferences.addCustom(text, column: .left)
        preferences.addCustom(image)
        #expect(preferences.cardOrder.prefix(2) == [image, text])
        // 따로 고르지 않으면 오른쪽 열이다(왼쪽 열의 오늘 루틴을 밀지 않는다).
        #expect(preferences.column(of: text) == .left && preferences.column(of: image) == .right)
        #expect(preferences.isLayoutCustomized)
        // 기본 카드는 그대로 다 있다.
        #expect(Set(preferences.cardOrder).isSuperset(of: DashboardCard.allCases))
        #expect(preferences.visibleCards.contains(.routines))

        let reopened = DevicePreferences(defaults: defaults, isPhone: false)
        #expect(reopened.cardOrder == preferences.cardOrder)
        #expect(reopened.leftCards.contains(text) && !reopened.leftCards.contains(image))

        reopened.setVisible(false, card: text)
        #expect(reopened.hiddenChoices.contains(text) && !reopened.visibleCards.contains(text))
        reopened.removeCustom(text)
        #expect(!reopened.cardOrder.contains(text) && !reopened.hiddenCards.contains(text) && !reopened.leftCards.contains(text))
        #expect(DevicePreferences(defaults: defaults, isPhone: false).cardOrder.filter(\.isCustom) == [image])
    }

    @Test func customCardsMoveLikeAnyOtherCard() {
        let preferences = DevicePreferences(defaults: testDefaults(), isPhone: false)
        let card = DashboardCard.custom(.sectionTitle, UUID())
        preferences.addCustom(card, column: .left)
        preferences.place(card, before: .meals)
        #expect(preferences.column(of: card) == .right)
        let right = preferences.layout(of: preferences.visibleCards).right
        #expect(right.firstIndex(of: card).map { $0 + 1 } == right.firstIndex(of: .meals))
        preferences.place(card, atEndOf: .left)
        #expect(preferences.layout(of: preferences.visibleCards).left.last == card)
    }

    @Test func restoringTheDefaultLayoutKeepsCustomCards() {
        let preferences = DevicePreferences(defaults: testDefaults(), isPhone: false)
        let card = DashboardCard.custom(.image, UUID())
        preferences.addCustom(card, column: .left)
        preferences.setVisible(false, card: .meals)
        preferences.restoreDashboard()
        // 기본 카드는 기본 배치로, 꾸미기 카드는 지워지지 않고 그 뒤에 남는다.
        #expect(preferences.cardOrder == DashboardCard.defaultOrder + [card])
        #expect(preferences.hiddenCards == DashboardCard.defaultHidden)
        #expect(preferences.leftCards == DashboardCard.defaultLeft.union([card]))
    }

    /// 우선순위: 사용자 설정 > 원격 기본값 > 내장 기본값. 꾸민 대시보드는 원격 설정이 건드리지 않는다.
    @Test func remoteDefaultsNeverResetACustomizedDashboard() {
        let preferences = DevicePreferences(defaults: testDefaults(), isPhone: true)
        let card = DashboardCard.custom(.text, UUID())
        preferences.addCustom(card)
        let before = preferences.cardOrder
        preferences.applyRemoteDefaults(order: ["trend", "routines"], hidden: ["meals"])
        #expect(preferences.cardOrder == before)
        #expect(!preferences.hiddenCards.contains(.meals))

        // 기본 배치로 되돌린 뒤에는 원격 기본값을 따르되, 꾸미기 카드는 그대로 둔다.
        preferences.restoreDashboard()
        #expect(preferences.cardOrder.first == .trend)
        #expect(preferences.cardOrder.last == card)
        preferences.applyRemoteDefaults(order: ["meals", "routines"], hidden: ["summary"])
        #expect(preferences.cardOrder.first == .meals && preferences.cardOrder.last == card)
        #expect(preferences.visibleCards.contains(card))
    }

    /// 원격 설정은 꾸미기 카드의 이름을 받아들이지 않는다(기본 카드의 허용 목록만).
    @Test func remoteConfigCannotNameCustomCards() throws {
        let custom = DashboardCard.custom(.image, UUID()).rawValue
        let json = """
        {"schemaVersion":1,"configVersion":9,"minimumSupportedAppBuild":1,"updatedAt":"2026-10-13T00:00:00Z",
         "dashboard":{"defaultCardOrder":["\(custom)","routines"],"defaultHiddenCards":["\(custom)"]}}
        """
        let settings = try MobileUIConfig.decode(Data(json.utf8), appBuild: 99).resolved()
        #expect(settings.defaultCardOrder?.contains(custom) != true)
        #expect(settings.defaultHiddenCards?.contains(custom) != true)
    }

    // MARK: - 사진 처리

    @Test func largePhotosAreResizedAndCompressed() throws {
        let original = try imageData(width: 4_800, height: 3_200)
        let processed = try DashboardImageStore.process(original)
        let image = try #require(processed.cgImage)
        #expect(max(image.width, image.height) <= DashboardImageStore.maxPixel)
        // 화면 비율은 그대로다.
        #expect(abs(Double(image.width) / Double(image.height) - 1.5) < 0.01)
        #expect(processed.data.count <= DashboardImageStore.maxStoredBytes)
        #expect(processed.data.count < original.count)
    }

    @Test func smallPhotosAreNotEnlarged() throws {
        let processed = try DashboardImageStore.process(try imageData(width: 320, height: 200, type: .jpeg))
        let image = try #require(processed.cgImage)
        #expect((image.width, image.height) == (320, 200))
    }

    @Test func transparentPicturesAreFlattenedOntoWhite() throws {
        let processed = try DashboardImageStore.process(try imageData(width: 200, height: 100, alpha: true))
        let image = try #require(processed.cgImage)
        #expect([.none, .noneSkipLast, .noneSkipFirst].contains(image.alphaInfo))
        // 투명했던 왼쪽은 검정이 아니라 밝게 나온다.
        let context = try #require(CGContext(
            data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: -50, width: 200, height: 100))
        let pixel = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        #expect(pixel[0] > 230 && pixel[1] > 230 && pixel[2] > 230)
    }

    @Test func unreadableAndOversizedFilesAreRejected() {
        #expect(throws: DashboardImageError.unreadable) { try DashboardImageStore.process(Data("사진이 아니다".utf8)) }
        #expect(throws: DashboardImageError.unreadable) { try DashboardImageStore.process(Data()) }
        #expect(throws: DashboardImageError.tooLarge) {
            try DashboardImageStore.process(Data(count: DashboardImageStore.maxSourceBytes + 1))
        }
    }

    @Test func theOriginalDataIsNeverChanged() throws {
        let original = try imageData(width: 2_400, height: 1_600)
        let copy = Data(original)
        _ = try DashboardImageStore.process(original)
        #expect(original == copy)
    }

    // MARK: - 이 기기의 꾸미기 설정

    @Test func decorPersistsSizeTitleAndPhotoPerDevice() throws {
        let defaults = testDefaults(), images = temporaryImages()
        let decor = DashboardDecor(defaults: defaults, images: images)
        let id = UUID()
        #expect(decor.entry(id) == DashboardDecor.Entry())
        decor.setSize(.large, for: id)
        decor.setTitle("  오늘도 한 걸음  ", for: id)
        try decor.setImage(try DashboardImageStore.process(try imageData(width: 800, height: 400)), for: id)

        let reopened = DashboardDecor(defaults: defaults, images: images)
        #expect(reopened.entry(id).size == .large)
        #expect(reopened.entry(id).title == "오늘도 한 걸음")
        #expect(reopened.image(for: id) != nil)
        // 다른 기기(다른 설정 저장소)에는 없다.
        #expect(DashboardDecor(defaults: testDefaults(), images: temporaryImages()).entries.isEmpty)
    }

    @Test func replacingAndRemovingPhotosLeavesNoStrayFiles() throws {
        let images = temporaryImages()
        let decor = DashboardDecor(defaults: testDefaults(), images: images)
        let id = UUID()
        try decor.setImage(try DashboardImageStore.process(try imageData(width: 400, height: 300)), for: id)
        let first = try #require(decor.entry(id).imageFile)
        try decor.setImage(try DashboardImageStore.process(try imageData(width: 600, height: 300)), for: id)
        let second = try #require(decor.entry(id).imageFile)
        #expect(first != second)
        #expect(files(in: images) == [second])

        decor.removeImage(for: id)
        #expect(decor.entry(id).imageFile == nil && decor.image(for: id) == nil)
        #expect(files(in: images).isEmpty)

        try decor.setImage(try DashboardImageStore.process(try imageData(width: 400, height: 300)), for: id)
        decor.remove(id)
        #expect(decor.entries[id] == nil)
        #expect(files(in: images).isEmpty)
    }

    @Test func aMissingOrDamagedPhotoShowsAsUnavailableInsteadOfCrashing() throws {
        let images = temporaryImages()
        let decor = DashboardDecor(defaults: testDefaults(), images: images)
        let id = UUID()
        try decor.setImage(try DashboardImageStore.process(try imageData(width: 400, height: 300)), for: id)
        let name = try #require(decor.entry(id).imageFile)
        let url = images.directory.appendingPathComponent(name)

        // 파일이 손상됐다.
        try Data("깨진 파일".utf8).write(to: url)
        let damaged = DashboardDecor(defaults: testDefaults(), images: DashboardImageStore(directory: images.directory))
        #expect(damaged.images.image(named: "other-" + name) == nil)
        // 파일이 사라졌다: 설정은 남아 있고(다시 고르라는 안내를 띄운다) 그림만 없다.
        try FileManager.default.removeItem(at: url)
        images.remove(name)
        #expect(decor.entry(id).imageFile == name)
        #expect(decor.image(for: id) == nil)
        // 폴더 밖을 가리키는 이름은 읽지 않는다.
        #expect(!DashboardImageStore.isSafe("../secret.jpg") && !DashboardImageStore.isSafe("a/b.jpg") && !DashboardImageStore.isSafe(""))
    }

    @Test func headerBackgroundIsOptionalAndRemovable() throws {
        let defaults = testDefaults(), images = temporaryImages()
        let decor = DashboardDecor(defaults: defaults, images: images)
        #expect(decor.headerImageFile == nil && decor.headerImage == nil)
        try decor.setHeaderImage(try DashboardImageStore.process(try imageData(width: 1_200, height: 400)))
        #expect(DashboardDecor(defaults: defaults, images: images).headerImage != nil)
        decor.removeHeaderImage()
        #expect(decor.headerImage == nil)
        #expect(DashboardDecor(defaults: defaults, images: images).headerImageFile == nil)
        #expect(files(in: images).isEmpty)
    }

    @Test func availabilityFollowsWhereTheContentLives() {
        let decor = DashboardDecor(defaults: testDefaults(), images: temporaryImages())
        let text = UUID(), divider = UUID()
        #expect(decor.isAvailable(.routines, texts: [:]))
        // 텍스트 카드는 함께 보는 내용이 있어야 하고, 나머지는 이 기기의 설정이 있어야 한다.
        #expect(!decor.isAvailable(.custom(.text, text), texts: [:]))
        #expect(decor.isAvailable(.custom(.text, text), texts: [text: DashboardText(title: "목표", body: "")]))
        #expect(!decor.isAvailable(.custom(.divider, divider), texts: [:]))
        decor.setSize(.regular, for: divider)
        #expect(decor.isAvailable(.custom(.divider, divider), texts: [:]))
    }

    // MARK: - 크기

    @Test func phoneImagesAreLowerAndCapped() {
        for size in CustomCardSize.allCases {
            #expect(size.imageHeight(compact: true) < size.imageHeight(compact: false))
            #expect(size.imageHeight(compact: true) <= CustomCardSize.compactImageLimit)
        }
        #expect(CustomCardSize.small.imageHeight(compact: false) < CustomCardSize.regular.imageHeight(compact: false))
        #expect(CustomCardSize.regular.imageHeight(compact: false) < CustomCardSize.large.imageHeight(compact: false))
    }

    // MARK: - 텍스트 카드 (기기 간 공유)

    @Test func textCardsAreSavedTrimmedAndSurviveARelaunch() throws {
        let env = try TestEnv()
        let store = makeStore(env)
        let id = UUID()
        #expect(store.saveDashboardText(id: id, title: "  이번 달 목표  ", body: String(repeating: "가", count: 600)))
        #expect(store.dashboardTexts[id]?.title == "이번 달 목표")
        #expect(store.dashboardTexts[id]?.body.count == DashboardText.bodyLimit)

        let relaunched = makeStore(env)
        #expect(relaunched.dashboardTexts[id]?.title == "이번 달 목표")
        // 수정은 같은 줄을 고쳐 쓴다(줄이 늘지 않는다).
        #expect(relaunched.saveDashboardText(id: id, title: "목표", body: "매일 30분 걷기"))
        #expect(relaunched.dashboardTexts[id] == DashboardText(title: "목표", body: "매일 30분 걷기"))
        let key = DashboardTextEdit.dateKey
        #expect(try env.context.fetchCount(FetchDescriptor<FieldEdit>(predicate: #Predicate { $0.dateKey == key })) == 1)
    }

    @Test func removingATextCardLeavesATombstoneSoItDoesNotComeBack() throws {
        let env = try TestEnv()
        let store = makeStore(env)
        let id = UUID()
        store.saveDashboardText(id: id, title: "다짐", body: "")
        #expect(store.removeDashboardText(id: id))
        #expect(store.dashboardTexts[id] == nil)

        // 다른 기기가 삭제를 못 본 채 예전에 고친 내용이 뒤늦게 도착해도 되살아나지 않는다.
        let stale = FieldEdit(dateKey: DashboardTextEdit.dateKey, field: DashboardTextEdit.fieldName(id), deviceID: otherMac)
        stale.value = try DashboardTextEdit.encode(DashboardText(title: "옛 내용", body: ""))
        stale.editedAt = earlier
        env.context.insert(stale)
        try env.context.save()
        store.handleExternalChanges()
        #expect(store.dashboardTexts[id] == nil)
    }

    @Test func aLaterEditFromAnotherDeviceWins() throws {
        let env = try TestEnv()
        let store = makeStore(env)
        let id = UUID()
        store.saveDashboardText(id: id, title: "목표", body: "물 2L")
        let mine = try #require(try FieldEditService(context: env.context, deviceID: thisMac)
            .entries(dateKey: DashboardTextEdit.dateKey, fieldName: DashboardTextEdit.fieldName(id)).first)

        let remote = FieldEdit(dateKey: DashboardTextEdit.dateKey, field: DashboardTextEdit.fieldName(id), deviceID: otherMac)
        remote.value = try DashboardTextEdit.encode(DashboardText(title: "목표", body: "물 3L"))
        remote.editedAt = mine.editedAt.addingTimeInterval(60)
        remote.seen = [thisMac: mine.editedAt.timeIntervalSinceReferenceDate]
        env.context.insert(remote)
        try env.context.save()
        store.handleExternalChanges()
        #expect(store.dashboardTexts[id]?.body == "물 3L")
    }

    /// 텍스트 카드는 기록·통계·휴가·건너뛰기와 섞이지 않는다.
    @Test func textCardsDoNotTouchRecordsStatsVacationsOrSkips() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(2, today: monday)
        let store = makeStore(env)
        store.setDone(routineID: routines[0].id, true)
        store.setSkipped(routineID: routines[1].id, true)
        #expect(store.saveVacation(start: monday.adding(days: 3), end: monday.adding(days: 4)))
        let statsBefore = store.stats, sections = store.checkSections, vacations = store.vacationPeriods
        let records = try env.context.fetchCount(FetchDescriptor<DayRecord>())
        let checks = try env.context.fetchCount(FetchDescriptor<DayCheck>())

        // 건너뛰기 표시와 글자가 같은 내용을 적어도 건너뛰기로 읽히지 않는다.
        let id = UUID()
        #expect(store.saveDashboardText(id: id, title: CheckEdit.skippedValue, body: "1"))

        #expect(store.stats == statsBefore)
        #expect(store.checkSections == sections)
        #expect(store.checkSections.flatMap(\.checks).map(\.status) == [.done, .skipped])
        #expect(store.vacationPeriods == vacations)
        #expect(try env.context.fetchCount(FetchDescriptor<DayRecord>()) == records)
        #expect(try env.context.fetchCount(FetchDescriptor<DayCheck>()) == checks)
        // 동기화 병합도 이 줄을 텍스트 칸이나 체크로 보지 않는다.
        #expect(try reconcile(env, today: monday).notices.isEmpty)
        #expect(store.dashboardTexts[id] != nil)
        store.removeDashboardText(id: id)
        #expect(store.stats == statsBefore)
    }

    @Test func aFailedSaveRestoresOnlyItsOwnEdit() throws {
        let env = try TestEnv()
        struct Failure: Error {}
        let service = DashboardTextService(context: env.context, deviceID: thisMac)
        let failing = DashboardTextService(context: env.context, deviceID: thisMac) { _ in throw Failure() }
        let existing = UUID()
        try service.save(id: existing, title: "기존 카드", body: "")
        let record = try env.records.fetchOrCreate(day: monday, today: monday)
        record.breakfast = "저장되지 않은 입력"

        #expect(throws: Failure.self) { try failing.save(id: existing, title: "실패한 수정", body: "") }
        #expect(throws: Failure.self) { try failing.remove(id: existing) }
        #expect(throws: Failure.self) { try failing.save(id: UUID(), title: "실패한 새 카드", body: "") }
        #expect(try service.texts() == [existing: DashboardText(title: "기존 카드", body: "")])
        // 적던 식사 입력은 그대로이고, 나중에 저장해도 실패한 카드가 되살아나지 않는다.
        #expect(record.breakfast == "저장되지 않은 입력")
        try env.context.save()
        #expect(try DashboardTextService(context: env.freshContext()).texts().keys.map { $0 } == [existing])
        #expect(try env.context.fetchCount(FetchDescriptor<FieldEdit>()) == 1)
    }

    @Test func otherDevicesTextsAreOfferedByAReadableLabel() {
        #expect(DashboardEditBar.chipTitle(DashboardText(title: "이번 달 목표", body: "걷기")) == "이번 달 목표")
        #expect(DashboardEditBar.chipTitle(DashboardText(title: "", body: "첫 줄\n둘째 줄")) == "첫 줄")
        #expect(DashboardEditBar.chipTitle(DashboardText(title: "", body: String(repeating: "가", count: 30))).count == 15)
    }
}
