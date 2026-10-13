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

    @Test func calendarDayCellsNeverExceedTheNarrowestColumn() {
        // 가장 좁은 iPhone(320pt)에서 카드 여백을 빼면 한 칸이 약 36pt다.
        #expect(CalendarMetrics.maxDaySize * 7 <= 320 - 2 * 16 - 2 * 16)
    }
}
