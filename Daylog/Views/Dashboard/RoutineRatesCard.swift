import SwiftUI

/// 루틴별 달성률(최근 30일). 달성률 내림차순.
struct RoutineRatesCard: View {
    @Environment(AppStore.self) private var store
    var showsAllLink = true
    /// 이름과 퍼센트 칸의 너비. 글자 크기 설정을 따라 커진다(iPhone에서 "100%"가 두 줄로 나뉘지 않게).
    @ScaledMetric(relativeTo: .callout) private var titleWidth: CGFloat = 104
    @ScaledMetric(relativeTo: .callout) private var percentWidth: CGFloat = Self.basePercentWidth

    #if os(macOS)
    private static let basePercentWidth: CGFloat = 40
    /// macOS는 한 줄로 두고 긴 이름은 도움말로 보여 준다.
    private static let titleLines = 1
    #else
    private static let basePercentWidth: CGFloat = 50
    /// 터치 화면에는 도움말이 없으므로 긴 이름은 두 줄까지 보여 준다.
    private static let titleLines = 2
    #endif

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                CardHeader(symbol: "chart.bar.doc.horizontal", title: "루틴별 달성률", subtitle: "(최근 30일)") {
                    if showsAllLink {
                        HeaderLink(title: "전체 보기") {
                            store.section = .statistics
                        }
                    }
                }

                if store.stats.routineRates.isEmpty {
                    EmptyHint(symbol: "list.bullet", message: "루틴을 추가하면 루틴별 달성률이 보여요.")
                } else {
                    VStack(spacing: 8) {
                        ForEach(store.stats.routineRates) { rate in
                            HStack(spacing: 10) {
                                Text(rate.isArchived ? "\(rate.title) (보관됨)" : rate.title)
                                    .font(.callout)
                                    .foregroundStyle(rate.isArchived ? .secondary : .primary)
                                    .lineLimit(Self.titleLines)
                                    .truncationMode(.tail)
                                    .frame(width: titleWidth, alignment: .leading)
                                    .help(rate.title)
                                ProgressBar(ratio: rate.ratio, height: 10, tint: GroupColor(key: rate.colorKey).color)
                                Text("\(rate.percent)%")
                                    .font(.callout)
                                    .monospacedDigit()
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                    .frame(width: percentWidth, alignment: .trailing)
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(rate.title)\(rate.isArchived ? ", 보관됨" : "")")
                            .accessibilityValue("달성률 \(rate.percent)%, 예정 \(rate.scheduled)일 중 \(rate.done)일 완료")
                        }
                    }
                }
            }
        }
    }
}
