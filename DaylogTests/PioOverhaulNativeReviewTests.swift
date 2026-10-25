#if DEBUG && os(macOS)
import XCTest
import AppKit
import QuartzCore
import SwiftUI
import Darwin
@testable import Daylog

/// Explicit opt-in visual/performance evidence from native CA presentation layers.
/// XCTest host uses RuntimeEnvironment.storeLocation == .inMemory.
@MainActor final class PioOverhaulNativeReviewTests: XCTestCase {
    private func wait(_ seconds: Double) async throws { try await Task.sleep(for: .seconds(seconds)); CATransaction.flush() }
    private func png(_ layer: CALayer, size: Int = 350, transparent: Bool = false) throws -> Data {
        let context = try XCTUnwrap(CGContext(data:nil,width:size,height:size,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue))
        if !transparent { context.setFillColor(NSColor(calibratedRed:0.06,green:0.11,blue:0.09,alpha:1).cgColor);context.fill(CGRect(x:0,y:0,width:size,height:size)) }
        let presentation = try XCTUnwrap(layer.presentation(), "Must capture real presentation layer")
        presentation.render(in:context)
        return try XCTUnwrap(NSBitmapImageRep(cgImage:try XCTUnwrap(context.makeImage())).representation(using:.png,properties:[:]))
    }
    private func attach(_ data: Data, name: String, type: String = "public.png") {
        let attachment = XCTAttachment(data:data,uniformTypeIdentifier:type);attachment.name=name;attachment.lifetime = .keepAlways;add(attachment)
    }
    private func cpu() -> Double {
        var usage = rusage();getrusage(RUSAGE_SELF,&usage)
        return Double(usage.ru_utime.tv_sec+usage.ru_stime.tv_sec) + Double(usage.ru_utime.tv_usec+usage.ru_stime.tv_usec)/1_000_000
    }
    private func resident() -> UInt64 {
        var info = mach_task_basic_info();var count=mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size/MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to:&info) { pointer in pointer.withMemoryRebound(to:integer_t.self,capacity:Int(count)) { task_info(mach_task_self_,task_flavor_t(MACH_TASK_BASIC_INFO),$0,&count) } }
        return result == KERN_SUCCESS ? UInt64(info.resident_size) : 0
    }
    func testNativeNeutralAndLandingBorders() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.arguments.contains("-PioNativePeakOnly"))
        let view=NSView(frame:CGRect(x:0,y:0,width:350,height:350));view.wantsLayer=true
        let window=NSWindow(contentRect:view.bounds,styleMask:[.titled],backing:.buffered,defer:false)
        window.isReleasedWhenClosed=false;window.contentView=view;window.orderFront(nil)
        defer { window.orderOut(nil);window.close() }
        let rig=PioOverhaulRig();view.layer!.addSublayer(rig.root)
        var results:[[String:Any]]=[]
        for outfit in PioOutfitID.allCases {
            for size in [64,220] {
                for action in [PioOverhaulAction.idle,.landing] {
                    rig.layout(CGRect(x:0,y:0,width:size,height:size));rig.configure(outfit,action:action);rig.setActive(action == .landing);CATransaction.flush();try await wait(action == .landing ? 0.18 : 0.05)
                    let data=try png(rig.root,size:size,transparent:true);let bitmap=try XCTUnwrap(NSBitmapImageRep(data:data));var maxAlpha=0.0
                    for i in 0..<size { for (x,y) in [(i,0),(i,size-1),(0,i),(size-1,i)] { maxAlpha=max(maxAlpha,Double(bitmap.colorAt(x:x,y:y)?.alphaComponent ?? 0)) } }
                    attach(data,name:"\(outfit.rawValue)-\(action.rawValue)-native-\(size)pt-alpha")
                    results.append(["outfit":outfit.rawValue,"size":size,"action":action.rawValue,"maxBorderAlpha":maxAlpha])
                    XCTAssertEqual(maxAlpha,0,"\(outfit.rawValue) \(action.rawValue) \(size)pt must stay within canvas")
                    rig.setActive(false)
                }
            }
        }
        attach(try JSONSerialization.data(withJSONObject:results,options:[.prettyPrinted,.sortedKeys]),name:"native-neutral-landing-border-verification",type:"public.json")
    }
    func testNativeMotionSequences() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.arguments.contains("-PioNativeMotionSequence"))
        XCTAssertTrue(RuntimeEnvironment.isRunningTests)
        let view=NSView(frame:CGRect(x:0,y:0,width:350,height:350));view.wantsLayer=true
        let window=NSWindow(contentRect:view.bounds,styleMask:[.titled],backing:.buffered,defer:false)
        window.isReleasedWhenClosed=false;window.contentView=view;window.orderFront(nil)
        defer { window.orderOut(nil);window.close() }
        let rig=PioOverhaulRig();view.layer!.addSublayer(rig.root);rig.layout(view.bounds)
        var evidence:[[String:Any]]=[]
        for (outfit,action) in [(PioOutfitID.hanbok,PioOverhaulAction.jump),(.christmas,.greet)] {
            rig.configure(outfit,action:action);rig.setActive(true);CATransaction.flush()
            let start=Date();var times:[Double]=[]
            for index in 0..<60 {
                let target=Double(index)/20
                let remaining=target-Date().timeIntervalSince(start)
                if remaining > 0 { try await wait(remaining) }
                times.append(Date().timeIntervalSince(start))
                attach(try png(rig.root),name:String(format:"native-sequence-%@-%@-%03d",outfit.rawValue,action.rawValue,index))
            }
            evidence.append(["outfit":outfit.rawValue,"action":action.rawValue,"captureMethod":"real Core Animation presentation layer sampled in wall time","requestedFPS":20,"actualSampleSeconds":times])
            rig.setActive(false)
        }
        attach(try JSONSerialization.data(withJSONObject:evidence,options:[.prettyPrinted,.sortedKeys]),name:"native-motion-sequence-timing",type:"public.json")
    }
    func testNativePresentationAndComparableObservations() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.arguments.contains("-PioNativeMotionReview"))
        XCTAssertTrue(RuntimeEnvironment.isRunningTests)
        var arguments=UserDefaults.standard.volatileDomain(forName:UserDefaults.argumentDomain)
        arguments["DaylogDebugCharacter"]="routimori";arguments["DaylogDebugLayeredRig"]=true
        UserDefaults.standard.setVolatileDomain(arguments,forName:UserDefaults.argumentDomain)
        let view=NSView(frame:CGRect(x:0,y:0,width:350,height:350));view.wantsLayer=true
        let window=NSWindow(contentRect:view.bounds,styleMask:[.titled],backing:.buffered,defer:false);window.isReleasedWhenClosed=false;window.title="Pio DEBUG native motion evidence";window.contentView=view;window.orderFront(nil)
        defer { window.orderOut(nil);window.close() }
        let rig=PioOverhaulRig();view.layer!.addSublayer(rig.root);rig.layout(view.bounds)
        if ProcessInfo.processInfo.arguments.contains("-PioNativePeakOnly") {
            var borderEvidence:[[String:Any]]=[]
            for outfit in PioOutfitID.allCases {
                for size in [64,220] {
                    rig.layout(CGRect(x:0,y:0,width:size,height:size));rig.configure(outfit,action:.jump);rig.setActive(true);CATransaction.flush();try await wait(1.14)
                    let data=try png(rig.root,size:size,transparent:true);attach(data,name:"\(outfit.rawValue)-jump-peak-native-\(size)pt-alpha")
                    let bitmap=try XCTUnwrap(NSBitmapImageRep(data:data));var maxAlpha=0.0
                    for i in 0..<size {
                        for (x,y) in [(i,0),(i,size-1),(0,i),(size-1,i)] { maxAlpha=max(maxAlpha,Double(bitmap.colorAt(x:x,y:y)?.alphaComponent ?? 0)) }
                    }
                    borderEvidence.append(["outfit":outfit.rawValue,"size":size,"maximumBorderAlpha":maxAlpha,"sampleTimeSeconds":1.14])
                    XCTAssertEqual(maxAlpha,0,"Native jump peak must retain transparent outer border: \(outfit.rawValue) \(size)pt")
                    rig.setActive(false)
                }
            }
            attach(try JSONSerialization.data(withJSONObject:borderEvidence,options:[.prettyPrinted,.sortedKeys]),name:"native-jump-peak-border-verification",type:"public.json")
            return
        }
        var presentationEvidence:[[String:Any]]=[]
        if !ProcessInfo.processInfo.arguments.contains("-PioNativePerformanceOnly") {
        for outfit in [PioOutfitID.basic,.christmas,.hanbok,.astronaut] {
            for action in [PioOverhaulAction.jump,.greet,.celebrate] {
                rig.configure(outfit,action:action);rig.setActive(true);CATransaction.flush()
                var captures:[Data]=[];var positions:[Double]=[]
                for (index,delay) in [0.15,0.50,0.55].enumerated() {
                    try await wait(delay)
                    positions.append(Double(rig.movement.presentation()?.transform.m42 ?? 0))
                    let data=try png(rig.root);captures.append(data);attach(data,name:"\(outfit.rawValue)-\(action.rawValue)-native-\(index)")
                }
                XCTAssertNotEqual(captures[0],captures[1],"Presentation must visibly change")
                presentationEvidence.append(["outfit":outfit.rawValue,"action":action.rawValue,"sampledTranslationY":positions,"presentationPNGChanges":captures[0] != captures[1]])
                rig.setActive(false)
            }
        }
        for size in [64,220] {
            rig.layout(CGRect(x:0,y:0,width:size,height:size));rig.configure(.hanbok,action:.greet);rig.setActive(true);try await wait(0.5)
            attach(try png(rig.root,size:size),name:"hanbok-greet-native-\(size)pt-dark")
            rig.setActive(false)
        }
        rig.layout(view.bounds)
        let gallery=NSHostingView(rootView:PioOverhaulMotionReview(outfit:.hanbok))
        gallery.frame=CGRect(x:0,y:0,width:620,height:800)
        let galleryWindow=NSWindow(contentRect:gallery.bounds,styleMask:[.titled],backing:.buffered,defer:false)
        galleryWindow.isReleasedWhenClosed=false;galleryWindow.contentView=gallery;galleryWindow.orderFront(nil)
        try await wait(0.7);gallery.layoutSubtreeIfNeeded()
        if let bitmap=gallery.bitmapImageRepForCachingDisplay(in:gallery.bounds) {
            gallery.cacheDisplay(in:gallery.bounds,to:bitmap)
            if let data=bitmap.representation(using:.png,properties:[:]) { attach(data,name:"native-motion-gallery-hanbok") }
        }
        galleryWindow.orderOut(nil);galleryWindow.close()
        }
        // Same 350pt layer host, same wall interval, same process and warmup.
        // CPU excludes WindowServer/GPU; RSS is process-wide, not a per-rig allocation.
        var observations:[[String:Any]]=[]
        let old=PioLayeredRig();old.configure(outfit:.basic,motion:.jump);old.layout(in:view.bounds,displayScale:2)
        rig.root.removeFromSuperlayer();view.layer!.addSublayer(old.root);old.setAnimating(true);try await wait(0.7);old.setAnimating(false);old.root.removeFromSuperlayer()
        for trial in 1...2 {
            for name in ["old-base-jump","new-base-static","new-base-jump","new-christmas-static","new-christmas-jump"] {
                if name == "old-base-jump" { view.layer!.addSublayer(old.root);old.setAnimating(true) }
                else { view.layer!.addSublayer(rig.root);rig.configure(name.contains("christmas") ? .christmas : .basic,action:.jump);rig.setActive(!name.contains("static")) }
                try await wait(0.7)
                let beforeCPU=cpu(),beforeRSS=resident(),start=Date();try await wait(2)
                let elapsed=Date().timeIntervalSince(start)
                observations.append(["trial":trial,"scenario":name,"wallSeconds":elapsed,"processCPUPercent":(cpu()-beforeCPU)/elapsed*100,"residentBeforeBytes":beforeRSS,"residentAfterBytes":resident(),"canvasPoints":350])
                old.setAnimating(false);rig.setActive(false);old.root.removeFromSuperlayer();rig.root.removeFromSuperlayer()
            }
        }
        var switchBatches:[[String:Any]]=[]
        for batch in 1...3 {
            let before=resident();let start=Date()
            for index in 0..<42 { rig.configure(PioOutfitID.allCases[index%14],action:.greet);rig.setActive(true);rig.setActive(false) }
            let after=resident();view.layer!.addSublayer(rig.root);try await wait(1)
            switchBatches.append(["batch":batch,"switchCount":42,"wallSeconds":Date().timeIntervalSince(start),"residentBeforeBytes":before,"residentAfterBytes":after,"residentAfterSettlingBytes":resident(),"inactiveAnimationTracks":rig.animationCount])
            XCTAssertEqual(rig.animationCount,0)
        }
        rig.configure(.christmas,action:.jump);rig.setActive(true);try await wait(0.7)
        let activeTracks=rig.animationCount,activeRSS=resident();rig.setActive(false)
        let stopCPU=cpu(),stopStart=Date();try await wait(2)
        let stopWall=Date().timeIntervalSince(stopStart)
        let inactive:[String:Any]=["activeTracksBeforeStop":activeTracks,"tracksAfterStop":rig.animationCount,"residentBeforeStopBytes":activeRSS,"residentAfterSettlingBytes":resident(),"wallSeconds":stopWall,"processCPUPercent":(cpu()-stopCPU)/stopWall*100]
        XCTAssertEqual(rig.animationCount,0)
        let report:[String:Any]=["status":"OBSERVATIONS_NOT_PERFORMANCE_CERTIFICATION","presentationEvidence":presentationEvidence,"comparisons":observations,"switchingBatches":switchBatches,"inactiveAfterStop":inactive,"limits":["Debug CPU process time only; excludes compositor and GPU","Not iPhone runtime profiling","Programmatic setActive(false) verified; scroll visibility and Reduce Motion UI require separate verification","RSS includes XCTest host and cache; no leak verdict from short observation"]]
        let data=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]);attach(data,name:"native-presentation-and-performance-observations",type:"public.json")
        print("PIO_NATIVE_OBSERVATIONS \(String(decoding:data,as:UTF8.self))")
    }
}
#endif
