import SwiftUI

/// 통계 화면. [루틴 통계]는 대시보드와 같은 컴포넌트·같은 계산 결과(`store.stats`)를 더 넓게 보여 주고,
/// [식사 기록]은 지난 식사를 찾아보는 화면이다.
struct StatisticsView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store
        GeometryReader { proxy in
            let isWide = proxy.size.width >= 880
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacing) {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline) {
                            PageTitle(title: "통계", subtitle: "오늘(\(store.today.longTitle)) 기준")
                            Spacer(minLength: 16)
                            tabPicker(selection: $store.statisticsTab)
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            PageTitle(title: "통계", subtitle: "오늘(\(store.today.longTitle)) 기준")
                            tabPicker(selection: $store.statisticsTab)
                        }
                    }

                    switch store.statisticsTab {
                    case .routines:
                        routineStatistics(isWide: isWide)
                    case .meals:
                        MealHistoryView(isWide: isWide)
                    }
                }
                .padding(Theme.pagePadding)
            }
        }
    }

    private func tabPicker(selection: Binding<StatisticsTab>) -> some View {
        Picker("통계 종류", selection: selection) {
            ForEach(StatisticsTab.allCases) { tab in
                Text(tab.title).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
    }

    @ViewBuilder
    private func routineStatistics(isWide: Bool) -> some View {
        StatCardsGrid(columns: isWide ? 4 : 2)
        TrendChartCard(chartHeight: 200)
        AdaptiveRow(isWide: isWide) {
            GroupRatesCard()
            RoutineRatesCard(showsAllLink: false)
        }
        AdaptiveRow(isWide: isWide) {
            MonthCalendarCard()
            RecentDaysCard(title: "최근 30일 기록", outcomes: store.stats.trend.reversed(), showsAllLink: false)
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

/// 그룹별 달성률(최근 30일). 각 날짜는 그날 속해 있던 그룹으로 집계한다.
struct GroupRatesCard: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                CardHeader(symbol: "square.stack.3d.up", title: "그룹별 달성률", subtitle: "(최근 30일)")

                if store.stats.groupRates.isEmpty {
                    EmptyHint(symbol: "square.stack", message: "그룹에 항목을 넣고 기록하면 그룹별 달성률이 보여요.")
                } else {
                    VStack(spacing: 9) {
                        ForEach(store.stats.groupRates) { rate in
                            let color = GroupColor(key: rate.colorKey)
                            HStack(spacing: 10) {
                                GroupBadge(title: rate.title, color: color, size: 20)
                                Text(rate.isArchived ? "\(rate.title) (보관됨)" : rate.title)
                                    .font(.callout)
                                    .foregroundStyle(rate.isArchived ? .secondary : .primary)
                                    .lineLimit(1)
                                    .frame(width: 104, alignment: .leading)
                                    .help(rate.title)
                                ProgressBar(ratio: rate.ratio, height: 10, tint: color.color)
                                Text("\(rate.percent)%")
                                    .font(.callout)
                                    .monospacedDigit()
                                    .frame(width: 40, alignment: .trailing)
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(rate.title) 그룹\(rate.isArchived ? ", 보관됨" : "")")
                            .accessibilityValue("달성률 \(rate.percent)%, 예정 \(rate.scheduled)개 중 \(rate.done)개 완료")
                        }
                    }
                }
            }
        }
    }
}
