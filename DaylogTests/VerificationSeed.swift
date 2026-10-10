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

        let morning = try routines.addGroup(title: "아침 루틴", colorKey: "orange")
        let work = try routines.addGroup(title: "작업 루틴", colorKey: "blue")
        let workout = try routines.addGroup(title: "운동", colorKey: "mint")
        let evening = try routines.addGroup(title: "저녁 루틴", colorKey: "purple")
        try routines.add(title: "기상 후 물 한 잔", timeLabel: "07:00", group: morning, today: start)
        let stretch = try routines.add(title: "가벼운 스트레칭", timeLabel: "07:10", group: morning, today: start)
        try routines.add(title: "필사 및 묵상", note: "하루 30분", timeLabel: "07:30", group: morning, today: start)
        try routines.add(title: "오전 핵심 작업 집중", timeLabel: "09:00", weekdays: Weekdays.workdays + [6], group: work, today: start)
        try routines.add(title: "오후 작업", timeLabel: "14:00", weekdays: Weekdays.workdays + [6], group: work, today: start)
        try routines.add(title: "근력운동", weekdays: [1, 3, 5], group: workout, today: start)
        try routines.add(title: "러닝", weekdays: [2, 4, 6], group: workout, today: start)
        try routines.add(title: "일기 작성", timeLabel: "21:00", group: evening, today: start)
        try routines.add(title: "내일 할 일 정리", timeLabel: "21:30", group: evening, today: start)

        let lunches = ["현미밥, 계란, 샐러드", "김치찌개와 밥", "닭가슴살 샐러드", "비빔밥", "샌드위치", "된장찌개"]
        let dinners = ["연어구이와 현미밥", "닭가슴살, 계란 2개", "두부 김치", "파스타", "", "소고기 무국"]
        // 완료 개수 패턴. nil은 앱을 열지 않은 날(미기록).
        let pattern: [Int?] = [6, 5, 8, 4, 7, nil, 8, 6, 7, 3, 8, 5, 6, 7, nil, 8, 8, 4, 6, 5, 8]
        for (offset, day) in Day.range(from: start, to: today.adding(days: -1)).enumerated() {
            if offset == 20 {
                try routines.updateGroup(workout, title: "운동 루틴", today: day)
            }
            if offset == 30 {
                try routines.move(stretch, to: workout, today: day)
            }
            guard let done = pattern[offset % pattern.count] else { continue }
            let record = try records.fetchOrCreate(day: day, today: day)
            for check in record.checkList.prefix(done) {
                try records.setDone(check, true)
            }
            if offset % 4 != 3 {
                records.setText(offset % 3 == 0 ? "그릭요거트, 블루베리" : "", at: \.breakfast, of: record)
                records.setText(lunches[offset % lunches.count], at: \.lunch, of: record)
                records.setText(dinners[offset % dinners.count], at: \.dinner, of: record)
                if offset % 5 == 0 { records.setText("바나나", at: \.snack, of: record) }
                if offset % 7 == 0 { records.setText("저녁에 배고픔이 적었음. 물 2L 마심.", at: \.mealMemo, of: record) }
            }
            record.activityAt = day.anchorDate
        }

        let record = try records.fetchOrCreate(day: today, today: today)
        for check in record.checkList where !["필사 및 묵상", "오후 작업"].contains(check.title) {
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
