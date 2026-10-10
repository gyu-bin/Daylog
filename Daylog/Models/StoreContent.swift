import Foundation
import SQLite3

/// 저장소의 내용을 "표마다, 정렬된 행 문자열"로 읽는다.
///
/// 행 번호(Z_PK)처럼 저장소 파일마다 달라지는 값은 빼고 읽어서, 서로 다른 파일에 든 기록이 같은지 비교할 수 있다.
/// 모델 코드가 아니라 실제 열을 그대로 읽으므로, 모델에 속성이 늘어도 비교에서 빠지지 않는다.
/// 동기화 이력 표(ANSCK…, Z_로 시작하는 표)는 보지 않는다.
enum StoreContent {
    /// 저장소마다 달라지는 열: 행 번호, 저장 횟수, 엔티티 번호.
    private static let volatileColumns: Set<String> = ["Z_PK", "Z_OPT", "Z_ENT"]

    static func rows(at url: URL) throws -> [String: [String]] {
        try StoreBackup.withDatabase(at: url) { database in
            let tables = try texts(
                "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'Z%' AND name NOT LIKE 'Z\\_%' ESCAPE '\\' ORDER BY name",
                in: database
            )
            var result: [String: [String]] = [:]
            for table in tables {
                let columns = try texts("SELECT name FROM pragma_table_info('\(table)') ORDER BY name", in: database)
                    .filter { !volatileColumns.contains($0) }
                let expressions = columns.map { column -> String in
                    // 체크가 속한 기록은 행 번호 대신 그 기록의 동기화 식별자로 비교한다.
                    table == "ZDAYCHECK" && column == "ZRECORD"
                        ? "(SELECT quote(ZSYNCID) FROM ZDAYRECORD WHERE ZDAYRECORD.Z_PK = ZDAYCHECK.ZRECORD)"
                        : "quote(\(column))"
                }
                let sql = "SELECT " + expressions.map { "ifnull(\($0), 'NULL')" }.joined(separator: " || char(31) || ") + " FROM \(table)"
                result[table] = try texts(sql, in: database).sorted()
            }
            return result
        }
    }

    /// 두 저장소에서 내용이 다른 표의 이름. 비어 있으면 같다.
    static func differingTables(_ lhs: [String: [String]], _ rhs: [String: [String]]) -> [String] {
        Set(lhs.keys).union(rhs.keys).filter { lhs[$0] != rhs[$0] }.sorted()
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
