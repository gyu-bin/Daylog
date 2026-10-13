import Foundation

/// 공개 템플릿 서버가 해 주는 일. 실제 구현(`SupabaseCommunityBackend`)과 시험용 구현(`MockCommunityBackend`)이 있다.
/// 권한은 서버가 정한다: 앱은 "내 것만 고친다" 같은 규칙을 믿고 건너뛰지 않고, 서버가 거절하면 그 오류를 보여 준다.
@MainActor
protocol CommunityBackend: AnyObject {
    /// 지금 로그인한 사용자. 로그인하지 않았으면 nil.
    var currentUserID: UUID? { get async }

    /// 공개 템플릿(내가 차단한 게시자의 것은 서버가 뺀다). 로그인 없이 부를 수 있다.
    func publicTemplates() async throws -> [CommunityTemplate]
    /// 내가 올린 템플릿(비공개·검토 중 포함).
    func myTemplates() async throws -> [CommunityTemplate]
    func publish(_ draft: TemplateDraft) async throws -> CommunityTemplate
    func update(_ id: UUID, with draft: TemplateDraft) async throws -> CommunityTemplate
    func delete(_ id: UUID) async throws
    func report(_ id: UUID, reason: ReportReason, detail: String) async throws
    func blockedAuthors() async throws -> Set<UUID>
    func block(_ authorID: UUID) async throws
    func unblock(_ authorID: UUID) async throws

    func signIn(appleIDToken: String, nonce: String) async throws
    func signOut() async
    /// 서버의 계정과 그 계정이 올린 템플릿을 지운다. 기기의 개인 기록과는 무관하다.
    func deleteAccount() async throws
}

/// HTTP 요청을 보내는 자리. 테스트는 여기에 가짜를 끼운다.
protocol CommunityTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionCommunityTransport: CommunityTransport {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.waitsForConnectivity = false
        let (data, response) = try await URLSession(configuration: configuration).data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, http)
    }
}

/// 로그인 정보를 두는 곳.
protocol CommunitySessionStore: AnyObject, Sendable {
    func load() -> CommunitySession?
    func save(_ session: CommunitySession)
    func clear()
}

/// 테스트와 시험용 서버가 쓰는 메모리 저장소.
final class MemorySessionStore: CommunitySessionStore, @unchecked Sendable {
    private var session: CommunitySession?
    init(_ session: CommunitySession? = nil) { self.session = session }
    func load() -> CommunitySession? { session }
    func save(_ session: CommunitySession) { self.session = session }
    func clear() { session = nil }
}
