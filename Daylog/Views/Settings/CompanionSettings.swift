import SwiftUI

/// 루틴 알림 설정. 이 기기에만 저장되고 다른 기기와 동기화하지 않는다.
struct NotificationSettingsSection: View {
    @Environment(AppStore.self) private var store
    @Environment(RoutineNotifications.self) private var notifications
    @State private var showsRoutines = false

    /// 알림이 울릴 수 있는 루틴: 사용 중이고 예정 시간이 시각으로 적힌 것.
    private var timedRoutines: [RoutineItem] {
        store.activeRoutines.filter { TimeLabel.minutes($0.timeLabel) != nil }
    }

    var body: some View {
        Section {
            Toggle("루틴 알림", isOn: Binding(
                get: { notifications.isEnabled },
                set: { enabled in
                    Task {
                        // 켜는 순간에만 시스템 권한을 묻는다(앱을 처음 열 때는 묻지 않는다).
                        await notifications.setEnabled(enabled)
                        AppRuntime.shared?.scheduleRefresh()
                    }
                }
            ))
            LabeledContent("\(Platform.thisDevice)의 알림 권한", value: notifications.permission.title)

            if notifications.isEnabled, notifications.permission == .denied {
                Label("시스템 설정에서 Daylog의 알림을 허용해야 울려요.", systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
            if notifications.permission != .notDetermined, notifications.permission != .unknown {
                Button("알림 설정 열기") {
                    Platform.openNotificationSettings()
                }
            }

            if notifications.isActive {
                LabeledContent("예약된 알림", value: "\(notifications.scheduledCount)개")
                if let last = notifications.lastScheduledDate {
                    LabeledContent("마지막 예약 시각") {
                        Text(last, format: .dateTime.year().month().day().hour().minute())
                    }
                }
                if notifications.schedulingFailedCount > 0 {
                    Label("\(notifications.schedulingFailedCount)개 알림을 예약하지 못했어요. 앱을 다시 열면 재시도해요.", systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
            }
            if notifications.isEnabled {
                DisclosureGroup("루틴별 알림", isExpanded: $showsRoutines) {
                    if timedRoutines.isEmpty {
                        Text("예정 시간이 있는 루틴이 없어요. 루틴 편집에서 시간을 정하면 여기에 나타나요.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(timedRoutines) { routine in
                        Toggle(isOn: Binding(
                            get: { !notifications.isMuted(routine.id) },
                            set: {
                                notifications.setMuted(routine.id, !$0)
                                AppRuntime.shared?.scheduleRefresh()
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(routine.title)
                                    .lineLimit(1)
                                Text("\(Weekdays.summary(routine.weekdays)) · \(routine.timeLabel)")
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityLabel("\(routine.title) 알림, \(Weekdays.summary(routine.weekdays)) \(routine.timeLabel)")
                    }
                }
            }
        } header: {
            Text("알림")
        } footer: {
            Text("예정 시간이 있는 루틴을 그 시간에 알려요. 완료한 루틴과 휴가 날짜는 건너뛰고, 알림의 [완료]로 바로 체크돼요. 오래 앱을 열지 않으면 멈출 수 있어요.")
        }
        .task {
            await notifications.refreshPermission()
        }
    }
}

#if os(macOS)
/// 메뉴 막대 아이콘 표시. 이 Mac에만 저장된다.
struct MenuBarSettingsSection: View {
    @AppStorage(MenuBarSettings.key) private var showsMenuBar = true

    var body: some View {
        Section {
            Toggle("메뉴 막대에 Daylog 표시", isOn: $showsMenuBar)
        } header: {
            Text("메뉴 막대")
        } footer: {
            Text("아이콘을 누르면 창을 열지 않고 오늘의 루틴을 체크해요. 켜 두면 창을 닫아도 Daylog가 메뉴 막대에 남아요.")
        }
    }
}
#else
/// 홈 화면 위젯 안내. 위젯은 사용자가 홈 화면에서 직접 추가한다.
struct WidgetGuideSection: View {
    var body: some View {
        Section {
            Label("홈 화면의 빈 곳을 길게 눌러요.", systemImage: "1.circle")
            Label("왼쪽 위의 편집(또는 +)을 누르고 위젯 추가를 골라요.", systemImage: "2.circle")
            Label("Daylog를 찾아 크기를 고르고 추가해요.", systemImage: "3.circle")
        } header: {
            Text("위젯")
        } footer: {
            Text("큰 위젯에서는 루틴을 눌러 바로 체크해요. 저장 대기 표시가 남으면 Daylog를 열어 주세요. 위젯은 시스템이 정한 때에 갱신돼 조금 늦게 바뀔 수 있어요.")
        }
    }
}
#endif

/// 새싹이 복귀 알림 설정. 루틴 알림과 따로 켜고 끄며, 이 기기에만 저장된다(기본은 꺼짐).
struct ComebackSettingsSection: View {
    @Environment(ComebackNotifications.self) private var comeback

    private var time: Binding<Date> {
        Binding(
            get: { Calendar.current.date(bySettingHour: comeback.minutes / 60, minute: comeback.minutes % 60, second: 0, of: .now) ?? .now },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                comeback.setMinutes((parts.hour ?? 19) * 60 + (parts.minute ?? 0))
                AppRuntime.shared?.scheduleRefresh()
            }
        )
    }

    var body: some View {
        Section {
            Toggle(isOn: Binding(
                get: { comeback.isEnabled },
                set: { enabled in
                    Task {
                        // 켜는 순간에만 시스템 권한을 묻는다(루틴 알림과 같은 흐름). 끄면 예약된 복귀 알림을 모두 지운다.
                        await comeback.setEnabled(enabled)
                        AppRuntime.shared?.scheduleRefresh()
                    }
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("새싹이 복귀 알림")
                    Text("며칠 동안 루틴을 쉬면 새싹이가 알려드려요.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if comeback.isEnabled {
                DatePicker("알림 시각", selection: time, displayedComponents: .hourAndMinute)
                if comeback.permission == .denied {
                    Label("시스템 설정에서 Daylog의 알림을 허용해야 울려요.", systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .foregroundStyle(.orange)
                } else if comeback.isWaitingForSync {
                    Label("iCloud 기록을 받아 온 뒤에 예약해요.", systemImage: "icloud")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else if let next = comeback.scheduled.first,
                          let date = Calendar.current.date(from: next.dateComponents) {
                    LabeledContent("다음 알림") {
                        Text("\(date.formatted(.dateTime.month().day().hour().minute())) · \(next.stage.rawValue)일째")
                            .monospacedDigit()
                    }
                } else if comeback.isActive {
                    Text("지금은 예약된 복귀 알림이 없어요.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        } footer: {
            Text("마지막으로 루틴을 완료한 날부터 3·7·14·30일째에 한 번씩 알려요. 휴가 중이거나 루틴이 없는 날에는 보내지 않고, 다시 완료하면 처음부터 새로 세요. 이 설정은 \(Platform.thisDevice)에만 적용돼요. 여러 기기를 쓴다면 알림을 받을 기기 하나에서만 켜 두세요. 다른 기기에서 완료한 기록은 이 기기가 iCloud에서 받아 온 뒤에 반영돼요.")
        }
        .task {
            await comeback.refreshPermission()
        }
    }
}
