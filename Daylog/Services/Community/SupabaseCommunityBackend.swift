import Foundation

/// Supabase(PostgREST + Auth)에 직접 말하는 구현. 별도 SDK 없이 HTTPS 요청만 쓴다.
///
/// 모든 요청은 공개(anon) 키를 `apikey`로 보내고, 로그인했으면 그 사용자의 접근 토큰을, 아니면 공개 키를 `Authorization`에 싣는다.
/// 무엇을 읽고 쓸 수 있는지는 서버의 행 수준 보안이 정한다(`supabase/migrations`). 게시자 ID는 보내지 않는다.
@MainActor
final class SupabaseCommunityBackend: CommunityBackend {
    /// 읽어 오는 열. `report_count`는 읽을 권한이 없어서 `*`를 쓰지 않는다.
    static let columns = "id,author_id,author_name,title,summary,category,tags,thumbnail,content,visibility,moderation,created_at,updated_at"
    /// 한 번에 받는 공개 템플릿 수. 검색과 분류는 받은 목록 안에서 한다.
    static let pageSize = 200

    private let configuration: CommunityConfiguration
    private let transport: CommunityTransport
    private let sessions: CommunitySessionStore
    private let now: () -> Date

    init(
        configuration: CommunityConfiguration, transport: CommunityTransport = URLSessionCommunityTransport(),
        sessions: CommunitySessionStore = KeychainSessionStore(), now: @escaping () -> Date = { .now }
    ) {
        self.configuration = configuration
        self.transport = transport
        self.sessions = sessions
        self.now = now
    }

    var currentUserID: UUID? {
        get async { sessions.load()?.userID }
    }

    // MARK: - 템플릿

    func publicTemplates() async throws -> [CommunityTemplate] {
        let query = [
            ("select", Self.columns), ("visibility", "eq.public"), ("moderation", "eq.active"),
            ("order", "created_at.desc"), ("limit", "\(Self.pageSize)")
        ]
        // 로그인했으면 그 토큰으로 읽어야 서버가 내가 차단한 게시자를 걸러 준다.
        return try await rows(.init(method: "GET", path: "/rest/v1/templates", query: query), auth: .optional)
            .compactMap(CommunityTemplate.init(row:))
    }

    func myTemplates() async throws -> [CommunityTemplate] {
        let session = try await validSession()
        let query = [("select", Self.columns), ("author_id", "eq.\(session.userID.uuidString.lowercased())"), ("order", "updated_at.desc")]
        return try await rows(.init(method: "GET", path: "/rest/v1/templates", query: query), auth: .required)
            .compactMap(CommunityTemplate.init(row:))
    }

    func publish(_ draft: TemplateDraft) async throws -> CommunityTemplate {
        let request = Request(method: "POST", path: "/rest/v1/templates", query: [("select", Self.columns)], body: draft.payload(), returnsRows: true)
        guard let template = try await rows(request, auth: .required).first.flatMap(CommunityTemplate.init(row:)) else {
            throw CommunityError.server("empty response")
        }
        return template
    }

    func update(_ id: UUID, with draft: TemplateDraft) async throws -> CommunityTemplate {
        let request = Request(
            method: "PATCH", path: "/rest/v1/templates", query: [("id", Self.eq(id)), ("select", Self.columns)],
            body: draft.payload(), returnsRows: true
        )
        // 내 것이 아니면 서버는 오류 없이 0줄을 돌려준다.
        guard let template = try await rows(request, auth: .required).first.flatMap(CommunityTemplate.init(row:)) else {
            throw CommunityError.notFound
        }
        return template
    }

    func delete(_ id: UUID) async throws {
        let request = Request(method: "DELETE", path: "/rest/v1/templates", query: [("id", Self.eq(id)), ("select", "id")], returnsRows: true)
        guard try await !rows(request, auth: .required).isEmpty else { throw CommunityError.notFound }
    }

    // MARK: - 신고와 차단

    func report(_ id: UUID, reason: ReportReason, detail: String) async throws {
        let body: [String: Any] = [
            "template_id": id.uuidString.lowercased(), "reason": reason.rawValue,
            "detail": String(detail.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
        ]
        do {
            _ = try await send(.init(method: "POST", path: "/rest/v1/template_reports", body: body), auth: .required)
        } catch CommunityError.server(let message) where message == Self.conflict {
            throw CommunityError.alreadyReported
        }
    }

    func blockedAuthors() async throws -> Set<UUID> {
        let rows = try await rows(.init(method: "GET", path: "/rest/v1/blocked_authors", query: [("select", "blocked_id")]), auth: .required)
        return Set(rows.compactMap { ($0["blocked_id"] as? String).flatMap(UUID.init(uuidString:)) })
    }

    func block(_ authorID: UUID) async throws {
        do {
            _ = try await send(
                .init(method: "POST", path: "/rest/v1/blocked_authors", body: ["blocked_id": authorID.uuidString.lowercased()]), auth: .required
            )
        } catch CommunityError.server(let message) where message == Self.conflict {
            // 이미 차단한 게시자다.
        }
    }

    func unblock(_ authorID: UUID) async throws {
        _ = try await send(.init(method: "DELETE", path: "/rest/v1/blocked_authors", query: [("blocked_id", Self.eq(authorID))]), auth: .required)
    }

    // MARK: - 로그인

    func signIn(appleIDToken: String, nonce: String) async throws {
        let body: [String: Any] = ["provider": "apple", "id_token": appleIDToken, "nonce": nonce]
        let data = try await send(.init(method: "POST", path: "/auth/v1/token", query: [("grant_type", "id_token")], body: body), auth: .none)
        sessions.save(try session(from: data))
    }

    func signOut() async {
        // 서버에 알리지 못해도 이 기기의 로그인 정보는 지운다.
        _ = try? await send(.init(method: "POST", path: "/auth/v1/logout", query: [("scope", "local")]), auth: .required)
        sessions.clear()
    }

    func deleteAccount() async throws {
        _ = try await send(.init(method: "POST", path: "/rest/v1/rpc/delete_my_account", body: [:]), auth: .required)
        sessions.clear()
    }

    // MARK: - 요청

    struct Request {
        var method: String
        var path: String
        var query: [(String, String)] = []
        var body: [String: Any]? = nil
        /// 쓴 줄을 돌려받는다(`Prefer: return=representation`).
        var returnsRows = false
    }

    enum Auth { case none, optional, required }

    private static let conflict = "conflict"

    private static func eq(_ id: UUID) -> String { "eq.\(id.uuidString.lowercased())" }

    private func rows(_ request: Request, auth: Auth) async throws -> [[String: Any]] {
        let data = try await send(request, auth: auth)
        guard let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw CommunityError.server("unexpected response")
        }
        return rows
    }

    /// 만료가 가까우면 갱신한 로그인 정보. 갱신 토큰이 거절되면 로그인 정보를 지우고 다시 로그인하게 한다.
    private func validSession() async throws -> CommunitySession {
        guard let session = sessions.load() else { throw CommunityError.signInRequired }
        guard session.needsRefresh(now: now()) else { return session }
        do {
            let request = Request(
                method: "POST", path: "/auth/v1/token", query: [("grant_type", "refresh_token")], body: ["refresh_token": session.refreshToken]
            )
            let refreshed = try self.session(from: try await send(request, auth: .none))
            sessions.save(refreshed)
            return refreshed
        } catch CommunityError.network {
            throw CommunityError.network
        } catch {
            sessions.clear()
            throw CommunityError.signInRequired
        }
    }

    private func session(from data: Data) throws -> CommunitySession {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = json["access_token"] as? String, let refresh = json["refresh_token"] as? String,
              let user = json["user"] as? [String: Any], let id = (user["id"] as? String).flatMap(UUID.init(uuidString:))
        else { throw CommunityError.server("unexpected sign-in response") }
        let lifetime = (json["expires_in"] as? Double) ?? Double(json["expires_in"] as? Int ?? 3_600)
        return CommunitySession(userID: id, accessToken: access, refreshToken: refresh, expiresAt: now().addingTimeInterval(lifetime))
    }

    private func send(_ request: Request, auth: Auth) async throws -> Data {
        var components = URLComponents(url: configuration.baseURL.appendingPathComponent(request.path), resolvingAgainstBaseURL: false)
        if !request.query.isEmpty {
            components?.queryItems = request.query.map { URLQueryItem(name: $0.0, value: $0.1) }
        }
        guard let url = components?.url else { throw CommunityError.notConfigured }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method
        urlRequest.setValue(configuration.anonKey, forHTTPHeaderField: "apikey")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        var token = configuration.anonKey
        switch auth {
        case .none: break
        case .required: token = try await validSession().accessToken
        // 로그인 정보를 쓸 수 없으면(만료·네트워크) 공개 키로 읽는다. 탐색은 로그인과 무관해야 한다.
        case .optional: if let session = try? await validSession() { token = session.accessToken }
        }
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body = request.body {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if request.returnsRows { urlRequest.setValue("return=representation", forHTTPHeaderField: "Prefer") }

        let data: Data, response: HTTPURLResponse
        do {
            (data, response) = try await transport.send(urlRequest)
        } catch {
            throw CommunityError.network
        }
        if (200..<300).contains(response.statusCode) { return data }
        throw Self.error(status: response.statusCode, data: data)
    }

    /// 서버의 거절을 앱의 오류로 옮긴다. PostgREST는 `{"code", "message", "hint"}`를, Auth는 `{"error_description"}`이나 `{"msg"}`를 준다.
    static func error(status: Int, data: Data) -> CommunityError {
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let code = json["code"] as? String ?? ""
        let hint = json["hint"] as? String ?? ""
        let message = (json["message"] ?? json["error_description"] ?? json["msg"]) as? String ?? "HTTP \(status)"
        if status == 409 || code == "23505" { return .server(conflict) }
        if hint == "limit_reached" { return .limitReached }
        if status == 401 { return .signInRequired }
        if status == 403 || code == "42501" { return .forbidden }
        if status == 404 { return .notFound }
        if code == "22023" || code == "23514" { return .invalid("서버가 내용을 받지 않았어요. 제목·태그·루틴 구성을 확인해 주세요.") }
        if hint == "own_template" { return .invalid("내가 올린 템플릿은 신고할 수 없어요.") }
        if hint == "not_reportable" { return .notFound }
        return .server(message)
    }
}
