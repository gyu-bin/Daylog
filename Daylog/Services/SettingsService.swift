import Foundation
import SwiftData

@MainActor
struct SettingsService {
    nonisolated static let thresholdRange = 50...100
    nonisolated static let defaultThreshold = 80

    let context: ModelContext

    /// 저장된 설정 전부. 대표가 맨 앞(어느 기기에서든 같은 순서).
    func allSettings() throws -> [AppSettings] {
        try context.fetch(FetchDescriptor<AppSettings>()).sorted { SyncOrder.precedes($0.syncID, $1.syncID) }
    }

    /// 저장된 설정. 아직 없으면 nil(읽기만 할 때는 만들지 않는다).
    func existingSettings() throws -> AppSettings? {
        try allSettings().first
    }

    /// 설정 객체를 재사용하고, 없을 때만 하나 만든다. 저장은 호출한 쪽에서 한다.
    func settings() throws -> AppSettings {
        if let existing = try existingSettings() { return existing }
        let settings = AppSettings(achieveThreshold: Self.defaultThreshold)
        context.insert(settings)
        return settings
    }

    func setThreshold(_ value: Int, now: Date = .now) throws {
        let clamped = min(max(value, Self.thresholdRange.lowerBound), Self.thresholdRange.upperBound)
        let settings = try settings()
        guard settings.achieveThreshold != clamped || context.hasChanges else { return }
        settings.achieveThreshold = clamped
        settings.updatedAt = now
        try context.save()
    }
}
