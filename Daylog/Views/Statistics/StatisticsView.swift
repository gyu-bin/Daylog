import SwiftUI

/// 통계 화면: 고른 기간의 루틴 달성 기록과, 식사를 얼마나 적었는지.
/// 지난 식사를 찾아보고 고치는 일은 식사 기록 화면이 맡는다.
struct StatisticsView: View {
    @Environment(AppStore.self) private var store
    @Environment(DevicePreferences.self) private var preferences
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width >= 880
            // 식사 요약은 그릴 때 바로 읽는다. 전에는 화면이 나타날 때 `@State`에 넣었는데, iPhone의 탭 화면에서는
            // 그 값이 화면에 반영되지 않아 "0일"로 남았다(식사 탭에는 제대로 나오는데 통계 탭만 0일).
            let mealSummary = mealSummary(version: store.dataVersion)
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacing) {
                    PageTitle(title: "통계", subtitle: "오늘(\(store.today.longTitle)) 기준", pio: PioLines.statistics(store.stats))

                    RoutineStatisticsView(isWide: isWide)

                    if preferences.mealsEnabled {
                        SectionTitle(symbol: "fork.knife", title: "식사 기록", tint: Theme.mealTint)
                        MealSummaryTiles(summary: mealSummary, periodTitle: MealPeriod.month.title, isWide: isWide)
                    }

                    // 아래 탭에는 캘린더가 없어서(iPhone, 좁은 창) 여기에 둔다. 날짜를 누르면 그날의 기록을 연다.
                    if horizontalSizeClass == .compact {
                        SectionTitle(symbol: "calendar", title: "캘린더", tint: Theme.accent)
                        MonthCalendarCard(opensDashboard: true)
                    }
                }
                .pagePadding()
            }
        }
    }

    /// `version`은 값에 쓰이지 않는다. 기록이 바뀌면(`dataVersion`) 이 화면을 다시 그리게 하려고 받는다.
    private func mealSummary(version: Int) -> MealSummary {
        preferences.mealsEnabled ? store.mealSummary(period: .month) : MealSummary()
    }
}

struct PageTitle: View {
    let title: String
    var subtitle: String?
    /// 피오의 한마디. 있으면 제목 줄 오른쪽 끝에 피오가 앉고, 탭을 열 때 잠깐 말한다.
    var pio: String? = nil
    /// 기본 크기는 24pt 그대로 두고, 글자 크기 설정을 따라 함께 커진다(설명보다 작아지지 않게).
    @ScaledMetric(relativeTo: .title2) private var titleSize: CGFloat = 24

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .center, spacing: 6) {
                Text(title)
                    .font(.system(size: titleSize, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                if let pio {
                    Spacer(minLength: 8)
                    // 제목 줄 오른쪽 끝: 탭을 열면 말풍선이 잠깐 떴다가 사라지고, 피오를 누르면 다시 뜬다.
                    PioPeekBubble(line: pio)
                }
            }
            if let subtitle {
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 2)
    }
}

/// 한 화면 안에서 묶음을 나누는 작은 제목.
struct SectionTitle: View {
    let symbol: String
    let title: String
    var tint: Color = Theme.accent

    var body: some View {
        Label {
            Text(title).font(.headline)
        } icon: {
            Image(systemName: symbol).foregroundStyle(tint)
        }
        .padding(.top, 6)
        .accessibilityAddTraits(.isHeader)
    }
}
