import Foundation

/// 템플릿의 출처: 앱에 든 공식 템플릿, 다른 사람에게 받은 파일, (보류 중인) 서버의 공개 템플릿.
enum TemplateSource: String, Codable, Sendable {
    case official
    case community
    /// 파일로 주고받은 템플릿(Phase 5-D).
    case file

    /// 모르는 출처는 받은 파일로 본다(나중 버전의 파일도 읽을 수 있게).
    init(from decoder: Decoder) throws {
        self = TemplateSource(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .file
    }
}

enum TemplateCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case morning, fitness, study, focus, lifestyle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .morning: return "아침 루틴"
        case .fitness: return "운동·건강"
        case .study: return "독서·공부"
        case .focus: return "생산성·집중"
        case .lifestyle: return "생활 습관"
        }
    }

    /// 나중 버전에서 생긴 분류는 생활 습관으로 본다(모르는 값 때문에 목록 전체를 버리지 않는다).
    init(from decoder: Decoder) throws {
        self = TemplateCategory(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .lifestyle
    }
}

/// 템플릿 목록의 작은 그림. 색 바탕에 기호를 그리고, 그림 파일이 있으면 그것을 쓴다.
/// 대시보드의 이미지 카드와는 무관하다(사용자의 사진을 쓰지 않는다).
struct TemplateThumbnail: Codable, Equatable, Sendable {
    /// SF Symbol 이름.
    var symbol: String
    /// `GroupColor`의 이름. 모르는 값은 기본색으로 그린다.
    var colorKey: String
    /// 앱에 든 그림(에셋)의 이름. 공개 템플릿이 생기면 같은 자리에 그림 주소를 둔다. 지금의 공식 템플릿은 쓰지 않는다.
    var imageName: String?
}

/// 루틴 정의만 담는다. 체크 기록·식사·휴가·사진처럼 개인 기록에 해당하는 칸은 이 모델에 없다.
struct RoutineTemplate: Codable, Equatable, Identifiable, Sendable {
    struct Routine: Codable, Equatable, Sendable {
        var title: String
        /// 반복 요일(월 = 1 … 일 = 7).
        var weekdays: [Int] = Weekdays.all
        /// "07:30" 같은 시각. 비어 있으면 시간 없이 추가된다.
        var time: String = ""
        var note: String = ""
    }

    struct Group: Codable, Equatable, Sendable {
        var title: String
        /// 그룹 색(`GroupColor`의 이름). 사용자가 올린 템플릿에만 있고, 미리보기에서 그룹을 구분하는 데 쓴다.
        var colorKey: String?
        var routines: [Routine]

        init(title: String, colorKey: String? = nil, routines: [Routine]) {
            self.title = title
            self.colorKey = colorKey
            self.routines = routines
        }
    }

    /// 출처 안에서 겹치지 않는 이름(예: "official.morning-light"). 공개 템플릿은 서버가 준 ID를 쓴다.
    var id: String
    var source: TemplateSource = .official
    var title: String
    /// 한두 문장의 설명.
    var summary: String
    var category: TemplateCategory
    /// 검색에 쓰는 낱말.
    var tags: [String] = []
    var thumbnail: TemplateThumbnail
    /// 만든 사람(공개 템플릿용). 공식 템플릿은 비워 둔다.
    var author: String?
    var groups: [Group]

    var routineCount: Int { groups.reduce(0) { $0 + $1.routines.count } }

    /// 가져오기 서비스가 받는 모양. 파일(CSV·JSON) 가져오기와 같은 줄이라 검사와 저장을 그대로 쓴다.
    var transferRoutines: [TransferRoutine] {
        groups.flatMap { group in
            group.routines.map {
                TransferRoutine(group: group.title, title: $0.title, weekdays: $0.weekdays, time: $0.time, note: $0.note)
            }
        }
    }

    /// 제목·설명·태그·분류·그룹·루틴 이름에서 찾는다. 대소문자와 앞뒤 공백은 가리지 않는다.
    func matches(_ query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return true }
        let haystack = [title, summary, category.title] + tags + groups.map(\.title) + groups.flatMap { $0.routines.map(\.title) }
        return haystack.contains { $0.lowercased().contains(needle) }
    }

    /// 목록에 올릴 수 있는 템플릿인지. 공개 템플릿을 받게 되면 같은 검사를 지나게 한다.
    var validationError: String? {
        guard !id.isEmpty, id.count <= 80 else { return "템플릿 ID가 올바르지 않아요." }
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, title.count <= 30 else { return "제목은 1~30자여야 해요." }
        guard summary.count <= 80 else { return "설명은 80자 이하여야 해요." }
        guard tags.count <= 8, tags.allSatisfy({ !$0.isEmpty && $0.count <= 12 }) else { return "태그는 8개 이하, 각 12자 이하여야 해요." }
        let rows = transferRoutines
        guard (1...Self.maximumRoutines).contains(rows.count) else { return "루틴은 1~\(Self.maximumRoutines)개여야 해요." }
        guard Set(groups.map(\.title)).count == groups.count else { return "그룹 이름이 겹쳐요." }
        guard Set(rows.map { "\($0.group)\u{1F}\($0.title)" }).count == rows.count else { return "같은 그룹에 이름이 같은 루틴이 있어요." }
        return rows.lazy.compactMap(RoutineTransferFormat.validation).first
    }

    static let maximumRoutines = 20
}

/// 여러 출처의 템플릿을 한 목록으로 다룬다. 지금은 공식 템플릿만 들어 있다.
struct TemplateCatalog: Equatable, Sendable {
    /// 주고받는 문서의 모양. 공개 템플릿 서버가 생기면 이 문서를 그대로 내려받아 읽는다.
    struct Document: Codable, Equatable {
        var format = TemplateCatalog.formatName
        var version = TemplateCatalog.formatVersion
        var templates: [RoutineTemplate]
    }

    static let formatName = "daylog.templates"
    static let formatVersion = 1

    var templates: [RoutineTemplate]

    /// 검사를 통과한 것만 받는다. ID가 겹치면 먼저 온 것을 남긴다.
    init(templates: [RoutineTemplate]) {
        var seen = Set<String>()
        self.templates = templates.filter { $0.validationError == nil && seen.insert($0.id).inserted }
    }

    init(data: Data) throws {
        let document = try JSONDecoder().decode(Document.self, from: data)
        guard document.format == Self.formatName, document.version == Self.formatVersion else {
            throw RoutineTransferError.invalid("지원하지 않는 템플릿 형식 또는 버전이에요.")
        }
        self.init(templates: document.templates)
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(Document(templates: templates))
    }

    /// 분류와 검색어로 좁힌다. `category`가 nil이면 전체.
    func filtered(category: TemplateCategory?, query: String) -> [RoutineTemplate] {
        templates.filter { (category == nil || $0.category == category) && $0.matches(query) }
    }

    /// 템플릿이 하나라도 있는 분류. 선언 순서대로.
    var categories: [TemplateCategory] {
        TemplateCategory.allCases.filter { category in templates.contains { $0.category == category } }
    }

    static let official = TemplateCatalog(templates: OfficialTemplates.all)
}
