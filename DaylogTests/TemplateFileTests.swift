import Foundation
import SwiftData
import Testing
import UniformTypeIdentifiers
@testable import Daylog

/// Phase 5-D: 루틴 템플릿을 파일로 주고받기. 파일에 무엇이 들어가는지, 받은 파일을 어떻게 걸러 내는지,
/// 가져오기가 기존 기록을 건드리지 않는지 본다.
@MainActor
struct TemplateFileTests {
    private func appStore(_ env: TestEnv, today: Day = monday) -> AppStore {
        let clock = TestClock(today)
        let store = AppStore(container: env.container, deviceID: thisMac, clock: { clock.today })
        store.start()
        return store
    }

    private func sample(
        title: String = "아침 시작",
        groups: [RoutineTemplate.Group] = [.init(title: "아침 루틴", colorKey: "orange", routines: [
            .init(title: "물 한 잔", time: "07:00"), .init(title: "스트레칭", weekdays: [1, 3, 5], note: "5분")
        ])]
    ) -> RoutineTemplate {
        TemplateFile.make(title: title, summary: "가볍게", category: .morning, tags: ["아침", " 아침 ", ""], groups: groups)
    }

    private func document(_ mutate: (inout [String: Any]) -> Void) throws -> Data {
        var json = try #require(try JSONSerialization.jsonObject(with: TemplateFile.encode(sample())) as? [String: Any])
        mutate(&json)
        return try JSONSerialization.data(withJSONObject: json)
    }

    // MARK: - 파일 만들기

    @Test func sharedFilesAreVersionedDocumentsWithOneTemplate() throws {
        let template = sample()
        #expect(template.source == .file && template.id.hasPrefix("file.") && template.tags == ["아침"])
        #expect(template.thumbnail.symbol == "sunrise.fill" && template.thumbnail.colorKey == "orange")
        let data = try TemplateFile.encode(template)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["format"] as? String == "daylog.templates" && json["version"] as? Int == 1)
        #expect((json["templates"] as? [[String: Any]])?.count == 1)
        #expect(Set(json.keys) == ["format", "version", "templates"])
        // 공식 템플릿 목록과 같은 문서라 같은 읽기 코드로도 읽힌다.
        #expect(try TemplateCatalog(data: data).templates == [template])
        #expect(try TemplateFile.decode(data) == template)
        #expect(TemplateFile.fileName(for: sample(title: "아침/저녁: 정리?")) == "Daylog 템플릿 - 아침 저녁  정리")
        // 올바르지 않은 템플릿은 파일로 만들지 않는다.
        #expect(throws: TemplateFileError.self) { try TemplateFile.encode(sample(title: " ")) }
        #expect(throws: TemplateFileError.self) { try TemplateFile.encode(sample(groups: [])) }
    }

    /// 파일에는 그룹 이름·색과 루틴의 이름·요일·시각(고르면 메모)만 들어간다. 개인 기록과 내부 ID는 없다.
    @Test func sharedFilesContainNoPersonalRecordsOrInternalIDs() throws {
        let env = try TestEnv()
        let store = appStore(env)
        let group = try #require(store.addGroup(title: "아침 루틴"))
        for title in ["물 한 잔", "약 먹기", "공유하지 않을 루틴", "보관한 루틴"] { store.addRoutine(title: title, in: group) }
        let routines = store.routines
        store.updateRoutine(routines[0], timeLabel: "07:00", weekdays: [1, 3, 5])
        store.updateRoutine(routines[1], note: "혈압약 5mg")
        store.setArchived(routines[3], true)
        store.setDone(routineID: routines[0].id, true)
        store.setSkipped(routineID: routines[1].id, true)
        store.setText("비밀 식단 메모", at: \.breakfast)
        store.flush()
        #expect(store.saveVacation(start: monday.adding(days: 3), end: monday.adding(days: 4), memo: "제주 여행"))
        #expect(store.saveDashboardText(id: UUID(), title: "나만 보는 다짐", body: "비밀"))

        let sources = TemplatePublishing.sources(groups: store.groups, routines: store.routines)
        #expect(sources.first?.routines.map(\.title) == ["물 한 잔", "약 먹기", "공유하지 않을 루틴"])
        // 루틴을 골라서 공유한다.
        let picked = TemplatePublishing.selected(sources, routineIDs: [routines[0].id, routines[1].id])
        #expect(picked.first?.routines.map(\.title) == ["물 한 잔", "약 먹기"])
        #expect(TemplatePublishing.selected(sources, routineIDs: []).isEmpty)

        let plain = TemplateFile.make(
            title: "내 아침", summary: "", category: .morning, tags: [], groups: TemplatePublishing.groups(from: picked, includesNotes: false)
        )
        let text = String(decoding: try TemplateFile.encode(plain), as: UTF8.self)
        #expect(text.contains("물 한 잔") && text.contains("07:00") && text.contains("아침 루틴"))
        // 메모는 포함한다고 하지 않으면 들어가지 않는다. 고르지 않은 루틴과 보관한 루틴도 없다.
        for absent in ["혈압약", "공유하지 않을 루틴", "보관한 루틴", "비밀 식단 메모", "제주 여행", "나만 보는 다짐", thisMac] {
            #expect(!text.contains(absent), "\(absent)")
        }
        // 그룹·루틴·체크·기록의 내부 ID가 하나도 없다.
        let records = try env.context.fetch(FetchDescriptor<DayRecord>())
        let internalIDs = store.groups.map(\.id) + store.routines.map(\.id) + store.checks.compactMap(\.syncID) + records.compactMap(\.syncID)
        for id in internalIDs { #expect(!text.lowercased().contains(id.uuidString.lowercased())) }

        // 칸은 정해진 것뿐이다.
        let json = try #require(try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        let template = try #require((json["templates"] as? [[String: Any]])?.first)
        #expect(Set(template.keys).isSubset(of: ["id", "source", "title", "summary", "category", "tags", "thumbnail", "author", "groups"]))
        #expect(template["author"] == nil)
        let first = try #require((template["groups"] as? [[String: Any]])?.first)
        #expect(Set(first.keys) == ["title", "colorKey", "routines"])
        let routine = try #require((first["routines"] as? [[String: Any]])?.first)
        #expect(Set(routine.keys) == ["title", "weekdays", "time", "note"])
        #expect(Set(try #require(template["thumbnail"] as? [String: Any]).keys) == ["symbol", "colorKey"])

        // 메모를 포함한다고 하면 고른 루틴의 메모만 더해진다.
        let noted = TemplateFile.make(
            title: "내 아침", summary: "", category: .morning, tags: [], groups: TemplatePublishing.groups(from: picked, includesNotes: true)
        )
        #expect(String(decoding: try TemplateFile.encode(noted), as: UTF8.self).contains("혈압약 5mg"))

        // 파일을 만드는 일은 내 루틴과 기록을 바꾸지 않는다.
        #expect(store.routines.map(\.id) == routines.map(\.id) && !env.context.hasChanges)
        #expect(store.checkSections.flatMap(\.checks).map(\.status) == [.done, .skipped, .pending])
    }

    // MARK: - 받은 파일 걸러 내기

    @Test func malformedOrForeignFilesAreRejectedSafely() throws {
        #expect(throws: TemplateFileError.unreadable) { try TemplateFile.decode(Data("템플릿이 아니다".utf8)) }
        #expect(throws: TemplateFileError.unreadable) { try TemplateFile.decode(Data()) }
        #expect(throws: TemplateFileError.unreadable) { try TemplateFile.decode(Data("[1,2,3]".utf8)) }
        #expect(throws: TemplateFileError.tooLarge) { try TemplateFile.decode(Data(count: TemplateFile.maximumBytes + 1)) }
        // 루틴 가져오기 파일이나 전체 백업은 템플릿이 아니다.
        let routinesFile = try RoutineTransferFormat.json([TransferRoutine(group: "그룹", title: "루틴", weekdays: [1], time: "", note: "")])
        #expect(throws: TemplateFileError.notATemplate) { try TemplateFile.decode(routinesFile) }
        // 더 새로운 버전의 파일은 읽지 않고 그렇게 알린다.
        #expect(throws: TemplateFileError.unsupportedVersion) { try TemplateFile.decode(try document { $0["version"] = 2 }) }
        #expect(throws: TemplateFileError.unreadable) { try TemplateFile.decode(try document { $0["version"] = 0 }) }
        // 템플릿이 없거나 여럿이면 받지 않는다.
        #expect(throws: TemplateFileError.wrongCount) { try TemplateFile.decode(try document { $0["templates"] = [[String: Any]]() }) }
        #expect(throws: TemplateFileError.wrongCount) {
            try TemplateFile.decode(try document { $0["templates"] = ($0["templates"] as! [[String: Any]]) + ($0["templates"] as! [[String: Any]]) })
        }
        // 칸이 빠졌거나 자료형이 다르면 읽지 않는다.
        #expect(throws: TemplateFileError.unreadable) {
            try TemplateFile.decode(try document { json in
                var templates = json["templates"] as! [[String: Any]]
                templates[0]["groups"] = "그룹"
                json["templates"] = templates
            })
        }
        // 모양은 맞지만 내용이 규칙에 어긋나면(요일 9) 까닭을 붙여 거절한다.
        let invalid = try document { json in
            var templates = json["templates"] as! [[String: Any]]
            templates[0]["groups"] = [["title": "그룹", "routines": [["title": "루틴", "weekdays": [9], "time": "", "note": ""]]]]
            json["templates"] = templates
        }
        #expect(throws: TemplateFileError.self) { try TemplateFile.decode(invalid) }
        #expect(TemplateFileError.unsupportedVersion.errorDescription?.contains("업데이트") == true)
    }

    @Test func receivedFilesCannotClaimAnotherSourceOrAppImages() throws {
        let data = try document { json in
            var templates = json["templates"] as! [[String: Any]]
            templates[0]["source"] = "official"
            templates[0]["thumbnail"] = ["symbol": "star.fill", "colorKey": "없는색", "imageName": "AppIcon"]
            templates[0]["author"] = "Daylog 공식"
            templates[0]["category"] = "travel"
            json["templates"] = templates
        }
        let template = try TemplateFile.decode(data)
        #expect(template.source == .file && template.thumbnail.imageName == nil)
        #expect(TemplateCard.sourceLabel(template) == "받은 파일")
        // 모르는 분류와 색은 기본값으로 읽는다.
        #expect(template.category == .lifestyle && GroupColor(key: template.thumbnail.colorKey) == .green)
        // 모르는 출처 이름도 받은 파일로 본다.
        let future = try document { json in
            var templates = json["templates"] as! [[String: Any]]
            templates[0]["source"] = "something-new"
            json["templates"] = templates
        }
        #expect(try TemplateFile.decode(future).source == .file)
    }

    // MARK: - 파일을 거쳐 다른 기기로

    @Test func aFileMadeOnOneDeviceImportsOnAnotherAndDuplicatesAreSkipped() throws {
        let senderEnv = try TestEnv(), receiverEnv = try TestEnv()
        let sender = appStore(senderEnv), receiver = appStore(receiverEnv, today: monday.adding(days: 2))
        let group = try #require(sender.addGroup(title: "저녁 루틴"))
        sender.addRoutine(title: "일기", in: group)
        sender.addRoutine(title: "내일 할 일 정리", in: group)
        sender.updateRoutine(try #require(sender.routines.first), timeLabel: "21:00", weekdays: [1, 2, 3, 4, 5])
        let sources = TemplatePublishing.sources(groups: sender.groups, routines: sender.routines)
        let shared = TemplateFile.make(
            title: "저녁 마무리", summary: "", category: .lifestyle, tags: [], groups: TemplatePublishing.groups(from: sources, includesNotes: false)
        )

        // 파일로 쓰고 다시 읽는다(다른 기기가 받는 것과 같다).
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).\(TemplateFile.fileExtension)")
        try TemplateFile.encode(shared).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let received = try TemplateFile.read(url)
        #expect(received == shared)

        // 받는 쪽에는 이미 같은 그룹에 같은 이름의 루틴이 하나 있고, 지난 기록도 있다.
        let existingGroup = try #require(receiver.addGroup(title: "저녁 루틴"))
        receiver.addRoutine(title: "일기", in: existingGroup)
        let mine = try #require(receiver.routines.first)
        receiver.setDone(routineID: mine.id, true)
        receiver.setText("받는 사람의 식사", at: \.dinner)
        receiver.flush()

        let preview = try receiver.previewTemplateImport(received)
        // 미리보기는 저장소를 건드리지 않는다.
        #expect(receiver.routines.count == 1)
        // 내 "일기"는 요일·시각이 달라도 건너뛰고(고치지 않는다), 새 루틴만 기존 그룹에 넣는다.
        #expect((preview.createdCount, preview.duplicateCount, preview.errorCount) == (1, 1, 0))
        #expect(receiver.confirmRoutineImport(preview))
        #expect(receiver.groups.count == 1 && receiver.routines.map(\.title) == ["일기", "내일 할 일 정리"])
        #expect(receiver.routines[0].id == mine.id && receiver.routines[0].timeLabel.isEmpty)
        #expect(receiver.checkSections.flatMap(\.checks).map(\.isDone) == [true, false])
        #expect(receiver.text(\.dinner) == "받는 사람의 식사")

        // 같은 파일을 다시 가져오면 추가할 것이 없다.
        let again = try receiver.previewTemplateImport(try TemplateFile.read(url))
        #expect(again.createdCount == 0 && again.duplicateCount == 2 && !again.canSave)
        #expect(!receiver.confirmRoutineImport(again))
        #expect(receiver.routines.count == 2)
        // 보낸 쪽의 루틴은 그대로다.
        #expect(sender.routines.map(\.title) == ["일기", "내일 할 일 정리"])
    }

    @Test func filesFromOtherAppsOpenAsAPreviewAndBadFilesShowAnError() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("daylog-tests-\(UUID().uuidString)/Inbox", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let inbox = TemplateInbox(inboxDirectory: directory)
        let good = directory.appendingPathComponent("받은 파일.daylogtemplate"), bad = directory.appendingPathComponent("깨진 파일.daylogtemplate")
        try TemplateFile.encode(sample()).write(to: good)
        try Data("{".utf8).write(to: bad)

        inbox.open(good)
        #expect(inbox.incoming?.title == "아침 시작" && inbox.error == nil)
        // 앱의 Inbox에 들어온 사본은 읽은 뒤 지운다.
        #expect(!FileManager.default.fileExists(atPath: good.path))

        inbox.open(bad)
        #expect(inbox.incoming == nil && inbox.error == TemplateFileError.unreadable.errorDescription)
        inbox.open(directory.appendingPathComponent("없는 파일.daylogtemplate"))
        #expect(inbox.incoming == nil && inbox.error != nil)
    }

    /// 사용자의 파일은 지우지 않는다: 폴더 이름이 Inbox여도, 앱이 넘겨받은 사본을 두는 폴더가 아니면 그대로 둔다.
    @Test func openingAUsersOwnFileNeverDeletesIt() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("daylog-tests-\(UUID().uuidString)", isDirectory: true)
        let appInbox = root.appendingPathComponent("App/Documents/Inbox", isDirectory: true)
        let userFolder = root.appendingPathComponent("User/Inbox", isDirectory: true)
        let nested = appInbox.appendingPathComponent("보관", isDirectory: true)
        for folder in [appInbox, userFolder, nested] { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) }
        let mine = userFolder.appendingPathComponent("내 템플릿.daylogtemplate"), deep = nested.appendingPathComponent("깊은 파일.daylogtemplate")
        try TemplateFile.encode(sample()).write(to: mine)
        try TemplateFile.encode(sample()).write(to: deep)

        // iOS처럼 사본 폴더가 정해져 있어도, 그 폴더 바로 안의 파일이 아니면 지우지 않는다.
        let phone = TemplateInbox(inboxDirectory: appInbox)
        phone.open(mine)
        phone.open(deep)
        #expect(phone.incoming != nil)
        #expect(FileManager.default.fileExists(atPath: mine.path) && FileManager.default.fileExists(atPath: deep.path))

        // macOS에는 사본 폴더가 없다: 무엇도 지우지 않는다.
        let mac = TemplateInbox(inboxDirectory: nil)
        mac.open(mine)
        #expect(mac.incoming?.title == "아침 시작" && FileManager.default.fileExists(atPath: mine.path))
        #if os(macOS)
        #expect(TemplateInbox.systemInbox == nil)
        #endif
    }

    /// 같은 파일이 두 경로로 연달아 들어와도 한 번만 처리한다. 사용자가 닫은 미리보기가 다시 뜨지 않는다.
    @Test func theSameFileArrivingTwiceInARowIsHandledOnce() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).daylogtemplate")
        try TemplateFile.encode(sample()).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let inbox = TemplateInbox(inboxDirectory: nil)
        let start = Date()
        inbox.open(url, now: start)
        #expect(inbox.incoming != nil)
        inbox.incoming = nil
        inbox.open(url, now: start.addingTimeInterval(0.3))
        #expect(inbox.incoming == nil)
        // 조금 뒤에 다시 열면 다시 보여 준다.
        inbox.open(url, now: start.addingTimeInterval(5))
        #expect(inbox.incoming != nil)
    }

    /// 지울지는 그 항목이 놓인 폴더로 정한다. 사본 폴더 밖에 있는 바로가기는 사본을 가리키더라도 지우지 않는다.
    @Test func linksAreJudgedByWhereTheyLiveNotWhereTheyPoint() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("daylog-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let appInbox = root.appendingPathComponent("App/Documents/Inbox", isDirectory: true)
        let userFolder = root.appendingPathComponent("User", isDirectory: true)
        for folder in [appInbox, userFolder] { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) }
        let copy = appInbox.appendingPathComponent("받은 파일.daylogtemplate")
        let mine = userFolder.appendingPathComponent("내 파일.daylogtemplate")
        try TemplateFile.encode(sample()).write(to: copy)
        try TemplateFile.encode(sample()).write(to: mine)
        let outsideLink = userFolder.appendingPathComponent("바로가기.daylogtemplate")
        let insideLink = appInbox.appendingPathComponent("밖을 가리킴.daylogtemplate")
        try FileManager.default.createSymbolicLink(at: outsideLink, withDestinationURL: copy)
        try FileManager.default.createSymbolicLink(at: insideLink, withDestinationURL: mine)
        func exists(_ url: URL) -> Bool { (try? FileManager.default.attributesOfItem(atPath: url.path)) != nil }

        // 밖에 있는 바로가기: 읽기만 하고, 바로가기도 그것이 가리키는 사본도 그대로 둔다.
        let inbox = TemplateInbox(inboxDirectory: appInbox)
        inbox.open(outsideLink)
        #expect(inbox.incoming != nil)
        #expect(exists(outsideLink) && exists(copy))

        // 사본 폴더 안의 바로가기: 바로가기만 지우고, 그것이 가리키는 사용자의 파일은 남긴다.
        inbox.open(insideLink)
        #expect(inbox.incoming != nil)
        #expect(!exists(insideLink) && exists(mine))
    }

    /// 같은 이름의 다른 파일이 곧바로 들어오면 새 파일로 다룬다(앞의 사본은 이미 지워졌다).
    @Test func aDifferentFileAtTheSamePathRightAfterIsANewFile() throws {
        let appInbox = FileManager.default.temporaryDirectory.appendingPathComponent("daylog-tests-\(UUID().uuidString)/Inbox", isDirectory: true)
        try FileManager.default.createDirectory(at: appInbox, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: appInbox.deletingLastPathComponent()) }
        let url = appInbox.appendingPathComponent("템플릿.daylogtemplate")
        let inbox = TemplateInbox(inboxDirectory: appInbox)
        let start = Date()

        try TemplateFile.encode(sample()).write(to: url)
        inbox.open(url, now: start)
        #expect(inbox.incoming?.title == "아침 시작")
        #expect(!FileManager.default.fileExists(atPath: url.path), "읽은 사본은 지운다.")

        // 같은 알림이 한 번 더 온다(파일은 이미 없다): 오류를 띄우지 않고 넘어간다.
        inbox.incoming = nil
        inbox.open(url, now: start.addingTimeInterval(0.2))
        #expect(inbox.incoming == nil && inbox.error == nil)

        // 같은 이름으로 다른 파일이 바로 들어온다: 새 파일로 미리보기에 올리고, 그 사본도 지운다.
        var other = sample()
        other.title = "저녁 마무리"
        try TemplateFile.encode(other).write(to: url)
        inbox.open(url, now: start.addingTimeInterval(0.6))
        #expect(inbox.incoming?.title == "저녁 마무리")
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    /// 공유 기능이 더해져도 공식 템플릿과 꺼 둔 서버 기능은 그대로다.
    @Test func officialTemplatesStayAndTheCommunityServerStaysOff() {
        #expect(TemplateCatalog.official.templates.count == 11)
        #expect(TemplateCatalog.official.templates.allSatisfy { $0.source == .official })
        #expect(CommunityConfiguration(info: Bundle.main.infoDictionary ?? [:]) == nil)
        #expect(UTType.daylogTemplate.conforms(to: .json))
    }
}
