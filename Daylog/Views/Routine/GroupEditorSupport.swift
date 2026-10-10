import SwiftUI

/// 팔레트에서 그룹 색을 고른다. 선택 여부는 테두리와 체크 표시, 접근성 상태로 함께 전달한다.
struct ColorSwatches: View {
    let selection: GroupColor
    let groupTitle: String
    let onPick: (GroupColor) -> Void

    var body: some View {
        HStack(spacing: 5) {
            ForEach(GroupColor.allCases, id: \.self) { color in
                let isSelected = color == selection
                Button {
                    onPick(color)
                } label: {
                    Circle()
                        .fill(color.color)
                        .frame(width: 16, height: 16)
                        .overlay {
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 8, weight: .heavy))
                                    .foregroundStyle(Theme.onAccent)
                            }
                        }
                        .padding(2)
                        .overlay(Circle().strokeBorder(isSelected ? Color.primary.opacity(0.55) : .clear, lineWidth: 1.5))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help(color.label)
                .accessibilityLabel("\(groupTitle) 그룹 색 \(color.label)")
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
    }
}

/// 끌어다 놓기로 옮기는 대상. 그룹과 항목을 문자열 하나로 구분한다.
enum DragPayload {
    case group(UUID)
    case item(UUID)

    init?(string: String) {
        let parts = string.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, let id = UUID(uuidString: parts[1]) else { return nil }
        switch parts[0] {
        case "group": self = .group(id)
        case "item": self = .item(id)
        default: return nil
        }
    }

    var string: String {
        switch self {
        case .group(let id): return "group:\(id.uuidString)"
        case .item(let id): return "item:\(id.uuidString)"
        }
    }
}
