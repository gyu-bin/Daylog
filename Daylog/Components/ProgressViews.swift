import SwiftUI

struct ProgressRing: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 0...1. nil이면 빈 고리.
    let ratio: Double?
    var lineWidth: CGFloat = 8
    var tint: Color = Theme.accent

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(ratio ?? 0, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(lineWidth / 2)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: ratio)
        .accessibilityHidden(true)
    }
}

struct ProgressBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let ratio: Double
    var height: CGFloat = 8
    var tint: Color = Theme.accent

    var body: some View {
        GeometryReader { proxy in
            let clamped = min(max(ratio, 0), 1)
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track)
                if clamped > 0 {
                    Capsule()
                        .fill(tint)
                        .frame(width: max(height, proxy.size.width * clamped))
                }
            }
        }
        .frame(height: height)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: ratio)
        .accessibilityHidden(true)
    }
}

/// 왼쪽에서 오른쪽으로 채우고 넘치면 다음 줄로 넘기는 배치. 추천 칩에 쓴다.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: proposal.width.map { min($0, width) } ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
