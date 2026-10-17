import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Browsing is local preview state. Only the explicit wear action changes Pio.
@MainActor
struct PioWardrobeView: View {
    @State private var store: PioWardrobeStore
    @State private var appearanceCoordinator: PioAppearanceCoordinator
    @State private var section: WardrobeSection = .browse
    @State private var category = "전체"
    @State private var selectedOutfit: PioOutfitID
    @State private var previewStage: Int
    @State private var motion: PioOutfitMotion = .idle
    @State private var notice: String?
    @State private var actionMessage: String?
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicType
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(store: PioWardrobeStore? = nil) {
        let wardrobe = store ?? .shared
        _store = State(initialValue: wardrobe)
        _appearanceCoordinator = State(initialValue: wardrobe === PioWardrobeStore.shared
            ? .shared : PioAppearanceCoordinator(wardrobe: wardrobe))
        _selectedOutfit = State(initialValue: wardrobe.equippedOutfit)
        _previewStage = State(initialValue: wardrobe.previewStage)
    }

    private var palette: WardrobePalette { WardrobePalette(dark: colorScheme == .dark) }
    private var previewAppearance: PioResolvedAppearance {
        appearanceCoordinator.preview(outfit: selectedOutfit, stage: previewStage, motion: motion)
    }
    private var outfits: [PioOutfitID] {
        PioOutfitID.allCases.filter {
            (section != .owned || store.availableOutfits.contains($0)) &&
            (category == "전체" || $0.category.title == category)
        }
    }
    private var categories: [String] {
        PioOutfitID.allCases.reduce(into: ["전체"]) { result, outfit in
            if !result.contains(outfit.category.title) { result.append(outfit.category.title) }
        }
    }
    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: dynamicType.isAccessibilitySize ? 230 : 142, maximum: 240), spacing: 12)]
    }

    var body: some View {
        GeometryReader { geometry in
            let isWide = geometry.size.width >= 760 && !dynamicType.isAccessibilitySize
            Group {
                if isWide {
                    HStack(spacing: 0) {
                        catalogPane
                            .frame(width: geometry.size.width / 2)
                        Divider().overlay(palette.border)
                        ScrollView {
                            previewPanel(artHeight: min(350, max(240, geometry.size.height * 0.42)))
                                .padding(28)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(palette.surface)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            previewPanel(artHeight: 240)
                                .padding(20)
                                .background(palette.surface)
                            Divider()
                            catalogContents
                                .padding(20)
                        }
                    }
                }
            }
        }
        .background(palette.background)
        .foregroundStyle(palette.ink)
        .tint(palette.accent)
        .navigationTitle("피오 옷장")
        .accessibilityIdentifier("wardrobe.screen")
        .task { if !RuntimeEnvironment.isRunningTests { await store.start() } }
        .onChange(of: selectedOutfit) { _, outfit in
            actionMessage = nil
            if !PioOutfitCapabilities(outfit: outfit).supportedMotions.contains(motion) { motion = .idle }
        }
        .alert("피오 옷장", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button("확인", role: .cancel) { notice = nil }
        } message: { Text(notice ?? "") }
    }

    private var catalogPane: some View {
        ScrollView {
            catalogContents.padding(24)
        }
        .accessibilityIdentifier("wardrobe.catalog")
    }

    private var catalogContents: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("피오의 옷장")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    Text("마음에 드는 의상을 골라 입혀 보세요.")
                        .font(.subheadline).foregroundStyle(palette.secondary)
                }
                Spacer(minLength: 8)
                Text("\(PioOutfitID.allCases.count)가지")
                    .font(.caption.weight(.medium)).foregroundStyle(palette.secondary)
            }
            if store.isOutfitTestingEnabled {
                Label("테스트 중 · 모든 의상 사용 가능", systemImage: "testtube.2")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.accent)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(palette.accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
                    .accessibilityIdentifier("wardrobe.testingBanner")
            }
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
            if !store.isOutfitTestingEnabled {
                purchaseStatus
                footer
            }
        }
    }

    private var outfitCollection: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(categories, id: \.self) { value in
                        Button { category = value } label: {
                            Text(value)
                                .font(.caption.weight(category == value ? .semibold : .regular))
                                .padding(.horizontal, 13).padding(.vertical, 10)
                                .background(category == value ? palette.accent : palette.surface, in: Capsule())
                                .foregroundStyle(category == value ? palette.onAccent : palette.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(category == value ? .isSelected : [])
                        .accessibilityIdentifier("wardrobe.category.\(value)")
                    }
                }.padding(.vertical, 2)
            }
            if outfits.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "hanger").font(.largeTitle).foregroundStyle(palette.accent)
                    Text("아직 이 의상이 없어요.").font(.headline)
                    Button("모든 의상 보기") { category = "전체"; section = .browse }
                        .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity).padding(32)
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                    ForEach(outfits) { outfit in
                        Button { selectedOutfit = outfit } label: { outfitCard(outfit) }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(outfit.title), \(stateText(outfit)). 미리보기 선택")
                            .accessibilityValue(selectedOutfit == outfit ? "미리보기 선택됨" : "")
                            .accessibilityRemoveTraits(selectedOutfit == outfit ? [] : .isSelected)
                            .accessibilityAddTraits(selectedOutfit == outfit ? .isSelected : [])
                            .accessibilityIdentifier("wardrobe.outfit.\(outfit.rawValue)")
                    }
                }
            }
        }
    }

    private func outfitCard(_ outfit: PioOutfitID) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .topTrailing) {
                WardrobeArt(outfit: outfit, palette: palette)
                    .frame(height: 132)
                    .frame(maxWidth: .infinity)
                    .background(palette.motif(for: outfit), in: RoundedRectangle(cornerRadius: 17))
                if store.equippedOutfit == outfit {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.headline).foregroundStyle(palette.accent)
                        .padding(7).background(palette.surface, in: Circle()).padding(6)
                }
            }
            Text(outfit.title)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(palette.ink).fixedSize(horizontal: false, vertical: true)
            Text(stateText(outfit))
                .font(.caption2).foregroundStyle(palette.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 23))
        .overlay {
            RoundedRectangle(cornerRadius: 23)
                .stroke(selectedOutfit == outfit ? palette.accent : palette.border,
                        lineWidth: selectedOutfit == outfit ? 2 : 1)
        }
    }

    private func stateText(_ outfit: PioOutfitID) -> String {
        if store.equippedOutfit == outfit { return "지금 입고 있어요" }
        if store.isOutfitTestingEnabled { return "테스트로 입혀 보기" }
        if outfit == .basic { return "무료 · 항상 보유" }
        if store.owns(outfit) { return "보유 중" }
        if let product = store.purchases.product(for: outfit) { return product.displayPrice }
        if store.purchases.productLoadState == .loading { return "상품 확인 중" }
        return "현재 구매 불가"
    }

    private func previewPanel(artHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Label("미리보기", systemImage: "sparkles")
                    .font(.headline)
                Spacer()
                if store.equippedOutfit == selectedOutfit {
                    WardrobeBadge(text: "입고 있어요", symbol: "checkmark.circle.fill", palette: palette)
                }
            }
            ZStack {
                RoundedRectangle(cornerRadius: 32)
                    .fill(palette.motif(for: selectedOutfit))
                PioAppearanceView(appearance: previewAppearance)
                    .padding(18)
                    .id(selectedOutfit)
            }
            .frame(height: artHeight)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("wardrobe.livePreview")
            VStack(alignment: .leading, spacing: 7) {
                Text(selectedOutfit.category.title)
                    .font(.caption.weight(.semibold)).foregroundStyle(palette.accent)
                Text(selectedOutfit.title)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text(selectedOutfit.description)
                    .font(.subheadline).foregroundStyle(palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // 피오는 레벨과 상관없이 한 가지 모습이라 성장 단계 고르기는 두지 않는다.
            if PioOutfitMotionView.isTrialEnabled {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("움직임").font(.subheadline.weight(.semibold))
                        Spacer()
                        Picker("움직임", selection: $motion) {
                            ForEach(PioOutfitCapabilities(outfit: selectedOutfit).supportedMotions) { action in
                                Text(action.title).tag(action)
                            }
                        }
                        .labelsHidden()
                        .accessibilityIdentifier("wardrobe.preview.motion")
                    }
                    if reduceMotion {
                        Text("움직임 줄이기 설정에 따라 정지한 모습으로 보여요.")
                            .font(.caption).foregroundStyle(palette.secondary)
                    }
                }
            }
            previewActions
            Text("의상을 고르면 미리보기만 바뀌어요. ‘입히기’를 누르면 홈에도 적용돼요.")
                .font(.caption).foregroundStyle(palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let actionMessage {
                Label(actionMessage, systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.medium)).foregroundStyle(palette.accent)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("wardrobe.preview.purchaseMessage")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("wardrobe.previewPanel")
    }

    @ViewBuilder private var previewActions: some View {
        if store.canWear(selectedOutfit) {
            Button {
                if store.equip(selectedOutfit) { actionMessage = "입혔어요. 홈에서도 이 피오와 함께해요." }
            } label: {
                Label(store.equippedOutfit == selectedOutfit ? "지금 입고 있어요" : "입히기",
                      systemImage: store.equippedOutfit == selectedOutfit ? "checkmark.circle.fill" : "hanger")
                    .font(.headline)
                    .foregroundStyle(palette.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(palette.accent, in: RoundedRectangle(cornerRadius: 16))
                    .opacity(store.equippedOutfit == selectedOutfit || !WardrobeArt.isAvailable(selectedOutfit) ? 0.55 : 1)
            }
            .buttonStyle(.plain)
            .disabled(store.equippedOutfit == selectedOutfit || !WardrobeArt.isAvailable(selectedOutfit))
            .accessibilityIdentifier("wardrobe.preview.equip")
        } else {
            Button {
                Task { actionMessage = (await store.purchase(selectedOutfit)).wardrobeMessage }
            } label: {
                Group {
                    if case .purchasing(let outfit) = store.purchases.purchaseState, outfit == selectedOutfit {
                        ProgressView("구매 진행 중").tint(palette.onAccent)
                    } else {
                        Text(store.purchases.product(for: selectedOutfit).map { "\($0.displayPrice)에 구매하기" } ?? "현재 구매 불가")
                    }
                }
                .foregroundStyle(palette.onAccent)
                .frame(maxWidth: .infinity).padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.purchases.isBusy || !store.purchases.availability.isEnabled || store.purchases.product(for: selectedOutfit) == nil)
            .accessibilityIdentifier("wardrobe.preview.purchase")
        }
    }

    @ViewBuilder private var purchaseStatus: some View {
        if let message = store.purchases.availability.message {
            Label(message, systemImage: "info.circle")
                .font(.subheadline).foregroundStyle(palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Label("Apple 로컬 구매 테스트 · 실제 청구 없음", systemImage: "testtube.2")
                    .font(.caption).foregroundStyle(palette.secondary)
                switch store.purchases.productLoadState {
                case .idle, .loading:
                    ProgressView("의상 정보를 불러오는 중이에요")
                case .failed(let message):
                    Text(message).font(.subheadline)
                    retryProducts
                case .unavailable:
                    Text("일부 의상의 상품 정보를 확인하지 못했어요. 미리보기는 이용할 수 있어요.").font(.subheadline)
                    retryProducts
                case .available: EmptyView()
                }
                if case .failed(let message) = store.purchases.entitlementState {
                    Text(message).font(.subheadline)
                    Button("구매 내역 다시 확인") { Task { await store.refreshEntitlements() } }
                        .disabled(store.purchases.isBusy)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var retryProducts: some View {
        Button("상품 정보 다시 불러오기") { Task { await store.purchases.loadProducts() } }
            .buttonStyle(.bordered)
            .disabled(store.purchases.isBusy || store.purchases.productLoadState == .loading)
            .accessibilityIdentifier("wardrobe.retryProducts")
    }

    private var iconCollection: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("앱 아이콘 미리보기").font(.title3.bold())
                Text("구매한 의상의 아이콘도 추가 결제 없이 사용할 수 있어요. 현재 전용 아이콘 파일은 준비 중이며, 아래 이미지는 테마 미리보기예요.")
                    .font(.subheadline).foregroundStyle(palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Label("선택한 테마 · \(store.selectedIcon.title)", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(palette.accent)
            }
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(PioOutfitID.allCases) { outfit in
                    let owned = store.owns(outfit)
                    Button {
                        Task { notice = await PioAppIconService.select(outfit, store: store) }
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
                            Text(owned ? "의상 보유 중" : "의상 구매 시 함께 제공")
                                .font(.caption2).foregroundStyle(palette.secondary)
                            Text(PioAppIconService.isAvailable(outfit) ? "기본 앱 아이콘" : "아이콘 변경 준비 중")
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
                    .disabled(!PioAppIconService.canSelect(outfit, store: store))
                    .accessibilityLabel("\(outfit.title) 아이콘 테마, \(owned ? "보유 중, 아이콘 변경 준비 중" : "잠김")")
                    .accessibilityAddTraits(store.selectedIcon == outfit ? .isSelected : [])
                    .accessibilityIdentifier("wardrobe.icon.\(outfit.rawValue)")
                }
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 14) {
            Divider().overlay(palette.border)
            Text("의상은 한 번 구매하면 계속 사용할 수 있어요. 아이콘은 준비되는 대로 별도 구매 없이 함께 제공돼요.")
                .font(.caption).foregroundStyle(palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                Task { notice = (await store.restorePurchases()).wardrobeMessage }
            } label: {
                if case .restoring = store.purchases.purchaseState {
                    ProgressView("구매 내역 복원 중")
                } else { Label("구매 복원", systemImage: "arrow.clockwise") }
            }
            .buttonStyle(.bordered)
            .disabled(store.purchases.isBusy || !store.purchases.availability.isEnabled)
            .accessibilityIdentifier("wardrobe.restore")
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(spacing: 16) {
                        PioAppearanceView(appearance: PioAppearanceCoordinator.shared.preview(
                            outfit: outfit, stage: store.previewStage, motion: motion))
                            .frame(height: 260)
                            .frame(maxWidth: .infinity)
                        Text(WardrobeArt.isAvailable(outfit)
                             ? "피오의 새로운 모습"
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

                    if PioOutfitMotionView.isTrialEnabled {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("움직임 미리보기").font(.headline)
                        Picker("동작", selection: $motion) {
                            ForEach(PioOutfitCapabilities(outfit: outfit).supportedMotions) { action in
                                Text(action.title).tag(action)
                            }
                        }
                        .accessibilityIdentifier("wardrobe.preview.motion")
                        Text("가볍게 숨 쉬고, 작은 기쁨을 함께 나누는 피오예요.")
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

                    purchaseControls

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
        .task { if !RuntimeEnvironment.isRunningTests { await store.start() } }
        #if os(macOS)
        .frame(minWidth: 440, idealWidth: 540, minHeight: 620, idealHeight: 760)
        #endif
    }
    private var purchaseControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            if store.canWear(outfit) {
                Text(store.isOutfitTestingEnabled ? "테스트 중 · 바로 입혀 보기" : (outfit == .basic ? "무료 · 항상 보유" : "보유 중")).font(.headline)
                Button {
                    if store.equip(outfit) { message = "피오에게 입혔어요. 홈에서도 함께할 거예요." }
                } label: {
                    Label(store.equippedOutfit == outfit ? "지금 입고 있어요" : "피오에게 입히기",
                          systemImage: store.equippedOutfit == outfit ? "checkmark.circle.fill" : "hanger")
                        .foregroundStyle(palette.onAccent)
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.equippedOutfit == outfit)
                .accessibilityIdentifier("wardrobe.preview.equip")
            } else {
                if let product = store.purchases.product(for: outfit) {
                    Text(product.displayPrice).font(.title2.bold())
                    Text("한 번 구매 · 구독 없음").font(.caption).foregroundStyle(palette.secondary)
                }
                Button {
                    message = nil
                    Task { message = (await store.purchase(outfit)).wardrobeMessage }
                } label: {
                    if case .purchasing(let selected) = store.purchases.purchaseState, selected == outfit {
                        ProgressView("구매 진행 중")
                            .tint(palette.onAccent)
                            .foregroundStyle(palette.onAccent)
                            .frame(maxWidth: .infinity).padding(.vertical, 9)
                    } else {
                        Text(store.purchases.product(for: outfit).map { "\($0.displayPrice)에 구매하기" } ?? "현재 구매 불가")
                            .foregroundStyle(palette.onAccent)
                            .frame(maxWidth: .infinity).padding(.vertical, 9)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.purchases.isBusy || !store.purchases.availability.isEnabled || store.purchases.product(for: outfit) == nil)
                .accessibilityIdentifier("wardrobe.preview.purchase")
                if let unavailable = store.purchases.availability.message {
                    Text(unavailable).font(.caption).foregroundStyle(palette.secondary)
                } else if store.purchases.product(for: outfit) == nil {
                    Text("상품 정보를 확인하지 못했어요. 잠시 후 다시 시도해 주세요.")
                        .font(.caption).foregroundStyle(palette.secondary)
                    Button("상품 정보 다시 불러오기") { Task { await store.purchases.loadProducts() } }
                        .disabled(store.purchases.isBusy || store.purchases.productLoadState == .loading)
                } else {
                    Text("Apple 로컬 구매 테스트 · 실제 청구 없음")
                        .font(.caption).foregroundStyle(palette.secondary)
                }
            }
            Text("미리보기만으로 의상이 구매되거나 바뀌지 않아요.")
                .font(.caption).foregroundStyle(palette.secondary)
            if let message {
                Text(message).font(.subheadline).foregroundStyle(palette.accent)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("wardrobe.preview.purchaseMessage")
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
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
