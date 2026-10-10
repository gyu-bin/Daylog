import Foundation
import SQLite3

/// 저장소 파일의 백업과 복원. 저장소를 열기 전(아무도 쓰고 있지 않을 때)에만 호출한다.
enum StoreBackup {
    /// 저장소에 들어 있는 기록 수. 백업이 온전한지, 마이그레이션 뒤에도 그대로인지 비교한다.
    struct Counts: Equatable {
        var routines: Int
        var revisions: Int
        var records: Int
        var checks: Int
        var settings: Int
        /// v1.1 형식에는 이 테이블이 없다(0으로 센다).
        var fieldEdits: Int = 0

        var summary: String {
            "루틴 \(routines), 이력 \(revisions), 기록 \(records), 체크 \(checks), 설정 \(settings), 편집 기록 \(fieldEdits)"
        }
    }

    struct Backup {
        /// 저장소 파일과 -wal, -shm 사본이 들어 있는 폴더.
        let directory: URL
        let storeFileName: String
        let counts: Counts
    }

    static let keptBackups = 5
    private static let sidecarSuffixes = ["", "-wal", "-shm"]

    /// <저장소 폴더>/Backups/<이름>-<label>-<시각>/ 에 사본을 만들고, 사본이 읽히는지와 기록 수가 원본과 같은지 확인한다.
    static func create(for storeURL: URL, label: String, now: Date = .now) throws -> Backup {
        let fileManager = FileManager.default
        let sourceCounts = try counts(at: storeURL)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let name = storeURL.deletingPathExtension().lastPathComponent
        let root = backupsRoot(for: storeURL)
        var directory = root.appendingPathComponent("\(name)-\(label)-\(formatter.string(from: now))", isDirectory: true)
        var attempt = 1
        while fileManager.fileExists(atPath: directory.path) {
            attempt += 1
            directory = root.appendingPathComponent(
                "\(name)-\(label)-\(formatter.string(from: now))-\(attempt)", isDirectory: true
            )
        }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        for suffix in sidecarSuffixes {
            let source = URL(fileURLWithPath: storeURL.path + suffix)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            try fileManager.copyItem(at: source, to: directory.appendingPathComponent(source.lastPathComponent))
        }

        let copy = directory.appendingPathComponent(storeURL.lastPathComponent)
        try verifyIntegrity(at: copy)
        let copiedCounts = try counts(at: copy)
        guard copiedCounts == sourceCounts else {
            throw DaylogError.backupVerificationFailed("원본(\(sourceCounts.summary))과 사본(\(copiedCounts.summary))이 다릅니다.")
        }

        prune(root: root, storeName: name)
        return Backup(directory: directory, storeFileName: storeURL.lastPathComponent, counts: sourceCounts)
    }

    /// 백업의 파일들로 저장소를 되돌린다. 현재 파일은 덮어쓴다.
    static func restore(_ backup: Backup, to storeURL: URL) throws {
        try restore(from: backup.directory, storeFileName: backup.storeFileName, to: storeURL)
    }

    static func restore(from directory: URL, storeFileName: String, to storeURL: URL) throws {
        let fileManager = FileManager.default
        for suffix in sidecarSuffixes {
            let destination = URL(fileURLWithPath: storeURL.path + suffix)
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            let source = directory.appendingPathComponent(storeFileName + suffix)
            if fileManager.fileExists(atPath: source.path) {
                try fileManager.copyItem(at: source, to: destination)
            }
        }
    }

    static func backupsRoot(for storeURL: URL) -> URL {
        storeURL.deletingLastPathComponent().appendingPathComponent("Backups", isDirectory: true)
    }

    /// SQLite 파일을 읽기 전용으로 열어 테이블별 행 수를 센다.
    static func counts(at storeURL: URL) throws -> Counts {
        try withDatabase(at: storeURL) { database in
            Counts(
                routines: try rowCount("ZROUTINEITEM", in: database),
                revisions: try rowCount("ZROUTINEREVISION", in: database),
                records: try rowCount("ZDAYRECORD", in: database),
                checks: try rowCount("ZDAYCHECK", in: database),
                settings: try rowCount("ZAPPSETTINGS", in: database),
                fieldEdits: try tableExists("ZFIELDEDIT", in: database) ? try rowCount("ZFIELDEDIT", in: database) : 0
            )
        }
    }

    static func verifyIntegrity(at storeURL: URL) throws {
        let result = try withDatabase(at: storeURL) { try firstText("PRAGMA integrity_check", in: $0) }
        guard result == "ok" else {
            throw DaylogError.backupVerificationFailed("무결성 검사 결과: \(result)")
        }
    }

    // MARK: - SQLite

    private static func withDatabase<T>(at url: URL, _ body: (OpaquePointer) throws -> T) throws -> T {
        var handle: OpaquePointer?
        // WAL 방식 저장소는 읽기 전용으로 열 때도 보조 파일(-shm)을 만들려고 해서 그냥은 열리지 않는다.
        // 아직 반영 안 된 WAL 내용이 없으면 "변하지 않는 파일"로 열어 아무것도 쓰지 않고,
        // 있으면 그 내용까지 읽어야 하므로 일반 모드로 연다.
        let walSize = (try? FileManager.default.attributesOfItem(atPath: url.path + "-wal")[.size] as? Int) ?? 0
        let status: Int32
        if walSize == 0 {
            status = sqlite3_open_v2(
                url.absoluteString + "?immutable=1", &handle, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil
            )
        } else {
            status = sqlite3_open_v2(url.path, &handle, SQLITE_OPEN_READWRITE, nil)
        }
        defer { sqlite3_close(handle) }
        guard status == SQLITE_OK, let handle else {
            throw DaylogError.backupVerificationFailed("저장소 파일을 열 수 없습니다(\(status)).")
        }
        return try body(handle)
    }

    private static func tableExists(_ table: String, in database: OpaquePointer) throws -> Bool {
        (Int(try firstText("SELECT count(*) FROM sqlite_master WHERE type = 'table' AND name = '\(table)'", in: database)) ?? 0) > 0
    }

    private static func rowCount(_ table: String, in database: OpaquePointer) throws -> Int {
        Int(try firstText("SELECT count(*) FROM \(table)", in: database)) ?? 0
    }

    private static func firstText(_ sql: String, in database: OpaquePointer) throws -> String {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              sqlite3_step(statement) == SQLITE_ROW,
              let text = sqlite3_column_text(statement, 0)
        else {
            throw DaylogError.backupVerificationFailed(String(cString: sqlite3_errmsg(database)))
        }
        return String(cString: text)
    }

    /// 같은 저장소의 백업은 최근 것만 남긴다.
    private static func prune(root: URL, storeName: String) {
        let fileManager = FileManager.default
        guard let entries = try? fileManager.contentsOfDirectory(
            at: root, includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles]
        ) else { return }
        let mine = entries
            .filter { $0.lastPathComponent.hasPrefix("\(storeName)-") }
            .sorted { lhs, rhs in
                let left = (try? lhs.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let right = (try? rhs.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return (left, lhs.lastPathComponent) > (right, rhs.lastPathComponent)
            }
        for old in mine.dropFirst(keptBackups) {
            try? fileManager.removeItem(at: old)
        }
    }
}
