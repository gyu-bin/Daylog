import SwiftUI

/// 체크 표시와 이름 전체가 눌리는 체크박스. VoiceOver에는 표준 체크박스로 보인다.
struct RoutineCheckStyle: ToggleStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var tint: Color = Theme.accent
    var routineTitle: String

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 19))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(
                        configuration.isOn ? Theme.onAccent : Color.secondary,
                        configuration.isOn ? tint : Color.secondary
                    )
                    .scaleEffect(reduceMotion || configuration.isOn ? 1 : 0.94)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isOn)
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 4 }
                    .accessibilityHidden(true)
                configuration.label
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        #if os(iOS)
        .sensoryFeedback(.success, trigger: configuration.isOn) { old, new in !old && new }
        #endif
        .transaction { transaction in
            if reduceMotion { transaction.animation = nil }
        }
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) {
                Text(routineTitle)
            }
            .accessibilityValue(configuration.isOn ? "완료" : "미완료")
            .accessibilityHint(configuration.isOn ? "활성화하면 완료를 취소합니다." : "활성화하면 완료로 기록합니다.")
            #if os(macOS)
            .toggleStyle(.checkbox)
            #endif
        }
    }
}
