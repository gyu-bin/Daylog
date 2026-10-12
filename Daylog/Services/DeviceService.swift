import Foundation
import SwiftData

/// 같은 iCloud 계정으로 Daylog를 쓰는 기기 하나. 설정의 iCloud 화면에 보여 준다.
struct DeviceInfo: Identifiable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case mac, phone, pad

        var symbol: String {
            switch self {
            case .mac: return "desktopcomputer"
            case .phone: return "iphone"
            case .pad: return "ipad"
            }
        }
    }

    /// 그 기기의 저장소 식별자(`AppStore.deviceID`).
    var id: String
    var name: String
    var kind: Kind
    var appVersion: String
    /// 그 기기가 마지막으로 자기 정보를 적은 때. "지금 연결됨"이 아니라 "마지막으로 앱을 쓴 때"에 가깝다.
    var lastActive: Date
}

/// 휴가처럼 기존 `FieldEdit`의 확장 칸에 적는다(새 CloudKit 유형·속성 없음). 기기마다 자기 줄 하나만 쓴다.
/// 칸 이름이 텍스트·체크·휴가와 달라서 이 기능이 없는 버전의 앱은 그냥 무시한다.
enum DeviceEdit {
    static let dateKey = "device"
    static let prefix = "device:"

    struct Payload: Codable, Equatable {
        var version = 1
        var name: String
        var kind: DeviceInfo.Kind
        var appVersion: String
        /// 목록에서 지운 기기. 그 기기가 다시 앱을 쓰면 false로 돌아온다.
        var isRemoved = false
    }

    static func fieldName(_ deviceID: String) -> String { prefix + deviceID }

    static func encode(_ payload: Payload) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(payload)).map { String(decoding: $0, as: UTF8.self) } ?? ""
    }

    static func decode(_ value: String) -> Payload? {
        try? JSONDecoder().decode(Payload.self, from: Data(value.utf8))
    }

    /// 자기 정보를 다시 적을 때가 됐는가: 처음이거나, 내용이 바뀌었거나, 마지막으로 적은 지 `interval`이 지났을 때.
    /// 너무 자주 적으면 그때마다 다른 기기로 동기화가 일어난다.
    static func needsWrite(existing: (payload: Payload, editedAt: Date)?, payload: Payload, now: Date, interval: TimeInterval) -> Bool {
        guard let existing else { return true }
        return existing.payload != payload || now.timeIntervalSince(existing.editedAt) >= interval
    }
}

@MainActor
struct DeviceService {
    let context: ModelContext
    let deviceID: String

    /// 마지막 활동을 다시 적는 최소 간격(6시간).
    static let touchInterval: TimeInterval = 6 * 3600
    /// 이보다 오래 활동이 없으면 "오래 쓰지 않은 기기"로 본다.
    static let staleInterval: TimeInterval = 30 * 86400

    private func rows() throws -> [FieldEdit] {
        let key = DeviceEdit.dateKey
        return try context.fetch(FetchDescriptor<FieldEdit>(predicate: #Predicate { $0.dateKey == key }))
    }

    /// 최근에 쓴 기기부터. 지운 기기는 빼고, 같은 기기의 줄이 여럿이면 가장 나중 것만 쓴다.
    func devices() throws -> [DeviceInfo] {
        var latest: [String: FieldEdit] = [:]
        for row in try rows() where row.field == DeviceEdit.fieldName(row.deviceID) {
            if let current = latest[row.deviceID], current.editedAt >= row.editedAt { continue }
            latest[row.deviceID] = row
        }
        return latest.values.compactMap { row in
            guard let payload = DeviceEdit.decode(row.value), !payload.isRemoved else { return nil }
            return DeviceInfo(id: row.deviceID, name: payload.name, kind: payload.kind, appVersion: payload.appVersion, lastActive: row.editedAt)
        }
        .sorted { ($0.lastActive, $0.id) > ($1.lastActive, $1.id) }
    }

    /// 이 기기의 정보를 적는다. 적었으면 true(저장은 호출한 쪽이 한다).
    @discardableResult
    func touch(name: String, kind: DeviceInfo.Kind, appVersion: String, now: Date = .now) throws -> Bool {
        let payload = DeviceEdit.Payload(name: name, kind: kind, appVersion: appVersion)
        let mine = try rows().filter { $0.deviceID == deviceID && $0.field == DeviceEdit.fieldName(deviceID) }
            .max { $0.editedAt < $1.editedAt }
        let existing = mine.flatMap { row in DeviceEdit.decode(row.value).map { (payload: $0, editedAt: row.editedAt) } }
        guard DeviceEdit.needsWrite(existing: existing, payload: payload, now: now, interval: Self.touchInterval) else { return false }
        let row = mine ?? {
            let created = FieldEdit(dateKey: DeviceEdit.dateKey, field: DeviceEdit.fieldName(deviceID), deviceID: deviceID)
            context.insert(created)
            return created
        }()
        row.value = DeviceEdit.encode(payload)
        row.editedAt = now
        return true
    }

    /// 다른 기기를 목록에서 지운다. 기록은 건드리지 않고, 그 기기가 다시 앱을 쓰면 목록에 돌아온다.
    func remove(_ id: String) throws {
        for row in try rows() where row.deviceID == id && row.field == DeviceEdit.fieldName(id) {
            guard var payload = DeviceEdit.decode(row.value) else { continue }
            payload.isRemoved = true
            row.value = DeviceEdit.encode(payload)
        }
    }
}
