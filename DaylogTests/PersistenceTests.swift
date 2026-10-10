import Foundation
import SwiftData
import Testing
@testable import Daylog

/// 17-10. 저장. 디스크의 임시 저장소를 닫았다가 새 컨테이너로 다시 열어 앱 재실행을 흉내 낸다.
@MainActor
struct PersistenceTests {
    private let directory: URL
    private var storeURL: URL { directory.appendingPathComponent("Daylog.store") }

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DaylogTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func cleanUp() {
        try? FileManager.default.removeItem(at: directory)
    }

    private func launch(today: Day) throws -> (ModelContainer, AppStore) {
        let container = try DaylogStore.makeContainer(.file(storeURL))
        let store = AppStore(container: container, clock: { today })
        store.start()
        return (container, store)
    }

    @Test func checkStateSurvivesRelaunch() throws {
        defer { cleanUp() }
        do {
            let (_, store) = try launch(today: saturday)
            store.addRoutine(title: "운동")
            store.addRoutine(title: "독서")
            store.setDone(routineID: try #require(store.checks.first?.routineID), true)
        }

        let (_, store) = try launch(today: saturday)
        #expect(store.checks.map(\.title) == ["운동", "독서"])
        #expect(store.checks.map(\.isDone) == [true, false])
        #expect(store.stats.today == DayOutcome(day: saturday, status: .recorded, done: 1, total: 2))
        #expect(store.record?.isRecorded == true)
    }

    @Test func mealTextSurvivesRelaunch() throws {
        defer { cleanUp() }
        do {
            let (_, store) = try launch(today: saturday)
            store.setText("그릭요거트, 블루베리", at: \.breakfast)
            store.setText("일반식", at: \.lunch)
            store.setText("계란 2개", at: \.dinner)
            store.setText("바나나", at: \.snack)
            store.setText("저녁에 배고픔이 적었음.\n물 2L 마심.", at: \.mealMemo)
            store.setText("앱 기획서 초안 정리하기", at: \.tomorrowTask)
            // 디바운스가 끝나기 전에 앱이 종료되는 상황: 종료 알림에서 flush가 호출된다.
            store.flush()
        }

        let (container, store) = try launch(today: saturday)
        #expect(store.text(\.breakfast) == "그릭요거트, 블루베리")
        #expect(store.text(\.lunch) == "일반식")
        #expect(store.text(\.dinner) == "계란 2개")
        #expect(store.text(\.snack) == "바나나")
        #expect(store.text(\.mealMemo) == "저녁에 배고픔이 적었음.\n물 2L 마심.")
        #expect(store.text(\.tomorrowTask) == "앱 기획서 초안 정리하기")
        #expect(try container.mainContext.fetchCount(FetchDescriptor<DayRecord>()) == 1)
    }

    @Test func debouncedTextIsSavedWithoutExplicitFlush() async throws {
        defer { cleanUp() }
        let (container, store) = try launch(today: saturday)
        store.setText("샐러드", at: \.lunch)

        // 저장은 입력 후 0.6초 뒤에 일어난다. 다른 테스트가 메인 액터를 오래 잡고 있을 수 있어
        // 정해진 시간만 기다리지 않고, 저장될 때까지(최대 10초) 확인한다.
        var savedLunch: String?
        for _ in 0..<100 {
            try await Task.sleep(for: .milliseconds(100))
            savedLunch = try DayRecordService(context: ModelContext(container)).record(on: saturday)?.lunch
            if savedLunch == "샐러드" { break }
        }
        #expect(savedLunch == "샐러드")
    }

    @Test func routineEditsSurviveRelaunch() throws {
        defer { cleanUp() }
        do {
            let (_, store) = try launch(today: saturday)
            store.addRoutine(title: "운동")
            store.addRoutine(title: "독서")
            store.addRoutine(title: "명상")
            let routines = store.routines
            store.updateRoutine(routines[0], title: "운동 (러닝)", note: "러닝 30분", timeLabel: "07:30", weekdays: [1, 3, 5, 6])
            store.setArchived(routines[1], true)
            store.moveActiveRoutine(routines[2], by: -1)
            store.setThreshold(70)
        }

        let (_, store) = try launch(today: saturday)
        #expect(store.activeRoutines.map(\.title) == ["명상", "운동 (러닝)"])
        #expect(store.archivedRoutines.map(\.title) == ["독서"])
        let running = try #require(store.activeRoutines.last)
        #expect(running.note == "러닝 30분")
        #expect(running.timeLabel == "07:30")
        #expect(running.weekdays == [1, 3, 5, 6])
        #expect(store.threshold == 70)
        #expect(store.checks.map(\.title) == ["명상", "운동 (러닝)"])
    }

    @Test func relaunchingManyTimesNeverDuplicatesTheDay() throws {
        defer { cleanUp() }
        for _ in 0..<5 {
            let (_, store) = try launch(today: saturday)
            if !store.hasRoutines { store.addRoutine(title: "운동") }
        }
        let (container, store) = try launch(today: saturday)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<DayRecord>()) == 1)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<DayCheck>()) == 1)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<AppSettings>()) == 1)
        #expect(store.checks.count == 1)
    }

    @Test func storeFileIsOutsideTheAppBundle() throws {
        defer { cleanUp() }
        let url = try DaylogStore.storeURL(name: "Daylog")
        #expect(!url.path.hasPrefix(Bundle.main.bundlePath))
        #expect(url.path.contains("Application Support/Daylog"))
    }
}
