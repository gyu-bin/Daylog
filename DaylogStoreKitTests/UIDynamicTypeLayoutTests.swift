#if DEBUG && os(iOS)
import XCTest
import SwiftUI
import UIKit
@testable import Daylog

/// 큰 글자(Dynamic Type)에서 화면 조각이 화면 너비를 넘지 않는지 잰다.
///
/// 실제 결함(2026-10-24, iPhone SE AX5): 루틴 관리의 단추 줄과 통계의 요약 칸이 화면보다 넓어져
/// 화면 전체가 옆으로 밀리고 글자가 잘렸다. 스크린샷 검수에서야 보였던 문제라, 같은 종류의 넘침을
/// 여기서 숫자로 잡는다. 각 조각에 화면 내용 너비를 제안하고, 조각이 고른 너비가 그보다 크면 실패다.
/// (글자가 한 글자씩 꺾이는 문제처럼 너비 안에서 생기는 결함은 이 검사로 잡히지 않는다. 그건 시각 검수가 맡는다.
/// FlowLayout은 자기 너비를 늘 제안 너비 이하로 알리므로, 그 안의 항목이 넘치는 것도 여기서는 잡히지 않는다.)
@MainActor final class UIDynamicTypeLayoutTests: XCTestCase {
    /// iPhone SE(375pt)와 iPhone 17(402pt)의 화면 너비에서 좌우 여백 16pt를 뺀 내용 너비.
    private let contentWidths: [CGFloat] = [343, 370]
    private let sizes: [DynamicTypeSize] = [.large, .xxxLarge, .accessibility1, .accessibility3, .accessibility5]

    private var store: AppStore!
    private var preferences: DevicePreferences!
    private var defaults: UserDefaults!
    private var suite = ""

    override func setUp() async throws {
        let container = try DaylogStore.makeContainer(.inMemory)
        store = AppStore(container: container)
        store.start()
        suite = "UIDynamicTypeLayout.\(UUID())"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        preferences = DevicePreferences(defaults: defaults, isPhone: true)
        // 실제 사용처럼: 그룹 둘, 긴 이름 하나, 시간이 정해진 항목, 완료 둘.
        _ = store.addGroup(title: "아침 루틴")
        for title in ["물 한 잔 마시기", "스트레칭 10분", "출근 전에 영어 단어 스무 개 외우고 소리 내서 읽기"] {
            _ = store.addRoutine(title: title, in: store.quickAddGroup)
        }
        _ = store.addGroup(title: "저녁 정리")
        for title in ["독서 30분", "일기 쓰기"] {
            _ = store.addRoutine(title: title, in: store.quickAddGroup)
        }
        if let stretch = store.routines.first(where: { $0.title == "스트레칭 10분" }) {
            store.updateRoutine(stretch, timeLabel: "00:01")
        }
        for title in ["물 한 잔 마시기", "독서 30분"] {
            if let check = store.checks.first(where: { $0.title == title }) { store.setDone(routineID: check.routineID, true) }
        }
    }

    override func tearDown() async throws {
        defaults?.removePersistentDomain(forName: suite)
        store = nil
    }

    private func environment<V: View>(_ view: V, _ size: DynamicTypeSize) -> some View {
        view
            .environment(store)
            .environment(preferences)
            .environment(DashboardDecor(defaults: defaults))
            .environment(CloudSyncMonitor(containerIdentifier: nil))
            .environment(RoutineEditorState())
            .environment(\.dynamicTypeSize, size)
            .environment(\.horizontalSizeClass, .compact)
    }

    /// 조각에 `width`를 제안했을 때 조각이 고른 크기.
    private func measure<V: View>(_ view: V, width: CGFloat, size: DynamicTypeSize) -> CGSize {
        let host = UIHostingController(rootView: environment(view, size))
        return host.sizeThatFits(in: CGSize(width: width, height: 20_000))
    }

    private var pieces: [(String, AnyView)] {
        let stats = store.periodStats(.month)
        var list: [(String, AnyView)] = [
            ("PageTitle", AnyView(PageTitle(title: "루틴 관리", subtitle: "변경한 내용은 오늘부터 적용되고, 지난 기록은 바뀌지 않아요."))),
            ("DateNavigator(날짜 포함)", AnyView(DateNavigator())),
            ("TodayProgressCard", AnyView(TodayProgressCard())),
            ("NextRoutineCard", AnyView(NextRoutineCard())),
            ("DashboardCards(한 열)", AnyView(DashboardCards(compact: true, wide: false, isEditing: false))),
            ("RoutineStatisticsView", AnyView(RoutineStatisticsView(isWide: false))),
            ("TrendChartCard", AnyView(TrendChartCard(outcomes: store.periodStats(.month).outcomes, subtitle: "(최근 30일)", chartHeight: 200, isInteractive: true))),
            ("ActivityHeatmapCard", AnyView(ActivityHeatmapCard(outcomes: store.periodStats(.month).heatmap, threshold: 80))),
            ("RoutineHistoryCard", AnyView(RoutineHistoryCard(histories: store.routineHistories(), isWide: false))),
            ("MealSummaryTiles", AnyView(MealSummaryTiles(summary: store.mealSummary(period: .month), periodTitle: MealPeriod.month.title, isWide: false))),
            ("MonthCalendarCard", AnyView(MonthCalendarCard(opensDashboard: true))),
            ("GroupRatesCard", AnyView(GroupRatesCard(rates: stats.groupRates, periodLabel: stats.period.label, selection: .constant(nil)))),
            ("ItemRatesCard", AnyView(ItemRatesCard(rates: stats.routineRates, periodLabel: stats.period.label, group: nil, clearGroup: {}))),
        ]
        for group in store.activeGroups {
            list.append(("RoutineGroupCard(\(group.title))", AnyView(RoutineGroupCard(group: group, canMoveUp: true, canMoveDown: true))))
        }
        for category in SettingsCategory.visible {
            list.append(("SettingsCategoryRow(\(category))", AnyView(SettingsCategoryRow(category: category, isSelected: false, showsChevron: false))))
        }
        return list
    }

    /// iPad 세로(사이드바 옆 내용 너비 약 480~520pt)와 좁은 창에서 쓰는 넓은 홈 조각.
    func testWideDashboardPiecesStayInsideContentWidthAtEveryTextSize() {
        var failures: [String] = []
        let wide: [(String, AnyView)] = [
            ("DashboardHeader", AnyView(DashboardHeader(isEditing: .constant(false)))),
            ("DashboardCards(넓은 화면 한 열)", AnyView(DashboardCards(compact: false, wide: false, isEditing: false))),
        ]
        for width: CGFloat in [343, 480, 700] {
            for size in sizes {
                for (name, view) in wide {
                    let fitted = measure(view, width: width, size: size)
                    if fitted.width > width + 0.5 {
                        failures.append("\(name) @\(size) 너비 \(Int(width)) → \(Int(fitted.width.rounded()))")
                    }
                }
            }
        }
        print("UI_LAYOUT_WIDE_OVERFLOW count=\(failures.count)\n" + failures.joined(separator: "\n"))
        XCTAssertTrue(failures.isEmpty, "내용 너비를 넘는 조각:\n" + failures.joined(separator: "\n"))
    }

    /// iPad 사이드바(기본 216pt, 큰 글자에서 최대 288pt): 머리말과 메뉴가 열 너비를 넘지 않는다(2026-10-24 브랜드 정리).
    func testIPadSidebarStaysInsideItsColumnAtEveryTextSize() {
        var failures: [String] = []
        for width: CGFloat in [216, 288] {
            for size in sizes {
                for (name, view) in [("SidebarView", AnyView(SidebarView())), ("SidebarBrandHeader", AnyView(SidebarBrandHeader()))] {
                    let fitted = measure(view, width: width, size: size)
                    if fitted.width > width + 0.5 {
                        failures.append("\(name) @\(size) 너비 \(Int(width)) → \(Int(fitted.width.rounded()))")
                    }
                }
            }
        }
        print("UI_LAYOUT_SIDEBAR_OVERFLOW count=\(failures.count)\n" + failures.joined(separator: "\n"))
        XCTAssertTrue(failures.isEmpty, "사이드바 열을 넘는 조각:\n" + failures.joined(separator: "\n"))
    }

    func testPhonePiecesStayInsideScreenWidthAtEveryTextSize() {
        var failures: [String] = []
        for width in contentWidths {
            for size in sizes {
                for (name, view) in pieces {
                    let fitted = measure(view, width: width, size: size)
                    if fitted.width > width + 0.5 {
                        failures.append("\(name) @\(size) 너비 \(Int(width)) → \(Int(fitted.width.rounded()))")
                    }
                }
            }
        }
        print("UI_LAYOUT_OVERFLOW count=\(failures.count)\n" + failures.joined(separator: "\n"))
        XCTAssertTrue(failures.isEmpty, "화면 너비를 넘는 조각:\n" + failures.joined(separator: "\n"))
    }
}
#endif
