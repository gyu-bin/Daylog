import Foundation

/// 대시보드 텍스트 카드의 내용 저장. 배치는 `DevicePreferences`, 이 기기에만 두는 꾸미기는 `DashboardDecor`가 맡는다.
extension AppStore {
    /// 텍스트 카드의 내용을 저장한다(새 카드와 수정 모두). 다른 기기에도 전달된다.
    @discardableResult
    func saveDashboardText(id: UUID, title: String, body: String) -> Bool {
        // 휴가와 같다: 적던 내용을 먼저 저장하고, 그 저장이 실패하면 시작하지 않는다.
        flush()
        guard !context.hasChanges else { return false }
        let succeeded = perform {
            try DashboardTextService(context: context, deviceID: deviceID).save(id: id, title: title, body: body)
        }
        reloadStats()
        return succeeded
    }

    /// 텍스트 카드를 지운다. 모든 기기에서 사라진다.
    @discardableResult
    func removeDashboardText(id: UUID) -> Bool {
        flush()
        guard !context.hasChanges else { return false }
        let succeeded = perform {
            try DashboardTextService(context: context, deviceID: deviceID).remove(id: id)
        }
        reloadStats()
        return succeeded
    }
}
