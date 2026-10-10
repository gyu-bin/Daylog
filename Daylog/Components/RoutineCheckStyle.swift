import SwiftUI

/// 체크 표시와 이름 전체가 눌리는 체크박스. VoiceOver에는 표준 체크박스로 보인다.
struct RoutineCheckStyle: ToggleStyle {
    var tint: Color = Theme.accent

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
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 4 }
                configuration.label
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) {
                configuration.label
            }
            .toggleStyle(.checkbox)
        }
    }
}
