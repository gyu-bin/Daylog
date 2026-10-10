import SwiftUI

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(CloudSyncMonitor.self) private var sync

    var body: some View {
        // 폼을 창 너비 전체에 두고 내용만 가운데 640pt로 모은다.
        // 폼 자체를 좁히면 제목 표시줄 아래의 스크롤 가장자리 효과가 폼 너비만큼만 생겨 띠처럼 보인다(다크 모드에서 두드러진다).
        GeometryReader { proxy in
            form
                .contentMargins(.horizontal, max(20, (proxy.size.width - 640) / 2), for: .scrollContent)
        }
    }

    private var form: some View {
        Form {
            AppearanceSection()

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
                HStack(spacing: 12) {
                    BrandIcon(size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Daylog")
                            .font(.headline)
                        Text("버전 \(Self.version)")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 2)
                .accessibilityElement(children: .combine)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
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

/// 외관(시스템 설정/라이트/다크). 고르는 즉시 앱 전체에 적용되고, 이 Mac에만 저장된다.
private struct AppearanceSection: View {
    @AppStorage(AppearanceMode.storageKey) private var mode: AppearanceMode = .system

    var body: some View {
        Section {
            Picker("테마", selection: $mode) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.radioGroup)
            .onChange(of: mode) { _, newValue in
                newValue.apply()
            }
        } header: {
            Text("외관")
        } footer: {
            Text("\"시스템 설정\"은 Mac의 외관 설정을 따라요. 라이트·다크를 고르면 Daylog만 그 모드로 보여요. 이 Mac에만 적용되고 다른 Mac과 동기화하지 않아요.")
        }
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
