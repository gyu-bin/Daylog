import Foundation

/// Portable routine definitions only. IDs/history are deliberately not part of this import format.
struct TransferRoutine: Codable, Equatable, Sendable {
    var group: String
    var title: String
    var weekdays: [Int]
    var time: String
    var note: String
}

struct RoutineTransferDocument: Codable, Equatable, Sendable {
    var format = "daylog.routines"
    var version = 1
    var routines: [TransferRoutine]
}

enum RoutineTransferError: LocalizedError {
    case invalid(String)
    case changed
    case pendingEdits

    var errorDescription: String? {
        switch self {
        case .invalid(let message): return message
        case .changed: return "미리보기 이후 데이터나 날짜가 바뀌었어요. 미리보기를 새로 확인한 뒤 저장해 주세요."
        case .pendingEdits: return "입력 중인 내용을 먼저 저장한 뒤 다시 시도해 주세요."
        }
    }
}

enum RoutineTransferFormat {
    static let maximumBytes = 5 * 1_024 * 1_024
    static let maximumRows = 1_000
    static let headers = ["group", "title", "weekdays", "time", "note"]

    static func decode(_ data: Data, isJSON: Bool) throws -> [TransferRoutine] {
        guard data.count <= maximumBytes else { throw RoutineTransferError.invalid("파일은 5MB 이하만 가져올 수 있어요.") }
        let rows: [TransferRoutine]
        if isJSON {
            do {
                let document = try JSONDecoder().decode(RoutineTransferDocument.self, from: data)
                guard document.format == "daylog.routines", document.version == 1 else {
                    throw RoutineTransferError.invalid("지원하지 않는 JSON 형식 또는 버전이에요. 전체 백업 JSON은 복원할 수 없어요.")
                }
                rows = document.routines
            } catch let error as RoutineTransferError { throw error }
            catch { throw RoutineTransferError.invalid("루틴 JSON의 필드와 자료형을 확인해 주세요. version은 정수, weekdays는 정수 배열이어야 해요.") }
        } else {
            guard var text = String(data: data, encoding: .utf8) else {
                throw RoutineTransferError.invalid("CSV를 UTF-8로 저장해 주세요.")
            }
            if text.first == "\u{FEFF}" { text.removeFirst() }
            let table = try parseCSV(text)
            guard table.first == headers else {
                throw RoutineTransferError.invalid("CSV 첫 줄은 group,title,weekdays,time,note여야 해요.")
            }
            rows = try table.dropFirst().enumerated().map { offset, cells in
                guard cells.count == headers.count else {
                    throw RoutineTransferError.invalid("CSV \(offset + 2)번째 행의 열은 5개여야 해요.")
                }
                let parts = cells[2].split(separator: ";", omittingEmptySubsequences: false)
                let weekdays = parts.compactMap { part -> Int? in
                    guard part.count == 1, let n = Int(part), (1...7).contains(n) else { return nil }
                    return n
                }
                guard weekdays.count == parts.count else {
                    throw RoutineTransferError.invalid("CSV \(offset + 2)번째 행의 요일은 1;2;3처럼 입력해 주세요(월=1, 일=7).")
                }
                return TransferRoutine(group: cells[0], title: cells[1], weekdays: weekdays, time: cells[3], note: cells[4])
            }
        }
        guard !rows.isEmpty, rows.count <= maximumRows else {
            throw RoutineTransferError.invalid("한 번에 1~1,000개 루틴을 가져올 수 있어요.")
        }
        return rows
    }

    static func validation(_ row: TransferRoutine) -> String? {
        for (name, value, maximum) in [("그룹명", row.group, 40), ("루틴명", row.title, 60)] {
            guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "\(name)을 입력해 주세요." }
            guard value.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else { return "\(name)에 줄바꿈·제어 문자를 넣을 수 없어요." }
            guard value.count <= maximum else { return "\(name)은 \(maximum)자 이하여야 해요." }
            guard value == value.trimmingCharacters(in: .whitespacesAndNewlines) else { return "\(name)의 앞뒤 공백을 제거해 주세요." }
        }
        guard !row.weekdays.isEmpty, row.weekdays.allSatisfy({ (1...7).contains($0) }), Set(row.weekdays).count == row.weekdays.count else {
            return "요일은 중복 없이 1~7 중 하나 이상이어야 해요."
        }
        guard row.time.count <= 12 else { return "시간은 12자 이하여야 해요." }
        guard row.time == row.time.trimmingCharacters(in: .whitespacesAndNewlines) else { return "시간의 앞뒤 공백을 제거해 주세요." }
        guard row.time.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else { return "시간에 줄바꿈·제어 문자를 넣을 수 없어요." }
        if row.time.contains(":"), row.time.allSatisfy({ $0.isNumber || $0 == ":" }), TimeLabel.minutes(row.time) == nil {
            return "시각은 00:00~23:59 범위로 입력해 주세요."
        }
        return nil
    }

    static func json(_ rows: [TransferRoutine]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(RoutineTransferDocument(routines: rows))
    }

    static func csv(_ rows: [TransferRoutine]) -> Data {
        let table = [headers] + rows.map { [$0.group, $0.title, $0.weekdays.map(String.init).joined(separator: ";"), $0.time, $0.note] }
        let text = table.map { $0.map(escapeCSV).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
        return Data(text.utf8)
    }

    static var template: Data {
        csv([TransferRoutine(group: "건강", title: "가볍게 걷기", weekdays: [1, 2, 3, 4, 5], time: "08:00", note: "20분")])
    }

    private static func escapeCSV(_ value: String) -> String {
        if value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" || $0 == "\r\n" }) {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    /// Strict quoted CSV; CRLF/LF and embedded newlines are preserved inside quotes.
    static func parseCSV(_ text: String) throws -> [[String]] {
        enum State { case plain, quoted, closed }
        var state = State.plain
        var table: [[String]] = [], row: [String] = []
        var field = ""
        var atFieldStart = true
        var endedRow = false
        func invalid() -> RoutineTransferError { .invalid("CSV 따옴표 형식이 잘못되었어요. 따옴표 안의 따옴표는 두 번 적어 주세요.") }
        for character in text {
            let newline = character == "\n" || character == "\r" || character == "\r\n"
            endedRow = false
            if state == .quoted {
                if character == "\"" { state = .closed } else { field.append(character) }
                continue
            }
            if character == "\"" {
                if state == .closed { field.append(character); state = .quoted }
                else if atFieldStart { state = .quoted; atFieldStart = false }
                else { throw invalid() }
            } else if character == "," || newline {
                row.append(field); field = ""; state = .plain; atFieldStart = true
                if newline {
                    table.append(row); row = []; endedRow = true
                    guard table.count <= maximumRows + 1 else { throw RoutineTransferError.invalid("루틴은 1,000개 이하만 가져올 수 있어요.") }
                }
            } else {
                guard state != .closed else { throw invalid() }
                field.append(character); atFieldStart = false
            }
        }
        guard state != .quoted else { throw invalid() }
        if !endedRow && (!text.isEmpty || !row.isEmpty) { row.append(field); table.append(row) }
        return table
    }
}
