import SwiftUI

/// 반복 요일 고르기: 빠른 선택(매일·평일·주말)과 월~일 버튼. 둘은 같은 값을 보여 주므로 늘 일치한다.
/// 선택 여부는 색만이 아니라 굵기와 접근성 상태로도 전달한다.
struct WeekdaySelector: View {
    @Binding var selection: Set<Int>
    let tint: Color
    /// 요일 버튼의 지름. 손가락으로 누르는 화면에서는 크게 준다.
    var daySize: CGFloat = 32
    /// 요일 글자의 실제 크기(callout). 단추 크기를 고정해 두면 큰 글자에서 글자가 칸 밖으로 나와 단추끼리 겹쳤다.
    @ScaledMetric(relativeTo: .callout) private var glyphSize: CGFloat = 16
    /// 요일 단추의 지름: 기본은 `daySize` 그대로, 글자가 커지면 글자를 감쌀 만큼만 커진다.
    private var scaledDaySize: CGFloat { max(daySize, glyphSize * 1.4) }

    private struct Preset: Identifiable {
        let title: String
        let detail: String
        let days: [Int]
        var id: String { title }
    }

    private static let presets = [
        Preset(title: "매일", detail: "", days: Weekdays.all),
        Preset(title: "평일", detail: " (월~금)", days: Weekdays.workdays),
        Preset(title: "주말", detail: " (토, 일)", days: Weekdays.weekend),
    ]

    var body: some View {
        // 한 줄에 다 들어가면 전과 같고, 큰 글자 크기처럼 들어가지 않을 때는 다음 줄로 넘긴다
        // (한 줄로 고정하면 시트 내용 전체가 화면보다 넓어져 양쪽이 잘린다).
        VStack(alignment: .leading, spacing: 10) {
            FlowLayout(spacing: 6) {
                ForEach(Self.presets) { preset in
                    presetButton(preset)
                }
            }
            FlowLayout(spacing: 6) {
                ForEach(Weekdays.all, id: \.self) { weekday in
                    dayButton(weekday)
                }
            }
        }
    }

    private func presetButton(_ preset: Preset) -> some View {
        let isOn = selection == Set(preset.days)
        return Button {
            selection = Set(preset.days)
        } label: {
            Text(preset.title + preset.detail)
                .font(.callout.weight(isOn ? .semibold : .regular))
                .foregroundStyle(isOn ? AnyShapeStyle(Theme.onAccent) : AnyShapeStyle(.primary))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .frame(minHeight: max(28, daySize - 4))
                .background(isOn ? AnyShapeStyle(tint) : AnyShapeStyle(Theme.track), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(preset.title)로 설정")
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }

    private func dayButton(_ weekday: Int) -> some View {
        let isOn = selection.contains(weekday)
        return Button {
            if isOn {
                selection.remove(weekday)
            } else {
                selection.insert(weekday)
            }
        } label: {
            Text(Weekdays.symbol(weekday))
                .font(.callout.weight(isOn ? .bold : .regular))
                .foregroundStyle(isOn ? AnyShapeStyle(Theme.onAccent) : AnyShapeStyle(.secondary))
                .frame(width: scaledDaySize, height: scaledDaySize)
                .background(isOn ? AnyShapeStyle(tint) : AnyShapeStyle(Theme.track), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(Weekdays.symbol(weekday))요일")
        .accessibilityValue(isOn ? "선택됨" : "선택 안 됨")
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}
