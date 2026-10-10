import SwiftUI

/// 루틴별 달성률(최근 30일). 달성률 내림차순.
struct RoutineRatesCard: View {
    @Environment(AppStore.self) private var store
    var showsAllLink = true

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
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .frame(width: 104, alignment: .leading)
                                    .help(rate.title)
                                ProgressBar(ratio: rate.ratio, height: 10, tint: GroupColor(key: rate.colorKey).color)
                                Text("\(rate.percent)%")
                                    .font(.callout)
                                    .monospacedDigit()
                                    .frame(width: 40, alignment: .trailing)
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
