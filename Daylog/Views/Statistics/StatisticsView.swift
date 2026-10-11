import SwiftUI

/// 통계 화면: 고른 기간의 루틴 달성 기록과, 식사를 얼마나 적었는지.
/// 지난 식사를 찾아보고 고치는 일은 식사 기록 화면이 맡는다.
struct StatisticsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var mealSummary = MealSummary()

    var body: some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width >= 880
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacing) {
                    PageTitle(title: "통계", subtitle: "오늘(\(store.today.longTitle)) 기준")

                    RoutineStatisticsView(isWide: isWide)

                    SectionTitle(symbol: "fork.knife", title: "식사 기록", tint: Theme.mealTint)
                    MealSummaryTiles(summary: mealSummary, periodTitle: MealPeriod.month.title, isWide: isWide)

                    // 아래 탭에는 캘린더가 없어서(iPhone, 좁은 창) 여기에 둔다. 날짜를 누르면 그날의 기록을 연다.
                    if horizontalSizeClass == .compact {
                        SectionTitle(symbol: "calendar", title: "캘린더", tint: Theme.accent)
                        MonthCalendarCard(opensDashboard: true)
                    }
                }
                .pagePadding()
            }
        }
        .onAppear(perform: reload)
        .onChange(of: store.dataVersion) { reload() }
    }

    private func reload() {
        mealSummary = store.mealSummary(period: .month)
    }
}

struct PageTitle: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .accessibilityAddTraits(.isHeader)
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
