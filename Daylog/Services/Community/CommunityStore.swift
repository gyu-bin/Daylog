import Foundation
import Observation

/// 공개 템플릿의 화면 상태와 동작. 개인 기록(`AppStore`)과는 서로 모른다:
/// 여기서 무슨 일이 생겨도(로그아웃, 네트워크 오류, 계정 삭제) 루틴·체크·식사·휴가는 건드리지 않는다.
@MainActor
@Observable
final class CommunityStore {
    static let shared = CommunityStore.makeShared()

    enum LoadState: Equatable {
        case idle, loading, loaded
        case failed(String)
    }

    @ObservationIgnored private let backend: CommunityBackend?
    /// Apple 로그인 단추를 보여 줄지(앱 서명에 권한이 있을 때만).
    let allowsAppleSignIn: Bool
    /// 시험용 서버에 붙어 있다(Debug 빌드의 실행 인자). 화면에 표시해 실제 서버와 헷갈리지 않게 한다.
    let isMock: Bool

    private(set) var userID: UUID?
    private(set) var publicTemplates: [CommunityTemplate] = []
    private(set) var myTemplates: [CommunityTemplate] = []
    private(set) var blockedAuthors: Set<UUID> = []
    private(set) var loadState: LoadState = .idle

    init(backend: CommunityBackend?, allowsAppleSignIn: Bool = false, isMock: Bool = false) {
        self.backend = backend
        self.allowsAppleSignIn = allowsAppleSignIn
        self.isMock = isMock
    }

    /// 서버 설정이 있는가. 없으면 공개 템플릿과 관련된 화면을 아예 보여 주지 않는다.
    var isAvailable: Bool { backend != nil }
    var isSignedIn: Bool { userID != nil }

    /// 탐색 화면에 섞어 보여 줄 공개 템플릿. 차단한 게시자의 것은 서버가 빼 주지만, 방금 차단한 것도 바로 사라지게 여기서도 뺀다.
    var catalogTemplates: [RoutineTemplate] {
        publicTemplates.filter { !blockedAuthors.contains($0.authorID) }.map(\.template)
    }

    func communityTemplate(for template: RoutineTemplate) -> CommunityTemplate? {
        guard let id = CommunityTemplate.id(fromTemplateID: template.id) else { return nil }
        return publicTemplates.first { $0.id == id } ?? myTemplates.first { $0.id == id }
    }

    func isMine(_ template: CommunityTemplate) -> Bool { template.authorID == userID }

    private func requireBackend() throws -> CommunityBackend {
        guard let backend else { throw CommunityError.notConfigured }
        return backend
    }

    // MARK: - 읽기

    /// 공개 목록과(로그인했으면) 내 템플릿·차단 목록을 다시 읽는다. 실패해도 이미 받아 둔 목록은 그대로 둔다.
    func refresh() async {
        guard let backend else { return }
        loadState = .loading
        userID = await backend.currentUserID
        do {
            publicTemplates = try await backend.publicTemplates()
            if userID != nil {
                // 로그인 정보가 만료됐을 수 있다. 그때는 탐색만 계속한다.
                do {
                    myTemplates = try await backend.myTemplates()
                    blockedAuthors = try await backend.blockedAuthors()
                } catch CommunityError.signInRequired {
                    clearAccountState()
                }
            } else {
                clearAccountState()
            }
            loadState = .loaded
        } catch {
            loadState = .failed(Self.message(error))
        }
    }

    /// 처음 한 번만 읽는다(화면이 뜰 때).
    func refreshIfNeeded() async {
        if loadState == .idle { await refresh() }
    }

    private func clearAccountState() {
        userID = nil
        myTemplates = []
        blockedAuthors = []
    }

    // MARK: - 로그인

    func signIn(appleIDToken: String, nonce: String) async throws {
        try await requireBackend().signIn(appleIDToken: appleIDToken, nonce: nonce)
        await refresh()
    }

    /// 이 기기의 로그인 정보만 지운다. 올려 둔 템플릿은 서버에 남고, 개인 기록은 그대로다.
    func signOut() async {
        await backend?.signOut()
        clearAccountState()
        await refresh()
    }

    func deleteAccount() async throws {
        try await requireBackend().deleteAccount()
        clearAccountState()
        await refresh()
    }

    // MARK: - 쓰기

    /// 새로 올리거나(`replacing == nil`) 올려 둔 것을 고친다. 올라가는 것은 `draft`의 내용뿐이다.
    @discardableResult
    func publish(_ draft: TemplateDraft, replacing id: UUID? = nil) async throws -> CommunityTemplate {
        let backend = try requireBackend()
        let draft = draft.cleaned
        if let error = draft.validationError { throw CommunityError.invalid(error) }
        let saved: CommunityTemplate
        if let id {
            saved = try await backend.update(id, with: draft)
        } else {
            saved = try await backend.publish(draft)
        }
        await refresh()
        return saved
    }

    func setVisibility(_ visibility: TemplateVisibility, for template: CommunityTemplate) async throws {
        var draft = template.draft
        draft.visibility = visibility
        try await publish(draft, replacing: template.id)
    }

    /// 서버의 게시물만 지운다. 다른 사람이 이미 가져간 루틴은 각자의 기기에 있는 사본이라 남는다.
    func delete(_ template: CommunityTemplate) async throws {
        try await requireBackend().delete(template.id)
        await refresh()
    }

    func report(_ template: CommunityTemplate, reason: ReportReason, detail: String) async throws {
        try await requireBackend().report(template.id, reason: reason, detail: detail)
        await refresh()
    }

    func block(_ authorID: UUID) async throws {
        try await requireBackend().block(authorID)
        blockedAuthors.insert(authorID)
        await refresh()
    }

    func unblock(_ authorID: UUID) async throws {
        try await requireBackend().unblock(authorID)
        blockedAuthors.remove(authorID)
        await refresh()
    }

    static func message(_ error: Error) -> String {
        (error as? CommunityError)?.errorDescription ?? error.localizedDescription
    }

    // MARK: - 만들기

    private static func makeShared() -> CommunityStore {
        #if DEBUG
        // 화면 검증용: -DaylogDebugCommunity mock | mock-signed-in | mock-offline. 실제 서버에 닿지 않는다.
        if let mode = UserDefaults.standard.string(forKey: "DaylogDebugCommunity"), mode.hasPrefix("mock") {
            let server = MockCommunityServer.seeded()
            server.isOffline = mode == "mock-offline"
            let backend = MockCommunityBackend(server: server, userID: mode == "mock-signed-in" ? MockCommunityBackend.demoUser : nil)
            return CommunityStore(backend: backend, isMock: true)
        }
        #endif
        guard let configuration = CommunityConfiguration(info: Bundle.main.infoDictionary ?? [:]) else {
            return CommunityStore(backend: nil)
        }
        return CommunityStore(
            backend: SupabaseCommunityBackend(configuration: configuration), allowsAppleSignIn: configuration.allowsAppleSignIn
        )
    }
}
