import AppIntents
import Foundation
import WidgetKit

/// 큰 위젯에서 루틴을 눌렀을 때. 저장소를 직접 고치지 않고 "이 루틴을 이 값으로"라는 요청을 대기열에 적는다.
/// 앱이 다음에 실행될 때 기존 저장 경로(중복 방지, 편집 기록, iCloud 병합 규칙)로 반영한다.
struct ToggleRoutineIntent: AppIntent {
    static var title: LocalizedStringResource = "루틴 체크"
    static var description = IntentDescription("오늘의 루틴을 완료하거나 완료를 취소합니다.")
    /// 단축어 앱에는 내놓지 않는다. 위젯의 버튼 전용이다.
    static var isDiscoverable: Bool { false }

    @Parameter(title: "루틴")
    var routineID: String
    @Parameter(title: "날짜")
    var dateKey: String
    @Parameter(title: "완료")
    var isDone: Bool

    init() {}

    init(routineID: UUID, dateKey: String, isDone: Bool) {
        self.routineID = routineID.uuidString
        self.dateKey = dateKey
        self.isDone = isDone
    }

    func perform() async throws -> some IntentResult {
        // 위젯이 어제의 화면을 아직 보여 주고 있을 수 있다. 오늘 날짜의 항목만 받는다(지난 날·미래의 기록을 만들지 않는다).
        guard dateKey == Day.today().key, let id = UUID(uuidString: routineID) else { return .result() }
        guard let bridge = WidgetBridge.shared else { throw ToggleError.noSharedStorage }
        // 적지 못하면 던진다. 대기열이 그대로라 위젯의 표시도 바뀌지 않는다.
        try bridge.appendPending(PendingCheck(dateKey: dateKey, routineID: id, isDone: isDone, at: .now))
        // 시스템이 알아서 다시 그리기를 기다리지 않고, 같은 종류의 위젯(작게·중간·크게)을 모두 새로 그리게 한다.
        WidgetCenter.shared.reloadTimelines(ofKind: TodayWidget.kind)
        return .result()
    }

    enum ToggleError: Error, CustomLocalizedStringResourceConvertible {
        case noSharedStorage

        var localizedStringResource: LocalizedStringResource {
            "Daylog와 위젯이 함께 쓰는 저장 공간을 열 수 없어요. Daylog를 열어 체크해 주세요."
        }
    }
}
