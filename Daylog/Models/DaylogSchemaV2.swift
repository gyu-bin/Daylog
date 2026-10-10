import Foundation
import SwiftData

/// v1.2의 저장소 형식. 이 파일은 고치지 않는다.
///
/// 저장 속성만 옮겨 적었다(형식을 식별하는 데에는 속성 정의만 있으면 된다).
enum DaylogSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [RoutineItem.self, RoutineRevision.self, DayRecord.self, DayCheck.self, AppSettings.self, FieldEdit.self]
    }

    @Model
    final class RoutineItem {
        var id: UUID = UUID()
        var title: String = ""
        var note: String = ""
        var timeLabel: String = ""
        var weekdayMask: Int = 127
        var order: Int = 0
        var isArchived: Bool = false
        var createdAt: Date = Date.distantPast
        var updatedAt: Date?

        init() {}
    }

    @Model
    final class RoutineRevision {
        var routineID: UUID = UUID()
        var effectiveFromKey: String = ""
        var title: String = ""
        var timeLabel: String = ""
        var note: String = ""
        var weekdayMask: Int = 127
        var isArchived: Bool = false
        var order: Int = 0
        var updatedAt: Date = Date.distantPast
        var syncID: UUID?

        init() {}
    }

    @Model
    final class DayRecord {
        var dateKey: String = ""
        var date: Date = Date.distantPast
        @Relationship(deleteRule: .cascade, inverse: \DayCheck.record)
        var checks: [DayCheck]? = []
        var breakfast: String = ""
        var lunch: String = ""
        var dinner: String = ""
        var snack: String = ""
        var mealMemo: String = ""
        var tomorrowTask: String = ""
        var activityAt: Date?
        var createdAt: Date = Date.distantPast
        var syncID: UUID?
        var mergeState: Data?

        init() {}
    }

    @Model
    final class DayCheck {
        var routineID: UUID = UUID()
        var title: String = ""
        var timeLabel: String = ""
        var note: String = ""
        var order: Int = 0
        var isDone: Bool = false
        var record: DayRecord?
        var isHidden: Bool = false
        var syncID: UUID?

        init() {}
    }

    @Model
    final class AppSettings {
        var singletonKey: String = "app"
        var achieveThreshold: Int = 80
        var firstRoutineDate: Date?
        var updatedAt: Date?
        var syncID: UUID?

        init() {}
    }

    @Model
    final class FieldEdit {
        var dateKey: String = ""
        var field: String = ""
        var deviceID: String = ""
        var value: String = ""
        var editedAt: Date = Date.distantPast
        var seenState: Data?
        var syncID: UUID?

        init() {}
    }
}
