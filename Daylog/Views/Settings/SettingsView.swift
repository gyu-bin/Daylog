import SwiftUI

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(CloudSyncMonitor.self) private var sync

    var body: some View {
        Form {
            Section {
                ThresholdControl()
            } header: {
                Text("달성한 날 기준값")
            } footer: {
                Text("하루 달성률이 이 값 이상이면 달성한 날로 세요. 바꾸면 연속 달성일과 최장 연속 달성일이 바로 다시 계산됩니다.")
            }

            Section {
                LabeledContent("상태", value: sync.account.title)
                if sync.isEnabled {
                    if let lastImportAt = sync.lastImportAt {
                        LabeledContent("이 Mac이 마지막으로 변경을 가져온 시각", value: Self.timestamp(lastImportAt))
                    }
                    if let lastExportAt = sync.lastExportAt {
                        LabeledContent("이 Mac이 마지막으로 변경을 보낸 시각", value: Self.timestamp(lastExportAt))
                    }
                    if let error = sync.lastErrorMessage {
                        Label("최근 동기화 오류: \(error)", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                    ForEach(store.syncNotices, id: \.self) { notice in
                        Label(notice, systemImage: "arrow.triangle.merge")
                    }
                    Button("상태 새로고침") {
                        sync.refreshAccountStatus()
                    }
                }
            } header: {
                Text("iCloud 동기화")
            } footer: {
                Text(sync.isEnabled
                     ? "같은 Apple 계정의 Mac끼리 자동으로 동기화돼요. iCloud는 변경을 즉시 반영한다고 보장하지 않습니다. 위 시각은 시스템이 알려 준 값이며, 모든 기록이 다른 Mac에 도착했다는 뜻은 아니에요. 새로고침은 계정 상태만 다시 확인합니다."
                     : "iCloud 권한이 있는 빌드로 실행하면 같은 Apple 계정의 Mac끼리 자동으로 동기화돼요.")
            }

            Section("데이터") {
                Label(sync.isEnabled ? "기록은 이 Mac에 저장되고, 내 iCloud 개인 데이터베이스로 동기화됩니다."
                                     : "기록은 이 Mac에만 저장됩니다.",
                      systemImage: "internaldrive")
                if sync.isEnabled {
                    Label("인터넷이 없어도 그대로 쓸 수 있고, 연결되면 이어서 동기화돼요.", systemImage: "wifi.slash")
                }
                Label("별도 계정·자체 서버를 쓰지 않고, 사용 정보도 수집하지 않아요.", systemImage: "lock.shield")
            }

            Section("앱 정보") {
                LabeledContent("이름", value: "Daylog")
                LabeledContent("버전", value: Self.version)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private static func timestamp(_ date: Date) -> String {
        date.formatted(.dateTime.month().day().hour().minute().second().locale(Locale(identifier: "ko_KR")))
    }

    private static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }
}

/// 달성 기준값(50~100%). 설정과 루틴 관리 화면이 같이 쓴다.
struct ThresholdControl: View {
    @Environment(AppStore.self) private var store

    private var range: ClosedRange<Int> { SettingsService.thresholdRange }

    var body: some View {
        HStack(spacing: 12) {
            Slider(
                value: Binding(
                    get: { Double(store.threshold) },
                    set: { store.setThreshold(Int($0.rounded())) }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: 5
            ) {
                Text("기준값")
            } minimumValueLabel: {
                Text("\(range.lowerBound)%").font(.caption).foregroundStyle(.secondary)
            } maximumValueLabel: {
                Text("\(range.upperBound)%").font(.caption).foregroundStyle(.secondary)
            }
            .labelsHidden()
            .accessibilityLabel("달성한 날 기준값")
            .accessibilityValue("\(store.threshold)%")

            Stepper(
                value: Binding(
                    get: { store.threshold },
                    set: { store.setThreshold($0) }
                ),
                in: range
            ) {
                Text("\(store.threshold)%")
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .frame(width: 48, alignment: .trailing)
            }
            .accessibilityLabel("달성한 날 기준값")
        }
    }
}
