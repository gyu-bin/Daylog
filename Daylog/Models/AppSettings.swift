import Foundation
import SwiftData

/// 앱 설정. 논리적으로 하나다.
///
/// 두 기기가 각자 설정을 만들면 둘이 들어올 수 있다. 지우지 않고, `SettingsService`가 항상 같은
/// 대표를 골라 쓰며 `SyncReconciler`가 값을 합친다.
@Model
final class AppSettings {
    var singletonKey: String = "app"
    /// 달성한 날로 보는 기준(%). 50...100.
    var achieveThreshold: Int = 80
    /// 첫 루틴을 만든 날짜의 UTC 정오. 통계 시작일.
    var firstRoutineDate: Date?
    /// 기준값을 마지막으로 바꾼 시각.
    var updatedAt: Date?
    var syncID: UUID?

    init(achieveThreshold: Int = 80, firstRoutineDate: Date? = nil) {
        self.singletonKey = "app"
        self.achieveThreshold = achieveThreshold
        self.firstRoutineDate = firstRoutineDate
        self.syncID = UUID()
    }

    var firstRoutineDay: Day? {
        firstRoutineDate.map(Day.init(anchorDate:))
    }
}
