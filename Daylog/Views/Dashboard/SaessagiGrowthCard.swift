import SwiftUI

/// 새싹이 성장: 루틴을 완료할수록 쌓이는 XP와 레벨, 그 단계의 새싹이(새싹 → 잎사귀 → 꽃).
///
/// 값은 기존 기록에서 계산한다(`SaessagiGrowth`, `GrowthCalculator`). 이 기기에서 루틴을 완료하면(`AppStore.growthEvent`)
/// 새싹이가 폴짝 뛰고 반짝이며 얻은 XP를 보여 준다. 레벨이 오르면 조금 더 크게 축하하고, 성장 단계가 바뀌면 머리 위의 잎(꽃)이 돋아난다.
/// 카드가 처음 나타날 때나 동기화로 값이 바뀔 때는 반응하지 않는다.
struct SaessagiGrowthCard: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 지금 보여 주고 있는 반응. 잠시 뒤 사라진다.
    @State private var shown: GrowthEvent?
    /// 잎이 돋아나는 연출을 할 단계(그 단계로 막 자랐을 때만).
    @State private var grownStage: GrowthStage?
    /// 폴짝 뛸 때 위로 뜬 높이.
    @State private var lift: CGFloat = 0
    @State private var burst = 0
    @State private var pending: Task<Void, Never>?

    /// iPhone에서는 한 열이라 카드가 길어지지 않게 조금 작게 그린다.
    private static let mascotSize: CGFloat = Platform.isPhone ? 64 : 76

    var body: some View {
        let growth = store.growth
        Card(fillsHeight: false) {
            VStack(alignment: .leading, spacing: 10) {
                CardHeader(symbol: "sparkles", title: "새싹이 성장", tint: growth.stage.tint)
                HStack(alignment: .center, spacing: 14) {
                    mascot(growth)
                    details(growth)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .onChange(of: store.growthEvent) { _, event in
            if let event { react(event) }
        }
        .onDisappear { pending?.cancel() }
    }

    // MARK: - 새싹이

    private func mascot(_ growth: SaessagiGrowth) -> some View {
        let size = Self.mascotSize
        return ZStack {
            Circle()
                .fill(growth.stage.tint.opacity(0.12))
                .frame(width: size * 1.12, height: size * 1.12)
                .offset(y: size * 0.06)
            SaessagiAnimatedView(
                pose: growth.stage.pose, size: size, behavior: .growing,
                entrance: grownStage == growth.stage ? .growLeaf : nil
            )
            // 단계가 바뀌면 새 그림으로 바꿔 끼운다(그때 잎이 돋아나는 연출을 한다).
            .id(growth.stage)
            .offset(y: lift)
            SparkleBurst(trigger: burst, count: shown.map { $0.leveledUp ? 9 : 5 } ?? 5, radius: size * 0.62, tint: growth.stage.tint)
                .allowsHitTesting(false)
        }
        .frame(width: size * 1.15, height: size * 1.15)
        // 얻은 XP는 머리 위의 잎을 가리지 않게 오른쪽 위에 띄운다.
        .overlay(alignment: .topTrailing) {
            if let shown {
                Text("+\(shown.gained) XP")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(growth.stage.tint)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Theme.cardBackground, in: Capsule())
                    .overlay(Capsule().strokeBorder(growth.stage.tint.opacity(0.4), lineWidth: 1))
                    .fixedSize()
                    .offset(x: 14, y: -8)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
                    .id(shown.id)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - 레벨과 XP

    private func details(_ growth: SaessagiGrowth) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Lv.\(growth.level)")
                    .font(.title2.weight(.bold))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(growth.level)))
                Text(growth.stage.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(growth.stage.tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(growth.stage.tint.opacity(0.14), in: Capsule())
                Spacer(minLength: 4)
                Text("\(growth.xpIntoLevel) / \(growth.xpForNextLevel) XP")
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .layoutPriority(1)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.track)
                    Capsule()
                        .fill(growth.stage.tint)
                        .frame(width: max(growth.progress > 0 ? 6 : 0, proxy.size.width * growth.progress))
                }
            }
            .frame(height: 8)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.5), value: growth.xp)
            // 방금 얻은 보상(레벨업·성장·하루 보너스)이 있으면 잠시 그것을, 아니면 다음 성장 단계 안내를 보여 준다.
            Group {
                if let message = shown.flatMap({ $0.celebration ?? $0.detail }) {
                    Label(message, systemImage: "sparkles")
                        .foregroundStyle(growth.stage.tint)
                        .fontWeight(.semibold)
                } else {
                    Text(growth.nextStageNote)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(growth.accessibilityLabel)
    }

    // MARK: - 반응

    private func react(_ event: GrowthEvent) {
        pending?.cancel()
        if event.grewUp { grownStage = event.after.stage }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { shown = event }
        AccessibilityNotification.Announcement(
            ([event.celebration, "\(event.gained) XP를 얻었어요."].compactMap { $0 }).joined(separator: " ")
        ).post()
        let size = Self.mascotSize
        pending = Task {
            if !reduceMotion {
                burst += 1
                // 기분 좋게 폴짝: 레벨이 오르면 더 높이, 두 번.
                let hops = event.leveledUp ? 2 : 1
                for _ in 0..<hops {
                    withAnimation(.easeOut(duration: 0.16)) { lift = -size * (event.leveledUp ? 0.3 : 0.2) }
                    try? await Task.sleep(for: .milliseconds(160))
                    guard !Task.isCancelled else { return }
                    withAnimation(.interpolatingSpring(stiffness: 300, damping: 12)) { lift = 0 }
                    try? await Task.sleep(for: .milliseconds(380))
                    guard !Task.isCancelled else { return }
                }
                if event.leveledUp { burst += 1 }
            }
            try? await Task.sleep(for: .seconds(event.leveledUp || event.grewUp ? 2.8 : 1.8))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeIn(duration: 0.25)) { shown = nil }
        }
    }
}

extension GrowthStage {
    /// 카드의 포인트 색: 새싹은 민트, 잎사귀는 초록, 꽃은 코랄. 모두 부드러운 파스텔이다.
    var tint: Color {
        switch self {
        case .sprout: return GroupColor.mint.color
        case .leaf: return GroupColor.green.color
        case .flower: return GroupColor.coral.color
        }
    }
}

/// 가운데에서 바깥으로 퍼지며 사라지는 작은 반짝임. `trigger`가 바뀔 때마다 한 번 터진다.
private struct SparkleBurst: View {
    let trigger: Int
    let count: Int
    let radius: CGFloat
    let tint: Color
    @State private var progress: CGFloat = 1

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { index in
                let angle = Double(index) / Double(count) * 2 * .pi - .pi / 2
                Image(systemName: index.isMultiple(of: 2) ? "sparkle" : "star.fill")
                    .font(.system(size: index.isMultiple(of: 2) ? 13 : 8, weight: .semibold))
                    .foregroundStyle(index.isMultiple(of: 3) ? Color.yellow : tint)
                    .offset(x: cos(angle) * radius * progress, y: sin(angle) * radius * progress)
                    .scaleEffect(0.4 + progress * 0.8)
                    .opacity(progress >= 1 ? 0 : 1 - Double(progress) * 0.85)
            }
        }
        .onChange(of: trigger) {
            // 얼굴 위에서 터지지 않게 몸 둘레에서 시작한다.
            progress = 0.5
            withAnimation(.easeOut(duration: 0.85)) { progress = 1 }
        }
    }
}
