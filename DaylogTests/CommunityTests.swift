import Foundation
import SwiftData
import Testing
@testable import Daylog

/// Phase 5-D1: 공개 템플릿의 앱 쪽 기반. 게시 내용에 개인 기록이 섞이지 않는지, 서버로 가는 요청의 모양,
/// 로그인 정보 처리, 게시·관리·신고·차단의 흐름, 네트워크가 끊겼을 때를 본다.
///
/// 여기의 서버는 가짜다(`StubTransport`, `MockCommunityBackend`). 실제 서버의 권한(행 수준 보안)은 이 테스트로 검증되지 않는다.
@MainActor
struct CommunityTests {
    // MARK: - 도구

    /// 보낸 요청을 적어 두고, 미리 넣어 둔 응답을 차례로 돌려주는 가짜 전송.
    final class StubTransport: CommunityTransport, @unchecked Sendable {
        struct Reply {
            var status = 200
            var json: Any = [[String: Any]]()
        }

        private(set) var requests: [URLRequest] = []
        var replies: [Reply] = []
        var failure: Error?

        func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
            requests.append(request)
            if let failure { throw failure }
            let reply = replies.isEmpty ? Reply() : replies.removeFirst()
            let data = try JSONSerialization.data(withJSONObject: reply.json)
            return (data, HTTPURLResponse(url: request.url!, statusCode: reply.status, httpVersion: nil, headerFields: nil)!)
        }

        func body(_ index: Int) -> [String: Any] {
            (requests[index].httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]) ?? [:]
        }

        func query(_ index: Int) -> [String: String] {
            let items = URLComponents(url: requests[index].url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
        }
    }

    private let anonKey = "public-anon-key"
    private let me = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let other = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private let third = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    private let fourth = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!

    private var configuration: CommunityConfiguration {
        CommunityConfiguration(baseURL: URL(string: "https://daylog.example.test")!, anonKey: anonKey)
    }

    private func session(_ user: UUID, expiresIn: TimeInterval = 3_600) -> CommunitySession {
        CommunitySession(userID: user, accessToken: "access-\(user.uuidString.suffix(1))", refreshToken: "refresh", expiresAt: Date().addingTimeInterval(expiresIn))
    }

    private func supabase(_ transport: StubTransport, session: CommunitySession? = nil) -> (SupabaseCommunityBackend, MemorySessionStore) {
        let store = MemorySessionStore(session)
        return (SupabaseCommunityBackend(configuration: configuration, transport: transport, sessions: store), store)
    }

    private func draft(
        _ title: String = "아침 시작", visibility: TemplateVisibility = .public,
        groups: [RoutineTemplate.Group] = [.init(title: "아침", colorKey: "orange", routines: [.init(title: "물 한 잔", time: "07:00")])]
    ) -> TemplateDraft {
        TemplateDraft(
            title: title, summary: "가볍게", category: .morning, tags: ["아침"],
            thumbnail: TemplateThumbnail(symbol: "sunrise.fill", colorKey: "orange"), authorName: "규빈", groups: groups, visibility: visibility
        )
    }

    private func row(id: UUID = UUID(), author: UUID, title: String = "아침 시작", visibility: String = "public", moderation: String = "active") -> [String: Any] {
        [
            "id": id.uuidString.lowercased(), "author_id": author.uuidString.lowercased(), "author_name": "규빈", "title": title,
            "summary": "가볍게", "category": "morning", "tags": ["아침"],
            "thumbnail": ["symbol": "sunrise.fill", "colorKey": "orange"],
            "content": TemplateDraft.content([.init(title: "아침", colorKey: "orange", routines: [.init(title: "물 한 잔", time: "07:00")])]),
            "visibility": visibility, "moderation": moderation,
            "created_at": "2026-10-13T09:00:00.123456+00:00", "updated_at": "2026-10-13T09:00:00+00:00"
        ]
    }

    private func store(_ server: MockCommunityServer, user: UUID?) -> CommunityStore {
        CommunityStore(backend: MockCommunityBackend(server: server, userID: user), isMock: true)
    }

    private func appStore(_ env: TestEnv) -> AppStore {
        let clock = TestClock(monday)
        let store = AppStore(container: env.container, deviceID: thisMac, clock: { clock.today })
        store.start()
        return store
    }

    // MARK: - 설정

    @Test func communityIsOffUnlessFullyConfiguredAndNeverAcceptsAServiceRoleKey() {
        #expect(CommunityConfiguration(info: [:]) == nil)
        #expect(CommunityConfiguration(info: [CommunityConfiguration.urlKey: "https://x.supabase.co"]) == nil)
        #expect(CommunityConfiguration(info: [CommunityConfiguration.urlKey: "http://x.supabase.co", CommunityConfiguration.anonKeyKey: "k"]) == nil)
        let ok = CommunityConfiguration(info: [CommunityConfiguration.urlKey: "https://x.supabase.co", CommunityConfiguration.anonKeyKey: "sb_publishable_abc"])
        #expect(ok?.anonKey == "sb_publishable_abc" && ok?.allowsAppleSignIn == false)

        func jwt(_ role: String) -> String {
            let payload = try! JSONSerialization.data(withJSONObject: ["role": role, "iss": "supabase"]).base64EncodedString()
                .replacingOccurrences(of: "=", with: "").replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            return "eyJhbGciOiJIUzI1NiJ9.\(payload).signature"
        }
        #expect(!CommunityConfiguration.isServiceRoleKey(jwt("anon")))
        #expect(CommunityConfiguration.isServiceRoleKey(jwt("service_role")))
        #expect(CommunityConfiguration.isServiceRoleKey("sb_secret_abc"))
        // 비밀 키가 설정에 들어와 있으면 공개 템플릿 기능을 켜지 않는다.
        #expect(CommunityConfiguration(info: [CommunityConfiguration.urlKey: "https://x.supabase.co", CommunityConfiguration.anonKeyKey: jwt("service_role")]) == nil)
        // 이 저장소의 앱 설정에는 서버 주소와 키가 들어 있지 않다(준비되기 전까지 기능이 꺼져 있다).
        #expect(CommunityStore(backend: nil).isAvailable == false)
    }

    // MARK: - 게시 내용과 개인 기록

    /// 게시 내용에는 그룹 이름·색과 루틴의 이름·요일·시각(고르면 설명)만 들어간다.
    @Test func publishedContentCarriesRoutineDefinitionsOnlyAndNoPersonalRecords() throws {
        let env = try TestEnv()
        let store = appStore(env)
        let group = try #require(store.addGroup(title: "아침 루틴"))
        store.addRoutine(title: "물 한 잔", in: group)
        store.addRoutine(title: "병원 약 먹기", in: group)
        store.addRoutine(title: "보관한 루틴", in: group)
        let routines = store.routines
        store.updateRoutine(routines[0], timeLabel: "07:00", weekdays: [1, 3, 5])
        store.updateRoutine(routines[1], note: "혈압약 5mg")
        store.setArchived(routines[2], true)
        // 개인 기록을 여러 가지 만들어 둔다.
        store.setDone(routineID: routines[0].id, true)
        store.setSkipped(routineID: routines[1].id, true)
        store.setText("비밀 식단 메모", at: \.breakfast)
        store.flush()
        #expect(store.saveVacation(start: monday.adding(days: 3), end: monday.adding(days: 4), memo: "제주 여행"))
        #expect(store.saveDashboardText(id: UUID(), title: "나만 보는 다짐", body: "비밀"))

        let sources = TemplatePublishing.sources(groups: store.groups, routines: store.routines)
        #expect(sources.map(\.title) == ["아침 루틴"])
        // 보관한 루틴은 올리지 않는다.
        #expect(sources[0].routines.map(\.title) == ["물 한 잔", "병원 약 먹기"])

        let withoutNotes = draft(groups: TemplatePublishing.groups(from: sources, includesNotes: false))
        let json = TemplatePublishing.previewJSON(withoutNotes.cleaned)
        // 설명은 포함하겠다고 하지 않으면 올라가지 않는다.
        #expect(!json.contains("혈압약"))
        #expect(json.contains("물 한 잔") && json.contains("07:00"))
        for secret in ["비밀 식단 메모", "제주 여행", "나만 보는 다짐", thisMac] { #expect(!json.contains(secret)) }
        // 내부 식별자(그룹·루틴 ID, 동기화 ID)가 하나도 실리지 않는다.
        for id in store.groups.map(\.id) + store.routines.map(\.id) + store.checks.compactMap(\.syncID) {
            #expect(!json.lowercased().contains(id.uuidString.lowercased()))
        }
        // 칸은 정해진 것뿐이다.
        let payload = withoutNotes.cleaned.payload()
        #expect(Set(payload.keys) == ["author_name", "title", "summary", "category", "tags", "thumbnail", "content", "visibility"])
        let content = try #require(payload["content"] as? [String: Any])
        #expect(Set(content.keys) == ["groups"])
        let first = try #require((content["groups"] as? [[String: Any]])?.first)
        #expect(Set(first.keys) == ["title", "colorKey", "routines"])
        let routine = try #require((first["routines"] as? [[String: Any]])?.first)
        #expect(Set(routine.keys) == ["title", "weekdays", "time", "note"])
        #expect(routine["weekdays"] as? [Int] == [1, 3, 5])

        // 설명을 포함하겠다고 하면 그 설명만 더해진다.
        let withNotes = draft(groups: TemplatePublishing.groups(from: sources, includesNotes: true))
        #expect(TemplatePublishing.previewJSON(withNotes).contains("혈압약 5mg"))
    }

    @Test func draftsAreCleanedAndValidatedLikeOfficialTemplates() {
        var messy = draft("  아침 시작  ")
        messy.tags = [" 아침 ", "", "아침", "스트레칭"]
        messy.authorName = String(repeating: "가", count: 40)
        messy.thumbnail.imageName = "local-photo"
        let cleaned = messy.cleaned
        #expect(cleaned.title == "아침 시작" && cleaned.tags == ["아침", "스트레칭"])
        #expect(cleaned.authorName.count == TemplateDraft.authorNameLimit && cleaned.thumbnail.imageName == nil)
        #expect(cleaned.validationError == nil)
        #expect(draft(groups: []).validationError != nil)
        #expect(draft("").validationError != nil)
        #expect(draft(groups: [.init(title: "그룹", routines: [.init(title: "루틴", weekdays: [9])])]).validationError != nil)
    }

    // MARK: - 서버 응답 읽기

    @Test func serverRowsAreParsedAndInvalidOnesAreDropped() throws {
        let id = UUID()
        let template = try #require(CommunityTemplate(row: row(id: id, author: other)))
        #expect(template.id == id && template.authorID == other && template.displayAuthor == "규빈")
        #expect(template.groups.first?.routines.first?.time == "07:00" && template.groups.first?.colorKey == "orange")
        #expect(template.isListed && template.statusLabel == "공개")
        // 탐색 화면이 쓰는 공통 모양으로 바뀐다.
        #expect(template.template.id == "community.\(id.uuidString)" && template.template.source == .community)
        #expect(CommunityTemplate.id(fromTemplateID: template.template.id) == id)
        #expect(CommunityTemplate.id(fromTemplateID: "official.morning-light") == nil)
        // 소수 초의 자릿수가 달라도 시각을 읽는다.
        #expect(CommunityTemplate.date("2026-10-13T09:00:00.123456+00:00") == CommunityTemplate.date("2026-10-13T09:00:00+00:00"))
        #expect(CommunityTemplate.date("2026-10-13T09:00:00Z") != nil)

        var broken = row(author: other)
        broken["content"] = ["groups": [["title": "그룹", "routines": [["title": "루틴", "weekdays": [9]]]]]]
        #expect(CommunityTemplate(row: broken) == nil)
        var missing = row(author: other)
        missing["author_id"] = nil
        #expect(CommunityTemplate(row: missing) == nil)
        #expect(CommunityTemplate(row: row(author: other, visibility: "private")).map(\.statusLabel) == "비공개")
        #expect(CommunityTemplate(row: row(author: other, moderation: "under_review")).map(\.statusLabel) == "검토 중")
        #expect(CommunityTemplate(row: row(author: other, moderation: "removed")).map(\.isListed) == false)
    }

    // MARK: - 서버로 가는 요청 (가짜 전송)

    @Test func browsingNeedsNoSignInAndAsksOnlyForListedTemplates() async throws {
        let transport = StubTransport()
        transport.replies = [.init(json: [row(author: other)])]
        let (backend, _) = supabase(transport)
        let templates = try await backend.publicTemplates()
        #expect(templates.count == 1)

        let request = try #require(transport.requests.first)
        #expect(request.httpMethod == "GET" && request.url?.path == "/rest/v1/templates" && request.url?.scheme == "https")
        #expect(request.value(forHTTPHeaderField: "apikey") == anonKey)
        // 로그인하지 않았으면 공개 키로 읽는다.
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer \(anonKey)")
        let query = transport.query(0)
        #expect(query["visibility"] == "eq.public" && query["moderation"] == "eq.active")
        #expect(query["select"] == SupabaseCommunityBackend.columns)
        #expect(!SupabaseCommunityBackend.columns.contains("report_count") && !SupabaseCommunityBackend.columns.contains("*"))
    }

    @Test func writingRequiresASessionAndNeverSendsAnAuthorID() async throws {
        let transport = StubTransport()
        let (anonymous, _) = supabase(transport)
        await #expect(throws: CommunityError.signInRequired) { try await anonymous.publish(draft()) }
        await #expect(throws: CommunityError.signInRequired) { try await anonymous.report(UUID(), reason: .spam, detail: "") }
        await #expect(throws: CommunityError.signInRequired) { try await anonymous.block(other) }
        // 로그인하지 않았으면 요청 자체를 보내지 않는다.
        #expect(transport.requests.isEmpty)

        transport.replies = [.init(status: 201, json: [row(author: me)])]
        let (backend, _) = supabase(transport, session: session(me))
        let saved = try await backend.publish(draft())
        #expect(saved.authorID == me)
        let request = try #require(transport.requests.first)
        #expect(request.httpMethod == "POST" && request.url?.path == "/rest/v1/templates")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer \(session(me).accessToken)")
        #expect(request.value(forHTTPHeaderField: "Prefer") == "return=representation")
        let body = transport.body(0)
        // 게시자·운영 상태·신고 수는 서버가 정한다. 앱은 보내지 않는다.
        for forbidden in ["author_id", "moderation", "report_count", "id", "created_at"] { #expect(body[forbidden] == nil) }
        #expect(body["title"] as? String == "아침 시작" && body["visibility"] as? String == "public")
    }

    @Test func serverRefusalsBecomeReadableErrors() async throws {
        let transport = StubTransport()
        let (backend, _) = supabase(transport, session: session(me))
        // 남의 것을 고치려 하면 서버는 0줄을 돌려준다.
        transport.replies = [.init(json: [[String: Any]]())]
        await #expect(throws: CommunityError.notFound) { try await backend.update(UUID(), with: draft()) }
        transport.replies = [.init(json: [[String: Any]]())]
        await #expect(throws: CommunityError.notFound) { try await backend.delete(UUID()) }
        // 같은 템플릿을 두 번 신고하면 유일성 제약에 걸린다.
        transport.replies = [.init(status: 409, json: ["code": "23505", "message": "duplicate key"])]
        await #expect(throws: CommunityError.alreadyReported) { try await backend.report(UUID(), reason: .spam, detail: "") }
        transport.replies = [.init(status: 400, json: ["code": "P0001", "message": "report limit reached", "hint": "limit_reached"])]
        await #expect(throws: CommunityError.limitReached) { try await backend.report(UUID(), reason: .spam, detail: "") }
        transport.replies = [.init(status: 403, json: ["code": "42501", "message": "permission denied"])]
        await #expect(throws: CommunityError.forbidden) { try await backend.publish(draft()) }
        transport.replies = [.init(status: 400, json: ["code": "22023", "message": "invalid template: routine has unknown fields"])]
        await #expect(throws: CommunityError.self) { try await backend.publish(draft()) }
        // 이미 차단한 게시자를 또 차단해도 오류가 아니다.
        transport.replies = [.init(status: 409, json: ["code": "23505"])]
        try await backend.block(other)
        #expect(SupabaseCommunityBackend.error(status: 500, data: Data("{}".utf8)) == .server("HTTP 500"))
    }

    @Test func networkFailuresAreReportedAsSuch() async throws {
        let transport = StubTransport()
        transport.failure = URLError(.notConnectedToInternet)
        let (backend, sessions) = supabase(transport, session: session(me))
        await #expect(throws: CommunityError.network) { try await backend.publicTemplates() }
        await #expect(throws: CommunityError.network) { try await backend.publish(draft()) }
        // 네트워크 오류로 로그인 정보를 지우지는 않는다.
        #expect(sessions.load() != nil)
        // 로그아웃은 서버에 닿지 못해도 이 기기의 로그인 정보를 지운다.
        await backend.signOut()
        #expect(sessions.load() == nil)
    }

    // MARK: - 로그인 정보

    @Test func appleSignInExchangesTheTokenAndKeepsTheSessionInTheStore() async throws {
        let transport = StubTransport()
        transport.replies = [.init(json: [
            "access_token": "new-access", "refresh_token": "new-refresh", "expires_in": 3_600, "token_type": "bearer",
            "user": ["id": me.uuidString.lowercased()]
        ])]
        let (backend, sessions) = supabase(transport)
        try await backend.signIn(appleIDToken: "apple-id-token", nonce: "raw-nonce")
        let request = try #require(transport.requests.first)
        #expect(request.url?.path == "/auth/v1/token" && transport.query(0)["grant_type"] == "id_token")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer \(anonKey)")
        let body = transport.body(0)
        #expect(body["provider"] as? String == "apple" && body["id_token"] as? String == "apple-id-token" && body["nonce"] as? String == "raw-nonce")
        #expect(sessions.load()?.userID == me && sessions.load()?.accessToken == "new-access")
        #expect(await backend.currentUserID == me)
    }

    @Test func expiringSessionsAreRefreshedAndRejectedOnesAreCleared() async throws {
        let transport = StubTransport()
        transport.replies = [
            .init(json: ["access_token": "fresh", "refresh_token": "next", "expires_in": 3_600, "user": ["id": me.uuidString]]),
            .init(json: [row(author: me)])
        ]
        let (backend, sessions) = supabase(transport, session: session(me, expiresIn: 10))
        _ = try await backend.myTemplates()
        #expect(transport.query(0)["grant_type"] == "refresh_token" && transport.body(0)["refresh_token"] as? String == "refresh")
        #expect(transport.requests[1].value(forHTTPHeaderField: "Authorization") == "Bearer fresh")
        #expect(sessions.load()?.refreshToken == "next")
        #expect(transport.query(1)["author_id"] == "eq.\(me.uuidString.lowercased())")

        // 갱신 토큰이 거절되면 로그인 정보를 지우고 다시 로그인하게 한다. 탐색은 공개 키로 계속된다.
        let rejected = StubTransport()
        rejected.replies = [.init(status: 400, json: ["error_description": "Invalid Refresh Token"]), .init(json: [row(author: other)])]
        let (expired, expiredSessions) = supabase(rejected, session: session(me, expiresIn: -100))
        await #expect(throws: CommunityError.signInRequired) { try await expired.myTemplates() }
        #expect(expiredSessions.load() == nil)
        #expect(try await expired.publicTemplates().count == 1)
        #expect(rejected.requests.last?.value(forHTTPHeaderField: "Authorization") == "Bearer \(anonKey)")
    }

    @Test func nonceIsRandomAndHashedForApple() {
        let first = CommunityAccountSection.randomNonce(), second = CommunityAccountSection.randomNonce()
        #expect(first.count == 32 && first != second)
        #expect(CommunityAccountSection.sha256("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    // MARK: - 게시·관리 흐름 (시험용 서버)

    @Test func browsingWorksSignedOutButPublishingDoesNot() async throws {
        let server = MockCommunityServer.seeded()
        let visitor = store(server, user: nil)
        await visitor.refresh()
        #expect(visitor.loadState == .loaded && !visitor.isSignedIn)
        #expect(visitor.catalogTemplates.count == 3)
        #expect(visitor.catalogTemplates.allSatisfy { $0.source == .community && $0.validationError == nil })
        await #expect(throws: CommunityError.signInRequired) { try await visitor.publish(draft()) }
        #expect(server.templates.count == 3)

        try await visitor.signIn(appleIDToken: me.uuidString, nonce: "")
        #expect(visitor.isSignedIn && visitor.userID == me)
        let saved = try await visitor.publish(draft())
        #expect(saved.authorID == me && visitor.myTemplates.map(\.id) == [saved.id])
        #expect(visitor.isMine(saved))
    }

    @Test func privateTemplatesAreInvisibleToOthersAndVisibilityCanBeSwitched() async throws {
        let server = MockCommunityServer()
        let mine = store(server, user: me), theirs = store(server, user: other)
        let hidden = try await mine.publish(draft("비공개 초안", visibility: .private))
        await theirs.refresh()
        #expect(theirs.catalogTemplates.isEmpty)
        #expect(mine.myTemplates.first?.statusLabel == "비공개")

        try await mine.setVisibility(.public, for: hidden)
        await theirs.refresh()
        #expect(theirs.catalogTemplates.map(\.title) == ["비공개 초안"])
        try await mine.setVisibility(.private, for: try #require(mine.myTemplates.first))
        await theirs.refresh()
        #expect(theirs.catalogTemplates.isEmpty && mine.myTemplates.count == 1)
    }

    @Test func onlyTheAuthorCanEditOrDelete() async throws {
        let server = MockCommunityServer()
        let mine = store(server, user: me), theirs = store(server, user: other)
        let saved = try await mine.publish(draft())
        await theirs.refresh()
        await #expect(throws: CommunityError.notFound) { try await theirs.publish(draft("가로채기"), replacing: saved.id) }
        await #expect(throws: CommunityError.notFound) { try await theirs.delete(saved) }
        #expect(server.templates.map(\.title) == ["아침 시작"])

        let edited = try await mine.publish(draft("고친 제목"), replacing: saved.id)
        #expect(edited.id == saved.id && edited.authorID == me && server.templates.map(\.title) == ["고친 제목"])
        try await mine.delete(edited)
        #expect(server.templates.isEmpty && mine.myTemplates.isEmpty)
    }

    /// 게시물은 게시한 때의 사본이다. 내 루틴을 바꿔도 따라 바뀌지 않고, 게시물을 지워도 가져간 사람의 루틴은 남는다.
    @Test func publishedTemplatesAreSnapshotsAndImportsSurviveDeletion() async throws {
        let authorEnv = try TestEnv(), readerEnv = try TestEnv()
        let author = appStore(authorEnv), reader = appStore(readerEnv)
        let group = try #require(author.addGroup(title: "아침 루틴"))
        author.addRoutine(title: "물 한 잔", in: group)
        let server = MockCommunityServer()
        let mine = store(server, user: me), theirs = store(server, user: other)

        let sources = TemplatePublishing.sources(groups: author.groups, routines: author.routines)
        let saved = try await mine.publish(draft(groups: TemplatePublishing.groups(from: sources, includesNotes: false)))
        // 게시한 뒤 내 루틴을 고치고 더한다.
        author.updateRoutine(try #require(author.routines.first), title: "따뜻한 물 한 잔")
        author.addRoutine(title: "새 루틴", in: group)
        await mine.refresh()
        #expect(mine.myTemplates.first?.groups.first?.routines.map(\.title) == ["물 한 잔"])

        // 다른 사람이 기존 가져오기 서비스로 가져간다.
        await theirs.refresh()
        let shared = try #require(theirs.catalogTemplates.first)
        let preview = try reader.previewTemplateImport(shared)
        #expect(preview.createdCount == 1 && preview.policy == .skipConflicts)
        #expect(reader.confirmRoutineImport(preview))
        #expect(reader.routines.map(\.title) == ["물 한 잔"])

        // 게시물을 지워도 가져간 루틴은 그대로다.
        try await mine.delete(saved)
        await theirs.refresh()
        #expect(theirs.catalogTemplates.isEmpty)
        #expect(reader.routines.map(\.title) == ["물 한 잔"])
        // 게시와 삭제는 게시자의 루틴도 건드리지 않는다.
        #expect(author.routines.map(\.title) == ["따뜻한 물 한 잔", "새 루틴"])
    }

    // MARK: - 신고와 차단

    @Test func reportsAreOnePerPersonAndThreeHideTheTemplatePendingReview() async throws {
        let server = MockCommunityServer()
        let author = store(server, user: me)
        let saved = try await author.publish(draft())
        let reporters = [other, third, fourth].map { store(server, user: $0) }
        for reporter in reporters { await reporter.refresh() }

        // 로그인하지 않으면 신고할 수 없고, 내 것은 신고할 수 없다.
        let visitor = store(server, user: nil)
        await #expect(throws: CommunityError.signInRequired) { try await visitor.report(saved, reason: .spam, detail: "") }
        await #expect(throws: CommunityError.self) { try await author.report(saved, reason: .spam, detail: "") }

        try await reporters[0].report(saved, reason: .spam, detail: "광고")
        await #expect(throws: CommunityError.alreadyReported) { try await reporters[0].report(saved, reason: .other, detail: "") }
        try await reporters[1].report(saved, reason: .inappropriate, detail: "")
        #expect(reporters[1].catalogTemplates.count == 1)
        try await reporters[2].report(saved, reason: .personalInfo, detail: "")
        // 세 사람이 신고하면 검토가 끝날 때까지 목록에서 빠진다. 게시자는 그 상태를 본다.
        #expect(reporters[2].catalogTemplates.isEmpty)
        await author.refresh()
        #expect(author.myTemplates.first?.moderation == .underReview && author.myTemplates.first?.statusLabel == "검토 중")
        #expect(MyTemplatesSheet.statusNote(try #require(author.myTemplates.first)) != nil)
        // 게시자가 고쳐도 운영 상태는 풀리지 않는다.
        _ = try await author.publish(draft("고친 제목"), replacing: saved.id)
        #expect(author.myTemplates.first?.moderation == .underReview)
    }

    @Test func blockingHidesAnAuthorAndCanBeUndone() async throws {
        let server = MockCommunityServer.seeded()
        let reader = store(server, user: me)
        await reader.refresh()
        let target = try #require(reader.publicTemplates.first { $0.authorName == "아나" })
        #expect(reader.catalogTemplates.count == 3)

        try await reader.block(target.authorID)
        #expect(reader.blockedAuthors == [target.authorID])
        #expect(reader.catalogTemplates.map(\.title) == ["주말 등산"])
        // 다른 사람의 목록에는 영향이 없다.
        let someoneElse = store(server, user: other)
        await someoneElse.refresh()
        #expect(someoneElse.catalogTemplates.count == 3)

        try await reader.unblock(target.authorID)
        #expect(reader.blockedAuthors.isEmpty && reader.catalogTemplates.count == 3)
        // 로그인하지 않으면 차단할 수 없다.
        let visitor = store(server, user: nil)
        await #expect(throws: CommunityError.signInRequired) { try await visitor.block(target.authorID) }
    }

    // MARK: - 네트워크 오류, 로그아웃, 개인 기록

    @Test func officialTemplatesAndPersonalRecordsWorkWithoutTheServer() async throws {
        let env = try TestEnv()
        let app = appStore(env)
        let server = MockCommunityServer.seeded()
        server.isOffline = true
        let community = store(server, user: nil)
        await community.refresh()
        guard case .failed(let message) = community.loadState else {
            Issue.record("오프라인이면 실패 상태여야 한다")
            return
        }
        #expect(message.contains("공식 템플릿"))
        #expect(community.catalogTemplates.isEmpty)
        // 탐색 화면의 목록: 공식 템플릿은 그대로다.
        let catalog = TemplateCatalog(templates: TemplateCatalog.official.templates + community.catalogTemplates)
        #expect(catalog.templates.count == OfficialTemplates.all.count)
        // 공식 템플릿 가져오기와 개인 기록도 그대로 동작한다.
        let official = try #require(catalog.templates.first)
        #expect(app.confirmRoutineImport(try app.previewTemplateImport(official)))
        app.setDone(routineID: try #require(app.routines.first).id, true)
        #expect(app.stats.today.done == 1)
        await #expect(throws: CommunityError.network) { try await community.signIn(appleIDToken: "demo", nonce: "") }

        // 다시 연결되면 목록이 채워진다.
        server.isOffline = false
        await community.refresh()
        #expect(community.loadState == .loaded && community.catalogTemplates.count == 3)
    }

    @Test func signingOutOrDeletingTheAccountLeavesPersonalDataUntouched() async throws {
        let env = try TestEnv()
        let app = appStore(env)
        let group = try #require(app.addGroup(title: "아침 루틴"))
        app.addRoutine(title: "물 한 잔", in: group)
        app.setDone(routineID: try #require(app.routines.first).id, true)
        app.setText("토스트", at: \.breakfast)
        app.flush()
        #expect(app.saveVacation(start: monday.adding(days: 2), end: monday.adding(days: 2)))
        let routines = app.routines.map(\.id), stats = app.stats, vacations = app.vacationPeriods
        let fieldEdits = try env.context.fetchCount(FetchDescriptor<FieldEdit>())

        let server = MockCommunityServer()
        let community = store(server, user: me)
        _ = try await community.publish(draft())
        await community.signOut()
        #expect(!community.isSignedIn && community.myTemplates.isEmpty)
        // 로그아웃해도 올려 둔 템플릿은 서버에 남는다.
        #expect(server.templates.count == 1)

        try await community.signIn(appleIDToken: me.uuidString, nonce: "")
        try await community.deleteAccount()
        #expect(!community.isSignedIn && server.templates.isEmpty)

        // 개인 기록은 그대로이고, 공유 기능은 기록 저장소에 아무것도 쓰지 않았다.
        #expect(app.routines.map(\.id) == routines && app.stats == stats && app.vacationPeriods == vacations)
        #expect(app.text(\.breakfast) == "토스트")
        #expect(try env.context.fetchCount(FetchDescriptor<FieldEdit>()) == fieldEdits)
        #expect(try DayRecordService(context: env.freshContext()).record(on: monday)?.breakfast == "토스트")
    }

    @Test func whatTheServerReceivesIsExactlyThePreviewedPayload() async throws {
        let server = MockCommunityServer()
        let community = store(server, user: me)
        let draft = draft()
        _ = try await community.publish(draft)
        let received = try #require(server.receivedPayloads.first)
        let previewed = try #require(try JSONSerialization.jsonObject(with: Data(TemplatePublishing.previewJSON(draft.cleaned).utf8)) as? [String: Any])
        #expect(NSDictionary(dictionary: received).isEqual(to: previewed))
    }
}
