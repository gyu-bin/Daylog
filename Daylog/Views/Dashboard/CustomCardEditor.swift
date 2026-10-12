import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// 꾸미기 편집 시트가 다루는 대상.
enum CustomCardEditorTarget: Identifiable {
    case new(CustomCardKind)
    case edit(DashboardCard)
    case header

    var id: String {
        switch self {
        case .new(let kind): return "new:\(kind.rawValue)"
        case .edit(let card): return "edit:\(card.rawValue)"
        case .header: return "header"
        }
    }
}

/// 꾸미기 카드 추가·수정과 상단 배경 사진. 내용에 따라 사진·글·크기를 고르고, 수정할 때는 삭제도 할 수 있다.
struct CustomCardEditorSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(DevicePreferences.self) private var preferences
    @Environment(DashboardDecor.self) private var decor
    @Environment(\.dismiss) private var dismiss
    let target: CustomCardEditorTarget

    @State private var title = ""
    @State private var text = ""
    @State private var size = CustomCardSize.regular
    /// 새로 고른 사진(줄여 둔 사본). 저장을 눌러야 적용된다.
    @State private var picked: ProcessedDashboardImage?
    @State private var removesImage = false
    @State private var error: String?
    @State private var confirmsDelete = false
    @State private var isLoaded = false

    private var kind: CustomCardKind? {
        switch target {
        case .new(let kind): return kind
        case .edit(let card): return card.customKind
        case .header: return nil
        }
    }

    private var existing: DashboardCard? {
        if case .edit(let card) = target { return card }
        return nil
    }

    private var sheetTitle: String {
        switch target {
        case .new(let kind): return "\(kind.title) 추가"
        case .edit(let card): return "\(card.title) 편집"
        case .header: return "상단 배경 이미지"
        }
    }

    private var subtitle: String {
        switch kind {
        case .image: return "사진은 줄인 사본으로 \(Platform.thisDevice)에만 저장돼요. 원본 사진은 바뀌지 않아요."
        case .text: return "목표·다짐·메모를 적어요. 내용은 같은 iCloud 계정의 기기에도 전달돼요."
        case .sectionTitle: return "카드 사이에 제목을 넣어 영역을 나눠요."
        case .divider: return "카드 사이에 선을 넣어 영역을 나눠요."
        case nil: return "날짜와 인사말 뒤에 낮게 깔려요. \(Platform.thisDevice)에만 저장돼요."
        }
    }

    /// 지금 저장돼 있는 사진(새로 고른 것이 없을 때의 미리보기).
    private var storedImage: CGImage? {
        guard !removesImage else { return nil }
        if case .header = target { return decor.headerImage }
        return existing?.customID.flatMap(decor.image(for:))
    }

    private var previewImage: CGImage? { picked?.cgImage ?? storedImage }

    private var canSave: Bool {
        switch kind {
        // 새 카드는 사진을 골라야 하고, 있던 카드는 사진을 뺀 채로도 저장할 수 있다(다시 고르라는 안내가 보인다).
        case .image: return previewImage != nil || existing != nil
        case .text: return !DashboardText.cleaned(title: title, body: text).isEmpty
        case .sectionTitle: return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .divider: return true
        case nil: return picked != nil || (removesImage && decor.headerImageFile != nil)
        }
    }

    var body: some View {
        SheetScaffold(
            title: sheetTitle, subtitle: subtitle, width: 460, cancel: { dismiss() },
            primary: SheetAction(title: "저장", isDisabled: !canSave, action: save)
        ) {
            if existing != nil {
                Button("카드 삭제", role: .destructive) { confirmsDelete = true }
            }
        } content: {
            VStack(alignment: .leading, spacing: 16) {
                if kind == .image || kind == nil {
                    DashboardImagePickField(
                        preview: previewImage,
                        previewHeight: kind == nil ? 84 : size.imageHeight(compact: false),
                        caption: kind == .image ? title : "",
                        size: size,
                        canRemove: previewImage != nil,
                        onPick: { picked = $0; removesImage = false; error = nil },
                        onRemove: { picked = nil; removesImage = true },
                        onError: { error = $0 }
                    )
                }
                if kind == .image {
                    SheetField(label: "사진 위 문구 (선택)") {
                        TextField("문구", text: $title, prompt: Text("예: 오늘도 한 걸음"))
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("사진 위 문구, 선택 사항")
                    }
                }
                if kind == .text {
                    SheetField(label: "제목 (선택)") {
                        TextField("제목", text: $title, prompt: Text("예: 이번 달 목표"))
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("제목, 선택 사항")
                    }
                    SheetField(label: "내용") {
                        TextField("내용", text: $text, prompt: Text("목표, 다짐, 메모를 적어 보세요"), axis: .vertical)
                            .lineLimit(3...8)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("내용")
                        Text("\(text.count) / \(DashboardText.bodyLimit)자")
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(text.count > DashboardText.bodyLimit ? AnyShapeStyle(.orange) : AnyShapeStyle(.tertiary))
                    }
                }
                if kind == .sectionTitle {
                    SheetField(label: "제목") {
                        TextField("제목", text: $title, prompt: Text("예: 아침"))
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("섹션 제목")
                    }
                }
                if kind != nil {
                    SheetField(label: kind == .divider ? "위아래 여백" : "크기") {
                        Picker("크기", selection: $size) {
                            ForEach(CustomCardSize.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .accessibilityLabel("카드 크기")
                    }
                }
                if let error {
                    Label(error, systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .onAppear(perform: load)
        .alert("이 카드를 삭제할까요?", isPresented: $confirmsDelete) {
            Button("삭제", role: .destructive, action: delete)
            Button("취소", role: .cancel) {}
        } message: {
            Text(kind == .text ? "적어 둔 내용이 다른 기기에서도 지워져요. 루틴·식사 기록은 그대로예요."
                : "이 카드만 지워져요. 루틴·식사 기록은 그대로예요.")
        }
    }

    private func load() {
        guard !isLoaded else { return }
        isLoaded = true
        guard let card = existing, let id = card.customID else { return }
        let entry = decor.entry(id)
        size = entry.size
        if card.customKind == .text {
            title = store.dashboardTexts[id]?.title ?? ""
            text = store.dashboardTexts[id]?.body ?? ""
        } else {
            title = entry.title
        }
    }

    private func save() {
        do {
            if case .header = target {
                if let picked { try decor.setHeaderImage(picked) } else if removesImage { decor.removeHeaderImage() }
                dismiss()
                return
            }
            guard let kind else { return }
            let id = existing?.customID ?? UUID()
            if kind == .text, !store.saveDashboardText(id: id, title: title, body: text) {
                error = store.errorMessage ?? "저장하지 못했어요."
                return
            }
            if kind == .image {
                if let picked { try decor.setImage(picked, for: id) } else if removesImage { decor.removeImage(for: id) }
            }
            if kind == .image || kind == .sectionTitle { decor.setTitle(title, for: id) }
            decor.setSize(size, for: id)
            if existing == nil { preferences.addCustom(.custom(kind, id)) }
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func delete() {
        guard let card = existing, let id = card.customID else { return }
        if card.customKind == .text, !store.removeDashboardText(id: id) {
            error = store.errorMessage ?? "삭제하지 못했어요."
            return
        }
        preferences.removeCustom(card)
        decor.remove(id)
        dismiss()
    }
}

/// 사진 미리보기와 고르기 단추. 사진 보관함은 시스템 선택 창(PhotosPicker)을 써서 보관함 접근 권한을 묻지 않는다.
struct DashboardImagePickField: View {
    let preview: CGImage?
    let previewHeight: CGFloat
    var caption = ""
    var size: CustomCardSize = .regular
    let canRemove: Bool
    let onPick: (ProcessedDashboardImage) -> Void
    let onRemove: () -> Void
    let onError: (String) -> Void

    @State private var photoItem: PhotosPickerItem?
    @State private var importsFile = false
    @State private var isWorking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let preview {
                DashboardImageSurface(image: preview, height: min(previewHeight, 180), caption: caption, size: size)
            } else {
                let shape = RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                Label("사진을 골라 주세요", systemImage: "photo")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 84)
                    .background(Theme.inset, in: shape)
                    .overlay(shape.strokeBorder(Theme.cardBorder, style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
            }
            FlowLayout(spacing: 8) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("사진 보관함", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.bordered)
                Button {
                    importsFile = true
                } label: {
                    Label("파일에서 고르기", systemImage: "folder")
                }
                .buttonStyle(.bordered)
                if canRemove {
                    Button("사진 제거", role: .destructive, action: onRemove)
                        .buttonStyle(.bordered)
                }
                if isWorking { ProgressView().controlSize(.small) }
            }
            .controlSize(.small)
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            isWorking = true
            Task {
                // 선택 창이 넘겨준 사본을 읽는다. 보관함의 원본은 건드리지 않는다.
                let data = try? await item.loadTransferable(type: Data.self)
                await handle(data)
                photoItem = nil
            }
        }
        .fileImporter(isPresented: $importsFile, allowedContentTypes: [.image]) { result in
            guard case .success(let url) = result else { return }
            isWorking = true
            Task {
                let isScoped = url.startAccessingSecurityScopedResource()
                let data = try? Data(contentsOf: url, options: .mappedIfSafe)
                if isScoped { url.stopAccessingSecurityScopedResource() }
                await handle(data)
            }
        }
    }

    /// 줄이기는 화면을 멈추지 않게 뒤에서 한다.
    private func handle(_ data: Data?) async {
        defer { isWorking = false }
        guard let data else {
            onError(DashboardImageError.unreadable.localizedDescription)
            return
        }
        let result = await Task.detached(priority: .userInitiated) {
            Result { try DashboardImageStore.process(data) }
        }.value
        switch result {
        case .success(let image): onPick(image)
        case .failure(let failure): onError(failure.localizedDescription)
        }
    }
}
