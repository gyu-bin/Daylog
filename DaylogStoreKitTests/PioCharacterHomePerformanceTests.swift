#if DEBUG && os(macOS)
import XCTest
import AppKit
import QuartzCore
import Darwin
@testable import Daylog

/// A separate quiet process from ledger/pixel QA. Native production home stage,
/// not the previous reference-PNG home benchmark and not actual app cold launch.
@MainActor final class PioCharacterHomePerformanceTests: XCTestCase {
    func testProductionHomeFourteenOutfitsTwiceAndPairedIdleStop() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.arguments.contains("-PioCharacterHomePerformance"))
        XCTAssertTrue(RuntimeEnvironment.isRunningTests)
        XCTAssertFalse(PioOverhaulTrial.isEnabled)
        let parent = NSView(frame: CGRect(x:0,y:0,width:340,height:380));parent.wantsLayer=true
        let window=NSWindow(contentRect:parent.bounds,styleMask:[.titled],backing:.buffered,defer:false)
        window.isReleasedWhenClosed=false;window.contentView=parent;window.orderFrontRegardless()
        defer { window.orderOut(nil);window.close() }
        try await waitUntil { window.isVisible && window.occlusionState.contains(.visible) }
        let initial=snapshot()
        var rows:[[String:Any]]=[]
        for pass in 1...2 {
            for outfit in PioOutfitID.allCases {
                var stage:PioHomeProductionStage?
                var host:PioCloudSceneHost?
                autoreleasepool {
                    stage=PioHomeProductionStage()
                    host=PioCloudSceneHost(frame:CGRect(x:60,y:80,width:220,height:220));host!.wantsLayer=true
                    host!.layer!.addSublayer(stage!.root);host!.hosted=stage!.root
                }
                weak var weakStage=stage
                weak var weakHost=host
                host!.visibilityChanged = { [weak s=stage,weak h=host] visible in
                    guard let h else { return }
                    s?.update(outfit:outfit,action:.idle,active:visible,bounds:h.bounds)
                }
                let before=snapshot()
                parent.addSubview(host!);host!.refreshVisibility();CATransaction.flush()
                try await waitUntil {
                    window.isVisible && window.occlusionState.contains(.visible)
                        && (stage?.animationCount ?? 0)>0 && stage?.root.presentation() != nil
                }
                // Fixed observation interval; not a retry for entitlement or assertions.
                try await Task.sleep(for:.milliseconds(150))
                let active=snapshot(),activeTracks=stage!.animationCount
                XCTAssertNotNil(stage!.rig.layers["body"]?.contents)
                host!.removeFromSuperview();CATransaction.flush()
                let detachedTracks=stage!.animationCount
                XCTAssertEqual(detachedTracks,0,"Real native visibility callback must halt before explicit cleanup")
                autoreleasepool {
                    host!.visibilityChanged=nil;stage!.halt();host!.hosted=nil
                    host=nil;stage=nil;CATransaction.flush()
                }
                let immediateStageReleased=weakStage == nil,immediateHostReleased=weakHost == nil
                let immediateAfter=snapshot()
                // AppKit can retain a removed NSView until its pending display/
                // run-loop work drains. Observe actual release, without sleep or
                // weakening the final ownership assertions.
                try await waitUntil { weakStage == nil && weakHost == nil }
                XCTAssertNil(weakStage);XCTAssertNil(weakHost)
                rows.append(["pass":pass,"outfit":outfit.rawValue,"before":before,"active":active,
                             "after":snapshot(),"immediateAfter":immediateAfter,
                             "immediateStageReleased":immediateStageReleased,"immediateHostReleased":immediateHostReleased,
                             "activeTracks":activeTracks,"detachedTracks":detachedTracks,
                             "stageReleased":weakStage == nil,"hostReleased":weakHost == nil])
            }
        }
        var phases:[[String:Any]]=[]
        phases.append(try await sample(window,label:"empty-warm-window",seconds:2))
        var stage:PioHomeProductionStage?=PioHomeProductionStage()
        var host:PioCloudSceneHost?=PioCloudSceneHost(frame:CGRect(x:60,y:80,width:220,height:220))
        weak var weakStage=stage;weak var weakHost=host
        host!.wantsLayer=true;host!.layer!.addSublayer(stage!.root);host!.hosted=stage!.root
        var requestedActive=false
        host!.visibilityChanged = { [weak s=stage,weak h=host] visible in
            guard let h else{return};s?.update(outfit:.basic,action:.idle,active:visible && requestedActive,bounds:h.bounds)
        }
        parent.addSubview(host!);host!.refreshVisibility();CATransaction.flush()
        phases.append(try await sample(window,label:"prepared-idle-stopped",seconds:2))
        for pair in 1...3 {
            for active in pair == 2 ? [false,true] : [true,false] {
                requestedActive=active;host!.refreshVisibility();CATransaction.flush()
                if active { XCTAssertGreaterThan(stage!.animationCount,0) }
                else { XCTAssertEqual(stage!.animationCount,0) }
                var phase=try await sample(window,label:"pair-\(pair)-\(active ? "active":"stopped")",seconds:5)
                phase["pair"]=pair;phase["active"]=active;phase["tracks"]=stage!.animationCount
                phases.append(phase)
            }
        }
        autoreleasepool {
            host!.removeFromSuperview();host!.visibilityChanged=nil;stage!.halt();host!.hosted=nil
            host=nil;stage=nil;CATransaction.flush()
        }
        let immediateCPUStageReleased=weakStage == nil,immediateCPUHostReleased=weakHost == nil
        try await waitUntil { weakStage == nil && weakHost == nil }
        XCTAssertNil(weakStage);XCTAssertNil(weakHost)
        phases.append(try await sample(window,label:"released-warm-window",seconds:2))
        let report:[String:Any]=["initial":initial,"final":snapshot(),"rows":rows,"cpuPhases":phases,
            "immediateCPUStageReleased":immediateCPUStageReleased,"immediateCPUHostReleased":immediateCPUHostReleased,
            "finalCPUStageReleased":weakStage == nil,"finalCPUHostReleased":weakHost == nil,
            "os":ProcessInfo.processInfo.operatingSystemVersionString,"processors":ProcessInfo.processInfo.processorCount,
            "scope":"Mac native production home stage; 14 outfits twice then warm basic idle/stopped 3 pairs; same visible window",
            "limitations":"Direct renderer fixture without ownership/UI navigation; not app cold launch, OS background, prior reference-home comparison, GPU, battery, or long-term leak proof. No absolute RSS pass threshold."]
        let data=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
        let a=XCTAttachment(data:data,uniformTypeIdentifier:"public.json");a.name="production-home-14x2-and-idle-stopped";a.lifetime = .keepAlways;add(a)
    }
    private func waitUntil(_ condition:@escaping @MainActor ()->Bool) async throws {
        let e=XCTNSPredicateExpectation(predicate:NSPredicate{_,_ in MainActor.assumeIsolated{condition()}},object:nil)
        await fulfillment(of:[e],timeout:5)
        guard condition() else{throw NSError(domain:"PioCharacterHomePerformance.visibility",code:1)}
    }
    private func sample(_ window:NSWindow,label:String,seconds:Int) async throws->[String:Any]{
        let initial=snapshot(),start=CACurrentMediaTime(),cpu=cpuSeconds()
        var samples:[[String:Any]]=[]
        for _ in 0..<seconds {
            try await Task.sleep(for:.seconds(1))
            XCTAssertTrue(window.isVisible && window.occlusionState.contains(.visible))
            samples.append(snapshot())
        }
        let elapsed=CACurrentMediaTime()-start
        return ["label":label,"seconds":elapsed,"cpuPercentOneCore":(cpuSeconds()-cpu)/elapsed*100,
                "initial":initial,"final":snapshot(),"samples":samples]
    }
    private func snapshot()->[String:Any]{["rssBytes":residentBytes(),"cpuSeconds":cpuSeconds(),"monotonicSeconds":CACurrentMediaTime()]}
    private func cpuSeconds()->Double {
        var usage=rusage();let status=getrusage(RUSAGE_SELF,&usage);XCTAssertEqual(status,0)
        return Double(usage.ru_utime.tv_sec+usage.ru_stime.tv_sec)+Double(usage.ru_utime.tv_usec+usage.ru_stime.tv_usec)/1e6
    }
    private func residentBytes()->UInt64 {
        var info=mach_task_basic_info();var count=mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size/4)
        let status=withUnsafeMutablePointer(to:&info){p in p.withMemoryRebound(to:integer_t.self,capacity:Int(count)){
            task_info(mach_task_self_,task_flavor_t(MACH_TASK_BASIC_INFO),$0,&count)
        }}
        XCTAssertEqual(status,KERN_SUCCESS)
        return status == KERN_SUCCESS ? UInt64(info.resident_size):0
    }
}
#endif
