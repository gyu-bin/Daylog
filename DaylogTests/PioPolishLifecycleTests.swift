#if DEBUG && os(macOS)
import XCTest
import AppKit
import QuartzCore
import Darwin
@testable import Daylog
@MainActor final class PioPolishLifecycleTests: XCTestCase {
 func testWindowVisibilityLifecycle() async throws {
  let host=PioCloudSceneHost(frame:CGRect(x:0,y:0,width:340,height:340));host.wantsLayer=true
  let window=NSWindow(contentRect:host.bounds,styleMask:[.titled,.miniaturizable],backing:.buffered,defer:false);window.isReleasedWhenClosed=false;window.contentView=host
  defer{window.orderOut(nil);window.close()}
  var visible=false;host.visibilityChanged={visible=$0}
  let observer=NotificationCenter.default.addObserver(forName:NSWindow.didChangeOcclusionStateNotification,object:nil,queue:.main){n in print("PIO_NOTIFICATION sameWindow=\((n.object as? NSWindow) === window)")}
  defer{NotificationCenter.default.removeObserver(observer)}
  let front=expectation(description:"native visible window notification")
  host.visibilityChanged={visible=$0;if $0 {front.fulfill()}}
  window.level = .floating;NSApp.activate(ignoringOtherApps:true);window.makeKeyAndOrderFront(nil);host.refreshVisibility()
  await fulfillment(of:[front],timeout:5)
  host.visibilityChanged={visible=$0}
  print("PIO_WINDOW visibility=\(window.isVisible) minimized=\(window.isMiniaturized) occlusion=\(window.occlusionState.rawValue) bounds=\(host.bounds) visibleRect=\(host.visibleRect) hidden=\(host.isHiddenOrHasHiddenAncestor)")
  print("PIO_HOST windowMatches=\(host.window === window) attached=\(host.window != nil) visibleConstant=\(NSWindow.OcclusionState.visible.rawValue)");host.refreshVisibility();print("PIO_HOST refreshed=\(visible)")
  XCTAssertTrue(visible)
  let hidden=expectation(description:"native hidden window notification")
  host.visibilityChanged={visible=$0;if !$0 {hidden.fulfill()}}
  window.orderOut(nil)
  await fulfillment(of:[hidden],timeout:5);XCTAssertFalse(visible)
  let restored=expectation(description:"native restored window notification")
  host.visibilityChanged={visible=$0;if $0 {restored.fulfill()}}
  window.makeKeyAndOrderFront(nil)
  await fulfillment(of:[restored],timeout:5)
  host.visibilityChanged={visible=$0}
  print("PIO_WINDOW visibility=\(window.isVisible) minimized=\(window.isMiniaturized) occlusion=\(window.occlusionState.rawValue) bounds=\(host.bounds) visibleRect=\(host.visibleRect) hidden=\(host.isHiddenOrHasHiddenAncestor)")
  print("PIO_HOST windowMatches=\(host.window === window) attached=\(host.window != nil) visibleConstant=\(NSWindow.OcclusionState.visible.rawValue)");host.refreshVisibility();print("PIO_HOST refreshed=\(visible)")
  XCTAssertTrue(visible)
  host.isHidden=true;host.refreshVisibility();XCTAssertFalse(visible)
 }
 func testTwoMinuteVisibleSceneSampling() async throws {
  let view=NSView(frame:CGRect(x:0,y:0,width:340,height:340));view.wantsLayer=true
  let window=NSWindow(contentRect:view.bounds,styleMask:[.titled],backing:.buffered,defer:false);window.isReleasedWhenClosed=false;window.contentView=view;window.orderFront(nil)
  defer{window.orderOut(nil);window.close()}
  let stage=RoutimoriSyncStage();view.layer!.addSublayer(stage.root);stage.root.position=CGPoint(x:170,y:170)
  var samples:[[String:Double]]=[]
  func cpu()->Double{var r=rusage();getrusage(RUSAGE_SELF,&r);return Double(r.ru_utime.tv_sec+r.ru_stime.tv_sec)+Double(r.ru_utime.tv_usec+r.ru_stime.tv_usec)/1e6}
  func rss()->Double{var r=mach_task_basic_info();var c=mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size/4);let status=withUnsafeMutablePointer(to:&r){p in p.withMemoryRebound(to:integer_t.self,capacity:Int(c)){task_info(mach_task_self_,task_flavor_t(MACH_TASK_BASIC_INFO),$0,&c)}};return status==KERN_SUCCESS ? Double(r.resident_size):0}
  let start=Date(),initialCPU=cpu();var tick=0
  let finished=expectation(description:"120 native presentation observation samples")
  let timer=Timer.scheduledTimer(withTimeInterval:1,repeats:true){_ in
   MainActor.assumeIsolated {
    tick+=1
    if tick==1 || tick%10==0 {stage.update(.init(kind:tick%30==0 ? .ready:.receiving,height:340,dark:false,scale:2,reduceMotion:false,outfit:PioOutfitID.allCases[(tick/10)%14],usesIndependentCharacter:true),isAnimating:true)}
    if tick%10==9 {stage.halt()}
    samples.append(["elapsed":Date().timeIntervalSince(start),"cpuSeconds":cpu()-initialCPU,"rss":rss()])
    if tick==120{finished.fulfill()}
   }
  }
  await fulfillment(of:[finished],timeout:140);timer.invalidate();stage.halt()
  func tracks(_ l:CALayer)->Int{(l.animationKeys()?.count ?? 0)+(l.sublayers ?? []).reduce(0){$0+tracks($1)}}
  XCTAssertEqual(tracks(stage.root),0)
  let report:[String:Any]=["samples":samples,"platform":"Mac Debug native visible cloud scene","limits":"120second observation; not battery profiling, home or vacation long-run verification"]
  let a=XCTAttachment(data:try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted]),uniformTypeIdentifier:"public.json");a.name="scene-120s-performance";a.lifetime = .keepAlways;add(a)
 }
}
#endif
