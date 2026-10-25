#if os(iOS)
import AppIntents
import Foundation
import WidgetKit

/// App and widget share the intent identity. App-only ForegroundContinuableIntent conformance routes execution
/// to the existing app process, retaining its store lock and serial main context. The extension is a durable fallback.
struct ToggleRoutineIntent: AppIntent {
    static var title: LocalizedStringResource = "루틴 체크"
    static var description = IntentDescription("오늘의 루틴을 완료하거나 완료를 취소합니다.")
    /// 단축어 앱에는 내놓지 않는다. 위젯의 버튼 전용이다.
    static var isDiscoverable: Bool { false }
    // Modern routing metadata; the app-only conformance covers iOS 17–25.
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .foreground(.dynamic) }
    @available(iOS 27.0, *)
    static var allowedExecutionTargets: IntentExecutionTargets { .main }

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

    @MainActor
    func perform() async throws -> some IntentResult {
        // 위젯이 어제의 화면을 아직 보여 주고 있을 수 있다. 오늘 날짜의 항목만 받는다(지난 날·미래의 기록을 만들지 않는다).
        guard dateKey == Day.today().key, let id = UUID(uuidString: routineID) else { return .result() }
        guard let bridge = WidgetBridge.shared else { throw ToggleError.noSharedStorage }
        // 적지 못하면 던진다. 대기열이 그대로라 위젯의 표시도 바뀌지 않는다.
        try bridge.appendPending(PendingCheck(dateKey: dateKey, routineID: id, isDone: isDone, at: .now))
        #if !DAYLOG_WIDGET_EXTENSION
        if let runtime = AppRuntime.shared {
            // SwiftData save and snapshot publication finish before WidgetKit reloads the timeline.
            // Failure leaves the journal and a visible pending target for the next app activation.
            _ = await runtime.commitWidgetChecks()
        }
        #endif
        WidgetCenter.shared.reloadTimelines(ofKind: "DaylogToday")
        return .result()
    }

    enum ToggleError: Error, CustomLocalizedStringResourceConvertible {
        case noSharedStorage

        var localizedStringResource: LocalizedStringResource {
            "RoutiMori와 위젯이 함께 쓰는 저장 공간을 열 수 없어요. RoutiMori를 열어 체크해 주세요."
        }
    }
}

#endif
