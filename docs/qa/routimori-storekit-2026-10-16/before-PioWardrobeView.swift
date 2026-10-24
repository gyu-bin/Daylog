import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Approved reference art with a DEBUG motion trial; missing part rigs and real purchases remain explicit.
@MainActor
struct PioWardrobeView: View {
    @State private var store: PioWardrobeStore
    @State private var section: WardrobeSection = .browse
    @State private var category = "전체"
    @State private var preview: PioOutfitID?
    @State private var notice: String?
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicType
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(store: PioWardrobeStore? = nil) {
        _store = State(initialValue: store ?? .shared)
    }

    private var palette: WardrobePalette { WardrobePalette(dark: colorScheme == .dark) }
    private var outfits: [PioOutfitID] {
        PioOutfitID.allCases.filter {
            (section != .owned || store.owns($0)) && (category == "전체" || $0.category.title == category)
        }
    }
    private var categories: [String] {
        PioOutfitID.allCases.reduce(into: ["전체"]) { result, outfit in
            if !result.contains(outfit.category.title) { result.append(outfit.category.title) }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                heading
                hero
                Picker("옷장 보기", selection: $section) {
                    ForEach(WardrobeSection.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("wardrobe.section")

                if section == .icons {
                    iconCollection
                } else {
                    outfitCollection
                }
                footer
            }
            .frame(maxWidth: 1000)
            .padding(.horizontal, 22)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)
        }
        .background(palette.background)
        .foregroundStyle(palette.ink)
        .tint(palette.accent)
        .navigationTitle("피오 옷장")
        .accessibilityIdentifier("wardrobe.screen")
        .sheet(item: $preview) { outfit in
            PioOutfitPreviewSheet(outfit: outfit, store: store)
        }
        .alert("피오 옷장", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button("확인", role: .cancel) { notice = nil }
        } message: {
            Text(notice ?? "")
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("ROUTIMORI · WARDROBE", systemImage: "leaf.fill")
                .font(.caption.weight(.semibold))
                .tracking(1.4)
                .foregroundStyle(palette.accent)
            Text("오늘은 어떤 피오와\n함께할까요?")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
            Text("작은 취향을 모아, 나다운 하루를 만들어요.")
                .font(.subheadline)
                .foregroundStyle(palette.secondary)
        }
    }

    private var hero: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 26) {
                heroArt.frame(width: 235)
                heroDescription.frame(minWidth: 200, maxWidth: .infinity, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: 20) {
                heroArt.frame(maxWidth: .infinity)
                heroDescription
            }
        }
        .padding(24)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 30))
        .overlay { RoundedRectangle(cornerRadius: 30).stroke(palette.border, lineWidth: 1) }
    }

    private var heroArt: some View {
        VStack(spacing: 10) {
            PioOutfitMotionView(outfit: store.equippedOutfit, stage: store.previewStage, motion: .idle, isAnimating: true)
                .frame(height: 206)
                .id(store.equippedOutfit)
                .transition(.opacity)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: store.equippedOutfit)
            Text(WardrobeArt.isAvailable(store.equippedOutfit)
                 ? (PioOutfitMotionView.isTrialEnabled ? "의상 원화 · 움직임 미리보기" : "의상 미리보기 원화")
                 : "의상 원화 준비 중")
                .font(.caption)
                .foregroundStyle(palette.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var heroDescription: some View {
        VStack(alignment: .leading, spacing: 13) {
            WardrobeBadge(text: "현재 선택한 의상", symbol: "checkmark.circle.fill", palette: palette)
            Text(store.equippedOutfit.title)
                .font(.system(.title2, design: .rounded, weight: .bold))
            Text(store.equippedOutfit == .basic
                 ? "초록 새싹과 동그란 볼.\n가장 피오다운 모습이에요."
                 : (PioOutfitMotionView.isTrialEnabled
                    ? "선택한 의상으로 가볍게 숨 쉬어요. 날개·소품별 동작과 성장 단계별 모습은 준비 중이에요."
                    : "선택한 의상의 참고 원화예요. 단계별 움직임과 캐릭터 적용은 준비 중이에요."))
                .font(.subheadline)
                .foregroundStyle(palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button { preview = store.equippedOutfit } label: {
                Label("자세히 보기", systemImage: "arrow.up.right")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("wardrobe.current.preview")
            if store.equippedOutfit != .basic {
                Button("기본 피오로 돌아가기") { store.unequip() }
                    .font(.caption.weight(.medium))
                    .buttonStyle(.plain)
                    .foregroundStyle(palette.accent)
                    .accessibilityIdentifier("wardrobe.resetOutfit")
            }
        }
    }

    private var outfitCollection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text(section == .owned ? "내가 모은 취향" : "피오의 다음 계절")
                    .font(.title3.bold())
                Spacer()
                Text("\(outfits.count)가지")
                    .font(.caption)
                    .foregroundStyle(palette.secondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories, id: \.self) { value in
                        Button { category = value } label: {
                            Text(value)
                                .font(.subheadline.weight(category == value ? .semibold : .regular))
                                .padding(.horizontal, 15)
                                .padding(.vertical, 10)
                                .background(category == value ? palette.accent : palette.surface,
                                            in: Capsule())
                                .foregroundStyle(category == value ? palette.onAccent : palette.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(category == value ? .isSelected : [])
                        .accessibilityIdentifier("wardrobe.category.\(value)")
                    }
                }
                .padding(.vertical, 2)
            }
            if outfits.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "hanger").font(.largeTitle).foregroundStyle(palette.accent)
                    Text("이 계절의 옷장은 아직 비어 있어요.").font(.headline)
                    Button("모든 의상 보기") { category = "전체"; section = .browse }
                        .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity).padding(32)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: 24))
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                    ForEach(outfits) { outfit in
                        Button { preview = outfit } label: {
                            outfitCard(outfit)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(outfit.title), \(outfit.category.title), \(stateText(outfit)). 자세히 보기")
                        .accessibilityIdentifier("wardrobe.outfit.\(outfit.rawValue)")
                    }
                }
            }
        }
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: dynamicType.isAccessibilitySize ? 270 : 148, maximum: 300), spacing: 16)]
    }

    private func outfitCard(_ outfit: PioOutfitID) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            ZStack(alignment: .topLeading) {
                WardrobeArt(outfit: outfit, palette: palette)
                    .frame(height: 148)
                    .frame(maxWidth: .infinity)
                    .background(palette.motif(for: outfit), in: RoundedRectangle(cornerRadius: 19))
                if store.equippedOutfit == outfit {
                    Text("선택 중")
                        .font(.caption2.bold())
                        .padding(.horizontal, 9).padding(.vertical, 6)
                        .background(palette.accent, in: Capsule())
                        .foregroundStyle(palette.onAccent)
                        .padding(9)
                }
            }
            Text(outfit.category.title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(palette.secondary)
            Text(outfit.title)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(stateText(outfit))
                .font(.caption.weight(.medium))
                .foregroundStyle(store.owns(outfit) ? palette.accent : palette.secondary)
            Text(WardrobeArt.isAvailable(outfit) ? "의상 미리보기 원화" : "원화 준비 중")
                .font(.caption2)
                .foregroundStyle(palette.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 25))
        .overlay { RoundedRectangle(cornerRadius: 25).stroke(palette.border, lineWidth: 1) }
    }

    private func stateText(_ outfit: PioOutfitID) -> String {
        if outfit == .basic { return "무료 · 항상 보유" }
        if store.owns(outfit) { return "테스트 보유" }
        return outfit.plannedPriceText
    }

    private var iconCollection: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("앱 아이콘 미리보기").font(.title3.bold())
                Text("의상과 별도로 취향을 골라요. 의상 참고 원화로 테마를 미리 보며, 기기의 실제 앱 아이콘은 바뀌지 않아요.")
                    .font(.subheadline).foregroundStyle(palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Label("선택한 테마 · \(store.selectedIcon.title)", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(palette.accent)
            }
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(PioOutfitID.allCases) { outfit in
                    let owned = store.owns(outfit)
                    Button {
                        if !store.selectIcon(outfit) { notice = "보유한 의상의 아이콘 테마만 선택할 수 있어요." }
                    } label: {
                        VStack(spacing: 12) {
                            ZStack(alignment: .bottomTrailing) {
                                WardrobeArt(outfit: outfit, palette: palette)
                                    .frame(width: 100, height: 100)
                                    .background(palette.motif(for: outfit), in: RoundedRectangle(cornerRadius: 25))
                                    .clipShape(RoundedRectangle(cornerRadius: 25))
                                Image(systemName: owned ? (store.selectedIcon == outfit ? "checkmark.circle.fill" : "circle") : "lock.fill")
                                    .font(.headline)
                                    .padding(5)
                                    .background(palette.surface, in: Circle())
                                    .foregroundStyle(palette.accent)
                            }
                            Text(outfit.title).font(.subheadline.weight(.semibold))
                                .fixedSize(horizontal: false, vertical: true)
                            Text(owned ? "미리보기 선택" : "의상 보유 후 선택")
                                .font(.caption2).foregroundStyle(palette.secondary)
                            Text("전용 아이콘 원화 준비 중")
                                .font(.caption2).foregroundStyle(palette.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(16)
                        .background(palette.surface, in: RoundedRectangle(cornerRadius: 24))
                        .overlay {
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(store.selectedIcon == outfit ? palette.accent : palette.border,
                                        lineWidth: store.selectedIcon == outfit ? 2 : 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!owned)
                    .accessibilityLabel("\(outfit.title) 아이콘 테마, \(owned ? "미리보기 가능" : "잠김")")
                    .accessibilityAddTraits(store.selectedIcon == outfit ? .isSelected : [])
                    .accessibilityIdentifier("wardrobe.icon.\(outfit.rawValue)")
                }
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 14) {
            Divider().overlay(palette.border)
            Label("의상 참고 원화 · 성장 1–4단계별 움직임과 적용 준비 중", systemImage: "sparkles")
                .font(.caption).foregroundStyle(palette.secondary)
            Text("가격은 출시 예정 안내이며 App Store에서 확인된 판매가가 아니에요. 실제 결제는 제공하지 않아요.")
                .font(.caption).foregroundStyle(palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("구매 복원 안내") {
                Task {
                    switch await store.restorePurchases() {
                    case .unavailable(let message), .failed(let message): notice = message
                    default: notice = "실제 구매 복원은 출시 준비 중이에요. 현재는 App Store 구매 내역을 조회하지 않아요."
                    }
                }
            }
            .font(.caption.weight(.semibold)).buttonStyle(.plain)
            .accessibilityIdentifier("wardrobe.restore")
            #if DEBUG
            Button("테스트 보유 내역 초기화", role: .destructive) {
                store.resetMockPurchases()
                notice = "이 기기의 테스트 보유 내역을 초기화했어요. 실제 구매 내역에는 영향을 주지 않아요."
            }
            .font(.caption).buttonStyle(.plain)
            .accessibilityIdentifier("wardrobe.resetMockPurchases")
            #endif
        }
        .padding(.bottom, 12)
    }
}

@MainActor
struct PioOutfitPreviewSheet: View {
    let outfit: PioOutfitID
    let store: PioWardrobeStore
    @State private var motion: PioOutfitMotion = .idle
    @State private var message: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var palette: WardrobePalette { WardrobePalette(dark: colorScheme == .dark) }
    private var growthStage: Binding<Int> {
        Binding(get: { store.previewStage }, set: { store.selectPreviewStage($0) })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(spacing: 16) {
                        PioOutfitMotionView(outfit: outfit, stage: store.previewStage, motion: motion, isAnimating: true)
                            .frame(height: 260)
                            .frame(maxWidth: .infinity)
                        Text(WardrobeArt.isAvailable(outfit)
                             ? (PioOutfitMotionView.isTrialEnabled ? "몸 전체 움직임 미리보기 · 부위 동작 준비 중" : "의상 미리보기 원화")
                             : "의상 원화 준비 중")
                            .font(.caption.weight(.medium)).foregroundStyle(palette.secondary)
                    }
                    .padding(22)
                    .background(palette.motif(for: outfit), in: RoundedRectangle(cornerRadius: 30))

                    VStack(alignment: .leading, spacing: 10) {
                        Text(outfit.category.title).font(.caption.weight(.semibold)).foregroundStyle(palette.accent)
                        Text(outfit.title).font(.system(.title, design: .rounded, weight: .bold))
                        Text(outfit.description).font(.body).foregroundStyle(palette.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("성장 단계별 적용 안내").font(.headline)
                        Picker("성장 단계", selection: growthStage) {
                            ForEach(1...4, id: \.self) { Text("\($0)단계").tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("wardrobe.preview.growthStage")
                        Text("\(store.previewStage)단계 전용 부위 원화는 준비 중이에요. 선택한 의상은 유지되며, 지금은 모든 단계에서 같은 의상 원화를 보여 줘요.")
                            .font(.caption).foregroundStyle(palette.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(18)
                    .background(palette.surface, in: RoundedRectangle(cornerRadius: 22))

                    if PioOutfitMotionView.isTrialEnabled {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("움직임 미리보기").font(.headline)
                        Picker("동작", selection: $motion) {
                            ForEach(PioOutfitCapabilities(outfit: outfit).supportedMotions) { action in
                                Text(action.title).tag(action)
                            }
                        }
                        .accessibilityIdentifier("wardrobe.preview.motion")
                        Text(outfit == .basic
                             ? "인사는 기존 기본 피오의 한쪽 날개 분리 마스크를 사용해요. 눈 깜빡임과 걷기·달리기 부위 동작은 준비 중이에요."
                             : "숨 쉬기·통통 뛰기·점프·착지·기쁨·쉬기는 몸 전체 움직임이에요. 눈·날개·소품을 따로 움직이려면 추가 원화가 필요해요.")
                            .font(.caption).foregroundStyle(palette.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if reduceMotion {
                            Text("움직임 줄이기가 켜져 있어 정지한 모습으로 보여 줘요.")
                                .font(.caption).foregroundStyle(palette.secondary)
                        }
                    }
                    .padding(18)
                    .background(palette.surface, in: RoundedRectangle(cornerRadius: 22))

                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text(store.owns(outfit) ? (outfit == .basic ? "무료 · 항상 보유" : "테스트 보유 중") : outfit.plannedPriceText)
                            .font(.headline)
                        if store.owns(outfit) {
                            Button {
                                if store.equip(outfit) { message = PioOutfitMotionView.isTrialEnabled
                                    ? "의상 선택을 저장했어요. 검토용 새싹 피오 화면에 반영돼요. 단계별 전용 부위 원화는 준비 중이에요."
                                    : "의상 선택을 저장했어요. 옷장에서 참고 원화를 볼 수 있어요. 캐릭터 적용은 준비 중이에요." }
                            } label: {
                                Label(store.equippedOutfit == outfit ? "현재 선택한 의상" : "이 의상 선택하기",
                                      systemImage: store.equippedOutfit == outfit ? "checkmark.circle.fill" : "hanger")
                                    .foregroundStyle(palette.onAccent)
                                    .frame(maxWidth: .infinity).padding(.vertical, 7)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(store.equippedOutfit == outfit)
                            .accessibilityIdentifier("wardrobe.preview.equip")
                        } else {
                            #if DEBUG
                            Button {
                                if store.mockPurchase(outfit) { message = "테스트 보유 내역에 추가했어요. 결제는 발생하지 않았고 현재 선택한 의상은 그대로예요." }
                            } label: {
                                Label("테스트 구매 · 결제 없음", systemImage: "flask.fill")
                                    .foregroundStyle(palette.onAccent)
                                    .frame(maxWidth: .infinity).padding(.vertical, 7)
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("wardrobe.preview.mockPurchase")
                            Text("개발용 구매 시뮬레이션이에요. App Store 구매 내역에는 남지 않아요.")
                                .font(.caption).foregroundStyle(palette.secondary)
                            #else
                            Label("출시 준비 중", systemImage: "clock")
                                .font(.headline).frame(maxWidth: .infinity).padding(15)
                                .background(palette.surface, in: RoundedRectangle(cornerRadius: 16))
                            #endif
                        }
                        Text("둘러보기와 단계 선택은 현재 의상을 변경하지 않아요.")
                            .font(.caption).foregroundStyle(palette.secondary)
                        if let message {
                            Text(message).font(.subheadline).foregroundStyle(palette.accent)
                                .accessibilityAddTraits(.updatesFrequently)
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .background(palette.background)
            .foregroundStyle(palette.ink)
            .navigationTitle("의상 미리보기")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                        .accessibilityIdentifier("wardrobe.preview.close")
                }
            }
        }
        .tint(palette.accent)
        #if os(macOS)
        .frame(minWidth: 440, idealWidth: 540, minHeight: 620, idealHeight: 760)
        #endif
    }
}

private enum WardrobeSection: String, CaseIterable, Identifiable {
    case browse = "둘러보기", owned = "내 옷장", icons = "앱 아이콘"
    var id: String { rawValue }
}

private struct WardrobeBadge: View {
    let text: String
    let symbol: String
    let palette: WardrobePalette
    var body: some View {
        Label(text, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 11).padding(.vertical, 7)
            .foregroundStyle(palette.accent)
            .background(palette.accent.opacity(0.1), in: Capsule())
    }
}

@MainActor
private struct WardrobeArt: View {
    /// An asset name describes the intended catalog mapping, not availability.
    /// Keep a real motif fallback for missing/unbundled artwork on both platforms.
    private static func image(for outfit: PioOutfitID) -> Image? {
        guard let name = outfit.artAssetName else { return nil }
        #if os(macOS)
        guard let image = NSImage(named: name) else { return nil }
        return Image(nsImage: image)
        #else
        guard let image = UIImage(named: name) else { return nil }
        return Image(uiImage: image)
        #endif
    }

    static func isAvailable(_ outfit: PioOutfitID) -> Bool { image(for: outfit) != nil }

    let outfit: PioOutfitID
    let palette: WardrobePalette
    var body: some View {
        Group {
            if let artwork = Self.image(for: outfit) {
                artwork.resizable().scaledToFit().padding(8)
            } else {
                ZStack {
                    Circle().fill(palette.surface.opacity(0.58)).frame(width: 100, height: 100)
                    Circle().stroke(palette.accent.opacity(0.09), lineWidth: 1).frame(width: 124, height: 124)
                    Image(systemName: outfit.symbol)
                        .font(.system(size: 42, weight: .light))
                        .foregroundStyle(palette.accent)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

private struct WardrobePalette {
    let dark: Bool
    var background: Color { dark ? Color(red: 0.07, green: 0.12, blue: 0.10) : Color(red: 0.98, green: 0.97, blue: 0.93) }
    var surface: Color { dark ? Color(red: 0.12, green: 0.19, blue: 0.15) : Color(red: 1, green: 0.995, blue: 0.975) }
    var ink: Color { dark ? Color(red: 0.92, green: 0.95, blue: 0.86) : Color(red: 0.18, green: 0.29, blue: 0.20) }
    var secondary: Color { dark ? Color(red: 0.68, green: 0.76, blue: 0.69) : Color(red: 0.43, green: 0.49, blue: 0.42) }
    var accent: Color { dark ? Color(red: 0.68, green: 0.82, blue: 0.58) : Color(red: 0.28, green: 0.43, blue: 0.25) }
    var onAccent: Color { dark ? Color(red: 0.09, green: 0.16, blue: 0.10) : .white }
    var border: Color { ink.opacity(dark ? 0.12 : 0.08) }
    func motif(for outfit: PioOutfitID) -> Color {
        let hue: Double
        switch outfit {
        case .cherryBlossom, .hanbok: hue = 0.94
        case .summerVacation, .rainyDay: hue = 0.52
        case .autumn, .halloween, .cafe: hue = 0.08
        case .winter, .astronaut: hue = 0.62
        case .christmas, .fitness, .basic: hue = 0.28
        case .student: hue = 0.13
        case .pajamas: hue = 0.74
        }
        return Color(hue: hue, saturation: dark ? 0.20 : 0.12, brightness: dark ? 0.22 : 0.96)
    }
}
