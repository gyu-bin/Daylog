import Foundation

/// 저장소 파일 하나를 한 번에 한 프로세스만 열게 한다.
///
/// 서로 다른 버전의 앱(예: 실행 중인 예전 버전과 새로 띄운 새 버전)이 같은 저장소를 동시에 열면,
/// 한쪽이 형식을 옮긴 뒤 다른 쪽이 예전 형식으로 써서 기록이 깨질 수 있다.
/// 잠금은 프로세스가 끝나면(비정상 종료 포함) 운영체제가 풀어 준다.
enum StoreLock {
    /// 이 프로세스가 잡고 있는 잠금. 같은 프로세스 안에서는 같은 저장소를 여러 번 열 수 있다(테스트, 2단계 열기).
    private static var held: [String: Int32] = [:]
    private static let guardQueue = DispatchQueue(label: "daylog.store-lock")

    static func acquire(for storeURL: URL) throws {
        let path = storeURL.path + ".lock"
        try guardQueue.sync {
            guard held[path] == nil else { return }
            let descriptor = open(path, O_CREAT | O_RDWR, 0o644)
            guard descriptor >= 0 else { throw DaylogError.storeInUse }
            guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
                close(descriptor)
                throw DaylogError.storeInUse
            }
            held[path] = descriptor
        }
    }

    /// 테스트에서 "다른 프로세스가 놓았다"를 흉내 낼 때만 쓴다.
    static func release(for storeURL: URL) {
        let path = storeURL.path + ".lock"
        guardQueue.sync {
            guard let descriptor = held.removeValue(forKey: path) else { return }
            flock(descriptor, LOCK_UN)
            close(descriptor)
        }
    }
}
