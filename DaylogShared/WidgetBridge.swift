import Foundation
import Darwin

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

    // MARK: - Durable request journal

    /// Reading never consumes requests. Only a confirmed database save and snapshot publication may acknowledge them.
    func readPending() -> [PendingCheck] {
        (try? pendingChecks()) ?? []
    }

    func pendingChecks() throws -> [PendingCheck] {
        try withQueueLock { try readQueueFiles().checks }
    }

    func appendPending(_ check: PendingCheck) throws {
        try withQueueLock {
            let queue = try readQueueFiles()
            var all = queue.checks
            var ordered = check
            // Serialize rapid taps even when the clock moves backwards or returns the same instant.
            if let previous = all.last { ordered.at = max(ordered.at, previous.at.addingTimeInterval(0.001)) }
            all.append(ordered)
            try writeQueue(all, recovered: queue.recovered)
        }
    }

    /// Remove exactly the requests we saved; concurrent appends remain in the journal.
    func acknowledge(_ confirmed: [PendingCheck]) throws {
        try withQueueLock {
            let queue = try readQueueFiles()
            try writeQueue(queue.checks.filter { !confirmed.contains($0) }, recovered: queue.recovered)
        }
    }

    private func readQueueFiles() throws -> (checks: [PendingCheck], recovered: [URL]) {
        // Recover journals left by the old take-before-save implementation after process termination.
        let recovered = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("widget-pending-") && $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        let files = recovered + (FileManager.default.fileExists(atPath: pendingURL.path) ? [pendingURL] : [])
        let checks = try files.flatMap { try JSONDecoder().decode([PendingCheck].self, from: Data(contentsOf: $0)) }
        // Preserve file order for legacy requests that share a timestamp.
        return (checks.enumerated().sorted {
            $0.element.at == $1.element.at ? $0.offset < $1.offset : $0.element.at < $1.element.at
        }.map(\.element), recovered)
    }

    private func writeQueue(_ checks: [PendingCheck], recovered: [URL]) throws {
        try Self.encoder.encode(checks).write(to: pendingURL, options: .atomic)
        for file in recovered { try FileManager.default.removeItem(at: file) }
    }

    /// The lock covers only short synchronous file operations, never SwiftData or an await.
    private func withQueueLock<T>(_ body: () throws -> T) throws -> T {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let descriptor = open(directory.appendingPathComponent("widget-pending.lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw POSIXError(.EIO) }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { throw POSIXError(.EIO) }
        defer { flock(descriptor, LOCK_UN) }
        return try body()
    }
}
