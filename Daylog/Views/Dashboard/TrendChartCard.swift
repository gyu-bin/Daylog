import Charts
import SwiftUI

/// 달성률 추이. 기록된 값은 선으로 잇고, 미기록은 별도 기호로 표시한다.
struct TrendChartCard: View {
    @Environment(AppStore.self) private var store
    /// 그릴 날짜들(오름차순). nil이면 대시보드와 같은 최근 30일.
    var outcomes: [DayOutcome]?
    var subtitle = "(최근 30일)"
    var chartHeight: CGFloat = 130
    /// 가리킨 날짜의 값을 보여 주고, 누르면 그 날짜의 기록을 연다.
    var isInteractive = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var hoveredIndex: Int?

    private struct Point: Identifiable {
        let index: Int
        let percent: Int
        /// 값이 없는 날을 사이에 두고 떨어진 구간끼리는 선을 잇지 않는다.
        let segment: Int
        /// 점을 찍을지. 날짜가 많으면 선만 그리되, 혼자 떨어진 날과 마지막 날은 점이 있어야 보인다.
        var showsDot = true
        var id: Int { index }
    }

    private func points(_ trend: [DayOutcome]) -> [Point] {
        var result: [Point] = []
        var segment = 0
        var previousHadValue = false
        for (index, outcome) in trend.enumerated() {
            guard outcome.status == .recorded, let percent = outcome.percent else {
                if previousHadValue { segment += 1 }
                previousHadValue = false
                continue
            }
            result.append(Point(index: index, percent: percent, segment: segment))
            previousHadValue = true
        }
        guard trend.count > 31 else { return result }
        let sizes = Dictionary(grouping: result, by: \.segment).mapValues(\.count)
        return result.map { point in
            var point = point
            point.showsDot = sizes[point.segment] == 1 || point.index == trend.count - 1
            return point
        }
    }

    var body: some View {
        let trend = outcomes ?? store.stats.trend
        let points = points(trend)
        Card(fillsHeight: !isInteractive) {
            VStack(alignment: .leading, spacing: 10) {
                CardHeader(symbol: "chart.line.uptrend.xyaxis", title: "달성률 추이", subtitle: subtitle) {
                    Text("기준값 \(store.threshold)%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                if trend.isEmpty {
                    EmptyHint(symbol: "chart.xyaxis.line", message: "집계할 기록 없음")
                        .frame(minHeight: chartHeight)
                } else {
                    if points.isEmpty {
                        Text(trend.contains { $0.status == .unrecorded }
                             ? "아직 기록한 날이 없어요. 미기록 예정일은 평균에 0%로 포함돼요."
                             : "집계할 기록 없음 · 휴가 날짜는 제외돼요.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    chart(trend: trend, points: points)
                        .frame(height: chartHeight)
                        .frame(maxHeight: isInteractive ? nil : .infinity, alignment: .top)
                    if trend.contains(where: { $0.status == .unrecorded }) {
                        Label("미기록 · 평균 계산에는 0%로 포함", systemImage: "diamond")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func chart(trend: [DayOutcome], points: [Point]) -> some View {
        let lastIndex = max(trend.count - 1, 1)
        // 눈금은 오늘부터 거꾸로 4~5개. 더 촘촘하면 좁은 카드에서 마지막 눈금(오늘)과 겹친다.
        let ticks = TrendAxis.ticks(lastIndex: lastIndex, isLargeText: dynamicTypeSize.isAccessibilitySize)
        let hovered = hoveredIndex.flatMap { trend.indices.contains($0) ? trend[$0] : nil }

        return Chart {
            ForEach(points) { point in
                AreaMark(
                    x: .value("날짜", point.index),
                    y: .value("달성률", point.percent),
                    series: .value("구간", point.segment),
                    stacking: .unstacked
                )
                .foregroundStyle(LinearGradient(
                    colors: [Theme.accent.opacity(0.26), Theme.accent.opacity(0.02)],
                    startPoint: .top, endPoint: .bottom
                ))

                LineMark(
                    x: .value("날짜", point.index),
                    y: .value("달성률", point.percent),
                    series: .value("구간", point.segment)
                )
                .foregroundStyle(Theme.accent)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                if point.showsDot {
                    PointMark(
                        x: .value("날짜", point.index),
                        y: .value("달성률", point.percent)
                    )
                    .symbolSize(point.index == trend.count - 1 ? 36 : 14)
                    .foregroundStyle(Theme.accent)
                }
            }


            ForEach(Array(trend.enumerated()).filter { $0.element.status == .unrecorded }, id: \.offset) { index, _ in
                PointMark(x: .value("날짜", index), y: .value("미기록", 0))
                    .symbol(.diamond)
                    .symbolSize(22)
                    .foregroundStyle(Color.secondary)
            }

            RuleMark(y: .value("기준값", store.threshold))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .foregroundStyle(Color.secondary.opacity(0.7))

            if let hoveredIndex, let hovered {
                RuleMark(x: .value("날짜", hoveredIndex))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .foregroundStyle(Color.secondary.opacity(0.45))
                    .annotation(
                        position: .top, spacing: 2,
                        overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))
                    ) {
                        tooltip(hovered)
                    }
                if hovered.status == .recorded, let percent = hovered.percent {
                    PointMark(x: .value("날짜", hoveredIndex), y: .value("달성률", percent))
                        .symbolSize(60)
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .chartXScale(domain: 0...lastIndex)
        .chartYScale(domain: 0...100)
        .chartXAxis {
            AxisMarks(values: ticks) { value in
                // 마지막(오늘) 눈금은 오른쪽 끝에 붙여야 잘리지 않는다.
                AxisValueLabel(anchor: value.as(Int.self) == lastIndex ? .topTrailing : .top) {
                    if let index = value.as(Int.self), trend.indices.contains(index) {
                        Text(axisLabel(trend[index].day, spansYears: trend.count > 300))
                            .fixedSize()
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let percent = value.as(Int.self) {
                        Text("\(percent)%")
                    }
                }
            }
        }
        .chartOverlay { proxy in
            if isInteractive {
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                hoveredIndex = index(at: location, proxy: proxy, geometry: geometry, lastIndex: lastIndex)
                            case .ended:
                                hoveredIndex = nil
                            }
                        }
                        .onTapGesture {
                            if let hovered { store.open(hovered.day) }
                        }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("달성률 추이 \(subtitle)")
        .accessibilityValue(summary(trend))
    }

    /// 가로축은 0...lastIndex의 선형 눈금이라, 그림 영역 안의 위치 비율로 날짜를 찾는다.
    private func index(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy, lastIndex: Int) -> Int? {
        guard let anchor = proxy.plotFrame else { return nil }
        let frame = geometry[anchor]
        guard frame.width > 0 else { return nil }
        let fraction = (location.x - frame.minX) / frame.width
        let index = Int((fraction * Double(lastIndex)).rounded())
        return (0...lastIndex).contains(index) ? index : nil
    }

    private func axisLabel(_ day: Day, spansYears: Bool) -> String {
        spansYears ? "\(day.year % 100).\(day.month)" : day.axisLabel
    }

    private func tooltip(_ outcome: DayOutcome) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(outcome.day.shortTitle) (\(outcome.day.weekdaySymbol))")
                .font(.caption.weight(.semibold))
            Text(detail(outcome))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Theme.separator, lineWidth: 1))
    }

    private func detail(_ outcome: DayOutcome) -> String {
        switch outcome.status {
        case .recorded: return "\(outcome.percentLabel) · \(outcome.total)개 중 \(outcome.done)개"
        case .unrecorded: return "미기록 · 평균에는 0%로 포함"
        case .vacation: return "휴가 · 통계 제외"
        case .rest: return "휴식일"
        case .preStart: return "통계 시작 전"
        case .future: return ""
        }
    }

    private func summary(_ trend: [DayOutcome]) -> String {
        let average = StatsCalculator.averagePercent(trend).map { "평균 \($0)%" } ?? "기록 없음"
        let achieved = trend.filter { $0.isAchieved(threshold: store.threshold) }.count
        let unrecorded = trend.filter { $0.status == .unrecorded }.count
        return "\(average), 기준 \(store.threshold)% 이상 \(achieved)일, 미기록 \(unrecorded)일은 마름모로 구분하며 평균에는 0%로 포함"
    }
}

/// 추이 차트의 날짜 눈금 자리.
enum TrendAxis {
    /// 오늘(마지막 날)부터 거꾸로 센다. 큰 글자 크기에서는 날짜 글자가 넓어 두 개만 둔다(더 두면 서로 겹친다).
    static func ticks(lastIndex: Int, isLargeText: Bool) -> [Int] {
        let step: Int
        if isLargeText {
            step = max(Int((Double(lastIndex) / 1.5).rounded(.up)), 1)
        } else {
            step = lastIndex <= 7 ? 1 : Int((Double(lastIndex) / 3.5).rounded(.up))
        }
        return Array(stride(from: lastIndex, through: 0, by: -step).reversed())
    }
}
