import Foundation

/// 앱과 위젯이 주고받는 파일. 앱 그룹 폴더에 둔다.
///
/// - `widget-snapshot.json`: 앱이 쓰고 위젯이 읽는다.
/// - `widget-pending.json`: 위젯이 쓰고(체크한 내용) 앱이 가져가 저장소에 반영한다.
///
/// 파일은 통째로 바꿔 쓰고(atomic) 잠금을 오래 쥐지 않는다. 공유 폴더의 파일을 잠근 채 멈춘 프로세스는 iOS가 종료시키기 때문이다.
struct WidgetBridge {
    static let appGroupID = "group.com.mungyubin.daylog"

    let directory: URL

    /// 앱 그룹 폴더. 앱 그룹 권한이 없는 빌드(macOS, 단위 테스트)에서는 nil.
    static var shared: WidgetBridge? {
        #if os(iOS)
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID).map(WidgetBridge.init(directory:))
        #else
        nil
        #endif
    }

    private var snapshotURL: URL { directory.appendingPathComponent("widget-snapshot.json") }
    private var pendingURL: URL { directory.appendingPathComponent("widget-pending.json") }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    // MARK: - 스냅샷 (앱 → 위젯)

    func readSnapshot() -> WidgetSnapshot? {
        guard let data = try? Data(contentsOf: snapshotURL) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    /// 내용이 달라졌을 때만 쓴다. 썼으면 true(위젯을 새로 그리라고 알릴 때다).
    @discardableResult
    func writeSnapshot(_ snapshot: WidgetSnapshot) throws -> Bool {
        let data = try Self.encoder.encode(snapshot)
        if let existing = try? Data(contentsOf: snapshotURL), existing == data { return false }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: snapshotURL, options: .atomic)
        return true
    }

    // MARK: - 대기 중인 체크 (위젯 → 앱)

    func readPending() -> [PendingCheck] {
        guard let data = try? Data(contentsOf: pendingURL) else { return [] }
        return (try? JSONDecoder().decode([PendingCheck].self, from: data)) ?? []
    }

    /// 위젯이 체크를 하나 보탠다. 실패하면 던져서 위젯이 상태를 바꾸지 않게 한다.
    func appendPending(_ check: PendingCheck) throws {
        var all = readPending()
        all.append(check)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Self.encoder.encode(all).write(to: pendingURL, options: .atomic)
    }

    /// 앱이 대기 중인 체크를 가져간다. 파일을 먼저 다른 이름으로 옮긴 뒤 읽어서, 그 사이 위젯이 보탠 것을 잃지 않는다.
    func takePending() -> [PendingCheck] {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: pendingURL.path) else { return [] }
        let taken = directory.appendingPathComponent("widget-pending-\(UUID().uuidString).json")
        do {
            try fileManager.moveItem(at: pendingURL, to: taken)
        } catch {
            return []
        }
        defer { try? fileManager.removeItem(at: taken) }
        guard let data = try? Data(contentsOf: taken) else { return [] }
        return ((try? JSONDecoder().decode([PendingCheck].self, from: data)) ?? []).sorted { $0.at < $1.at }
    }
}
