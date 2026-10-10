import Charts
import SwiftUI

/// 최근 30일 달성률 추이. 미기록일은 0%, 휴식일은 값 없음(선이 끊긴다).
struct TrendChartCard: View {
    @Environment(AppStore.self) private var store
    var chartHeight: CGFloat = 130

    private struct Point: Identifiable {
        let index: Int
        let percent: Int
        /// 값이 없는 날을 사이에 두고 떨어진 구간끼리는 선을 잇지 않는다.
        let segment: Int
        var id: Int { index }
    }

    private var points: [Point] {
        var result: [Point] = []
        var segment = 0
        var previousHadValue = false
        for (index, outcome) in store.stats.trend.enumerated() {
            guard let percent = outcome.percent else {
                if previousHadValue { segment += 1 }
                previousHadValue = false
                continue
            }
            result.append(Point(index: index, percent: percent, segment: segment))
            previousHadValue = true
        }
        return result
    }

    var body: some View {
        let trend = store.stats.trend
        let points = points
        Card {
            VStack(alignment: .leading, spacing: 10) {
                CardHeader(symbol: "chart.line.uptrend.xyaxis", title: "달성률 추이", subtitle: "(최근 30일)") {
                    Text("기준값 \(store.threshold)%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                if points.isEmpty {
                    EmptyHint(symbol: "chart.xyaxis.line", message: "기록이 쌓이면 추이가 그려져요.")
                        .frame(minHeight: chartHeight)
                } else {
                    chart(trend: trend, points: points)
                        .frame(height: chartHeight)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
            }
        }
    }

    private func chart(trend: [DayOutcome], points: [Point]) -> some View {
        let lastIndex = max(trend.count - 1, 1)
        // 오늘부터 9일 간격. 더 촘촘하면 좁은 카드에서 마지막 눈금(오늘)과 겹친다.
        let ticks = Array(stride(from: lastIndex, through: 0, by: -9).reversed())

        return Chart {
            ForEach(points) { point in
                AreaMark(
                    x: .value("날짜", point.index),
                    y: .value("달성률", point.percent),
                    series: .value("구간", point.segment),
                    stacking: .unstacked
                )
                .foregroundStyle(Theme.accent.opacity(0.12))

                LineMark(
                    x: .value("날짜", point.index),
                    y: .value("달성률", point.percent),
                    series: .value("구간", point.segment)
                )
                .foregroundStyle(Theme.accent)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                PointMark(
                    x: .value("날짜", point.index),
                    y: .value("달성률", point.percent)
                )
                .symbolSize(point.index == lastIndex ? 36 : 14)
                .foregroundStyle(Theme.accent)
            }

            RuleMark(y: .value("기준값", store.threshold))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .foregroundStyle(Theme.accent.opacity(0.8))
        }
        .chartXScale(domain: 0...lastIndex)
        .chartYScale(domain: 0...100)
        .chartXAxis {
            AxisMarks(values: ticks) { value in
                // 마지막(오늘) 눈금은 오른쪽 끝에 붙여야 잘리지 않는다.
                AxisValueLabel(anchor: value.as(Int.self) == lastIndex ? .topTrailing : .top) {
                    if let index = value.as(Int.self), trend.indices.contains(index) {
                        Text(trend[index].day.axisLabel)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("최근 30일 달성률 추이")
        .accessibilityValue(summary(trend))
    }

    private func summary(_ trend: [DayOutcome]) -> String {
        let average = StatsCalculator.averagePercent(trend).map { "평균 \($0)%" } ?? "기록 없음"
        let achieved = trend.filter { $0.isAchieved(threshold: store.threshold) }.count
        return "\(average), 기준 \(store.threshold)% 이상 \(achieved)일"
    }
}
