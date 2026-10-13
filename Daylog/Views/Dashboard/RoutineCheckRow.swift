import SwiftUI

/// 체크 행의 [오늘 건너뛰기] / [건너뛰기 취소]. ⋯ 메뉴와 컨텍스트 메뉴가 같은 항목을 쓴다.
struct CheckSkipActions: View {
    let check: CheckValue
    /// 실제 오늘의 체크인가. 지난 날짜에서는 "이날"이라고 적는다.
    let isToday: Bool
    let setSkipped: (Bool) -> Void

    static func title(isSkipped: Bool, isToday: Bool) -> String {
        isSkipped ? "건너뛰기 취소" : isToday ? "오늘 건너뛰기" : "이날 건너뛰기"
    }

    var body: some View {
        Button {
            setSkipped(!check.isSkipped)
        } label: {
            Label(
                Self.title(isSkipped: check.isSkipped, isToday: isToday),
                systemImage: check.isSkipped ? "arrow.uturn.backward" : SkipStyle.symbol
            )
        }
    }
}

/// 오늘 화면의 루틴 한 줄: 이름, 시간, 그리고 오른쪽의 [✓ | »] 단추 묶음.
/// 체크 칸과 ⋯ 메뉴를 쓰던 자리다. 완료와 건너뛰기를 같은 자리에 늘 보여 주어, 메뉴를 열지 않고 한 번에 누른다.
struct RoutineCheckRow: View {
    let check: CheckValue
    let tint: Color
    let showsTime: Bool
    let isToday: Bool
    let setDone: (Bool) -> Void
    let setSkipped: (Bool) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                // 큰 글자 크기: 이름이 찌그러지지 않게 시간과 단추를 아랫줄로 내린다.
                VStack(alignment: .leading, spacing: 6) {
                    titles(lineLimit: 4)
                    HStack(spacing: 10) {
                        if !check.timeLabel.isEmpty { timeLabel }
                        Spacer(minLength: 0)
                        buttons
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .center, spacing: 10) {
                    titles(lineLimit: 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if showsTime { timeLabel }
                    buttons
                }
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, Self.trailingPadding)
        .padding(.vertical, Self.verticalPadding)
    }

    private var buttons: some View {
        RoutineActionButtons(
            title: check.title, isDone: check.isDone, isSkipped: check.isSkipped,
            skipTitle: CheckSkipActions.title(isSkipped: check.isSkipped, isToday: isToday),
            toggleDone: { RoutineActionButtons.toggleDone(check, setDone: setDone) },
            toggleSkipped: { RoutineActionButtons.toggleSkipped(check, setSkipped: setSkipped) }
        )
    }

    private func titles(lineLimit: Int) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(check.title)
                .lineLimit(lineLimit)
                // 건너뛴 줄은 이름을 옅게 한다. 완료한 줄은 그대로 둔다(단추의 색이 알려 준다).
                .foregroundStyle(check.isSkipped && !check.isDone ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
            if !check.note.isEmpty {
                Text(check.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var timeLabel: some View {
        Text(check.timeLabel)
            .font(.callout)
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    #if os(macOS)
    static let trailingPadding: CGFloat = 8
    static let verticalPadding: CGFloat = 4
    #else
    static let trailingPadding: CGFloat = 8
    static let verticalPadding: CGFloat = 4
    #endif
}

/// 줄 오른쪽의 [✓ | »]: 완료와 건너뛰기. 하나의 둥근 컨트롤로 묶여 있고, 둘이 함께 켜지는 일은 없다.
///
/// - 미완료: ✓ → 완료, » → 건너뜀
/// - 완료: ✓ → 완료 취소, » → 건너뜀으로
/// - 건너뜀: » → 건너뛰기 취소, ✓ → 완료로
struct RoutineActionButtons: View {
    let title: String
    let isDone: Bool
    let isSkipped: Bool
    /// "오늘 건너뛰기"·"이날 건너뛰기"·"건너뛰기 취소". 도움말과 VoiceOver에 쓴다.
    let skipTitle: String
    let toggleDone: () -> Void
    let toggleSkipped: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 글자 크기를 키우면 단추도 조금 커진다(너무 커져 이름을 밀어내지 않게 상한을 둔다).
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    /// ✓: 완료면 취소하고, 미완료나 건너뜀이면 완료로 만든다.
    static func toggleDone(_ check: CheckValue, setDone: (Bool) -> Void) {
        setDone(!check.isDone)
    }

    /// »: 건너뜀이면 취소하고, 미완료나 완료면 건너뜀으로 만든다.
    static func toggleSkipped(_ check: CheckValue, setSkipped: (Bool) -> Void) {
        setSkipped(!check.isSkipped)
    }

    private var isShowingSkip: Bool { isSkipped && !isDone }

    var body: some View {
        HStack(spacing: 2) {
            segment(
                symbol: "checkmark", isOn: isDone, fill: Theme.accent, ink: Theme.onAccent,
                label: "\(title) 완료", hint: isDone ? "누르면 완료를 취소합니다." : "누르면 완료로 기록합니다.",
                help: isDone ? "완료 취소" : "완료", action: toggleDone
            )
            segment(
                symbol: Self.skipSymbol, isOn: isShowingSkip, fill: Self.skipFill, ink: Theme.onAccent,
                label: "\(title) 건너뛰기", hint: isShowingSkip ? "누르면 건너뛰기를 취소합니다." : "누르면 건너뜀으로 기록합니다.",
                help: skipTitle, action: toggleSkipped
            )
        }
        .padding(2)
        .background(Theme.track, in: RoundedRectangle(cornerRadius: Self.radius + 2, style: .continuous))
        .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: isDone)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: isSkipped)
        #if os(iOS)
        .sensoryFeedback(.success, trigger: isDone) { old, new in !old && new }
        #endif
        .fixedSize()
    }

    private func segment(
        symbol: String, isOn: Bool, fill: Color, ink: Color, label: String, hint: String, help: String,
        action: @escaping () -> Void
    ) -> some View {
        let factor = min(scale, Self.maxScale)
        return Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: Self.symbolSize * factor, weight: .bold))
                .foregroundStyle(isOn ? AnyShapeStyle(ink) : AnyShapeStyle(.secondary))
                .frame(width: Self.width * factor, height: Self.height * factor)
                .background(
                    isOn ? AnyShapeStyle(fill) : AnyShapeStyle(.clear),
                    in: RoundedRectangle(cornerRadius: Self.radius, style: .continuous)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "켜짐" : "꺼짐")
        .accessibilityHint(hint)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    /// "»". 건너뛴 상태를 나타내는 표시(회색 "—", `SkipStyle.symbol`)와 달리, 누르는 단추에는 "넘기기" 기호를 쓴다.
    static let skipSymbol = "chevron.right.2"
    /// 건너뛰기가 켜졌을 때의 진한 회색. 밝은 화면과 어두운 화면에서 각각 바탕과 구분되게 고른다.
    static let skipFill = Color.adaptive(name: "DaylogSkipFill", light: (0.45, 0.48, 0.54), dark: (0.66, 0.68, 0.73))
    static let maxScale: CGFloat = 1.35
    static let radius: CGFloat = 7
    #if os(macOS)
    static let width: CGFloat = 32
    static let height: CGFloat = 22
    static let symbolSize: CGFloat = 11
    #else
    // 터치 화면: 단추 하나가 44pt 너비를 차지하고, 줄의 위아래 여백까지 합쳐 손가락이 닿는 높이를 채운다.
    static let width: CGFloat = 44
    static let height: CGFloat = 32
    static let symbolSize: CGFloat = 14
    #endif
}
