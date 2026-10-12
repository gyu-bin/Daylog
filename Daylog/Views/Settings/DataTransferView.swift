import SwiftUI
import UniformTypeIdentifiers

struct DataTransferSettingsSection: View {
    @State private var presented = false
    var body: some View {
        Section {
            Button { presented = true } label: {
                Label("가져오기 · 내보내기", systemImage: "square.and.arrow.up.on.square")
            }
        } header: { Text("파일로 데이터 이동") } footer: {
            Text("CSV·JSON으로 루틴을 추가하거나, 현재 이 기기의 기록을 파일로 보관할 수 있어요.")
        }
        .sheet(isPresented: $presented) { DataTransferView() }
    }
}

struct DataTransferFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText, .plainText] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct DataTransferView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var importing = false
    @State private var exporting = false
    @State private var confirming = false
    @State private var preview: RoutineImportPreview?
    @State private var selectedName = ""
    @State private var message: String?
    @State private var exportKind: DataTransferExportKind = .csv
    @State private var document = DataTransferFile(data: Data())

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button("CSV 또는 루틴 JSON 선택", systemImage: "square.and.arrow.down") { importing = true }
                    Button("CSV 양식 저장", systemImage: "doc.badge.plus") { prepareExport(.template) }
                    Text("최대 5MB · 1,000개 루틴. 파일을 선택해도 미리보기에서 저장을 확인하기 전에는 바뀌지 않아요.")
                        .font(.caption).foregroundStyle(.secondary)
                } header: { Text("루틴 가져오기") } footer: {
                    Text("CSV 열: group,title,weekdays,time,note\n요일은 1;2;3처럼 작성해요(월=1, 일=7). 시간은 12자 이내의 자유 문구도 가능하며, 알림은 읽을 수 있는 시각(예: 08:00)만 지원해요. 앞뒤 공백이나 잘못된 시각을 자동으로 고치지 않아요.")
                }
                if let preview { previewSection(preview) }
                if let message {
                    Section { Text(message).font(.callout).accessibilityIdentifier("transfer-result") }
                }
                Section {
                    ForEach([DataTransferExportKind.csv, .routines, .backup]) { kind in
                        Button(kind.title, systemImage: "square.and.arrow.up") { prepareExport(kind) }
                    }
                } header: { Text("내보내기") } footer: {
                    Text("활성 루틴 CSV·JSON은 다시 가져올 수 있어요. 전체 기록 JSON은 보관·삭제된 항목, 체크·식사·휴가와 동기화 이력까지 포함하며 이번 버전에서는 복원할 수 없어요. 아직 iCloud에서 내려오지 않은 기록은 포함하지 않아요. 파일에는 개인 기록이 담깁니다.")
                }
            }
            .formStyle(.grouped)
            .sheetTitle("가져오기 · 내보내기")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } } }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.commaSeparatedText, .json, .plainText]) { result in
                load(result)
            }
            .fileExporter(isPresented: $exporting, document: document,
                          contentType: exportKind.isJSON ? .json : .commaSeparatedText,
                          defaultFilename: exportKind.filename) { result in
                switch result {
                case .success: message = "파일을 저장했어요."
                case .failure(let error): message = error.localizedDescription
                }
            }
            .confirmationDialog("새 루틴 \(preview?.createdCount ?? 0)개를 오늘부터 추가할까요?", isPresented: $confirming, titleVisibility: .visible) {
                Button("확인하고 저장") { save() }
                Button("취소", role: .cancel) { }
            } message: { Text("기존 루틴과 지난 기록은 그대로 유지해요. 같은 루틴은 건너뛰어요.") }
        }
        #if os(macOS)
        // 미리보기가 없을 때는 내용이 짧아, 높이를 내용에 가깝게 둔다(미리보기가 생기면 폼이 스크롤된다).
        .frame(minWidth: 540, idealWidth: 600, minHeight: 440, idealHeight: preview == nil ? 500 : 640)
        #endif
    }

    private func previewSection(_ value: RoutineImportPreview) -> some View {
        Section {
            Text(selectedName).font(.headline)
            Text("추가 \(value.createdCount) · 중복 \(value.duplicateCount) · 오류 \(value.errorCount)")
            Text("새 그룹 \(value.newGroupCount) · 재사용 그룹 \(value.reusedGroupCount)").font(.caption).foregroundStyle(.secondary)
            ForEach(value.rows) { row in
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(row.id). \(row.routine.group) / \(row.routine.title)").font(.callout.weight(.medium))
                    Text(Self.scheduleLabel(weekdays: row.routine.weekdays, time: row.routine.time))
                        .font(.caption).foregroundStyle(.secondary)
                    if !row.routine.note.isEmpty { Text(row.routine.note).font(.caption).lineLimit(3) }
                    Text(row.action.label).font(.caption).foregroundStyle(isError(row.action) ? Color.red : Color.secondary)
                }
                .accessibilityElement(children: .combine)
            }
            Button("미리보기 새로 확인") { refresh(value) }
            Button("\(value.createdCount)개 추가…") { confirming = true }
                .disabled(!value.canSave)
        } header: { Text("저장 전 미리보기") }
    }

    /// 미리보기의 요일·시간 한 줄. 파일의 숫자(1;2;3) 대신 루틴 화면과 같은 말(평일, 월·수·금)로 보여 준다.
    static func scheduleLabel(weekdays: [Int], time: String) -> String {
        "\(Weekdays.summary(weekdays)) · \(time.isEmpty ? "시간 없음" : time)"
    }

    private func isError(_ action: RoutineImportPreview.Action) -> Bool {
        if case .error = action { return true }; return false
    }

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
            message = error.localizedDescription
        }
    }

    private func refresh(_ previous: RoutineImportPreview) {
        do { preview = try store.refreshRoutineImport(previous) }
        catch { message = error.localizedDescription; preview = nil }
    }

    private func save() {
        guard let confirmed = preview else { return }
        if store.confirmRoutineImport(confirmed) {
            message = "루틴 \(confirmed.createdCount)개를 추가했어요. 기존 기록은 유지됩니다."
            preview = nil
        } else {
            message = store.errorMessage ?? "저장하지 못했어요. 미리보기를 다시 확인해 주세요."
            refresh(confirmed)
        }
    }

    private func prepareExport(_ kind: DataTransferExportKind) {
        do {
            document = DataTransferFile(data: try store.exportData(kind))
            exportKind = kind
            exporting = true
        } catch { message = error.localizedDescription }
    }
}
