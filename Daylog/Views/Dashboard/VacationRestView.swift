import SwiftUI

/// 휴가인 날의 오늘 화면: 대시보드 대신 보여 주는 휴식 화면. 바닷가의 해먹에서 새싹이가 쉬고, 휴가가 며칠째인지 알려 준다.
///
/// 오늘 영역만 차지한다(사이드바·탭은 그대로). 기록이나 카드 배치는 건드리지 않고, 단추로 평소 화면을 잠깐 볼 수 있다.
/// 풍경과 해먹은 배경(`VacationSceneBackground`)이 그린다. 이 뷰는 문구와 단추를 놓고, 그 사이에 해먹이 들어갈 자리를 비워 둔다.
struct VacationRestView: View {
    @Environment(AppStore.self) private var store
    /// 해먹 말고 나머지(문구, 진행 카드, 단추, 여백)가 쓰는 높이의 어림값. 글자 크기를 따라 커진다.
    @ScaledMetric(relativeTo: .body) private var reservedHeight: CGFloat = Self.baseReservedHeight
    /// [유지할 루틴 보기]. 휴가 중에 이어 가는 루틴이 없으면 nil이고 단추를 보여 주지 않는다.
    var onShowKeptRoutines: (() -> Void)?
    /// [평소 화면 보기].
    let onShowDashboard: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let reserved = reservedHeight - (onShowKeptRoutines == nil ? Self.buttonHeight : 0)
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
                    VacationSceneBackground(slot: anchor.map { area[$0] }, topInset: proxy.safeAreaInsets.top)
                }
                .ignoresSafeArea(edges: Self.backgroundEdges)
            }
        }
    }

    #if os(macOS)
    private static let baseReservedHeight: CGFloat = 380
    private static let buttonHeight: CGFloat = 42
    #else
    private static let baseReservedHeight: CGFloat = 450
    private static let buttonHeight: CGFloat = 60
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
            VStack(spacing: 8) {
                Text(store.today.longTitle)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Text("오늘은\n쉬어가는 날이에요.")
                    .font(.title.bold())
                    .accessibilityAddTraits(.isHeader)
                Text("잠시 멈춰도 괜찮아요.\n새싹이와 함께 여유로운 시간을 보내요.")
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
                .accessibilityLabel("해먹에서 쉬는 새싹이")
                .accessibilityAddTraits(.isImage)

            // 진행 상황과 단추는 한 카드에 담는다. 모래 위에 바로 두면 저녁 풍경에서 단추의 글자가 묻힌다.
            VStack(spacing: 14) {
                if let info = VacationRestInfo.make(periods: store.vacationPeriods, today: store.today) {
                    progress(info)
                }
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
            .padding(16)
            .frame(maxWidth: 340)
            .background(Theme.cardBackground.opacity(0.94), in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).strokeBorder(Theme.cardBorder, lineWidth: 1))
            .padding(.horizontal, 20)
        }
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
