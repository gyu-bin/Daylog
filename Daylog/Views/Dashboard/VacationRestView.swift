import SwiftUI

/// 휴가인 날의 오늘 화면: 대시보드 대신 보여 주는 휴식 화면. 바닷가의 해먹에서 새싹이가 쉬고, 휴가가 며칠째인지 알려 준다.
///
/// 오늘 영역만 차지한다(사이드바·탭은 그대로). 기록이나 카드 배치는 건드리지 않고, 단추로 평소 화면을 잠깐 볼 수 있다.
/// 풍경과 해먹은 배경(`VacationSceneBackground`)이 그린다. 이 뷰는 문구와 단추를 놓고, 그 사이에 해먹이 들어갈 자리를 비워 둔다.
struct VacationRestView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    /// 해먹 말고 나머지(문구, 진행 카드, 단추, 여백)가 쓰는 높이의 어림값. 글자 크기를 따라 커진다.
    @ScaledMetric(relativeTo: .body) private var reservedHeight: CGFloat = Self.baseReservedHeight
    /// [유지할 루틴 보기]. 휴가 중에 이어 가는 루틴이 없으면 nil이고 단추를 보여 주지 않는다.
    var onShowKeptRoutines: (() -> Void)?
    /// [평소 화면 보기].
    var onShowDashboard: () -> Void = {}
    /// 설정의 미리보기로 띄웠을 때: 예시 휴가 기간과 낮·밤 전환, [미리보기 종료]. 실제 기록과 휴가는 읽기만 한다.
    var preview: VacationRestPreview?

    private var appearance: PioResolvedAppearance {
        PioAppearanceCoordinator.shared.resolve(level: store.growth.level,
            context: colorScheme == .dark ? .vacationNight : .vacationDay, motion: .rest)
    }

    var body: some View {
        GeometryReader { proxy in
            // 미리보기는 맨 위의 표시와 낮·밤 전환이 더 있다(유지할 루틴 단추는 없다).
            let reserved = reservedHeight - (onShowKeptRoutines == nil ? Self.buttonHeight : 0)
                + (preview == nil ? 0 : Self.previewExtraHeight)
            // 글자를 크게 쓰거나 창이 낮으면 한 화면을 넘을 수 있다. 넘치면 스크롤하고, 아니면 가운데에 둔다.
            ScrollView {
                content(hammock: VacationArt.hammockSide(pane: proxy.size, reserved: reserved))
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
            // 배경은 해먹 자리를 받아 그 자리에 해먹을, 그 둘레에 풍경을 그린다(스크롤하면 함께 움직인다).
            .backgroundPreferenceValue(VacationSlotKey.self) { anchor in
                GeometryReader { area in
                    if PioCharacter.isEnabled {
                        RoutimoriVacationScene(slot: anchor.map { area[$0] })
                    } else {
                        VacationSceneBackground(slot: anchor.map { area[$0] }, topInset: proxy.safeAreaInsets.top)
                    }
                }
                .ignoresSafeArea(edges: Self.backgroundEdges)
            }
        }
    }

    #if os(macOS)
    private static let baseReservedHeight: CGFloat = 380
    private static let buttonHeight: CGFloat = 42
    private static let previewExtraHeight: CGFloat = 80
    #else
    private static let baseReservedHeight: CGFloat = 450
    private static let buttonHeight: CGFloat = 60
    private static let previewExtraHeight: CGFloat = 90
    #endif

    /// 배경이 번지는 가장자리. Mac에서는 사이드바 밑으로 들어가지 않게 왼쪽은 남긴다.
    private static var backgroundEdges: Edge.Set {
        #if os(macOS)
        [.top, .bottom, .trailing]
        #else
        .all
        #endif
    }

    private func content(hammock: CGFloat) -> some View {
        VStack(spacing: 14) {
            if preview != nil {
                // 실제 휴가가 아니라는 것을 맨 위에 분명히 적는다.
                Label("미리보기 · 실제 휴가와 기록은 바뀌지 않아요", systemImage: "eye")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.regularMaterial, in: Capsule())
            }
            VStack(spacing: 8) {
                Text(store.today.longTitle)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Text(PioCharacter.isEnabled ? "지금은 휴식 중이에요" : "오늘은\n쉬어가는 날이에요.")
                    .font(.title.bold())
                    .accessibilityAddTraits(.isHeader)
                Text(PioCharacter.isEnabled ? "잠시 쉬어가요.\n더 좋은 내가 되기 위해서요." : "잠시 멈춰도 괜찮아요.\n새싹이와 함께 여유로운 시간을 보내요.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 24)

            // 해먹이 들어갈 자리. 그림은 배경이 이 자리에 맞춰 그린다.
            Color.clear
                .frame(width: hammock, height: hammock * VacationArt.slotHeight / VacationArt.canvas)
                .anchorPreference(key: VacationSlotKey.self, value: .bounds) { $0 }
                .accessibilityElement()
                .accessibilityLabel(PioCharacter.isEnabled
                    ? "해먹에서 쉬는 \(appearance.outfitApplied ? appearance.outfit.title : "기본 피오"). \(appearance.compatibilityNote ?? "")"
                    : "해먹에서 쉬는 새싹이")
                .accessibilityAddTraits(.isImage)

            // 진행 상황과 단추는 한 카드에 담는다. 모래 위에 바로 두면 저녁 풍경에서 단추의 글자가 묻힌다.
            VStack(spacing: 14) {
                if PioCharacter.isEnabled {
                    PioAppearanceNotice(appearance: appearance)
                }
                if let info = preview?.info ?? VacationRestInfo.make(periods: store.vacationPeriods, today: store.today) {
                    progress(info)
                }
                if let preview {
                    previewControls(preview)
                } else {
                    VStack(spacing: 10) {
                        if let onShowKeptRoutines {
                            Button(action: onShowKeptRoutines) {
                                Text("유지할 루틴 보기").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityHint("휴가 중에도 이어 가기로 한 루틴을 보여 줍니다.")
                        }
                        Button(action: onShowDashboard) {
                            Text("평소 화면 보기").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityHint("평소의 오늘 화면을 잠시 봅니다. 휴가와 카드 배치는 바뀌지 않아요.")
                    }
                    .controlSize(.large)
                }
            }
            .padding(16)
            .frame(maxWidth: 340)
            .background(Theme.cardBackground.opacity(0.94), in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).strokeBorder(Theme.cardBorder, lineWidth: 1))
            .padding(.horizontal, 20)
        }
    }

    /// 미리보기의 단추: 낮·밤 전환과 [미리보기 종료].
    private func previewControls(_ preview: VacationRestPreview) -> some View {
        VStack(spacing: 10) {
            Picker("풍경", selection: preview.isNight) {
                Label("낮", systemImage: "sun.max.fill").tag(false)
                Label("밤", systemImage: "moon.stars.fill").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Button(action: preview.onClose) {
                Text("미리보기 종료").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.cancelAction)
        }
        .controlSize(.large)
    }

    private func progress(_ info: VacationRestInfo) -> some View {
        VStack(spacing: 8) {
            Text(info.title)
                .font(.headline)
                .monospacedDigit()
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.track)
                    Capsule().fill(Theme.accent).frame(width: max(8, proxy.size.width * info.progress))
                }
            }
            .frame(height: 8)
            Text(info.periodTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(info.title). \(info.periodTitle)")
    }
}

/// 휴가 중에 평소 화면을 보고 있을 때 머리말 아래에 두는 줄: 휴식 화면으로 돌아가는 길.
struct VacationRestReturnBar: View {
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Label("휴가 중이에요. 평소 화면을 보고 있어요.", systemImage: "beach.umbrella.fill")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Button("휴식 화면으로", action: action)
                .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.vacationTint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// 휴가 화면을 미리보기로 띄울 때 넘기는 값.
struct VacationRestPreview {
    /// 예시 휴가 기간의 진행(실제 휴가 기록이 아니다).
    let info: VacationRestInfo
    /// 밤 풍경으로 볼지.
    let isNight: Binding<Bool>
    let onClose: () -> Void

    /// 예시 기간: 어제부터 5일 동안의 휴가 2일째.
    static func sampleInfo(today: Day) -> VacationRestInfo? {
        VacationRestInfo.make(periods: [VacationPeriod(start: today.adding(days: -1), end: today.adding(days: 3))], today: today)
    }
}

/// 설정 > 휴가의 [휴가 화면 미리보기]: 실제 휴가 화면(`VacationRestView`)을 예시 기간으로 띄운다. 낮·밤을 바꿔 볼 수 있다.
/// 휴가·기록·알림은 건드리지 않는다(화면이 읽기만 한다).
struct VacationRestPreviewScreen: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var systemScheme
    @Environment(\.dismiss) private var dismiss
    @State private var isNight: Bool?

    var body: some View {
        let night = Binding(get: { isNight ?? (systemScheme == .dark) }, set: { isNight = $0 })
        Group {
            if let info = VacationRestPreview.sampleInfo(today: store.today) {
                VacationRestView(preview: VacationRestPreview(info: info, isNight: night, onClose: { dismiss() }))
            }
        }
        // 풍경과 글자를 함께 낮·밤으로 바꾼다(앱의 화면 모드 설정은 그대로).
        .environment(\.colorScheme, night.wrappedValue ? .dark : .light)
        #if os(macOS)
        .frame(width: 720, height: 800)
        #endif
    }
}
