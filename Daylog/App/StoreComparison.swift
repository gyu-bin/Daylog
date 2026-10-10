#if DEBUG
import Foundation
import SQLite3

/// 형식 변환 전 백업과 지금의 저장소를 행 단위로 비교한다(Debug 빌드 전용).
/// 기록의 "내용"은 출력하지 않고, 표 이름·열 이름·개수만 알려 준다.
enum StoreComparison {
    struct TableReport {
        var table: String
        var backupRows = 0
        var liveRows = 0
        var missingInLive = 0
        var addedInLive = 0
        var changedRows = 0
        /// 값이 달라진 열 이름과 그런 행의 수.
        var changedColumns: [String: Int] = [:]
        /// 백업에는 없고 지금 저장소에만 있는 열과, 그 열에 값이 들어 있는 행의 수.
        var newColumns: [String: Int] = [:]

        var summary: String {
            var parts = ["\(table): 백업 \(backupRows)행, 현재 \(liveRows)행, 사라진 행 \(missingInLive), 새 행 \(addedInLive), 값이 달라진 행 \(changedRows)"]
            if !changedColumns.isEmpty {
                parts.append("달라진 열 " + changedColumns.sorted { $0.key < $1.key }.map { "\($0.key)×\($0.value)" }.joined(separator: " "))
            }
            if !newColumns.isEmpty {
                parts.append("새 열 " + newColumns.sorted { $0.key < $1.key }.map { "\($0.key)(값 있음 \($0.value))" }.joined(separator: " "))
            }
            return parts.joined(separator: " | ")
        }
    }

    /// Core Data가 저장할 때마다 올리는 버전 번호. 내용이 아니라서 비교에서 뺀다.
    private static let ignoredColumns: Set<String> = ["Z_OPT"]

    static func compare(backup: URL, live: URL) throws -> [TableReport] {
        let old = try open(backup)
        defer { sqlite3_close(old) }
        let new = try open(live)
        defer { sqlite3_close(new) }

        // 엔티티 표만 본다(Z로 시작하고 Z_로 시작하지 않는 표).
        let tables = try texts("SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'Z%' AND name NOT LIKE 'Z\\_%' ESCAPE '\\' ORDER BY name", in: old)
        return try tables.map { table in
            var report = TableReport(table: table)
            let oldColumns = try texts("SELECT name FROM pragma_table_info('\(table)')", in: old)
            let newColumns = try texts("SELECT name FROM pragma_table_info('\(table)')", in: new)
            guard !newColumns.isEmpty else {
                report.backupRows = try rows(table, columns: ["Z_PK"], in: old).count
                report.missingInLive = report.backupRows
                return report
            }
            let common = oldColumns.filter { newColumns.contains($0) && !ignoredColumns.contains($0) }
            let oldRows = try rows(table, columns: common, in: old)
            let newRows = try rows(table, columns: common, in: new)
            report.backupRows = oldRows.count
            report.liveRows = newRows.count
            report.missingInLive = oldRows.keys.filter { newRows[$0] == nil }.count
            report.addedInLive = newRows.keys.filter { oldRows[$0] == nil }.count
            for (key, before) in oldRows {
                guard let after = newRows[key], before != after else { continue }
                report.changedRows += 1
                for (index, column) in common.enumerated() where before[index] != after[index] {
                    report.changedColumns[column, default: 0] += 1
                }
            }
            for column in newColumns where !oldColumns.contains(column) {
                let filled = try texts("SELECT count(*) FROM \(table) WHERE \(column) IS NOT NULL", in: new).first ?? "?"
                report.newColumns[column] = Int(filled) ?? -1
            }
            return report
        }
    }

    /// `StoreBackup`과 같은 방식으로 연다: 반영 안 된 WAL 내용이 없으면 아무것도 쓰지 않는 방식으로,
    /// 있으면 그 내용까지 읽을 수 있게 일반 모드로. 어느 쪽이든 읽기만 한다.
    private static func open(_ url: URL) throws -> OpaquePointer {
        var handle: OpaquePointer?
        let walSize = (try? FileManager.default.attributesOfItem(atPath: url.path + "-wal")[.size] as? Int) ?? 0
        let status = walSize == 0
            ? sqlite3_open_v2(url.absoluteString + "?immutable=1", &handle, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil)
            : sqlite3_open_v2(url.path, &handle, SQLITE_OPEN_READWRITE, nil)
        guard status == SQLITE_OK, let handle else {
            sqlite3_close(handle)
            throw DaylogError.backupVerificationFailed("비교할 저장소를 열 수 없어요: \(url.lastPathComponent)")
        }
        return handle
    }

    /// 기본 키 → 각 열의 값(SQL 리터럴 표기). 값의 형식 차이까지 드러나도록 `quote()`로 읽는다.
    private static func rows(_ table: String, columns: [String], in database: OpaquePointer) throws -> [Int64: [String]] {
        let list = columns.map { "quote(\($0))" }.joined(separator: ", ")
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(database, "SELECT Z_PK, \(list) FROM \(table)", -1, &statement, nil) == SQLITE_OK else {
            throw DaylogError.backupVerificationFailed(String(cString: sqlite3_errmsg(database)))
        }
        var result: [Int64: [String]] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            result[sqlite3_column_int64(statement, 0)] = columns.indices.map { index in
                sqlite3_column_text(statement, Int32(index + 1)).map { String(cString: $0) } ?? "NULL"
            }
        }
        return result
    }

    private static func texts(_ sql: String, in database: OpaquePointer) throws -> [String] {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DaylogError.backupVerificationFailed(String(cString: sqlite3_errmsg(database)))
        }
        var result: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let text = sqlite3_column_text(statement, 0) { result.append(String(cString: text)) }
        }
        return result
    }
}
#endif
