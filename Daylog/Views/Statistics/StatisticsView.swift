import SwiftUI

/// 통계 화면. [루틴 통계]는 고른 기간의 달성 기록을, [식사 기록]은 지난 식사를 보여 준다.
struct StatisticsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width >= 880
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacing) {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .center) {
                            PageTitle(title: "통계", subtitle: "오늘(\(store.today.longTitle)) 기준")
                            Spacer(minLength: 16)
                            tabPicker
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            PageTitle(title: "통계", subtitle: "오늘(\(store.today.longTitle)) 기준")
                            tabPicker
                        }
                    }

                    switch store.statisticsTab {
                    case .routines:
                        RoutineStatisticsView(isWide: isWide)
                    case .meals:
                        MealHistoryView(isWide: isWide)
                    }
                }
                .padding(Theme.pagePadding)
            }
        }
    }

    private var tabPicker: some View {
        Picker("통계 종류", selection: Binding(
            get: { store.statisticsTab },
            set: { tab in
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { store.statisticsTab = tab }
            }
        )) {
            ForEach(StatisticsTab.allCases) { tab in
                Text(tab.title).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
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
