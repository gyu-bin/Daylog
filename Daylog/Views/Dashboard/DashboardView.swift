import SwiftUI

struct DashboardView: View {
    @Environment(AppStore.self) private var store

    /// 이 너비 이상이면 지표 4열 · 루틴/식사 2열로 배치한다.
    private static let wideBreakpoint: CGFloat = 880
    /// 이 너비 이상이면 하단 통계를 3열로 배치한다. 그 사이에서는 2×2.
    private static let threeColumnBreakpoint: CGFloat = 980

    var body: some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width >= Self.wideBreakpoint
            let isExtraWide = proxy.size.width >= Self.threeColumnBreakpoint
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacing) {
                    DashboardHeader()
                    if !store.stats.hasStarted {
                        StartHint()
                    }
                    StatCardsGrid(columns: isWide ? 4 : 2)
                    AdaptiveRow(isWide: isWide) {
                        RoutineCard()
                        MealCard()
                    }
                    if isExtraWide {
                        AdaptiveRow(isWide: true) {
                            recentDays
                            MonthCalendarCard()
                            VStack(spacing: Theme.spacing) {
                                TrendChartCard()
                                RoutineRatesCard()
                            }
                        }
                    } else {
                        AdaptiveRow(isWide: isWide) {
                            recentDays
                            MonthCalendarCard()
                        }
                        AdaptiveRow(isWide: isWide) {
                            TrendChartCard()
                            RoutineRatesCard()
                        }
                    }
                }
                .padding(Theme.pagePadding)
            }
        }
    }

    private var recentDays: some View {
        RecentDaysCard(title: "최근 7일 기록", outcomes: store.stats.week.reversed())
    }
}

/// 넓으면 같은 높이의 가로 열, 좁으면 세로로 쌓는다.
struct AdaptiveRow<Content: View>: View {
    let isWide: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        if isWide {
            HStack(alignment: .top, spacing: Theme.spacing, content: content)
        } else {
            VStack(spacing: Theme.spacing, content: content)
        }
    }
}

private struct StartHint: View {
    var body: some View {
        Label("루틴을 추가하면 통계가 시작돼요.", systemImage: "sparkles")
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.accentWash, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct DashboardHeader: View {
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 16) {
                titles
                Spacer(minLength: 16)
                DateNavigator()
            }
            VStack(alignment: .leading, spacing: 12) {
                titles
                DateNavigator()
            }
        }
        .padding(.bottom, 4)
    }

    private var titles: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("좋은 하루예요.")
                .font(.system(size: 28, weight: .bold))
            Text("완벽한 하루보다, 꾸준한 하루.")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .fixedSize()
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

struct DateNavigator: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 0) {
                stepButton(symbol: "chevron.left", label: "이전 날짜", help: "이전 날짜 (⌘[)") {
                    store.goToPreviousDay()
                }
                Text(store.selectedDay.longTitle)
                    .font(.headline)
                    .monospacedDigit()
                    .frame(minWidth: 168)
                    .accessibilityLabel("선택한 날짜 \(store.selectedDay.longTitle)")
                stepButton(symbol: "chevron.right", label: "다음 날짜", help: "다음 날짜 (⌘])") {
                    store.goToNextDay()
                }
                .disabled(!store.canGoToNextDay)
            }
            .frame(height: 32)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.separator, lineWidth: 1))

            Button("오늘") {
                store.goToToday()
            }
            .controlSize(.large)
            .disabled(store.isViewingToday)
            .help("오늘로 이동 (⌘T)")
        }
        .fixedSize()
    }

    private func stepButton(symbol: String, label: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(help)
    }
}
