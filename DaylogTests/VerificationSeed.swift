import Foundation
import SwiftData
import Testing
@testable import Daylog

/// 화면 검증용 저장소를 만드는 도구. 평소 테스트 실행에서는 건너뛴다.
///
/// 실제 서비스 코드로 며칠치 사용을 흉내 내어 `verify.store`를 만든다. 앱 코드에는 예시 데이터가 없고,
/// 사용자의 실제 저장소(`Daylog.store`)는 건드리지 않는다.
///
///     TEST_RUNNER_DAYLOG_SEED=2026-10-10 xcodebuild -project Daylog.xcodeproj -scheme Daylog \
///         -derivedDataPath build test -only-testing:DaylogTests/VerificationSeed
///     open -n build/Build/Products/Debug/Daylog.app --args -DaylogStoreName verify
@MainActor
struct VerificationSeed {
    private nonisolated static let seedDay = ProcessInfo.processInfo.environment["DAYLOG_SEED"].flatMap(Day.init(key:))

    @Test(.enabled(if: VerificationSeed.seedDay != nil))
    func seedVerifyStore() throws {
        let today = try #require(Self.seedDay)
        let url = try DaylogStore.storeURL(name: "verify")
        for suffix in ["", "-shm", "-wal"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + suffix))
        }

        let container = try DaylogStore.makeContainer(.file(url))
        let context = container.mainContext
        let routines = RoutineService(context: context)
        let records = DayRecordService(context: context)
        let start = today.adding(days: -45)

        try routines.add(title: "현관 출발", note: "기상 후 바로 나가기", timeLabel: "07:00", today: start)
        let run = try routines.add(title: "운동", note: "러닝 30분", timeLabel: "07:30", today: start)
        try routines.add(title: "필사 · 묵상", note: "하루 30분", timeLabel: "08:00", today: start)
        try routines.add(title: "오전 블록", note: "집중할 일 1개", today: start)
        try routines.add(title: "오후 블록", note: "가벼운 일", today: start)
        let words = try routines.add(title: "영어 단어", weekdays: Weekdays.workdays, today: start)
        try routines.add(title: "주간 회고", weekdays: [7], today: start)

        // 완료 개수 패턴. nil은 앱을 열지 않은 날(미기록).
        let pattern: [Int?] = [5, 4, 6, 3, 5, nil, 6, 5, 5, 2, 6, 4, 5, 5, nil, 6, 6, 3, 5, 4, 6]
        for (offset, day) in Day.range(from: start, to: today.adding(days: -1)).enumerated() {
            if offset == 25 {
                try routines.update(run, title: "운동 (러닝)", today: day)
            }
            if offset == 35 {
                try routines.setArchived(words, true, today: day)
            }
            guard let done = pattern[offset % pattern.count] else { continue }
            let record = try records.fetchOrCreate(day: day, today: day)
            for check in record.checkList.sorted(by: { $0.order < $1.order }).prefix(done) {
                try records.setDone(check, true)
            }
            if offset % 3 == 0 {
                records.setText("현미밥, 계란, 샐러드", at: \.lunch, of: record)
            }
            record.activityAt = day.anchorDate
        }

        let record = try records.fetchOrCreate(day: today, today: today)
        for check in record.checkList.sorted(by: { $0.order < $1.order }).prefix(4) {
            try records.setDone(check, true)
        }
        records.setText("그릭요거트, 블루베리, 그래놀라", at: \.breakfast, of: record)
        records.setText("일반식 (김치찌개, 밥, 반찬)\n닭가슴살 추가", at: \.lunch, of: record)
        records.setText("계란 2개, 닭가슴살, 샐러드", at: \.dinner, of: record)
        records.setText("바나나, 프로틴 쉐이크", at: \.snack, of: record)
        records.setText("저녁에 배고픔이 적었음.\n물 2L 마심.", at: \.mealMemo, of: record)
        records.setText("앱 기획서 초안 정리하기", at: \.tomorrowTask, of: record)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<DayRecord>()) > 30)
    }
}
