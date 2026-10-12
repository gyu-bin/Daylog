import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum DashboardImageError: LocalizedError, Equatable {
    case tooLarge
    case unreadable
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .tooLarge: return "사진이 너무 커요. \(DashboardImageStore.maxSourceBytes / 1_000_000)MB 이하의 사진을 골라 주세요."
        case .unreadable: return "이 파일은 사진으로 읽을 수 없어요. 다른 사진을 골라 주세요."
        case .saveFailed: return "사진을 저장하지 못했어요. 저장 공간을 확인해 주세요."
        }
    }
}

/// 저장할 수 있게 줄여 둔 사진(JPEG). `DashboardImageStore.process`만 만든다.
struct ProcessedDashboardImage: Equatable, Sendable {
    fileprivate(set) var data: Data

    /// 미리보기용 그림.
    var cgImage: CGImage? {
        CGImageSourceCreateWithData(data as CFData, nil).flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) }
    }
}

/// 한 번 읽은 사본을 들고 있는다. 화면이 다시 그려질 때마다 파일을 풀지 않게 한다.
private final class DashboardImageCache: @unchecked Sendable {
    static let shared = DashboardImageCache()
    private let cache = NSCache<NSString, CGImage>()

    init() { cache.countLimit = 12 }

    func image(_ key: String) -> CGImage? { cache.object(forKey: key as NSString) }
    func set(_ image: CGImage, _ key: String) { cache.setObject(image, forKey: key as NSString) }
    func remove(_ key: String) { cache.removeObject(forKey: key as NSString) }
}

/// 대시보드 꾸미기에 쓰는 사진의 사본을 이 기기에 둔다.
///
/// 고른 원본은 읽기만 하고 고치지 않는다. 화면에 필요한 크기로 줄인 JPEG 사본만 앱의 보관 폴더에 만든다.
/// 사본은 동기화하지 않는다(iCloud의 기록 저장소에 사진을 넣지 않는다).
struct DashboardImageStore: Sendable {
    /// 읽어 들이는 원본의 최대 크기.
    static let maxSourceBytes = 40_000_000
    /// 사본의 긴 변(픽셀). 2열 대시보드의 카드와 상단 배경에 충분한 크기다.
    static let maxPixel = 1_600
    /// 사본 한 장의 목표 크기. 넘으면 한 단계씩 더 줄인다.
    static let maxStoredBytes = 600_000
    /// 긴 변과 압축 품질을 낮춰 가는 단계.
    private static let steps: [(pixel: Int, quality: Double)] = [(1_600, 0.82), (1_280, 0.74), (1_024, 0.64), (800, 0.5)]

    let directory: URL

    static var standard: DashboardImageStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return DashboardImageStore(directory: base.appendingPathComponent("DashboardImages", isDirectory: true))
    }

    /// 원본 데이터를 줄인 JPEG로 바꾼다. 원본의 방향(EXIF)을 반영하고, 투명한 부분은 흰색으로 채운다.
    static func process(_ data: Data) throws -> ProcessedDashboardImage {
        guard data.count <= maxSourceBytes else { throw DashboardImageError.tooLarge }
        guard !data.isEmpty, let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0 else { throw DashboardImageError.unreadable }
        var smallest: Data?
        for step in steps {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: step.pixel,
                kCGImageSourceShouldCacheImmediately: true
            ]
            guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
                  let encoded = jpeg(flattened(thumbnail), quality: step.quality) else { throw DashboardImageError.unreadable }
            smallest = encoded
            if encoded.count <= maxStoredBytes { break }
        }
        guard let smallest else { throw DashboardImageError.unreadable }
        return ProcessedDashboardImage(data: smallest)
    }

    /// 줄여 둔 사본을 저장하고 파일 이름을 돌려준다. 이름은 매번 새로 지어서, 사진을 바꾸면 화면이 새 파일을 읽는다.
    func save(_ image: ProcessedDashboardImage) throws -> String {
        let name = UUID().uuidString + ".jpg"
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try image.data.write(to: directory.appendingPathComponent(name), options: .atomic)
        } catch {
            throw DashboardImageError.saveFailed
        }
        return name
    }

    /// 저장해 둔 사본. 파일이 없거나 깨졌으면 nil(화면은 대체 안내를 보여 준다).
    func image(named name: String) -> CGImage? {
        guard Self.isSafe(name) else { return nil }
        let url = directory.appendingPathComponent(name)
        if let cached = DashboardImageCache.shared.image(url.path) { return cached }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
        else { return nil }
        DashboardImageCache.shared.set(image, url.path)
        return image
    }

    func remove(_ name: String) {
        guard Self.isSafe(name) else { return }
        let url = directory.appendingPathComponent(name)
        DashboardImageCache.shared.remove(url.path)
        try? FileManager.default.removeItem(at: url)
    }

    /// 이 폴더 안의 파일 이름만 받는다(경로 조각이 섞인 이름은 쓰지 않는다).
    static func isSafe(_ name: String) -> Bool {
        !name.isEmpty && !name.contains("/") && !name.contains("..")
    }

    private static func flattened(_ image: CGImage) -> CGImage {
        switch image.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast: return image
        default: break
        }
        guard let context = CGContext(
            data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return image }
        let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(rect)
        context.draw(image, in: rect)
        return context.makeImage() ?? image
    }

    private static func jpeg(_ image: CGImage, quality: Double) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }
}
