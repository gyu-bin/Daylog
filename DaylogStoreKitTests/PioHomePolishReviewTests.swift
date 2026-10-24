#if DEBUG && os(iOS)
import XCTest
import UIKit
import SwiftUI
import QuartzCore
@testable import Daylog
@MainActor final class PioHomePolishReviewTests: XCTestCase {
 func testHeaderNativeMotionFrames() async throws {
  let scene=try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap{$0 as? UIWindowScene}.first)
  let window=UIWindow(windowScene:scene);let controller=UIViewController();window.rootViewController=controller;window.makeKeyAndVisible();defer{window.isHidden=true}
  let view=UIView(frame:CGRect(x:40,y:150,width:220,height:220));controller.view.addSubview(view)
  let stage=PioHeaderMotionStage();view.layer.addSublayer(stage.root)
  stage.update(outfit:.hanbok,gesture:.greet,active:true,bounds:view.bounds);CATransaction.flush()
  var positions:[Double]=[];var count=0
  let done=expectation(description:"native motion frame series")
  let timer=Timer.scheduledTimer(withTimeInterval:0.1,repeats:true){_ in MainActor.assumeIsolated{
   count+=1
   if let p=view.layer.presentation(){let image=UIGraphicsImageRenderer(size:view.bounds.size).image{p.render(in:$0.cgContext)};let a=XCTAttachment(image:image);a.name="header-motion-frame-\(count)";a.lifetime = .keepAlways;self.add(a)}
   positions.append(Double(stage.rig.movement.presentation()?.transform.m11 ?? 0))
   if count==20{done.fulfill()}
  }}
  await fulfillment(of:[done],timeout:8);timer.invalidate();stage.halt();XCTAssertEqual(stage.animationCount,0)
  XCTAssertGreaterThan(Set(positions).count,1)
 }
 func testHeaderSnapshots() async throws {
  XCTAssertTrue(RuntimeEnvironment.isRunningTests)
  let container = try DaylogStore.makeContainer(.inMemory)
  let store = AppStore(container: container);store.start()
  let suite = "pio-polish-\(UUID().uuidString)";let defaults = try XCTUnwrap(UserDefaults(suiteName:suite));defer{defaults.removePersistentDomain(forName:suite)}
  let preferences = DevicePreferences(defaults:defaults,isPhone:true)
  let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap{$0 as? UIWindowScene}.first)
  let window = UIWindow(windowScene:scene)
  let controller = UIHostingController(rootView:TodayCompactView().environment(\.dynamicTypeSize,.large).environment(store).environment(preferences).environment(DashboardDecor(defaults:defaults)).environment(CloudSyncMonitor(containerIdentifier:nil)).environment(\.scenePhase,.active))
  window.rootViewController=controller;window.makeKeyAndVisible();defer{window.isHidden=true}
  controller.view.setNeedsLayout();controller.view.layoutIfNeeded()
  let ready = expectation(description:"native next runloop layout")
  DispatchQueue.main.async { ready.fulfill() };await fulfillment(of:[ready],timeout:5)
  let image = UIGraphicsImageRenderer(size:controller.view.bounds.size).image{_ in controller.view.drawHierarchy(in:controller.view.bounds,afterScreenUpdates:true)}
  let a=XCTAttachment(image:image);a.name="iphone-home-header";a.lifetime = .keepAlways;add(a)
  controller.rootView=TodayCompactView().environment(\.dynamicTypeSize,.accessibility5).environment(store).environment(preferences).environment(DashboardDecor(defaults:defaults)).environment(CloudSyncMonitor(containerIdentifier:nil)).environment(\.scenePhase,.active)
  controller.view.setNeedsLayout();controller.view.layoutIfNeeded()
  let ax=UIGraphicsImageRenderer(size:controller.view.bounds.size).image{_ in controller.view.drawHierarchy(in:controller.view.bounds,afterScreenUpdates:true)}
  let axAttachment=XCTAttachment(image:ax);axAttachment.name="iphone-home-AX5";axAttachment.lifetime = .keepAlways;add(axAttachment)
  controller.rootView=TodayCompactView().environment(\.dynamicTypeSize,.large).environment(store).environment(preferences).environment(DashboardDecor(defaults:defaults)).environment(CloudSyncMonitor(containerIdentifier:nil)).environment(\.scenePhase,.active)
  for width:CGFloat in [320,768] {
   controller.view.frame=CGRect(x:0,y:0,width:width,height:900);controller.view.setNeedsLayout();controller.view.layoutIfNeeded()
   let image=UIGraphicsImageRenderer(size:controller.view.bounds.size).image{_ in controller.view.drawHierarchy(in:controller.view.bounds,afterScreenUpdates:true)}
   let a=XCTAttachment(image:image);a.name="home-layout-\(Int(width))pt-iphone-host";a.lifetime = .keepAlways;add(a)
  }

 }
}
#endif
