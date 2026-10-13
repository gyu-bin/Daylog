import CoreTransferable
import Foundation
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// Daylog 루틴 템플릿 파일(`.daylogtemplate`). 내용은 JSON이다. 앱의 Info.plist가 이 유형을 내보낸다.
    static let daylogTemplate = UTType(exportedAs: "com.mungyubin.daylog.template", conformingTo: .json)
}

enum TemplateFileError: LocalizedError, Equatable {
    case tooLarge
    case unreadable
    case notATemplate
    case unsupportedVersion
    case wrongCount
    case invalid(String)

    var errorDescription: String? {
        switch self {
        case .tooLarge: return "파일이 너무 커요. Daylog 템플릿 파일은 \(TemplateFile.maximumBytes / 1_024)KB 이하예요."
        case .unreadable: return "파일을 읽을 수 없어요. Daylog에서 만든 템플릿 파일인지 확인해 주세요."
        case .notATemplate: return "Daylog 템플릿 파일이 아니에요."
        case .unsupportedVersion: return "이 파일은 더 새로운 Daylog에서 만든 것이라 읽을 수 없어요. 앱을 업데이트한 뒤 다시 시도해 주세요."
        case .wrongCount: return "템플릿이 하나 들어 있는 파일만 가져올 수 있어요."
        case .invalid(let message): return "템플릿 내용이 올바르지 않아요. \(message)"
        }
    }
}

/// 루틴 템플릿을 파일로 주고받는다. 서버 없이 AirDrop·메시지·메신저로 파일을 건네는 방식이다.
///
/// 파일의 모양은 공식 템플릿 목록과 같은 문서(`TemplateCatalog.Document`: `format`, `version`, `templates`)에 템플릿 하나를 담은 것이다.
/// 담기는 것은 템플릿 모델의 칸뿐이라, 체크·식사·휴가 같은 기록이나 내부 ID가 실릴 자리가 없다.
enum TemplateFile {
    static let fileExtension = "daylogtemplate"
    /// 읽어 들이는 파일의 최대 크기. 루틴 20개짜리 템플릿은 수 KB다.
    static let maximumBytes = 256 * 1_024

    /// 고른 루틴으로 공유할 템플릿을 만든다. ID는 매번 새로 짓는 임의의 값이다(내 루틴·그룹의 ID가 아니다).
    static func make(
        id: UUID = UUID(), title: String, summary: String, category: TemplateCategory, tags: [String], groups: [RoutineTemplate.Group]
    ) -> RoutineTemplate {
        var seen = Set<String>()
        return RoutineTemplate(
            id: "file.\(id.uuidString.lowercased())", source: .file,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            summary: summary.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            tags: tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty && seen.insert($0).inserted },
            thumbnail: TemplateThumbnail(symbol: symbol(for: category), colorKey: groups.first?.colorKey ?? GroupColor.mint.rawValue),
            groups: groups
        )
    }

    /// 분류에 맞는 작은 그림의 기호.
    static func symbol(for category: TemplateCategory) -> String {
        switch category {
        case .morning: return "sunrise.fill"
        case .fitness: return "figure.walk"
        case .study: return "book.fill"
        case .focus: return "target"
        case .lifestyle: return "house.fill"
        }
    }

    /// 파일에 쓸 JSON. 사람이 열어 봐도 읽을 수 있게 줄을 나눈다.
    static func encode(_ template: RoutineTemplate) throws -> Data {
        if let error = template.validationError { throw TemplateFileError.invalid(error) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(TemplateCatalog.Document(templates: [template]))
    }

    /// 받은 파일의 내용을 읽는다. 형식·버전·개수·내용을 차례로 보고, 하나라도 어긋나면 거절한다.
    static func decode(_ data: Data) throws -> RoutineTemplate {
        guard data.count <= maximumBytes else { throw TemplateFileError.tooLarge }
        struct Header: Decodable {
            var format: String
            var version: Int
        }
        guard let header = try? JSONDecoder().decode(Header.self, from: data) else { throw TemplateFileError.unreadable }
        guard header.format == TemplateCatalog.formatName else { throw TemplateFileError.notATemplate }
        guard header.version <= TemplateCatalog.formatVersion else { throw TemplateFileError.unsupportedVersion }
        guard header.version == TemplateCatalog.formatVersion,
              let document = try? JSONDecoder().decode(TemplateCatalog.Document.self, from: data) else { throw TemplateFileError.unreadable }
        guard document.templates.count == 1, var template = document.templates.first else { throw TemplateFileError.wrongCount }
        // 받은 파일이 앱의 그림이나 다른 출처를 자처하지 못하게 한다.
        template.source = .file
        template.thumbnail.imageName = nil
        if let error = template.validationError { throw TemplateFileError.invalid(error) }
        return template
    }

    /// 파일에서 읽는다. 사용자가 고른 파일이나 다른 앱이 넘겨준 파일은 접근 권한을 잠깐 얻어서 읽는다.
    static func read(_ url: URL) throws -> RoutineTemplate {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > maximumBytes { throw TemplateFileError.tooLarge }
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { throw TemplateFileError.unreadable }
        return try decode(data)
    }

    /// "Daylog 템플릿 - 제목". 파일 이름에 쓸 수 없는 글자는 뺀다.
    static func fileName(for template: RoutineTemplate) -> String {
        let cleaned = template.title.components(separatedBy: CharacterSet(charactersIn: "/\\:*?\"<>|\n\r\t")).joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        return "Daylog 템플릿 - \(cleaned.isEmpty ? "루틴" : cleaned)"
    }
}

/// 시스템 공유 시트에 넘기는 파일. 공유를 시작할 때 임시 폴더에 파일을 만든다.
struct TemplateShareFile: Transferable {
    let template: RoutineTemplate

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .daylogTemplate) { file in
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("TemplateShare", isDirectory: true)
            // 전에 공유하느라 만든 임시 파일을 치우고 새로 만든다(임시 폴더에 쌓이지 않게).
            try? FileManager.default.removeItem(at: directory)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent(TemplateFile.fileName(for: file.template)).appendingPathExtension(TemplateFile.fileExtension)
            try TemplateFile.encode(file.template).write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
        .suggestedFileName { TemplateFile.fileName(for: $0.template) }
    }
}

/// [파일로 저장]이 쓰는 문서.
struct TemplateFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.daylogTemplate, .json] }
    static var writableContentTypes: [UTType] { [.daylogTemplate] }
    var data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

/// 다른 앱(파일 앱, Finder, 메신저)이 Daylog로 넘겨준 템플릿 파일. 뿌리 화면이 이 값을 보고 미리보기를 띄운다.
@MainActor
@Observable
final class TemplateInbox {
    static let shared = TemplateInbox()

    var incoming: RoutineTemplate?
    var error: String?
    /// iOS가 넘겨받은 파일의 사본을 넣어 두는 폴더(앱의 Documents/Inbox). 이 폴더 안의 파일만 읽은 뒤 지운다.
    /// macOS에는 그런 사본이 없다: 사용자의 파일을 그 자리에서 읽으므로 아무것도 지우지 않는다.
    @ObservationIgnored private let inboxDirectory: URL?
    /// 같은 파일이 두 경로(앱 델리게이트와 화면)로 연달아 들어오는 것을 한 번으로 본다.
    @ObservationIgnored private var lastOpened: (path: String, at: Date)?

    init(inboxDirectory: URL? = TemplateInbox.systemInbox) {
        self.inboxDirectory = inboxDirectory
    }

    nonisolated static var systemInbox: URL? {
        #if os(iOS)
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("Inbox", isDirectory: true)
        #else
        nil
        #endif
    }

    /// 파일을 읽어 미리보기에 올린다. 저장소는 건드리지 않는다(추가는 사용자가 미리보기에서 확인한 뒤에만).
    func open(_ url: URL, now: Date = .now) {
        let path = url.standardizedFileURL.path
        if let lastOpened, lastOpened.path == path, now.timeIntervalSince(lastOpened.at) < 2 { return }
        lastOpened = (path, now)
        do {
            incoming = try TemplateFile.read(url)
            error = nil
        } catch {
            incoming = nil
            self.error = error.localizedDescription
        }
        removeInboxCopy(url)
    }

    /// 앱의 Inbox에 들어온 사본만 지운다. 그 밖의 위치에 있는 파일은 사용자의 것이라 손대지 않는다.
    private func removeInboxCopy(_ url: URL) {
        guard let inboxDirectory else { return }
        let inbox = inboxDirectory.standardizedFileURL.resolvingSymlinksInPath().path
        let parent = url.standardizedFileURL.resolvingSymlinksInPath().deletingLastPathComponent().path
        guard parent == inbox else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
