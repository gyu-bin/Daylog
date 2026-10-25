import Foundation

enum DaylogError: LocalizedError, Equatable {
    case futureDate(String)
    case emptyTitle
    case noWeekdays
    case backupVerificationFailed(String)
    case storeInUse
    case migrationCountMismatch(expected: String, actual: String)
    case cloudEnvironmentMismatch(previous: String, current: String)

    var errorDescription: String? {
        switch self {
        case .futureDate(let key):
            return "미래 날짜(\(key))에는 기록을 만들 수 없어요."
        case .emptyTitle:
            return "루틴 이름을 입력해 주세요."
        case .noWeekdays:
            return "요일을 하나 이상 선택해 주세요. 쉬고 싶다면 루틴을 보관하면 돼요."
        case .storeInUse:
            return "다른 RoutiMori가 이미 이 기록을 열고 있어요. 그 앱을 먼저 종료한 뒤 다시 실행해 주세요."
        case .backupVerificationFailed(let detail):
            return "기록을 백업하지 못해 작업을 중단했어요. 기존 기록은 그대로입니다. (\(detail))"
        case .cloudEnvironmentMismatch(let previous, let current):
            return "이 Mac의 기록은 iCloud의 \(previous) 환경과 동기화하던 것인데, 이 앱은 \(current) 환경을 써요. "
                + "두 환경의 기록이 섞이지 않도록 열지 않았어요. 기록은 그대로입니다. 이전과 같은 방법으로 설치한 RoutiMori로 열어 주세요."
        case .migrationCountMismatch(let expected, let actual):
            return "기록을 새 형식으로 옮긴 뒤 개수가 달라 원래대로 되돌렸어요. 이전: \(expected) / 이후: \(actual)"
        }
    }
}
