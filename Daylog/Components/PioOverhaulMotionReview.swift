#if DEBUG
import SwiftUI

/// Local visual review only. Selection never changes the equipped outfit or ownership.
struct PioOverhaulMotionReview: View {
    @State private var outfit: PioOutfitID
    @State private var action: PioOverhaulAction = .greet
    @State private var playing = true
    @State private var size = 220
    @State private var dark = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(outfit: PioOutfitID) { _outfit = State(initialValue: outfit) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("피오의 새로운 움직임").font(.title2.bold())
                        Text("의상과 동작을 골라 비교해 보세요.").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("닫기") { dismiss() }
                }
                Picker("의상", selection: $outfit) {
                    ForEach(PioOutfitID.allCases) { Text($0.title).tag($0) }
                }
                .accessibilityIdentifier("pio.motionReview.outfit")
                ZStack {
                    (dark ? Color(red: 0.08, green: 0.12, blue: 0.15) : Color(red: 0.98, green: 0.97, blue: 0.93))
                    PioOverhaulCharacterView(outfit: outfit, action: action, isAnimating: playing)
                        .frame(width: CGFloat(size), height: CGFloat(size))
                }
                .frame(maxWidth: .infinity).frame(height: 290)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .accessibilityLabel("\(outfit.title), \(action.title)")
                HStack {
                    Picker("크기", selection: $size) {
                        Text("64pt").tag(64); Text("120pt").tag(120); Text("220pt").tag(220)
                    }.pickerStyle(.segmented)
                    Button(playing ? "멈추기" : "재생") { playing.toggle() }
                        .accessibilityIdentifier("pio.motionReview.play")
                }
                Toggle("어두운 배경에서 보기", isOn: $dark)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 8)], spacing: 8) {
                    ForEach(PioOverhaulAction.allCases) { item in
                        Button { action = item } label: {
                            Text(item.title).font(.callout)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .padding(.horizontal, 8)
                                .background(action == item ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(action == item ? .isSelected : [])
                        .accessibilityIdentifier("pio.motionReview.\(item.rawValue)")
                    }
                }
                Text("미리보기에서는 선택한 동작이 반복돼요. 여기서 고른 의상은 실제 착용 의상을 바꾸지 않아요.")
                    .font(.caption).foregroundStyle(.secondary)
                if outfit == .christmas || outfit == .pajamas {
                    Text("이 의상은 소품을 두 손으로 잡고 있어요. 소품을 놓지 않고 표정과 몸짓으로 인사해요.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if reduceMotion {
                    Label("동작 줄이기가 켜져 있어 피오가 편안히 쉬고 있어요.", systemImage: "pause.circle")
                        .font(.callout)
                }
            }
            .padding(24)
        }
        .frame(idealWidth: 620, idealHeight: 700)
        .accessibilityIdentifier("pio.motionReview.screen")
    }
}
#endif
