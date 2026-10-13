#if DEBUG
import Foundation

/// 시험용 서버. 메모리에만 있고, 서버의 행 수준 보안과 같은 규칙을 흉내 낸다(내 것만 고치고 지운다, 공개·정상만 남에게 보인다,
/// 한 사람은 한 번만 신고한다, 차단한 게시자는 목록에서 빠진다). 실제 서버의 권한을 검증하는 것은 아니다:
/// 그 검증은 `supabase/tests/community_rls_test.sql`이 맡는다.
@MainActor
final class MockCommunityServer {
    struct Report: Equatable {
        var templateID: UUID
        var reporterID: UUID
        var reason: ReportReason
    }

    var templates: [CommunityTemplate] = []
    var reports: [Report] = []
    var blocks: [UUID: Set<UUID>] = [:]
    /// 켜면 모든 요청이 네트워크 오류로 끝난다.
    var isOffline = false
    /// 서버가 받은 게시 내용(무엇이 서버로 가는지 확인하는 데 쓴다).
    var receivedPayloads: [[String: Any]] = []
    var now: () -> Date = { .now }

    static let reviewThreshold = 3

    /// 다른 사람들이 올려 둔 것처럼 보이는 예시. 화면 검증용이다.
    static func seeded() -> MockCommunityServer {
        let server = MockCommunityServer()
        let ana = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!, ben = UUID(uuidString: "00000000-0000-0000-0000-0000000000B2")!
        func add(_ author: UUID, _ name: String, _ title: String, _ summary: String, _ category: TemplateCategory, _ symbol: String,
                 _ color: GroupColor, _ tags: [String], _ group: String, _ routines: [RoutineTemplate.Routine]) {
            server.templates.append(CommunityTemplate(
                id: UUID(), authorID: author, authorName: name, title: title, summary: summary, category: category, tags: tags,
                thumbnail: TemplateThumbnail(symbol: symbol, colorKey: color.rawValue),
                groups: [.init(title: group, colorKey: color.rawValue, routines: routines)],
                visibility: .public, moderation: .active, createdAt: server.now(), updatedAt: server.now()
            ))
        }
        add(ana, "아나", "퇴근 후 30분", "퇴근하고 바로 하는 짧은 정리.", .lifestyle, "moon.stars.fill", .purple, ["저녁", "정리"], "퇴근 루틴", [
            .init(title: "가방 정리", time: "19:00"), .init(title: "내일 옷 꺼내 두기", time: "19:10"), .init(title: "10분 산책", time: "19:30")
        ])
        add(ana, "아나", "시험 기간 공부", "평일 저녁 두 시간 집중.", .study, "book.fill", .blue, ["공부", "시험"], "시험 공부", [
            .init(title: "기출 문제 풀기", weekdays: Weekdays.workdays, time: "20:00"), .init(title: "오답 정리", weekdays: Weekdays.workdays, time: "21:30")
        ])
        add(ben, "", "주말 등산", "토요일 아침 가볍게 오르기.", .fitness, "figure.walk", .green, ["등산", "주말"], "주말 운동", [
            .init(title: "등산", weekdays: [6], time: "08:00", note: "2시간"), .init(title: "하산 후 스트레칭", weekdays: [6])
        ])
        return server
    }
}

@MainActor
final class MockCommunityBackend: CommunityBackend {
    let server: MockCommunityServer
    private(set) var userID: UUID?
    /// 시험용 로그인이 쓰는 계정.
    static let demoUser = UUID(uuidString: "00000000-0000-0000-0000-0000000000D0")!

    init(server: MockCommunityServer, userID: UUID? = nil) {
        self.server = server
        self.userID = userID
    }

    var currentUserID: UUID? {
        get async { userID }
    }

    private func online() throws {
        if server.isOffline { throw CommunityError.network }
    }

    private func requireUser() throws -> UUID {
        try online()
        guard let userID else { throw CommunityError.signInRequired }
        return userID
    }

    func publicTemplates() async throws -> [CommunityTemplate] {
        try online()
        let blocked = userID.flatMap { server.blocks[$0] } ?? []
        return server.templates.filter { $0.isListed && !blocked.contains($0.authorID) }.sorted { $0.createdAt > $1.createdAt }
    }

    func myTemplates() async throws -> [CommunityTemplate] {
        let user = try requireUser()
        return server.templates.filter { $0.authorID == user }.sorted { $0.updatedAt > $1.updatedAt }
    }

    func publish(_ draft: TemplateDraft) async throws -> CommunityTemplate {
        let user = try requireUser()
        let draft = draft.cleaned
        if let error = draft.validationError { throw CommunityError.invalid(error) }
        guard server.templates.filter({ $0.authorID == user }).count < 30 else { throw CommunityError.limitReached }
        server.receivedPayloads.append(draft.payload())
        let template = CommunityTemplate(
            id: UUID(), authorID: user, authorName: draft.authorName, title: draft.title, summary: draft.summary, category: draft.category,
            tags: draft.tags, thumbnail: draft.thumbnail, groups: draft.groups, visibility: draft.visibility, moderation: .active,
            createdAt: server.now(), updatedAt: server.now()
        )
        server.templates.append(template)
        return template
    }

    func update(_ id: UUID, with draft: TemplateDraft) async throws -> CommunityTemplate {
        let user = try requireUser()
        let draft = draft.cleaned
        if let error = draft.validationError { throw CommunityError.invalid(error) }
        // 내 것이 아니면 서버에는 "없는 줄"이다.
        guard let index = server.templates.firstIndex(where: { $0.id == id && $0.authorID == user }) else { throw CommunityError.notFound }
        server.receivedPayloads.append(draft.payload())
        var template = server.templates[index]
        template.authorName = draft.authorName
        template.title = draft.title
        template.summary = draft.summary
        template.category = draft.category
        template.tags = draft.tags
        template.thumbnail = draft.thumbnail
        template.groups = draft.groups
        template.visibility = draft.visibility
        template.updatedAt = server.now()
        // 운영 상태와 게시자는 고칠 수 없다.
        server.templates[index] = template
        return template
    }

    func delete(_ id: UUID) async throws {
        let user = try requireUser()
        guard let index = server.templates.firstIndex(where: { $0.id == id && $0.authorID == user }) else { throw CommunityError.notFound }
        server.templates.remove(at: index)
        server.reports.removeAll { $0.templateID == id }
    }

    func report(_ id: UUID, reason: ReportReason, detail: String) async throws {
        let user = try requireUser()
        guard let index = server.templates.firstIndex(where: { $0.id == id && $0.visibility == .public && $0.moderation != .removed }) else {
            throw CommunityError.notFound
        }
        guard server.templates[index].authorID != user else { throw CommunityError.invalid("내가 올린 템플릿은 신고할 수 없어요.") }
        guard !server.reports.contains(where: { $0.templateID == id && $0.reporterID == user }) else { throw CommunityError.alreadyReported }
        guard server.reports.filter({ $0.reporterID == user }).count < 10 else { throw CommunityError.limitReached }
        server.reports.append(.init(templateID: id, reporterID: user, reason: reason))
        if server.reports.filter({ $0.templateID == id }).count >= MockCommunityServer.reviewThreshold {
            server.templates[index].moderation = .underReview
        }
    }

    func blockedAuthors() async throws -> Set<UUID> {
        server.blocks[try requireUser()] ?? []
    }

    func block(_ authorID: UUID) async throws {
        let user = try requireUser()
        guard authorID != user else { throw CommunityError.invalid("나 자신은 차단할 수 없어요.") }
        server.blocks[user, default: []].insert(authorID)
    }

    func unblock(_ authorID: UUID) async throws {
        server.blocks[try requireUser(), default: []].remove(authorID)
    }

    func signIn(appleIDToken: String, nonce: String) async throws {
        try online()
        // 시험용: 토큰 글자를 계정으로 본다("demo"면 정해 둔 계정).
        userID = UUID(uuidString: appleIDToken) ?? Self.demoUser
    }

    func signOut() async {
        userID = nil
    }

    func deleteAccount() async throws {
        let user = try requireUser()
        server.templates.removeAll { $0.authorID == user }
        server.reports.removeAll { $0.reporterID == user }
        server.blocks[user] = nil
        userID = nil
    }
}
#endif
