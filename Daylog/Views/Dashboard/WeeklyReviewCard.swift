import SwiftUI

/// 새싹이의 주간 회고: 지난주(끝난 한 주)를 짧게 요약한다. [자세히 보기]의 상세 회고에서 새싹이가 함께 돌아보고 응원한다.
///
/// "이번 주의 성장"이 진행 중인 이번 주의 목표를 보여 준다면, 이 카드는 끝난 지난주의 요약이다.
/// 값은 기존 기록에서 계산한다(`WeeklyReview`). 오늘 화면에 움직이는 새싹이가 겹치지 않도록 카드에는 새싹이를 두지 않는다
/// (성장의 새싹이는 "새싹이 성장" 카드가 맡는다).
struct WeeklyReviewCard: View {
    @Environment(AppStore.self) private var store
    @Environment(DevicePreferences.self) private var preferences
    @State private var showsDetail = false

    var body: some View {
        let review = store.weeklyReview(weekStart: preferences.weekStart)
        let stage = store.growth.stage
        Card(fillsHeight: false) {
            VStack(alignment: .leading, spacing: 12) {
                CardHeader(symbol: "leaf.circle.fill", title: PioOutfitMotionView.isTrialEnabled ? "피오의 주간 회고" : "새싹이의 주간 회고", tint: stage.tint) {
                    Button("자세히 보기") { showsDetail = true }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.borderless)
                        .foregroundStyle(stage.tint)
                        .accessibilityHint("지난주 회고를 자세히 봅니다.")
                }
                // 날짜는 제목 줄에 두면 좁은 화면에서 잘려서 한마디 위에 따로 적는다.
                VStack(alignment: .leading, spacing: 3) {
                    Text("지난주 · \(review.periodTitle)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(review.headline)
                        .font(.subheadline.weight(.semibold))
                }
                .fixedSize(horizontal: false, vertical: true)
                if review.hasRecords {
                    WeeklyReviewFigures(review: review, compact: true)
                    // 가장 꾸준했던 습관과 지난주 대비는 한두 줄로. 자세한 것은 상세 회고에 있다.
                    VStack(alignment: .leading, spacing: 3) {
                        if let top = review.topRoutine {
                            Label {
                                Text("가장 꾸준했던 습관 · \(top.title) \(top.days)일")
                                    .lineLimit(2)
                            } icon: {
                                Image(systemName: "sparkles").foregroundStyle(stage.tint)
                            }
                            .font(.caption.weight(.semibold))
                        }
                        if let note = review.changeNote {
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(review.cheer)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .contain)
        }
        .sheet(isPresented: $showsDetail) {
            WeeklyReviewSheet(review: review, stage: stage)
        }
        #if DEBUG
        // 화면 검증용: `-DaylogDebugOpenWeeklyReview YES`면 상세 회고를 바로 연다(Debug 빌드만).
        .task {
            guard UserDefaults.standard.bool(forKey: "DaylogDebugOpenWeeklyReview") else { return }
            try? await Task.sleep(for: .seconds(1.5))
            showsDetail = true
        }
        #endif
    }
}

extension WeeklyReview {
    /// 카드의 새싹이: 좋은 한 주는 작게 축하하고, 쉬어 간 한 주는 차분하게 곁에 있다.
    var saessagiBehavior: SaessagiBehavior {
        if isCelebration { return .growingCheer }
        switch mood {
        case .empty, .vacation, .eased: return .growingCalm
        case .grew, .steady, .fresh: return .growing
        }
    }
}

/// 완료한 루틴·실천한 날·얻은 XP(상세 화면은 지난주 대비도).
struct WeeklyReviewFigures: View {
    let review: WeeklyReview
    var compact = false

    var body: some View {
        let items = figures
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                ForEach(items, id: \.title) { tile($0) }
            }
            // 글자가 커서 한 줄에 다 들어가지 않으면 두 줄로.
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(items, id: \.title) { tile($0) }
            }
        }
    }

    private var figures: [(title: String, value: String)] {
        var items = [("완료한 루틴", "\(review.completed)개"), ("실천한 날", "\(review.practicedDays)일"), ("얻은 XP", "+\(review.xp)")]
        if !compact, let change = review.change {
            items.insert(("지난주 대비", change > 0 ? "+\(change)개" : change == 0 ? "같아요" : "\(change)개"), at: 2)
        }
        return items.map { (title: $0.0, value: $0.1) }
    }

    private func tile(_ item: (title: String, value: String)) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(item.title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(item.value)
                .font(compact ? .headline : .title3.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.inset, in: RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// 가장 꾸준했던 습관 한 줄.
struct WeeklyReviewTopRoutine: View {
    let top: WeeklyReview.TopRoutine
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text("가장 꾸준했던 습관")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(top.title) · \(top.days)일 실천")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// 지난주 회고를 조금 더 자세히: 날짜, 하루하루의 실천, 숫자 넷, 가장 꾸준했던 습관, 새싹이의 응원. 차트는 통계 화면에 맡긴다.
struct WeeklyReviewSheet: View {
    let review: WeeklyReview
    let stage: GrowthStage
    @Environment(\.dismiss) private var dismiss
    private var appearance: PioResolvedAppearance {
        PioAppearanceCoordinator.shared.resolve(context: .weeklyReview, motion: .idle)
    }

    var body: some View {
        SheetScaffold(title: PioOutfitMotionView.isTrialEnabled ? "피오의 주간 회고" : "새싹이의 주간 회고", subtitle: review.periodTitle, cancelTitle: "닫기", cancel: { dismiss() }) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 16) {
                    // 열면 반갑게 한 번 뛰고, 그다음은 한 주의 분위기대로 움직인다.
                    Group {
                        if PioOutfitMotionView.isTrialEnabled {
                            PioAppearanceView(appearance: appearance)
                                .frame(width: 96, height: 96)
                        } else {
                            SaessagiAnimatedView(pose: stage.pose, size: 96, behavior: review.saessagiBehavior, entrance: .hello)
                        }
                    }
                        .padding(10)
                        .background(stage.tint.opacity(0.12), in: Circle())
                    VStack(alignment: .leading, spacing: 6) {
                        Text("“\(review.headline)”")
                            .font(.headline)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(PioOutfitMotionView.isTrialEnabled
                             ? "\(appearance.outfit.title)와 지난주를 함께 돌아봐요."
                             : "\(stage.title) 단계의 새싹이가 지난주를 함께 돌아봤어요.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if PioOutfitMotionView.isTrialEnabled {
                    PioAppearanceNotice(appearance: appearance)
                }
                WeeklyReviewDays(review: review, tint: stage.tint)
                if review.hasRecords {
                    WeeklyReviewFigures(review: review)
                    if let top = review.topRoutine {
                        WeeklyReviewTopRoutine(top: top, tint: stage.tint)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    if let note = review.changeNote {
                        Text(note).font(.subheadline.weight(.medium))
                    }
                    Text(review.cheer)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// 한 주의 하루하루: 실천한 날은 채운 동그라미, 루틴이 있었지만 쉰 날은 빈 동그라미, 휴가는 우산, 루틴이 없던 날은 점.
private struct WeeklyReviewDays: View {
    let review: WeeklyReview
    let tint: Color

    var body: some View {
        HStack(spacing: 0) {
            ForEach(review.days) { outcome in
                VStack(spacing: 5) {
                    Text(outcome.day.weekdaySymbol)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    mark(outcome)
                        .frame(width: 22, height: 22)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(outcome.day.shortTitle) \(description(outcome))")
            }
        }
        .padding(.vertical, 10)
        .background(Theme.inset, in: RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
    }

    @ViewBuilder
    private func mark(_ outcome: DayOutcome) -> some View {
        if outcome.status == .vacation {
            Image(systemName: "beach.umbrella").font(.caption).foregroundStyle(Theme.vacationTint)
        } else if WeeklyGrowthCalculator.isPracticed(outcome) {
            Circle().fill(tint).overlay(Text("\(outcome.done)").font(.caption2.weight(.bold)).foregroundStyle(.white))
        } else if WeeklyGrowthCalculator.isEligible(outcome) {
            Circle().strokeBorder(Theme.track, lineWidth: 2)
        } else {
            Circle().fill(Theme.track).frame(width: 5, height: 5)
        }
    }

    private func description(_ outcome: DayOutcome) -> String {
        if outcome.status == .vacation { return "휴가" }
        if WeeklyGrowthCalculator.isPracticed(outcome) { return "\(outcome.done)개 완료" }
        if WeeklyGrowthCalculator.isEligible(outcome) { return "쉬어 감" }
        return "예정된 루틴 없음"
    }
}
