import Foundation
import SwiftData

/// v1.1의 저장소 형식. 이 파일은 고치지 않는다.
///
/// 기존 저장소를 열 때 SwiftData가 "어떤 형식에서 왔는지" 알아야 안전하게 옮길 수 있다.
/// 모델을 바꿀 때는 여기를 건드리지 말고 새 버전을 추가한다.
enum DaylogSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [RoutineItem.self, RoutineRevision.self, DayRecord.self, DayCheck.self, AppSettings.self]
    }

    @Model
    final class RoutineItem {
        @Attribute(.unique) var id: UUID
        var title: String
        var note: String
        var timeLabel: String
        var weekdayMask: Int
        var order: Int
        var isArchived: Bool
        var createdAt: Date

        init(
            id: UUID = UUID(),
            title: String,
            note: String = "",
            timeLabel: String = "",
            weekdays: [Int] = Weekdays.all,
            order: Int,
            isArchived: Bool = false,
            createdAt: Date = .now
        ) {
            self.id = id
            self.title = title
            self.note = note
            self.timeLabel = timeLabel
            self.weekdayMask = Weekdays.mask(weekdays)
            self.order = order
            self.isArchived = isArchived
            self.createdAt = createdAt
        }

        /// 1 = 월요일 … 7 = 일요일.
        var weekdays: [Int] {
            get { Weekdays.days(mask: weekdayMask) }
            set { weekdayMask = Weekdays.mask(newValue) }
        }
    }

    @Model
    final class RoutineRevision {
        var routineID: UUID
        var effectiveFromKey: String
        var title: String
        var timeLabel: String
        var note: String
        var weekdayMask: Int
        var isArchived: Bool
        var order: Int
        var updatedAt: Date

        init(routine: RoutineItem, effectiveFrom day: Day, now: Date = .now) {
            self.routineID = routine.id
            self.effectiveFromKey = day.key
            self.title = routine.title
            self.timeLabel = routine.timeLabel
            self.note = routine.note
            self.weekdayMask = routine.weekdayMask
            self.isArchived = routine.isArchived
            self.order = routine.order
            self.updatedAt = now
        }

        func apply(_ routine: RoutineItem, now: Date) {
            title = routine.title
            timeLabel = routine.timeLabel
            note = routine.note
            weekdayMask = routine.weekdayMask
            isArchived = routine.isArchived
            order = routine.order
            updatedAt = now
        }

        func matches(_ routine: RoutineItem) -> Bool {
            title == routine.title
                && timeLabel == routine.timeLabel
                && note == routine.note
                && weekdayMask == routine.weekdayMask
                && isArchived == routine.isArchived
                && order == routine.order
        }
    }

    @Model
    final class DayRecord {
        @Attribute(.unique) var dateKey: String
        /// 해당 날짜의 UTC 정오(`Day.anchorDate`).
        var date: Date

        @Relationship(deleteRule: .cascade, inverse: \DayCheck.record)
        var checks: [DayCheck] = []

        var breakfast: String
        var lunch: String
        var dinner: String
        var snack: String
        var mealMemo: String
        var tomorrowTask: String

        /// 사용자가 이 날짜에 마지막으로 무언가를 입력한 시각.
        /// nil이면 날짜를 열어 자동 생성되기만 한 미기록 상태다.
        var activityAt: Date?
        var createdAt: Date

        init(day: Day, now: Date = .now) {
            self.dateKey = day.key
            self.date = day.anchorDate
            self.breakfast = ""
            self.lunch = ""
            self.dinner = ""
            self.snack = ""
            self.mealMemo = ""
            self.tomorrowTask = ""
            self.activityAt = nil
            self.createdAt = now
        }

        var isRecorded: Bool { activityAt != nil }
    }

    @Model
    final class DayCheck {
        var routineID: UUID
        var title: String
        var timeLabel: String
        var note: String
        var order: Int
        var isDone: Bool
        var record: DayRecord?

        init(routineID: UUID, title: String, timeLabel: String, note: String, order: Int, isDone: Bool = false) {
            self.routineID = routineID
            self.title = title
            self.timeLabel = timeLabel
            self.note = note
            self.order = order
            self.isDone = isDone
        }

        convenience init(routine: RoutineItem) {
            self.init(
                routineID: routine.id,
                title: routine.title,
                timeLabel: routine.timeLabel,
                note: routine.note,
                order: routine.order
            )
        }

        convenience init(snapshotV1 snapshot: RevisionSnapshot) {
            self.init(
                routineID: snapshot.routineID,
                title: snapshot.title,
                timeLabel: snapshot.timeLabel,
                note: snapshot.note,
                order: snapshot.order
            )
        }
    }

    @Model
    final class AppSettings {
        @Attribute(.unique) var singletonKey: String
        /// 달성한 날로 보는 기준(%). 50...100.
        var achieveThreshold: Int
        /// 첫 루틴을 만든 날짜의 UTC 정오. 통계 시작일.
        var firstRoutineDate: Date?

        init(achieveThreshold: Int = 80, firstRoutineDate: Date? = nil) {
            self.singletonKey = "app"
            self.achieveThreshold = achieveThreshold
            self.firstRoutineDate = firstRoutineDate
        }

        var firstRoutineDay: Day? {
            firstRoutineDate.map(Day.init(anchorDate:))
        }
    }
}
