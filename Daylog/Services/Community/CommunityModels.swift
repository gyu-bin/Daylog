import Foundation

/// 공개 템플릿 서버의 주소와 공개 키. 값이 없으면 공개 템플릿 기능 전체가 꺼지고, 앱은 공식 템플릿만 보여 준다.
///
/// 여기 넣는 키는 Supabase의 anon(공개) 키다. 권한은 서버의 행 수준 보안이 정하므로 앱에 들어가도 된다.
/// service_role 키는 어떤 경우에도 앱에 넣지 않는다(`isServiceRoleKey`로 걸러 낸다).
struct CommunityConfiguration: Equatable, Sendable {
    static let urlKey = "DaylogCommunityURL"
    static let anonKeyKey = "DaylogCommunityAnonKey"
    static let appleSignInKey = "DaylogCommunityAppleSignIn"

    var baseURL: URL
    var anonKey: String
    /// Apple 로그인 권한(entitlement)이 앱 서명에 들어 있을 때만 켠다.
    var allowsAppleSignIn: Bool

    init?(info: [String: Any]) {
        guard let text = info[Self.urlKey] as? String, let url = URL(string: text), url.scheme == "https", url.host != nil,
              let key = info[Self.anonKeyKey] as? String, !key.isEmpty, !Self.isServiceRoleKey(key) else { return nil }
        baseURL = url
        anonKey = key
        allowsAppleSignIn = info[Self.appleSignInKey] as? Bool ?? false
    }

    init(baseURL: URL, anonKey: String, allowsAppleSignIn: Bool = false) {
        self.baseURL = baseURL
        self.anonKey = anonKey
        self.allowsAppleSignIn = allowsAppleSignIn
    }

    /// JWT의 role이 service_role이거나 비밀 키(`sb_secret_…`) 모양이면 true. 그런 키로는 설정을 만들지 않는다.
    static func isServiceRoleKey(_ key: String) -> Bool {
        if key.hasPrefix("sb_secret_") { return true }
        let parts = key.split(separator: ".")
        guard parts.count == 3 else { return false }
        var payload = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 { payload.append("=") }
        guard let data = Data(base64Encoded: payload),
              let claims = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        return claims["role"] as? String == "service_role"
    }
}

enum TemplateVisibility: String, Codable, Sendable {
    case `public`, `private`
}

/// 서버가 정하는 운영 상태. 앱은 읽기만 한다.
enum TemplateModeration: String, Codable, Sendable {
    case active
    /// 신고가 쌓여 관리자 검토를 기다린다. 목록에서 숨겨진다.
    case underReview = "under_review"
    /// 관리자가 내렸다.
    case removed
}

enum ReportReason: String, CaseIterable, Identifiable, Sendable {
    case spam, inappropriate, personalInfo = "personal_info", copyright, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .spam: return "광고·도배"
        case .inappropriate: return "부적절한 내용"
        case .personalInfo: return "개인정보가 들어 있음"
        case .copyright: return "저작권 침해"
        case .other: return "기타"
        }
    }
}

enum CommunityError: LocalizedError, Equatable {
    case notConfigured
    case signInRequired
    case network
    case forbidden
    case notFound
    case alreadyReported
    case limitReached
    case invalid(String)
    case server(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "템플릿 공유는 아직 준비 중이에요."
        case .signInRequired: return "로그인이 필요해요."
        case .network: return "서버에 연결하지 못했어요. 네트워크를 확인하고 다시 시도해 주세요. 내 기록과 공식 템플릿은 그대로 쓸 수 있어요."
        case .forbidden: return "이 작업을 할 권한이 없어요."
        case .notFound: return "템플릿을 찾을 수 없어요. 삭제됐거나 비공개로 바뀌었을 수 있어요."
        case .alreadyReported: return "이미 신고한 템플릿이에요."
        case .limitReached: return "한도를 넘었어요. 잠시 뒤에 다시 시도해 주세요."
        case .invalid(let message): return message
        case .server(let message): return "서버에서 처리하지 못했어요. (\(message))"
        }
    }
}

/// 게시할 내용. 여기 있는 것이 공개되는 전부다(게시자 식별자와 시각은 서버가 붙인다).
struct TemplateDraft: Equatable, Sendable {
    static let authorNameLimit = 20

    var title: String
    var summary: String
    var category: TemplateCategory
    var tags: [String]
    var thumbnail: TemplateThumbnail
    /// 게시자가 고른 표시 이름. 비워 두면 "익명"으로 보인다.
    var authorName: String
    var groups: [RoutineTemplate.Group]
    var visibility: TemplateVisibility

    /// 앞뒤 공백을 떼고, 빈 태그와 겹치는 태그를 뺀 값.
    var cleaned: TemplateDraft {
        var copy = self
        copy.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.summary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.authorName = String(authorName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.authorNameLimit))
        var seen = Set<String>()
        copy.tags = tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty && seen.insert($0).inserted }
        copy.thumbnail.imageName = nil
        return copy
    }

    /// 목록에 올릴 수 있는지. 공식 템플릿과 같은 검사를 쓴다.
    var validationError: String? {
        if groups.isEmpty { return "게시할 그룹을 하나 이상 골라 주세요." }
        return RoutineTemplate(
            id: "draft", source: .community, title: title, summary: summary, category: category, tags: tags,
            thumbnail: thumbnail, author: authorName, groups: groups
        ).validationError
    }

    /// 서버로 보내는 JSON. 표의 열 이름과 같다. 게시자·운영 상태·신고 수는 넣지 않는다(서버가 정한다).
    func payload() -> [String: Any] {
        [
            "author_name": authorName,
            "title": title,
            "summary": summary,
            "category": category.rawValue,
            "tags": tags,
            "thumbnail": ["symbol": thumbnail.symbol, "colorKey": thumbnail.colorKey],
            "content": Self.content(groups),
            "visibility": visibility.rawValue
        ]
    }

    /// 그룹과 루틴의 공개 모양. 이 칸들 말고는 아무것도 싣지 않는다.
    static func content(_ groups: [RoutineTemplate.Group]) -> [String: Any] {
        ["groups": groups.map { group -> [String: Any] in
            var value: [String: Any] = [
                "title": group.title,
                "routines": group.routines.map { routine -> [String: Any] in
                    ["title": routine.title, "weekdays": routine.weekdays, "time": routine.time, "note": routine.note]
                }
            ]
            if let colorKey = group.colorKey { value["colorKey"] = colorKey }
            return value
        }]
    }
}

/// 서버에 있는 템플릿 한 건. 게시한 시점의 스냅샷이라 게시자의 루틴이 바뀌어도 따라 바뀌지 않는다.
struct CommunityTemplate: Identifiable, Equatable, Sendable {
    var id: UUID
    var authorID: UUID
    var authorName: String
    var title: String
    var summary: String
    var category: TemplateCategory
    var tags: [String]
    var thumbnail: TemplateThumbnail
    var groups: [RoutineTemplate.Group]
    var visibility: TemplateVisibility
    var moderation: TemplateModeration
    var createdAt: Date
    var updatedAt: Date

    static let idPrefix = "community."

    /// 다른 사람의 목록에 나오는가.
    var isListed: Bool { visibility == .public && moderation == .active }

    var displayAuthor: String { authorName.isEmpty ? "익명" : authorName }

    /// 내 템플릿 목록에 보여 주는 상태.
    var statusLabel: String {
        switch moderation {
        case .removed: return "게시 중단"
        case .underReview: return "검토 중"
        case .active: return visibility == .public ? "공개" : "비공개"
        }
    }

    /// 탐색·미리보기·가져오기가 쓰는 공통 모양.
    var template: RoutineTemplate {
        RoutineTemplate(
            id: Self.idPrefix + id.uuidString, source: .community, title: title, summary: summary, category: category,
            tags: tags, thumbnail: thumbnail, author: displayAuthor, groups: groups
        )
    }

    /// 고칠 때의 출발점.
    var draft: TemplateDraft {
        TemplateDraft(
            title: title, summary: summary, category: category, tags: tags, thumbnail: thumbnail,
            authorName: authorName, groups: groups, visibility: visibility
        )
    }

    /// 탐색 목록의 ID에서 서버 ID를 얻는다.
    static func id(fromTemplateID id: String) -> UUID? {
        id.hasPrefix(idPrefix) ? UUID(uuidString: String(id.dropFirst(idPrefix.count))) : nil
    }
}

extension CommunityTemplate {
    /// 서버의 한 줄(JSON 객체)을 읽는다. 모양이 맞지 않거나 검사를 통과하지 못하면 nil(그 줄만 버린다).
    init?(row: [String: Any]) {
        guard let id = (row["id"] as? String).flatMap(UUID.init(uuidString:)),
              let authorID = (row["author_id"] as? String).flatMap(UUID.init(uuidString:)),
              let title = row["title"] as? String,
              let categoryName = row["category"] as? String,
              let thumbnail = row["thumbnail"] as? [String: Any],
              let symbol = thumbnail["symbol"] as? String, let colorKey = thumbnail["colorKey"] as? String,
              let content = row["content"] as? [String: Any], let rawGroups = content["groups"] as? [[String: Any]],
              let visibility = (row["visibility"] as? String).flatMap(TemplateVisibility.init(rawValue:)),
              let moderation = (row["moderation"] as? String).flatMap(TemplateModeration.init(rawValue:))
        else { return nil }
        let groups = rawGroups.compactMap { group -> RoutineTemplate.Group? in
            guard let title = group["title"] as? String, let routines = group["routines"] as? [[String: Any]] else { return nil }
            return RoutineTemplate.Group(title: title, colorKey: group["colorKey"] as? String, routines: routines.compactMap { routine in
                guard let title = routine["title"] as? String, let weekdays = routine["weekdays"] as? [Int] else { return nil }
                return RoutineTemplate.Routine(
                    title: title, weekdays: weekdays, time: routine["time"] as? String ?? "", note: routine["note"] as? String ?? ""
                )
            })
        }
        self.init(
            id: id, authorID: authorID, authorName: row["author_name"] as? String ?? "", title: title,
            summary: row["summary"] as? String ?? "",
            category: TemplateCategory(rawValue: categoryName) ?? .lifestyle,
            tags: row["tags"] as? [String] ?? [],
            thumbnail: TemplateThumbnail(symbol: symbol, colorKey: colorKey),
            groups: groups, visibility: visibility, moderation: moderation,
            createdAt: Self.date(row["created_at"]) ?? .distantPast, updatedAt: Self.date(row["updated_at"]) ?? .distantPast
        )
        // 서버가 검사하지만, 받은 내용도 앱의 규칙으로 한 번 더 본다(가져오기 화면에 그대로 들어가므로).
        guard template.validationError == nil else { return nil }
    }

    /// Postgres가 주는 시각("2026-10-13T09:00:00.123456+00:00"). 소수 초의 자릿수가 달라도 읽는다.
    static func date(_ value: Any?) -> Date? {
        guard var text = value as? String else { return nil }
        if let dot = text.firstIndex(of: "."), let zone = text[dot...].firstIndex(where: { $0 == "+" || $0 == "-" || $0 == "Z" }) {
            text.removeSubrange(dot..<zone)
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text)
    }
}

/// 로그인 상태. 접근 토큰과 갱신 토큰은 키체인에만 둔다.
struct CommunitySession: Codable, Equatable, Sendable {
    var userID: UUID
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date

    /// 만료가 가까우면 갱신한다.
    func needsRefresh(now: Date = .now) -> Bool { expiresAt.timeIntervalSince(now) < 60 }
}
