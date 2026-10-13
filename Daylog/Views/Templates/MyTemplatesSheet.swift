import SwiftUI

/// 내가 올린 템플릿: 상태를 보고, 고치고, 공개·비공개를 바꾸고, 지운다. 로그인과 차단 목록도 여기서 관리한다.
struct MyTemplatesSheet: View {
    @Environment(CommunityStore.self) private var community
    @Environment(\.dismiss) private var dismiss
    @State private var editing: CommunityTemplate?
    @State private var deleting: CommunityTemplate?
    @State private var error: String?
    @State private var isWorking = false

    var body: some View {
        SheetScaffold(
            title: "내 템플릿",
            subtitle: "올려 둔 템플릿은 게시한 때의 사본이에요. 내 루틴을 바꿔도 저절로 바뀌지 않아요.",
            width: 540, cancelTitle: "닫기", cancel: { dismiss() }
        ) {
            EmptyView()
        } content: {
            SheetScrollArea(maxHeight: 520) {
                VStack(alignment: .leading, spacing: 14) {
                    CommunityAccountSection(showsManagement: true)
                    if community.isSignedIn {
                        if community.myTemplates.isEmpty {
                            EmptyHint(symbol: "rectangle.stack", message: "아직 올린 템플릿이 없어요.")
                        }
                        ForEach(community.myTemplates) { template in
                            row(template)
                        }
                        blockedSection
                    }
                    if let error {
                        Label(error, systemImage: "exclamationmark.circle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if isWorking { ProgressView().controlSize(.small) }
                }
            }
        }
        .sheet(item: $editing) { TemplatePublishSheet(editing: $0) }
        .alert("이 템플릿을 삭제할까요?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("삭제", role: .destructive) {
                if let target = deleting { run { try await community.delete(target) } }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("목록에서 사라져요. 다른 사람이 이미 가져간 루틴과 내 루틴은 그대로예요.")
        }
    }

    private func row(_ template: CommunityTemplate) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                TemplateThumbnailView(thumbnail: template.thumbnail, size: 40)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(template.title).font(.callout.weight(.semibold)).lineLimit(1)
                        StatusBadge(text: template.statusLabel, tint: Self.statusTint(template))
                    }
                    Text("\(template.category.title) · 루틴 \(template.template.routineCount)개")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    if let note = Self.statusNote(template) {
                        Text(note).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            FlowLayout(spacing: 6) {
                Button("수정") { editing = template }
                    .accessibilityLabel("\(template.title) 수정")
                Button(template.visibility == .public ? "비공개로 전환" : "공개로 전환") {
                    run { try await community.setVisibility(template.visibility == .public ? .private : .public, for: template) }
                }
                .accessibilityLabel("\(template.title) \(template.visibility == .public ? "비공개로 전환" : "공개로 전환")")
                Button("삭제", role: .destructive) { deleting = template }
                    .accessibilityLabel("\(template.title) 삭제")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.inset, in: RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
    }

    @ViewBuilder
    private var blockedSection: some View {
        if !community.blockedAuthors.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("차단한 게시자 \(community.blockedAuthors.count)명")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                ForEach(community.blockedAuthors.sorted { $0.uuidString < $1.uuidString }, id: \.self) { author in
                    HStack {
                        Text("게시자 \(author.uuidString.prefix(8))").font(.caption).monospaced()
                        Spacer(minLength: 8)
                        Button("차단 해제") { run { try await community.unblock(author) } }
                            .controlSize(.small)
                    }
                }
            }
        }
    }

    static func statusTint(_ template: CommunityTemplate) -> Color {
        switch template.moderation {
        case .removed: return GroupColor.coral.ink
        case .underReview: return GroupColor.orange.ink
        case .active: return template.visibility == .public ? GroupColor.mint.ink : .secondary
        }
    }

    static func statusNote(_ template: CommunityTemplate) -> String? {
        switch template.moderation {
        case .underReview: return "신고가 접수되어 검토 중이에요. 검토가 끝날 때까지 다른 사람에게 보이지 않아요."
        case .removed: return "운영 정책에 따라 게시가 중단됐어요. 다른 사람에게 보이지 않아요."
        case .active: return nil
        }
    }

    private func run(_ work: @escaping () async throws -> Void) {
        isWorking = true
        error = nil
        Task {
            do { try await work() } catch { self.error = CommunityStore.message(error) }
            isWorking = false
        }
    }
}

/// 템플릿 신고: 사유를 고르고, 필요하면 한 줄 적는다. 한 템플릿은 한 번만 신고할 수 있다.
struct TemplateReportSheet: View {
    @Environment(CommunityStore.self) private var community
    @Environment(\.dismiss) private var dismiss
    let template: CommunityTemplate

    @State private var reason = ReportReason.spam
    @State private var detail = ""
    @State private var error: String?
    @State private var isWorking = false
    @State private var isDone = false

    var body: some View {
        SheetScaffold(
            title: "템플릿 신고", subtitle: "\"\(template.title)\"을(를) 신고해요. 누가 신고했는지는 게시자에게 보이지 않아요.",
            width: 440, cancelTitle: isDone ? "닫기" : "취소", cancel: { dismiss() },
            primary: isDone ? nil : SheetAction(title: "신고", isDisabled: !community.isSignedIn || isWorking, action: submit)
        ) {
            EmptyView()
        } content: {
            VStack(alignment: .leading, spacing: 14) {
                if isDone {
                    Label("신고를 접수했어요. 운영자가 확인할게요.", systemImage: "checkmark.circle.fill")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(Theme.accent)
                } else {
                    if !community.isSignedIn { CommunityAccountSection() }
                    SheetField(label: "사유") {
                        Picker("사유", selection: $reason) {
                            ForEach(ReportReason.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                        .accessibilityLabel("신고 사유")
                    }
                    SheetField(label: "설명 (선택)") {
                        TextField("설명", text: $detail, prompt: Text("어떤 점이 문제인지 적어 주세요"), axis: .vertical)
                            .lineLimit(2...4)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("신고 설명, 선택 사항")
                    }
                }
                if let error {
                    Label(error, systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if isWorking { ProgressView().controlSize(.small) }
            }
        }
    }

    private func submit() {
        isWorking = true
        error = nil
        Task {
            do {
                try await community.report(template, reason: reason, detail: detail)
                isDone = true
            } catch {
                self.error = CommunityStore.message(error)
            }
            isWorking = false
        }
    }
}
