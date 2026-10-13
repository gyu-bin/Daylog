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

/// 오늘 화면의 체크 한 줄: 체크 칸과 이름, 시간, 그리고 ⋯ 메뉴.
/// ⋯는 Mac·iPhone·iPad 모두 늘 보여 준다. 마우스를 올린 줄에만 보이게 했더니 건너뛰기가 있는 줄 모르고 지나쳤다
/// (오른쪽 클릭으로도 같은 메뉴가 열린다). 작고 옅게 그려 체크할 것이 먼저 보이게 한다.
struct RoutineCheckRow: View {
    let check: CheckValue
    let tint: Color
    let showsTime: Bool
    let isToday: Bool
    let setDone: (Bool) -> Void
    let setSkipped: (Bool) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: 2) {
            Toggle(isOn: Binding(get: { check.isDone }, set: setDone)) {
                if dynamicTypeSize.isAccessibilitySize {
                    // 큰 글자 크기: 이름이 찌그러지지 않게 건너뜀 표시와 시간을 아랫줄로 내린다.
                    VStack(alignment: .leading, spacing: 2) {
                        titles(lineLimit: 4)
                        if check.isSkipped || !check.timeLabel.isEmpty {
                            HStack(spacing: 8) {
                                if check.isSkipped { skipLabel }
                                if !check.timeLabel.isEmpty { timeLabel }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        titles(lineLimit: 2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if check.isSkipped { skipLabel }
                        if showsTime { timeLabel }
                    }
                }
            }
            .toggleStyle(RoutineCheckStyle(tint: tint, routineTitle: check.title, isSkipped: check.isSkipped))
            // VoiceOver에서는 ⋯를 찾지 않아도 체크 칸의 동작으로 바로 고를 수 있다.
            .accessibilityAction(named: Text(CheckSkipActions.title(isSkipped: check.isSkipped, isToday: isToday))) {
                setSkipped(!check.isSkipped)
            }

            Menu {
                actions
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: Self.menuWidth, height: Self.menuHeight)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
            // 메뉴 단추가 강조색을 입지 않게 한다. 목록에서는 눈에 덜 띄어야 한다.
            .tint(.secondary)
            .fixedSize()
            .accessibilityLabel("\(check.title) 더 보기")
        }
        .padding(.leading, 10)
        .padding(.trailing, Self.trailingPadding)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .contextMenu { actions }
    }

    private var actions: some View {
        CheckSkipActions(check: check, isToday: isToday, setSkipped: setSkipped)
    }

    private func titles(lineLimit: Int) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(check.title)
                .lineLimit(lineLimit)
            if !check.note.isEmpty {
                Text(check.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var skipLabel: some View {
        Text(SkipStyle.label)
            .font(.caption.weight(.medium))
            .foregroundStyle(SkipStyle.ink)
            .lineLimit(1)
            .fixedSize()
    }

    private var timeLabel: some View {
        Text(check.timeLabel)
            .font(.callout)
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    #if os(macOS)
    static let menuWidth: CGFloat = 22
    static let menuHeight: CGFloat = 20
    static let trailingPadding: CGFloat = 6
    #else
    // 터치 화면에서는 누르기 쉽게 넓힌다.
    static let menuWidth: CGFloat = 36
    static let menuHeight: CGFloat = 30
    static let trailingPadding: CGFloat = 2
    #endif
}
