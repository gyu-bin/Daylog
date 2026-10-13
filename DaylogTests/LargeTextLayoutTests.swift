import SwiftUI
import Testing
@testable import Daylog

/// 큰 글자 크기에서 화면 너비를 넘기지 않게 한 배치 규칙.
/// 범례와 카드 머리글이 한 줄로 고정되면 화면 전체가 옆으로 밀려 오른쪽이 잘렸다.
@MainActor
struct LargeTextLayoutTests {
    private func size(_ view: some View, width: CGFloat) -> CGSize {
        NSHostingController(rootView: view).sizeThatFits(in: CGSize(width: width, height: 10_000))
    }

    private func chips(_ count: Int) -> some View {
        FlowLayout(spacing: 10) {
            ForEach(0..<count, id: \.self) { _ in
                Color.clear.frame(width: 100, height: 20)
            }
        }
    }

    @Test func aLegendThatDoesNotFitWrapsInsteadOfWideningThePage() {
        // 여섯 칸(100pt)과 간격(10pt)은 한 줄에 650pt가 필요하다.
        let fits = size(chips(6), width: 700)
        #expect(abs(fits.height - 20) < 0.5)

        let narrow = size(chips(6), width: 250)
        #expect(narrow.width <= 250, "주어진 너비를 넘기지 않는다.")
        // 호스팅 뷰가 화소 단위로 맞추면서 소수점 아래가 달라질 수 있어 오차를 둔다.
        #expect(abs(narrow.height - 80) < 0.5, "두 칸씩 세 줄(20×3 + 간격 10×2)로 나뉜다. 실제: \(narrow)")
    }

    @Test func aCardHeaderMovesItsControlBelowTheTitleAtAccessibilitySizes() {
        func header(_ type: DynamicTypeSize) -> some View {
            CardHeader(symbol: "calendar", title: "월간 캘린더") {
                Color.clear.frame(width: 160, height: 24)
            }
            .environment(\.dynamicTypeSize, type)
        }
        let regular = size(header(.large), width: 320)
        let large = size(header(.accessibility2), width: 320)
        #expect(regular.height <= 26, "기본 크기에서는 한 줄 그대로다.")
        #expect(large.height > regular.height + 20, "큰 글자 크기에서는 컨트롤이 아랫줄로 내려간다.")
        #expect(large.width <= 320)
    }

    @Test func trendChartShowsFewerDateTicksAtLargeTextSizes() {
        // 기본 크기: 30일이면 오늘부터 거꾸로 네 개(전과 같다).
        #expect(TrendAxis.ticks(lastIndex: 29, isLargeText: false) == [2, 11, 20, 29])
        #expect(TrendAxis.ticks(lastIndex: 6, isLargeText: false) == [0, 1, 2, 3, 4, 5, 6])

        // 큰 글자 크기: 날짜 글자가 넓어 두 개만 두고, 마지막(오늘)은 늘 남긴다.
        for lastIndex in [1, 6, 29, 89, 364] {
            let ticks = TrendAxis.ticks(lastIndex: lastIndex, isLargeText: true)
            #expect(ticks.count <= 2, "\(lastIndex): \(ticks)")
            #expect(ticks.last == lastIndex)
        }
    }

    @Test func weekdayButtonsWrapInsteadOfWideningTheSheet() {
        let selector = WeekdaySelector(selection: .constant(Set(Weekdays.all)), tint: .orange, daySize: 40)
        // 일곱 개(40pt)와 간격(6pt)은 한 줄에 316pt가 필요하다.
        let wide = size(selector, width: 400)
        let narrow = size(selector, width: 200)
        #expect(narrow.width <= 200, "주어진 너비를 넘기지 않는다. 실제: \(narrow)")
        #expect(narrow.height > wide.height + 30, "들어가지 않는 요일은 다음 줄로 넘어간다.")
    }

    @Test func aStatTileGrowsWithItsTextAtAccessibilitySizes() {
        func tile(_ type: DynamicTypeSize) -> some View {
            StatTile(
                symbol: "calendar", title: "이번 달 식사 기록률을 길게 적은 제목", color: .blue, value: "100%",
                caption: "설명이 길어서 좁은 칸에서는 여러 줄로 나뉘어야 하는 문장입니다."
            )
            .environment(\.dynamicTypeSize, type)
        }
        // 기본 크기에서는 높이가 고정이다. 큰 글자 크기에서는 내용만큼 자라서 아래 칸과 겹치지 않는다.
        let regular = size(tile(.large), width: 150)
        let large = size(tile(.accessibility2), width: 150)
        #expect(abs(regular.height - Theme.statCardHeight) < 0.5)
        #expect(large.height > Theme.statCardHeight + 10, "실제: \(large)")
    }

    @Test func smallCalendarAndHeatmapTextStaysInsideItsCell() {
        // 날짜 아래 달성률 글자는 날짜 칸보다 작게, 히트맵 글자는 칸 높이 안에 머문다.
        #expect(CalendarMetrics.maxStatusSize < CalendarMetrics.maxDaySize / 2)
        #expect(HeatmapMetrics.maxCell * 9 / 13 < HeatmapMetrics.maxCell)
        #expect(HeatmapMetrics.maxCell >= 13, "기본 칸 크기(13pt)보다 작아지지 않는다.")
    }

    @Test func calendarDayCellsNeverExceedTheNarrowestColumn() {
        // 가장 좁은 iPhone(320pt)에서 카드 여백을 빼면 한 칸이 약 36pt다.
        #expect(CalendarMetrics.maxDaySize * 7 <= 320 - 2 * 16 - 2 * 16)
    }
}
