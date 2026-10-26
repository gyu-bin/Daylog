import SwiftUI
import WidgetKit

@main
struct DaylogWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
    }
}

/// 오늘의 루틴 위젯(작게·중간·크게). 앱이 앱 그룹 폴더에 적어 둔 실제 루틴만 보여 준다.
struct TodayWidget: Widget {
    static let kind = "DaylogToday"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
                .widgetURL(URL(string: "daylog://today"))
        }
        .configurationDisplayName("오늘의 루틴")
        .description("오늘의 달성률과 루틴을 보여 줘요. 루틴을 눌러서 앱을 열지 않고 바로 체크할 수 있어요.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}
