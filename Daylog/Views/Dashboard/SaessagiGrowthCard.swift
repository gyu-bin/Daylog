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
        Group {
            if PioOutfitMotionView.isTrialEnabled {
                PioHomeGrowthPresentation(growth: growth, event: shown, burst: burst)
            } else {
                Card(fillsHeight: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        CardHeader(symbol: "sparkles", title: PioTrial.isEnabled ? "피오 성장" : "새싹이 성장", tint: growth.stage.tint)
                        HStack(alignment: .center, spacing: 14) {
                            mascot(growth)
                            details(growth)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
        .onChange(of: store.growthEvent) { _, event in
            if let event { react(event) }
        }
        .onDisappear {
            pending?.cancel()
            // A cancelled dismissal timer must not leave the trial celebrating
            // indefinitely when this card is shown again.
            if PioOutfitMotionView.isTrialEnabled { shown = nil }
        }
    }

    // MARK: - 새싹이

    private func mascot(_ growth: SaessagiGrowth) -> some View {
        let size = Self.mascotSize
        return ZStack {
            Circle()
                .fill(growth.stage.tint.opacity(0.12))
                .frame(width: size * 1.12, height: size * 1.12)
                .offset(y: size * 0.06)
            Group {
                if PioOutfitMotionView.isTrialEnabled {
                    let appearance = PioAppearanceCoordinator.shared.resolve(
                        level: growth.level, context: .growth, motion: shown == nil ? .idle : .celebration)
                    ZStack {
                        PioAppearanceView(appearance: appearance)
                        .id(appearance.outfit)
                        .transition(reduceMotion ? .identity : .opacity)
                    }
                    .frame(width: size, height: size)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: appearance.outfit)
                } else if PioTrial.isEnabled {
                    // 피오 시범(검증용 앱에서만): 부위 리그로 그 레벨의 성장 단계(1·2) 피오가 움직인다.
                    SaessagiAnimatedView(
                        pose: .idle, size: size, behavior: .growing, pioStage: PioTrial.artStage(level: growth.level)
                    )
                } else {
                    SaessagiAnimatedView(
                        pose: growth.stage.pose, size: size, behavior: .growing,
                        entrance: grownStage == growth.stage ? .growLeaf : nil
                    )
                    // 단계가 바뀌면 새 그림으로 바꿔 끼운다(그때 잎이 돋아나는 연출을 한다).
                    .id(growth.stage)
                }
            }
            .offset(y: PioOutfitMotionView.isTrialEnabled ? 0 : lift)
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
                Text(PioOutfitMotionView.isTrialEnabled
                     ? "\(PioTrial.stage(forLevel: growth.level).number)단계"
                     : (PioTrial.isEnabled ? PioTrial.stageTitle(level: growth.level) : growth.stage.title))
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
                    Text(PioOutfitMotionView.isTrialEnabled
                         ? "성장해도 선택한 의상을 유지해요."
                         : (PioTrial.isEnabled ? PioTrial.nextStageNote(level: growth.level) : growth.nextStageNote))
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PioOutfitMotionView.isTrialEnabled
            ? "피오 성장. 레벨 \(growth.level), \(PioTrial.stage(forLevel: growth.level).number)단계. \(PioAppearanceCoordinator.shared.resolve(level: growth.level, context: .growth).outfit.title). \(growth.xpIntoLevel) / \(growth.xpForNextLevel) XP"
            : growth.accessibilityLabel)
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
                // 의상 시범은 Core Animation 축하 동작이 담당한다. 중복으로 띄우지 않는다.
                // 기존 새싹이·피오 경로의 반응은 그대로 유지한다.
                let hops = PioOutfitMotionView.isTrialEnabled ? 0 : (event.leveledUp ? 2 : 1)
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

/// The home presentation uses the approved full-body artwork and its existing
/// motion host. Layout never changes the costume or invents growth-stage art.
private struct PioHomeGrowthPresentation: View {
    @Environment(AppStore.self) private var store
    let growth: SaessagiGrowth
    let event: GrowthEvent?
    let burst: Int
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsWardrobe = false

    private var appearance: PioResolvedAppearance {
        PioAppearanceCoordinator.shared.resolve(level: growth.level, context: .growth,
                                                motion: event == nil ? .idle : .celebration)
    }
    private var outfit: PioOutfitID { appearance.outfit }
    private var dark: Bool { colorScheme == .dark }
    private var ink: Color {
        dark ? Color(red: 0.92, green: 0.95, blue: 0.86) : Color(red: 0.18, green: 0.29, blue: 0.20)
    }
    private var secondaryInk: Color {
        dark ? Color(red: 0.72, green: 0.80, blue: 0.72) : Color(red: 0.36, green: 0.44, blue: 0.35)
    }
    private var accent: Color {
        dark ? Color(red: 0.68, green: 0.82, blue: 0.58) : Color(red: 0.28, green: 0.43, blue: 0.25)
    }
    private var surface: Color {
        dark ? Color(red: 0.10, green: 0.16, blue: 0.12) : Color(red: 0.99, green: 0.98, blue: 0.94)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardHeader(symbol: "leaf.fill", title: "피오와 함께", tint: accent) {
                Button {
                    #if os(macOS)
                    store.section = .wardrobe
                    #else
                    showsWardrobe = true
                    #endif
                } label: {
                    Label("옷장", systemImage: "tshirt")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .background(accent.opacity(dark ? 0.13 : 0.08), in: Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(accent)
                .accessibilityLabel("피오 옷장 열기")
                .accessibilityIdentifier("home.pio.wardrobe")
            }

            if dynamicTypeSize.isAccessibilitySize {
                stackedCharacter
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        character(size: 156)
                        identity.frame(minWidth: 150, maxWidth: .infinity, alignment: .leading)
                    }
                    stackedCharacter
                }
            }

            progress
            PioAppearanceNotice(appearance: appearance)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(ink)
        .background(surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(accent.opacity(dark ? 0.20 : 0.13), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .accessibilityIdentifier("home.pio.card")
        .sheet(isPresented: $showsWardrobe) {
            NavigationStack {
                PioWardrobeView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("완료") { showsWardrobe = false }
                        }
                    }
            }
            #if os(macOS)
            .frame(minWidth: 540, idealWidth: 740, minHeight: 560, idealHeight: 760)
            #endif
        }
    }

    private var stackedCharacter: some View {
        VStack(alignment: .leading, spacing: 12) {
            character(size: 180)
                .frame(maxWidth: .infinity)
            identity
        }
    }

    private func character(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [accent.opacity(dark ? 0.18 : 0.12), accent.opacity(0.025)],
                                     center: .center, startRadius: 0, endRadius: size * 0.54))
                .frame(width: size * 0.94, height: size * 0.94)
            Ellipse()
                .fill(accent.opacity(dark ? 0.12 : 0.08))
                .frame(width: size * 0.54, height: size * 0.08)
                .offset(y: size * 0.40)
            PioAppearanceView(appearance: appearance)
                .frame(width: size, height: size)
                .id(outfit)
                .transition(.opacity)
            SparkleBurst(trigger: burst, count: event?.leveledUp == true ? 9 : 5,
                         radius: size * 0.49, tint: accent)
                .allowsHitTesting(false)
        }
        .frame(width: size, height: size + 20)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: outfit)
        .overlay(alignment: .topTrailing) {
            if let event {
                Text("+\(event.gained) XP")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(surface, in: Capsule())
                    .overlay(Capsule().strokeBorder(accent.opacity(0.3), lineWidth: 1))
                    .fixedSize()
                    .transition(.opacity)
                    .id(event.id)
            }
        }
        .accessibilityHidden(true)
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("오늘의 작은 동행")
                .font(.caption.weight(.medium))
                .foregroundStyle(secondaryInk)
            Text(outfit.title)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("home.pio.outfit")
            Text(outfit.description)
                .font(.subheadline)
                .foregroundStyle(secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 10) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) {
                    level
                    xp
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        level
                        Spacer(minLength: 0)
                        xp
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        level
                        xp
                    }
                }
            }
            ProgressView(value: growth.progress)
                .tint(accent)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.5), value: growth.xp)
            Text(event.flatMap { $0.celebration ?? $0.detail }
                 ?? "다음 레벨까지 \(max(0, growth.xpForNextLevel - growth.xpIntoLevel)) XP · 작은 실천을 쌓아가요.")
                .font(.caption)
                .foregroundStyle(event == nil ? secondaryInk : accent)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(accent.opacity(dark ? 0.075 : 0.045), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("피오 성장, 레벨 \(growth.level)")
        .accessibilityValue("\(growth.xpIntoLevel) / \(growth.xpForNextLevel) XP. 다음 레벨까지 \(max(0, growth.xpForNextLevel - growth.xpIntoLevel)) XP")
        .accessibilityIdentifier("home.pio.progress")
    }

    private var level: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
        return layout {
            Text("Lv.\(growth.level)")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(growth.level)))
        }
        .fixedSize(horizontal: !dynamicTypeSize.isAccessibilitySize, vertical: true)
    }

    private var xp: some View {
        Text("\(growth.xpIntoLevel) / \(growth.xpForNextLevel) XP")
            .font(.caption.weight(.medium))
            .monospacedDigit()
            .foregroundStyle(secondaryInk)
            .fixedSize(horizontal: !dynamicTypeSize.isAccessibilitySize, vertical: true)
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
