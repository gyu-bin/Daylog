import Foundation

extension AppStore {
    /// 이 기기의 정보를 iCloud 기기 목록에 적는다(처음, 내용이 바뀌었을 때, 6시간마다). 로컬 전용 저장소에서도 적어 둔다.
    func touchDevice() {
        // 단위 테스트의 저장소에는 기기 줄을 만들지 않는다(실제 앱만 켠다).
        guard tracksDevice else { return }
        perform {
            let service = DeviceService(context: context, deviceID: deviceID)
            if try service.touch(name: Platform.deviceName, kind: Platform.deviceKind, appVersion: Platform.appVersion) {
                try context.save()
            }
            let updated = try service.devices()
            if updated != devices { devices = updated }
        }
    }

    /// 다른 기기를 목록에서 지운다.
    func removeDevice(_ device: DeviceInfo) {
        guard device.id != deviceID else { return }
        perform {
            let service = DeviceService(context: context, deviceID: deviceID)
            try service.remove(device.id)
            try context.save()
            devices = try service.devices()
        }
    }
}
