import Foundation
import SwiftData

/// 날짜별 하루 기록. 논리적으로 `dateKey`당 하나다.
///
/// CloudKit은 고유 제약을 지원하지 않아서, 두 기기가 오프라인에서 같은 날짜를 각각 만들면 같은 `dateKey`의
/// 기록이 둘 들어올 수 있다. 그때는 `SyncReconciler`가 대표 기록 하나로 내용을 합치고, 화면과 통계는
/// 대표 기록만 본다. 대표가 아닌 기록은 지우지 않는다(다른 기기가 아직 그 기록에 쓰고 있을 수 있다).
@Model
final class DayRecord {
    var dateKey: String = ""
    /// 해당 날짜의 UTC 정오(`Day.anchorDate`).
    var date: Date = Date.distantPast

    /// CloudKit 조건 때문에 optional이다. 읽을 때는 `checkList`를 쓴다.
    @Relationship(deleteRule: .cascade, inverse: \DayCheck.record)
    var checks: [DayCheck]? = []

    var breakfast: String = ""
    var lunch: String = ""
    var dinner: String = ""
    var snack: String = ""
    var mealMemo: String = ""
    var tomorrowTask: String = ""

    /// 사용자가 이 날짜에 마지막으로 무언가를 입력한 시각.
    /// nil이면 날짜를 열어 자동 생성되기만 한 미기록 상태다.
    var activityAt: Date?
    var createdAt: Date = Date.distantPast
    /// 기기 간에 같은 값으로 동기화되는 식별자. 어느 기기에서든 같은 대표 기록을 고르는 데 쓴다.
    var syncID: UUID?
    /// 대표 기록이 다른 기록·중복 체크에서 이미 가져온 내용의 장부(`MergeLedger`의 JSON).
    /// 이게 있어야 가져온 뒤 사용자가 고치거나 지운 내용이 병합 때 되살아나지 않는다.
    var mergeState: Data?

    init(day: Day, now: Date = .now) {
        self.dateKey = day.key
        self.date = day.anchorDate
        self.activityAt = nil
        self.createdAt = now
        self.syncID = UUID()
    }

    var isRecorded: Bool { activityAt != nil }

    /// 이 기록에 실제로 붙어 있는 체크 전부(같은 루틴의 중복 포함).
    var physicalChecks: [DayCheck] { checks ?? [] }

    /// 루틴당 하나씩만 고른, 그날의 대상인 체크 목록. 표시 순서대로.
    /// 숨긴 항목은 빼되, 완료한 항목은 숨김이어도 남긴다.
    var checkList: [DayCheck] {
        Dictionary(grouping: physicalChecks, by: \.routineID)
            .values
            .compactMap { group -> DayCheck? in
                guard let representative = group.min(by: { SyncOrder.precedes($0.syncID, $1.syncID) }) else { return nil }
                let isVisible = !representative.isHidden || group.contains(where: \.isDone)
                return isVisible ? representative : nil
            }
            .sorted {
                ($0.order, $0.title, $0.routineID.uuidString) < ($1.order, $1.title, $1.routineID.uuidString)
            }
    }

    func attach(_ check: DayCheck) {
        check.record = self
        if checks == nil {
            checks = [check]
        } else if !physicalChecks.contains(where: { $0 === check }) {
            checks?.append(check)
        }
    }
}

/// 기기와 무관하게 같은 결과가 나오는 순서 규칙.
enum SyncOrder {
    /// 식별자가 없는 것(이론상 없어야 함)은 항상 뒤로 보낸다.
    static func precedes(_ lhs: UUID?, _ rhs: UUID?) -> Bool {
        switch (lhs, rhs) {
        case let (lhs?, rhs?): return lhs.uuidString < rhs.uuidString
        case (_?, nil): return true
        default: return false
        }
    }
}
