import CoreGraphics
import Foundation
import Observation

/// 대시보드 꾸미기 가운데 이 기기에만 두는 것: 꾸미기 카드의 크기·문구·사진, 상단 배경 사진.
/// 배치(순서·열·숨김)는 `DevicePreferences`가, 여러 기기가 함께 보는 텍스트 카드의 내용은 `AppStore.dashboardTexts`가 맡는다.
/// 기록 저장소(SwiftData·iCloud)에는 아무것도 쓰지 않는다.
@MainActor
@Observable
final class DashboardDecor {
    static let shared = DashboardDecor()
    static let cardsKey = "device.dashboard.customCards"
    static let headerKey = "device.dashboard.headerImage"
    /// 이미지 카드의 문구와 섹션 제목의 최대 길이.
    static let titleLimit = 40

    /// 꾸미기 카드 한 장의 이 기기 설정.
    struct Entry: Codable, Equatable {
        var size: CustomCardSize = .regular
        /// 섹션 제목의 글자, 이미지 카드 위에 올리는 문구. 텍스트 카드의 내용은 여기 두지 않는다.
        var title = ""
        /// 보관 폴더의 사진 파일 이름.
        var imageFile: String?
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored let images: DashboardImageStore
    private(set) var entries: [UUID: Entry]
    /// 상단 배경 사진의 파일 이름. 없으면 머리말은 예전 모습 그대로다.
    private(set) var headerImageFile: String?

    init(defaults: UserDefaults = .standard, images: DashboardImageStore = .standard) {
        self.defaults = defaults
        self.images = images
        let stored = defaults.data(forKey: Self.cardsKey).flatMap { try? JSONDecoder().decode([String: Entry].self, from: $0) } ?? [:]
        entries = Dictionary(uniqueKeysWithValues: stored.compactMap { key, value in UUID(uuidString: key).map { ($0, value) } })
        headerImageFile = defaults.string(forKey: Self.headerKey)
    }

    /// 그 카드의 설정. 아직 정한 것이 없으면 기본값(보통 크기, 빈 문구).
    func entry(_ id: UUID) -> Entry {
        entries[id] ?? Entry()
    }

    func image(for id: UUID) -> CGImage? {
        entries[id]?.imageFile.flatMap(images.image(named:))
    }

    var headerImage: CGImage? {
        headerImageFile.flatMap(images.image(named:))
    }

    func setSize(_ size: CustomCardSize, for id: UUID) {
        update(id) { $0.size = size }
    }

    func setTitle(_ title: String, for id: UUID) {
        update(id) { $0.title = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.titleLimit)) }
    }

    /// 줄여 둔 사본을 저장해 그 카드에 건다. 전에 쓰던 사본은 지운다. 실패하면 전 사진이 그대로 남는다.
    func setImage(_ image: ProcessedDashboardImage, for id: UUID) throws {
        let name = try images.save(image)
        let previous = entries[id]?.imageFile
        update(id) { $0.imageFile = name }
        previous.map(images.remove)
    }

    func removeImage(for id: UUID) {
        guard let previous = entries[id]?.imageFile else { return }
        update(id) { $0.imageFile = nil }
        images.remove(previous)
    }

    /// 카드를 지울 때: 이 기기의 설정과 사진 사본을 함께 지운다.
    func remove(_ id: UUID) {
        guard let entry = entries.removeValue(forKey: id) else { return }
        entry.imageFile.map(images.remove)
        save()
    }

    func setHeaderImage(_ image: ProcessedDashboardImage) throws {
        let name = try images.save(image)
        let previous = headerImageFile
        headerImageFile = name
        defaults.set(name, forKey: Self.headerKey)
        previous.map(images.remove)
    }

    func removeHeaderImage() {
        guard let previous = headerImageFile else { return }
        headerImageFile = nil
        defaults.removeObject(forKey: Self.headerKey)
        images.remove(previous)
    }

    /// 그 카드가 이 기기에 있는가. 텍스트 카드는 내용이 따로 저장되므로 `texts`에 있어야 한다.
    func isAvailable(_ card: DashboardCard, texts: [UUID: DashboardText]) -> Bool {
        guard case .custom(let kind, let id) = card else { return true }
        return kind == .text ? texts[id] != nil : entries[id] != nil
    }

    private func update(_ id: UUID, _ change: (inout Entry) -> Void) {
        var entry = entries[id] ?? Entry()
        change(&entry)
        entries[id] = entry
        save()
    }

    private func save() {
        let encodable = Dictionary(uniqueKeysWithValues: entries.map { ($0.key.uuidString, $0.value) })
        defaults.set(try? JSONEncoder().encode(encodable), forKey: Self.cardsKey)
    }
}
