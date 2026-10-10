import Foundation
import SwiftData
import Testing
@testable import Daylog

/// 7·14. 날짜별 중복과 충돌 (한 저장소 안에서 동기화 결과를 재현)
@MainActor
struct DuplicateDayRecordTests {
    /// TEST B·C: 두 기기가 오프라인에서 같은 날짜를 각각 만들고 서로 다른 루틴을 체크했다.
    @Test func sameDateFromTwoDevicesBecomesOneLogicalRecord() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(3, today: saturday)
        let local = try env.records.fetchOrCreate(day: saturday, today: saturday)
        try env.records.setDone(try #require(local.checkList.first { $0.routineID == routines[0].id }), true)
        insertRemoteRecord(env, day: saturday, createdAt: later, done: [routines[1].id], routines: routines)

        let report = try reconcile(env)

        let representative = try #require(try env.records.record(on: saturday))
        #expect(report.changed)
        #expect(representative === local) // 먼저 만들어진 쪽이 대표
        #expect(representative.checkList.count == 3)
        #expect(representative.checkList.map(\.isDone) == [true, true, false])
        // 통계와 기간 조회는 날짜당 하나만 본다.
        #expect(try env.records.records(from: saturday, to: saturday).count == 1)
        #expect(try env.stats.dashboard(today: saturday).today == DayOutcome(day: saturday, status: .recorded, done: 2, total: 3))
        // 아무것도 지우지 않는다.
        #expect(try env.context.fetchCount(FetchDescriptor<DayRecord>()) == 2)
        #expect(try env.context.fetchCount(FetchDescriptor<DayCheck>()) == 6)
    }

    /// TEST A·대표 교체: 다른 기기가 먼저 만든 기록이 나중에 도착하면 그쪽이 대표가 되고 이쪽 내용이 옮겨진다.
    @Test func earlierRemoteRecordBecomesRepresentative() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(2, today: saturday)
        let local = try env.records.fetchOrCreate(day: saturday, today: saturday)
        try env.records.setDone(try #require(local.checkList.first), true)
        env.records.setText("토스트", at: \.breakfast, of: local)
        let remote = insertRemoteRecord(env, day: saturday, createdAt: earlier, routines: routines)

        _ = try reconcile(env)

        let representative = try #require(try env.records.record(on: saturday))
        #expect(representative === remote)
        #expect(representative.breakfast == "토스트")
        #expect(representative.checkList.map(\.isDone) == [true, false])
        #expect(representative.isRecorded)
    }

    /// TEST D: 서로 다른 식사 칸은 둘 다 남는다.
    @Test func differentMealFieldsAreBothKept() throws {
        let env = try TestEnv()
        let local = try env.records.fetchOrCreate(day: saturday, today: saturday)
        env.records.setText("그릭요거트", at: \.breakfast, of: local)
        let remote = insertRemoteRecord(env, day: saturday, createdAt: later, routines: [])
        remote.dinner = "계란 2개"
        remote.tomorrowTask = "기획서 정리"

        let report = try reconcile(env)

        #expect(local.breakfast == "그릭요거트")
        #expect(local.dinner == "계란 2개")
        #expect(local.tomorrowTask == "기획서 정리")
        #expect(report.notices.isEmpty)
    }

    /// TEST E: 같은 칸에 서로 다른 내용이면 둘 다 남기고 알려 준다. 원본도 각 기록에 그대로 있다.
    @Test func conflictingTextKeepsBothValues() throws {
        let env = try TestEnv()
        let local = try env.records.fetchOrCreate(day: saturday, today: saturday)
        env.records.setText("김치찌개", at: \.lunch, of: local)
        env.records.setText("운동 가기", at: \.tomorrowTask, of: local)
        let remote = insertRemoteRecord(env, day: saturday, createdAt: later, routines: [])
        remote.lunch = "샐러드"
        remote.tomorrowTask = "장보기"

        let report = try reconcile(env)

        #expect(local.lunch == "김치찌개\n샐러드")
        #expect(local.tomorrowTask == "운동 가기 / 장보기")
        #expect(remote.lunch == "샐러드")
        #expect(report.notices.count == 2)
        #expect(report.notices.first?.contains("10월 10일 점심") == true)
    }

    @Test func identicalOrContainedTextIsNotDuplicated() throws {
        let env = try TestEnv()
        let local = try env.records.fetchOrCreate(day: saturday, today: saturday)
        env.records.setText("그릭요거트, 블루베리", at: \.breakfast, of: local)
        env.records.setText("일반식", at: \.lunch, of: local)
        let remote = insertRemoteRecord(env, day: saturday, createdAt: later, routines: [])
        remote.breakfast = "그릭요거트"            // 대표에 이미 들어 있는 내용
        remote.lunch = "일반식, 닭가슴살 추가"      // 대표의 내용을 포함하는 더 긴 내용
        remote.snack = "   "                       // 공백뿐

        let report = try reconcile(env)

        #expect(local.breakfast == "그릭요거트, 블루베리")
        #expect(local.lunch == "일반식, 닭가슴살 추가")
        #expect(local.snack == "")
        #expect(report.notices.isEmpty)
    }

    /// TEST L: 병합을 다시 실행해도 아무것도 바뀌지 않는다.
    @Test func reconcilingTwiceChangesNothing() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(3, today: saturday)
        let local = try env.records.fetchOrCreate(day: saturday, today: saturday)
        env.records.setText("김치찌개", at: \.lunch, of: local)
        let remote = insertRemoteRecord(env, day: saturday, createdAt: later, done: [routines[2].id], routines: routines)
        remote.lunch = "샐러드"
        remote.dinner = "계란"

        #expect(try reconcile(env).changed)
        let first = try FixtureSnapshot.capture(context: env.context, today: saturday)
        let ledger = local.mergeState

        for _ in 0..<3 {
            let report = try reconcile(env)
            #expect(!report.changed)
            #expect(report.notices.isEmpty)
        }
        #expect(try FixtureSnapshot.capture(context: env.context, today: saturday) == first)
        #expect(local.mergeState == ledger)
        #expect(local.lunch == "김치찌개\n샐러드")
        #expect(try env.context.fetchCount(FetchDescriptor<DayCheck>()) == 6)
    }

    /// 병합한 뒤 사용자가 지우거나 해제한 내용은 다음 병합에서 되살아나지 않는다.
    @Test func userEditsAfterMergeAreNotUndone() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(1, today: saturday)
        let local = try env.records.fetchOrCreate(day: saturday, today: saturday)
        let remote = insertRemoteRecord(env, day: saturday, createdAt: later, done: [routines[0].id], routines: routines)
        remote.breakfast = "토스트"
        _ = try reconcile(env)
        #expect(local.breakfast == "토스트")
        #expect(local.checkList.first?.isDone == true)

        try type(env, "", in: .breakfast, of: local)
        try env.records.setDone(try #require(local.checkList.first), false)
        _ = try reconcile(env)
        _ = try reconcile(env)

        #expect(local.breakfast == "")
        #expect(local.checkList.first?.isDone == false)
        // 다른 기록은 건드리지 않았다.
        #expect(remote.breakfast == "토스트")
        #expect(remote.checkList.first?.isDone == true)
    }

    /// 병합한 뒤에 다른 기기가 자기 기록을 더 고치면 그 변경만 다시 가져온다.
    @Test func laterChangesOnTheOtherRecordAreAbsorbed() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(2, today: saturday)
        let local = try env.records.fetchOrCreate(day: saturday, today: saturday)
        let remote = insertRemoteRecord(env, day: saturday, createdAt: later, done: [routines[0].id], routines: routines)
        remote.dinner = "계란"
        _ = try reconcile(env)

        // 다른 기기(아직 대표를 모르는 상태)에서 이어서 입력하고, 체크 하나는 해제하고 하나는 완료했다.
        remote.dinner = "계란, 샐러드"
        remote.snack = "바나나"
        let remoteChecks = remote.checkList
        remoteChecks[0].isDone = false
        remoteChecks[1].isDone = true
        _ = try reconcile(env)

        #expect(local.dinner == "계란, 샐러드")
        #expect(local.snack == "바나나")
        #expect(local.checkList.map(\.isDone) == [false, true])
    }

    /// 대표 기록에 없는 루틴은 사본을 만들어 붙인다(원본은 옮기지 않는다).
    @Test func missingRoutineCheckIsCopiedOnce() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(1, today: saturday)
        let local = try env.records.fetchOrCreate(day: saturday.adding(days: -1), today: saturday)
        let extra = RoutineItem(title: "다른 기기에서 만든 루틴", order: 9)
        let remote = insertRemoteRecord(
            env, day: saturday.adding(days: -1), createdAt: later, done: [extra.id], routines: routines + [extra]
        )

        _ = try reconcile(env)
        _ = try reconcile(env)

        #expect(local.checkList.map(\.title) == ["루틴 1", "다른 기기에서 만든 루틴"])
        #expect(local.checkList.last?.isDone == true)
        #expect(local.physicalChecks.count == 2)
        #expect(remote.physicalChecks.count == 2)
    }

    @Test func differentDatesAreNeverMerged() throws {
        let env = try TestEnv()
        let friday = saturday.adding(days: -1)
        let today = try env.records.fetchOrCreate(day: saturday, today: saturday)
        env.records.setText("오늘 아침", at: \.breakfast, of: today)
        let remote = insertRemoteRecord(env, day: friday, createdAt: later, routines: [])
        remote.breakfast = "어제 아침"

        #expect(try reconcile(env).changed == false)
        #expect(today.breakfast == "오늘 아침")
        #expect(remote.breakfast == "어제 아침")
        #expect(try env.records.records(from: friday, to: saturday).count == 2)
    }

    /// 어느 기기에서 실행하든(= 어떤 순서로 들어오든) 같은 대표를 고르고 같은 결과를 만든다.
    @Test func resultDoesNotDependOnArrivalOrder() throws {
        func merged(reversed: Bool) throws -> (lunch: String, representative: UUID?, done: [Bool]) {
            let env = try TestEnv()
            let routines = [
                RoutineItem(id: UUID(uuidString: "00000000-0000-0000-0000-00000000000A") ?? UUID(), title: "가", order: 0),
                RoutineItem(id: UUID(uuidString: "00000000-0000-0000-0000-00000000000B") ?? UUID(), title: "나", order: 1),
            ]
            let created = Date(timeIntervalSince1970: 5_000) // 생성 시각까지 같아도 식별자로 순서가 정해진다
            let specs: [(id: String, lunch: String, done: Set<UUID>)] = [
                ("11111111-1111-1111-1111-111111111111", "김치찌개", [routines[0].id]),
                ("22222222-2222-2222-2222-222222222222", "샐러드", [routines[1].id]),
            ]
            for spec in reversed ? specs.reversed() : specs {
                let record = insertRemoteRecord(
                    env, day: saturday, createdAt: created,
                    syncID: UUID(uuidString: spec.id) ?? UUID(), done: spec.done, routines: routines
                )
                record.lunch = spec.lunch
            }
            _ = try reconcile(env)
            let representative = try #require(try env.records.record(on: saturday))
            return (representative.lunch, representative.syncID, representative.checkList.map(\.isDone))
        }

        let forward = try merged(reversed: false)
        let backward = try merged(reversed: true)
        #expect(forward.lunch == "김치찌개\n샐러드")
        #expect(forward.lunch == backward.lunch)
        #expect(forward.representative == backward.representative)
        #expect(forward.done == [true, true])
        #expect(backward.done == [true, true])
    }

    /// 한 기록 안에 같은 루틴의 체크가 둘 들어온 경우(두 기기가 각자 오늘 목록에 추가).
    @Test func duplicateChecksInOneRecordCountOnce() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(2, today: saturday)
        let record = try env.records.fetchOrCreate(day: saturday, today: saturday)
        let duplicate = DayCheck(routine: routines[0])
        duplicate.isDone = true
        record.attach(duplicate)
        try env.context.save()

        #expect(record.physicalChecks.count == 3)
        #expect(record.checkList.count == 2)
        _ = try reconcile(env)

        #expect(record.checkList.count == 2)
        #expect(record.checkList.first { $0.routineID == routines[0].id }?.isDone == true)
        #expect(try env.stats.dashboard(today: saturday).today == DayOutcome(day: saturday, status: .unrecorded, done: 1, total: 2))
        #expect(try reconcile(env).changed == false)
    }
}

struct TextMergeTests {
    @Test func rules() {
        #expect(TextMerge.merge("", "토스트", separator: "\n") == ("토스트", false))
        #expect(TextMerge.merge("토스트", "", separator: "\n") == ("토스트", false))
        #expect(TextMerge.merge("토스트", "토스트 ", separator: "\n") == ("토스트", false))
        #expect(TextMerge.merge("토스트, 우유", "우유", separator: "\n") == ("토스트, 우유", false))
        #expect(TextMerge.merge("우유", "토스트, 우유", separator: "\n") == ("토스트, 우유", false))
        #expect(TextMerge.merge("토스트", "시리얼", separator: "\n") == ("토스트\n시리얼", true))
        // 한 번 합친 결과에 같은 값을 다시 합쳐도 늘어나지 않는다.
        #expect(TextMerge.merge("토스트\n시리얼", "시리얼", separator: "\n") == ("토스트\n시리얼", false))
    }

    @Test func ledgerHashIsStable() {
        #expect(MergeLedger.hash("") == MergeLedger.hash(""))
        #expect(MergeLedger.hash("아침") != MergeLedger.hash("점심"))
        #expect(MergeLedger.hash("abc") == "e71fa2190541574b")
    }
}
