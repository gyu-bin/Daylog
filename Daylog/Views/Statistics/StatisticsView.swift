import SwiftUI

/// 통계 화면. 대시보드와 같은 컴포넌트와 같은 계산 결과(`store.stats`)를 더 넓게 보여 준다.
struct StatisticsView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width >= 880
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacing) {
                    PageTitle(title: "통계", subtitle: "오늘(\(store.today.longTitle)) 기준")
                    StatCardsGrid(columns: isWide ? 4 : 2)
                    TrendChartCard(chartHeight: 200)
                    AdaptiveRow(isWide: isWide) {
                        MonthCalendarCard()
                        RoutineRatesCard(showsAllLink: false)
                    }
                    RecentDaysCard(title: "최근 30일 기록", outcomes: store.stats.trend.reversed(), showsAllLink: false)
                }
                .padding(Theme.pagePadding)
            }
        }
    }
}

struct PageTitle: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 4)
    }
}
