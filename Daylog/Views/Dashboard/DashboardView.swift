import SwiftUI

struct DashboardView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// 이 너비 이상이면 지표 4열 · 루틴/식사 2열로 배치한다.
    private static let wideBreakpoint: CGFloat = 880
    /// 이 너비 이상이면 하단 통계를 3열로 배치한다. 그 사이에서는 2×2.
    private static let threeColumnBreakpoint: CGFloat = 980

    var body: some View {
        // 좁은 화면(iPhone, 좁은 iPad 창)은 오늘 할 일만 담은 짧은 화면을 쓴다. macOS는 늘 넓은 쪽이다.
        if horizontalSizeClass == .compact {
            TodayCompactView()
        } else {
            wideDashboard
        }
    }

    private var wideDashboard: some View {
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
                    // 두 카드는 내용만큼만 차지한다(위쪽을 맞춰 나란히). 비어 있을 때 억지로 늘리지 않는다.
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

/// 넓으면 가로 열(위쪽 맞춤), 좁으면 세로로 쌓는다.
/// 안의 카드가 `fillsHeight`면 가장 높은 카드에 맞춰 늘어나고, 아니면 각자 내용만큼만 차지한다.
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

struct StartHint: View {
    var body: some View {
        Label("그룹을 만들고 루틴을 추가하면 통계가 시작돼요.", systemImage: "sparkles")
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.accentWash, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// 제목과 날짜 이동을 한 줄에 둔다. 좁으면 두 줄로 내려간다.
struct DashboardHeader: View {
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 16) {
                titles
                Spacer(minLength: 16)
                DateNavigator()
            }
            VStack(alignment: .leading, spacing: 10) {
                titles
                DateNavigator()
            }
        }
    }

    private var titles: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("좋은 하루예요.")
                .font(.system(size: 24, weight: .bold))
            Text("완벽한 하루보다, 꾸준한 하루.")
                .font(.callout)
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
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                    .frame(minWidth: 160)
                    .accessibilityLabel("선택한 날짜 \(store.selectedDay.longTitle)")
                stepButton(symbol: "chevron.right", label: "다음 날짜", help: "다음 날짜 (⌘])") {
                    store.goToNextDay()
                }
                .disabled(!store.canGoToNextDay)
            }
            .frame(height: 32)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.cardBorder, lineWidth: 1))

            // 오늘을 보고 있으면 눌러도 할 일이 없다: 흐리게 비활성화하고, 과거를 볼 때는 눈에 띄게 한다.
            Button {
                store.goToToday()
            } label: {
                Text("오늘")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(store.isViewingToday ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Theme.onAccent))
                    .padding(.horizontal, 14)
                    .frame(height: 32)
                    .background(
                        store.isViewingToday ? AnyShapeStyle(Theme.track) : AnyShapeStyle(Theme.accent),
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(store.isViewingToday)
            .help("오늘로 이동 (⌘T)")
            .accessibilityLabel("오늘로 이동")
        }
        .fixedSize()
    }

    private func stepButton(symbol: String, label: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 34, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(help)
    }
}
