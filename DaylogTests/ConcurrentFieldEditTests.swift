import Foundation
import SwiftData
import Testing
@testable import Daylog

/// 9·14(TEST E). 같은 칸을 두 기기가 고친 경우.
/// 실제 iCloud에서는 나중에 동기화한 기기의 값이 칸을 덮어쓰고 다른 값은 사라진다(실측).
/// 기기별 편집 기록으로 그 상황을 알아내 두 내용을 모두 남긴다.
@MainActor
struct ConcurrentFieldEditTests {
    private func time(_ seconds: Double) -> Date { Date(timeIntervalSinceReferenceDate: 800_000_000 + seconds) }

    /// 다른 기기의 편집 기록이 동기화로 들어온 상태를 만든다.
    private func insertEdit(
        _ env: TestEnv, _ value: String, field: DayTextField = .dinner, device: String,
        at seconds: Double, seen: [String: Double] = [:]
    ) {
        let edit = FieldEdit(dateKey: saturday.key, field: field.rawValue, deviceID: device)
        edit.value = value
        edit.editedAt = time(seconds)
        edit.seen = seen.mapValues { time($0).timeIntervalSinceReferenceDate }
        env.context.insert(edit)
    }

    @Test func concurrentEditsToTheSameFieldAreBothKept() throws {
        let env = try TestEnv()
        let record = try env.records.fetchOrCreate(day: saturday, today: saturday)
        // 이 Mac이 오프라인에서 먼저 쓰고, 다른 Mac이 그걸 못 본 채 나중에 다르게 썼다.
        try type(env, "A가 쓴 저녁", in: .dinner, of: record, at: time(10))
        insertEdit(env, "B가 쓴 저녁", device: otherMac, at: 20)
        // iCloud가 정한 칸의 값: 나중에 동기화한 이 Mac의 값.
        #expect(record.dinner == "A가 쓴 저녁")

        let report = try reconcile(env)

        #expect(record.dinner == "A가 쓴 저녁\nB가 쓴 저녁")
        #expect(report.notices == ["10월 10일 저녁: 두 기기에서 다르게 적은 내용을 함께 남겼어요."])
        // 다시 실행해도, 다른 Mac에서 실행해도 더 바뀌지 않는다.
        #expect(try reconcile(env).changed == false)
        #expect(try reconcile(env, as: otherMac).changed == false)
        #expect(record.dinner == "A가 쓴 저녁\nB가 쓴 저녁")
    }

    /// 덮어써진 쪽 기기에서 먼저 병합이 실행돼도 결과는 같다.
    @Test func theOverwrittenDeviceAlsoRecoversBothValues() throws {
        let env = try TestEnv()
        let record = try env.records.fetchOrCreate(day: saturday, today: saturday)
        try type(env, "B가 쓴 저녁", in: .dinner, of: record, on: otherMac, at: time(20))
        insertEdit(env, "A가 쓴 저녁", device: thisMac, at: 10)
        record.dinner = "A가 쓴 저녁" // iCloud가 덮어쓴 값

        _ = try reconcile(env, as: otherMac)

        #expect(record.dinner == "A가 쓴 저녁\nB가 쓴 저녁")
        #expect(try reconcile(env, as: thisMac).changed == false)
    }

    /// 상대 내용을 보고 나서 고친 것은 충돌이 아니다. 여러 번 고쳐 써도 예전 내용이 되살아나지 않는다.
    @Test func editingAfterSeeingTheOtherValueIsNotAConflict() throws {
        let env = try TestEnv()
        let record = try env.records.fetchOrCreate(day: saturday, today: saturday)
        try type(env, "김치찌개", in: .lunch, of: record, at: time(10))
        // 다른 Mac이 그 내용을 받은 뒤 완전히 다른 내용으로 두 번 고쳐 썼다.
        try type(env, "샐러", in: .lunch, of: record, on: otherMac, at: time(20))
        try type(env, "샐러드", in: .lunch, of: record, on: otherMac, at: time(21))

        let report = try reconcile(env)

        #expect(record.lunch == "샐러드")
        #expect(report.notices.isEmpty)
        #expect(try env.context.fetchCount(FetchDescriptor<FieldEdit>()) == 2) // 기기당 하나
    }

    @Test func clearingAfterSeeingTheOtherValueStaysCleared() throws {
        let env = try TestEnv()
        let record = try env.records.fetchOrCreate(day: saturday, today: saturday)
        try type(env, "바나나", in: .snack, of: record, at: time(10))
        try type(env, "", in: .snack, of: record, on: otherMac, at: time(20))
        record.snack = "바나나" // 칸의 값만 예전 것으로 되돌아온 경우

        _ = try reconcile(env)
        #expect(record.snack == "")
    }

    /// 두 기기가 각자 병합을 실행해 같은 결과를 각자 기록해도 안정적이다.
    @Test func bothDevicesMergingConverges() throws {
        let env = try TestEnv()
        let record = try env.records.fetchOrCreate(day: saturday, today: saturday)
        record.dinner = "A\nB"
        insertEdit(env, "A\nB", device: thisMac, at: 30, seen: [otherMac: 20])
        insertEdit(env, "A\nB", device: otherMac, at: 31, seen: [thisMac: 10])

        #expect(try reconcile(env).changed == false)
        #expect(try reconcile(env, as: otherMac).changed == false)
        #expect(record.dinner == "A\nB")
    }

    /// 앱에서 입력하면 저장할 때마다 기기당 한 건의 편집 기록이 갱신된다.
    @Test func typingInTheAppRecordsOneEditPerField() throws {
        let env = try TestEnv()
        let store = AppStore(container: env.container, deviceID: thisMac, clock: { saturday })
        store.start()
        store.setText("그", at: \.breakfast)
        store.setText("그릭", at: \.breakfast)
        store.flush()
        store.setText("그릭요거트", at: \.breakfast)
        store.setText("장보기", at: \.tomorrowTask)
        store.flush()

        let edits = try env.context.fetch(FetchDescriptor<FieldEdit>())
        #expect(edits.count == 2)
        #expect(edits.allSatisfy { $0.deviceID == thisMac && $0.dateKey == saturday.key })
        #expect(edits.first { $0.field == "breakfast" }?.value == "그릭요거트")

        // 같은 값을 다시 써 보내는 것(포커스를 잃을 때 등)은 편집으로 남기지 않는다.
        store.setText("그릭요거트", at: \.breakfast)
        store.setText("", at: \.lunch)
        store.flush()
        #expect(try env.context.fetchCount(FetchDescriptor<FieldEdit>()) == 2)

        // 그 뒤 다른 Mac이 못 본 채 쓴 내용이 들어오면 화면에 둘 다 남고 안내가 쌓인다.
        insertEdit(env, "토스트", field: .breakfast, device: otherMac, at: 1)
        store.handleExternalChanges()
        #expect(store.text(\.breakfast) == "토스트\n그릭요거트")
        #expect(store.syncNotices.count == 1)
        store.handleExternalChanges()
        #expect(store.syncNotices.count == 1)
    }
}

struct FieldEditResolverTests {
    private func edit(_ device: String, _ value: String, at time: Double, seen: [String: Double] = [:]) -> FieldEditSnapshot {
        FieldEditSnapshot(deviceID: device, value: value, editedAt: time, seen: seen)
    }

    @Test func rules() {
        #expect(FieldEditResolver.resolve([], separator: "\n") == nil)
        #expect(FieldEditResolver.resolve([edit("a", "x", at: 1)], separator: "\n")?.value == "x")

        // 순차 편집: b가 a를 보고 고쳤다.
        let sequential = FieldEditResolver.resolve(
            [edit("a", "x", at: 1), edit("b", "y", at: 2, seen: ["a": 1])], separator: "\n"
        )
        #expect(sequential == .init(value: "y", needsMerge: false, isConflict: false))

        // 동시 편집: 서로 못 봤다. 먼저 쓴 내용이 앞에 온다.
        let concurrent = FieldEditResolver.resolve([edit("b", "y", at: 2), edit("a", "x", at: 1)], separator: " / ")
        #expect(concurrent == .init(value: "x / y", needsMerge: true, isConflict: true))

        // b가 a의 예전 내용만 본 상태에서 a가 다시 고쳤다.
        let stale = FieldEditResolver.resolve(
            [edit("a", "x2", at: 3), edit("b", "y", at: 2, seen: ["a": 1])], separator: "\n"
        )
        #expect(stale == .init(value: "y\nx2", needsMerge: true, isConflict: true))

        // 한쪽이 다른 쪽을 포함하면 이어 붙이지 않는다.
        let contained = FieldEditResolver.resolve([edit("a", "토스트", at: 1), edit("b", "토스트, 우유", at: 2)], separator: "\n")
        #expect(contained == .init(value: "토스트, 우유", needsMerge: true, isConflict: false))
    }
}
