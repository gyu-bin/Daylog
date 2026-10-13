import SwiftUI
import UniformTypeIdentifiers

struct DataTransferSettingsSection: View {
    @State private var presented = false
    var body: some View {
        Section {
            Button { presented = true } label: {
                Label("가져오기 · 내보내기", systemImage: "square.and.arrow.up.on.square")
            }
        } header: { Text("파일") } footer: {
            Text("CSV·JSON으로 루틴을 가져오거나, 이 기기의 기록을 파일로 보관해요.")
        }
        .sheet(isPresented: $presented) { DataTransferView() }
        #if DEBUG
        .onAppear {
            if DebugScript.presentsTransfer {
                DebugScript.presentsTransfer = false
                presented = true
            }
        }
        #endif
    }
}

struct DataTransferFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText, .plainText] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

/// 가져오기·내보내기 시트. 파일을 고르면 미리보기가 나오고, 저장을 확인하기 전에는 아무것도 바뀌지 않는다.
struct DataTransferView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var importing = false
    @State private var exporting = false
    @State private var confirming = false
    @State private var preview: RoutineImportPreview?
    @State private var selectedName = ""
    @State private var message: Message?
    @State private var exportKind: DataTransferExportKind = .csv
    @State private var document = DataTransferFile(data: Data())

    /// 결과 안내: 성공과 실패를 색과 아이콘으로 구분한다.
    struct Message: Equatable {
        enum Kind { case success, failure }
        let kind: Kind
        let text: String
    }

    var body: some View {
        SheetScaffold(title: "가져오기 · 내보내기", width: 560, cancelTitle: "닫기", cancel: { dismiss() }) {
            VStack(alignment: .leading, spacing: 18) {
                importSection
                if let preview { previewSection(preview) }
                if let message { messageView(message) }
                exportSection
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.commaSeparatedText, .json, .plainText]) { result in
            load(result)
        }
        .fileExporter(isPresented: $exporting, document: document,
                      contentType: exportKind.isJSON ? .json : .commaSeparatedText,
                      defaultFilename: exportKind.filename) { result in
            switch result {
            case .success: message = Message(kind: .success, text: "파일을 저장했어요.")
            case .failure(let error): message = Message(kind: .failure, text: error.localizedDescription)
            }
        }
        .confirmationDialog("새 루틴 \(preview?.createdCount ?? 0)개를 오늘부터 추가할까요?", isPresented: $confirming, titleVisibility: .visible) {
            Button("확인하고 저장") { save() }
            Button("취소", role: .cancel) { }
        } message: { Text("기존 루틴과 지난 기록은 그대로 유지해요. 같은 루틴은 건너뛰어요.") }
        #if DEBUG
        .onAppear {
            // 검증 스크립트(transfer:<경로>)가 준 파일로 미리보기를 만든다. 파일 선택 창을 연 것과 같다.
            if let url = DebugScript.pendingTransferFile {
                DebugScript.pendingTransferFile = nil
                load(.success(url))
            }
        }
        #endif
    }

    // MARK: - 가져오기

    private var importSection: some View {
        SheetField(label: "루틴 가져오기") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Button {
                        importing = true
                    } label: {
                        Label("파일 선택…", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    Button("CSV 양식 저장") { prepareExport(.template) }
                    Spacer(minLength: 0)
                }
                SheetNote(symbol: "doc.text", text: "CSV 또는 루틴 JSON, 5MB·1,000개까지. 열: group, title, weekdays(1;2;3, 월=1), time, note. 파일을 골라도 미리보기에서 확인하기 전에는 바뀌지 않아요.")
            }
        }
    }

    // MARK: - 미리보기

    private func previewSection(_ value: RoutineImportPreview) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "doc.badge.gearshape")
                    .foregroundStyle(Theme.accent)
                    .accessibilityHidden(true)
                Text(selectedName)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 8)
                Button("다시 확인") { refresh(value) }
                    .controlSize(.small)
                    .help("지금 루틴 목록 기준으로 미리보기를 새로 만들어요.")
            }

            HStack(spacing: 6) {
                countBadge("추가 \(value.createdCount)", tint: Theme.accent)
                countBadge("중복 \(value.duplicateCount)", tint: .secondary)
                countBadge("오류 \(value.errorCount)", tint: value.errorCount > 0 ? GroupColor.coral.color : .secondary)
                Text("새 그룹 \(value.newGroupCount) · 기존 그룹 \(value.reusedGroupCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            rows(value.rows)

            HStack {
                Spacer(minLength: 0)
                Button("\(value.createdCount)개 추가…") { confirming = true }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .disabled(!value.canSave)
            }
        }
        .padding(12)
        .background(Theme.inset, in: RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("저장 전 미리보기, 추가 \(value.createdCount)개, 중복 \(value.duplicateCount)개, 오류 \(value.errorCount)개")
    }

    /// 행이 많으면 안에서 스크롤한다. 한 행은 그룹/이름, 요일·시간, 결과.
    private func rows(_ rows: [RoutineImportPreview.Row]) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: rowSymbol(row.action))
                            .font(.caption)
                            .foregroundStyle(rowTint(row.action))
                            .frame(width: 14)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(row.routine.group) / \(row.routine.title)")
                                .font(.callout)
                                .lineLimit(1)
                            Text(Self.scheduleLabel(weekdays: row.routine.weekdays, time: row.routine.time)
                                 + (row.routine.note.isEmpty ? "" : " · \(row.routine.note)"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        Text(row.action.label)
                            .font(.caption)
                            .foregroundStyle(rowTint(row.action))
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 160, alignment: .trailing)
                    }
                    .padding(.vertical, 6)
                    .accessibilityElement(children: .combine)
                    if row.id != rows.last?.id { Divider() }
                }
            }
        }
        .frame(maxHeight: 220)
        .scrollBounceBehavior(.basedOnSize)
    }

    private func countBadge(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(tint.opacity(0.14), in: Capsule())
    }

    private func rowSymbol(_ action: RoutineImportPreview.Action) -> String {
        switch action {
        case .create: return "plus.circle.fill"
        case .duplicate, .conflict: return "equal.circle"
        case .error: return "exclamationmark.circle.fill"
        }
    }

    private func rowTint(_ action: RoutineImportPreview.Action) -> Color {
        switch action {
        case .create: return Theme.accent
        case .duplicate, .conflict: return .secondary
        case .error: return GroupColor.coral.color
        }
    }

    /// 미리보기의 요일·시간 한 줄. 파일의 숫자(1;2;3) 대신 루틴 화면과 같은 말(평일, 월·수·금)로 보여 준다.
    static func scheduleLabel(weekdays: [Int], time: String) -> String {
        "\(Weekdays.summary(weekdays)) · \(time.isEmpty ? "시간 없음" : time)"
    }

    // MARK: - 결과와 내보내기

    private func messageView(_ message: Message) -> some View {
        Label {
            Text(message.text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: message.kind == .success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(message.kind == .success ? Theme.accent : GroupColor.coral.color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            (message.kind == .success ? Theme.accent : GroupColor.coral.color).opacity(0.12),
            in: RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
        )
        .accessibilityIdentifier("transfer-result")
    }

    private var exportSection: some View {
        SheetField(label: "내보내기") {
            VStack(alignment: .leading, spacing: 10) {
                // 다시 가져올 수 있는 것과 보관만 되는 것을 줄을 나눠 둔다(전체 기록은 복원할 수 없다).
                HStack(spacing: 8) {
                    ForEach([DataTransferExportKind.csv, .routines]) { kind in
                        Button(kind.title) { prepareExport(kind) }
                    }
                    Spacer(minLength: 0)
                }
                SheetNote(symbol: "arrow.triangle.2.circlepath", text: "루틴 CSV·JSON은 위의 [파일 선택…]으로 다시 가져올 수 있어요.")
                Button(DataTransferExportKind.backup.title) { prepareExport(.backup) }
                SheetNote(symbol: "lock", text: "현재 버전에서는 전체 기록 복원을 지원하지 않습니다. 체크·식사·휴가까지 담는 보관용 파일이고, 아직 iCloud에서 내려오지 않은 기록은 빠져요. 파일에는 개인 기록이 담깁니다.")
            }
        }
    }

    // MARK: - 동작

    private func load(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= RoutineTransferFormat.maximumBytes else { throw RoutineTransferError.invalid("파일은 5MB 이하만 가져올 수 있어요.") }
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            preview = try store.previewRoutineImport(data, isJSON: url.pathExtension.lowercased() == "json")
            selectedName = url.lastPathComponent
            message = nil
        } catch {
            preview = nil
            message = Message(kind: .failure, text: error.localizedDescription)
        }
    }

    private func refresh(_ previous: RoutineImportPreview) {
        do { preview = try store.refreshRoutineImport(previous) }
        catch { message = Message(kind: .failure, text: error.localizedDescription); preview = nil }
    }

    private func save() {
        guard let confirmed = preview else { return }
        if store.confirmRoutineImport(confirmed) {
            message = Message(kind: .success, text: "루틴 \(confirmed.createdCount)개를 추가했어요. 기존 기록은 유지됩니다.")
            preview = nil
        } else {
            message = Message(kind: .failure, text: store.errorMessage ?? "저장하지 못했어요. 미리보기를 다시 확인해 주세요.")
            refresh(confirmed)
        }
    }

    private func prepareExport(_ kind: DataTransferExportKind) {
        do {
            document = DataTransferFile(data: try store.exportData(kind))
            exportKind = kind
            exporting = true
        } catch { message = Message(kind: .failure, text: error.localizedDescription) }
    }
}
