#if DEBUG && os(iOS)
import XCTest
import SwiftUI
import UIKit
@testable import Daylog

@MainActor final class PioDeviceSizeReviewTests: XCTestCase {
    func testActualDeviceDashboardAndLargeText() async throws {
        XCTAssertTrue(RuntimeEnvironment.isRunningTests)
        let container = try DaylogStore.makeContainer(.inMemory)
        let store = AppStore(container: container); store.start()
        let suite = "PioDeviceSize.\(UUID())"; let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        let preferences = DevicePreferences(defaults: defaults, isPhone: isPhone)
        let window = UIWindow(windowScene: scene)
        let decor = DashboardDecor(defaults: defaults)
        let cloud = CloudSyncMonitor(containerIdentifier: nil)
        func content(_ size: DynamicTypeSize) -> some View {
            DashboardView().environment(store).environment(preferences).environment(decor).environment(cloud)
                .environment(\.dynamicTypeSize, size).environment(\.scenePhase, .active)
        }
        let controller = UIHostingController(rootView: content(.large))
        window.rootViewController = controller; window.makeKeyAndVisible()
        defer { window.isHidden = true }
        for (label, size) in [("normal", DynamicTypeSize.large), ("AX5", .accessibility5)] {
            controller.rootView = content(size)
            controller.view.setNeedsLayout(); controller.view.layoutIfNeeded()
            let ready = expectation(description: "SwiftUI layout transaction \(label)")
            DispatchQueue.main.async { ready.fulfill() }
            await fulfillment(of: [ready], timeout: 5)
            controller.view.layoutIfNeeded()
            print("PIO_DEVICE idiom=\(isPhone ? "phone" : "pad") bounds=\(controller.view.bounds) sizeClass=\(controller.traitCollection.horizontalSizeClass.rawValue) text=\(label)")
            XCTAssertGreaterThan(controller.view.bounds.width, 0)
            let image = UIGraphicsImageRenderer(size: controller.view.bounds.size).image { _ in
                controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = "actual-\(isPhone ? "phone" : "ipad")-dashboard-\(label)"
            attachment.lifetime = .keepAlways; add(attachment)
        }
    }
}
#endif
