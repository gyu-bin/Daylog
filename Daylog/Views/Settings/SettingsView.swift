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

    /// 위에서 아래로: 보이는 것(외관·오늘 화면) → 루틴 규칙(기준값·휴가·알림) → 이 기기(메뉴 막대·위젯) → 데이터(파일·iCloud) → 앱 정보.
    private var form: some View {
        Form {
            AppearanceSection()
            DevicePreferenceSections()

            Section {
                ThresholdControl()
            } header: {
                Text("달성한 날 기준값")
            } footer: {
                Text("하루 달성률이 이 값 이상이면 달성한 날로 세요. 연속 달성일도 이 기준으로 바로 다시 계산돼요.")
            }

            CalendarSettingsSection()
            VacationSettingsSection()
            NotificationSettingsSection()
            #if os(macOS)
            MenuBarSettingsSection()
            #else
            WidgetGuideSection()
            #endif

            DataTransferSettingsSection()
            cloudSection

            Section {
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
                OnboardingReplayButton()
            } header: {
                Text("앱 정보")
            } footer: {
                Text("별도 계정이나 자체 서버를 쓰지 않고, 사용 정보도 수집하지 않아요.")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    /// iCloud 상태와 저장 위치. 오류와 안내는 한 줄씩.
    private var cloudSection: some View {
        Section {
            LabeledContent("상태", value: sync.account.title)
            if sync.isEnabled {
                if let environment = sync.environmentTitle {
                    LabeledContent("iCloud 환경", value: environment)
                }
                if let lastImportAt = sync.lastImportAt {
                    LabeledContent("마지막으로 가져온 시각", value: Self.timestamp(lastImportAt))
                }
                if let lastExportAt = sync.lastExportAt {
                    LabeledContent("마지막으로 보낸 시각", value: Self.timestamp(lastExportAt))
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
                 ? "기록은 \(Platform.thisDevice)에 저장되고 내 iCloud 개인 데이터베이스로 동기화돼요. 인터넷이 없어도 쓸 수 있고, 연결되면 이어서 맞춰요. 위 시각은 시스템이 알려 준 값이라 모든 기록이 다른 기기에 도착했다는 뜻은 아니에요."
                 : "기록은 \(Platform.thisDevice)에만 저장돼요. iCloud 권한이 있는 빌드로 실행하면 같은 Apple 계정의 기기끼리 동기화돼요.")
        }
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
            #if os(macOS)
            .pickerStyle(.radioGroup)
            .onChange(of: mode) { _, newValue in
                newValue.apply()
            }
            #else
            // iOS·iPadOS는 화면 뿌리가 같은 설정값을 읽어 바로 바꾼다.
            .pickerStyle(.segmented)
            #endif
        } header: {
            Text("외관")
        } footer: {
            Text("라이트·다크를 고르면 Daylog만 그 모드로 보여요. \(Platform.thisDevice)에만 적용돼요.")
        }
    }
}

/// 달력의 한 주 시작 요일. 이 기기에만 저장하고, 고르는 즉시 모든 달력에 적용된다.
private struct CalendarSettingsSection: View {
    @Environment(DevicePreferences.self) private var preferences

    var body: some View {
        Section {
            Picker("한 주의 시작", selection: Binding(
                get: { preferences.weekStart },
                set: { preferences.setWeekStart($0) }
            )) {
                ForEach(WeekStart.allCases) { start in
                    Text(start.title).tag(start)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("캘린더")
        } footer: {
            Text("월간 캘린더, 휴가 달력, 활동 히트맵의 요일 순서가 바뀌어요. 통계의 집계 기간은 바뀌지 않아요. \(Platform.thisDevice)에만 적용돼요.")
        }
    }
}

/// 달성 기준값(50~100%). 설정과 루틴 관리 화면이 같이 쓴다.
struct ThresholdControl: View {
    @Environment(AppStore.self) private var store
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var range: ClosedRange<Int> { SettingsService.thresholdRange }

    var body: some View {
        // 좁은 화면(iPhone, 좁은 iPad 창)에서는 슬라이더가 눌리지 않게 값과 단추를 아래 줄로 내린다.
        if horizontalSizeClass == .compact {
            VStack(alignment: .leading, spacing: 10) {
                slider
                stepper
            }
        } else {
            HStack(spacing: 12) {
                slider
                stepper
            }
        }
    }

    private var slider: some View {
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
    }

    /// 값과 올림·내림 단추. 폼 안의 스테퍼는 레이블을 달면 줄 전체로 늘어나므로, 값은 따로 그리고 스테퍼는 단추만 둔다.
    private var stepper: some View {
        HStack(spacing: 8) {
            Text("\(store.threshold)%")
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .frame(width: 48, alignment: .trailing)
                .accessibilityHidden(true)
            Stepper(
                "달성한 날 기준값",
                value: Binding(
                    get: { store.threshold },
                    set: { store.setThreshold($0) }
                ),
                in: range
            )
            .labelsHidden()
            .accessibilityValue("\(store.threshold)%")
        }
        .fixedSize()
    }
}
