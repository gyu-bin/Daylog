import Foundation

extension AppStore {
    func previewRoutineImport(_ data: Data, isJSON: Bool) throws -> RoutineImportPreview {
        try RoutineTransferService(context: context).preview(RoutineTransferFormat.decode(data, isJSON: isJSON), today: today)
    }

    func refreshRoutineImport(_ preview: RoutineImportPreview) throws -> RoutineImportPreview {
        try RoutineTransferService(context: context).preview(preview.source, today: today, policy: preview.policy)
    }

    /// 템플릿을 가져오면 무엇이 추가되고 무엇을 건너뛰는지. 저장소는 건드리지 않는다.
    /// 파일 가져오기와 같은 서비스를 쓰되, 이름이 겹치는 줄은 오류로 세우지 않고 건너뛴다.
    func previewTemplateImport(_ template: RoutineTemplate) throws -> RoutineImportPreview {
        try RoutineTransferService(context: context).preview(template.transferRoutines, today: today, policy: .skipConflicts)
    }

    @discardableResult
    func confirmRoutineImport(_ preview: RoutineImportPreview) -> Bool {
        mutateRoutines { _ in
            // mutateRoutines flushes drafts first. A failed draft save must not be silently folded into this import.
            guard !context.hasChanges else { throw RoutineTransferError.pendingEdits }
            try RoutineTransferService(context: context).commit(preview, today: today)
        }
    }

    /// No flush/save/reconciliation here: exporting and selecting an export destination are read-only.
    func exportData(_ kind: DataTransferExportKind) throws -> Data {
        let service = DataExportService(context: context)
        switch kind {
        case .template: return RoutineTransferFormat.template
        case .csv: return try service.routineCSV()
        case .routines: return try service.routineJSON()
        case .backup: return try service.fullJSON()
        }
    }
}

enum DataTransferExportKind: String, CaseIterable, Identifiable {
    case template, csv, routines, backup
    var id: String { rawValue }
    var title: String {
        switch self {
        case .template: return "CSV 가져오기 양식"
        case .csv: return "활성 루틴 CSV"
        case .routines: return "활성 루틴 JSON"
        case .backup: return "전체 기록 JSON"
        }
    }
    var isJSON: Bool { self == .routines || self == .backup }
    var filename: String {
        switch self {
        case .template: return "daylog-template"
        case .csv: return "daylog-routines"
        case .routines: return "daylog-routines"
        case .backup: return "daylog-backup"
        }
    }
}
