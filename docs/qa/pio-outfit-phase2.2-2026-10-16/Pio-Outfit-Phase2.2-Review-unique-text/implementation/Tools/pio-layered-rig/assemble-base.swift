import Foundation
import AppKit
import ImageIO
import CryptoKit

let args = CommandLine.arguments
let root = args.count > 1 ? args[1] : FileManager.default.currentDirectoryPath
let qa = root + "/docs/qa/pio-outfit-phase2.2-2026-10-16"
let output = args.count > 2 ? args[2] : qa + "/registered/candidate-a"
let size = 1254
try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
func load(_ path: String) -> CGImage {
    let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil)!
    return CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)!
}
func context(_ w: Int, _ h: Int) -> CGContext {
    CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w*4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}
func save(_ image: CGImage, _ path: String) {
    let target = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(target, image, nil); precondition(CGImageDestinationFinalize(target))
}
func draw(_ image: CGImage, _ rect: CGRect, _ c: CGContext, height: CGFloat) {
    c.interpolationQuality = .high
    c.draw(image, in: CGRect(x: rect.minX, y: height-rect.maxY, width: rect.width, height: rect.height))
}
func bounds(_ image: CGImage, threshold: UInt8) -> (CGRect, [String: Int]) {
    let c = context(image.width,image.height)
    c.draw(image,in:CGRect(x:0,y:0,width:image.width,height:image.height))
    let bytes=c.data!.assumingMemoryBound(to:UInt8.self)
    var x0=image.width,y0=image.height,x1 = -1,y1 = -1
    var zero=0,partial=0,solid=0
    for y in 0..<image.height { for x in 0..<image.width {
        let a=bytes[y*c.bytesPerRow+x*4+3]
        if a==0 { zero+=1 } else if a==255 { solid+=1 } else { partial+=1 }
        if a>=threshold { x0=min(x0,x);x1=max(x1,x);y0=min(y0,y);y1=max(y1,y) }
    }}
    return (x1 < 0 ? .zero : CGRect(x:x0,y:y0,width:x1-x0+1,height:y1-y0+1),["alpha0":zero,"alpha1to254":partial,"alpha255":solid])
}
func arr(_ r: CGRect) -> [Double] { [r.minX,r.minY,r.width,r.height].map(Double.init) }
let names=["body-clean","wing-left","wing-right","eye-open","eyelid-closed","foot","sprout"]
var sources:[String:CGImage]=[:], audits:[[String:Any]]=[]
for name in names {
    let path=qa+"/candidates/base/"+name+"-v1.png", image=load(path)
    sources[name]=image
    let (b,a)=bounds(image,threshold:1)
    audits.append(["name":name,"width":image.width,"height":image.height,"sha256":SHA256.hash(data:try Data(contentsOf:URL(fileURLWithPath:path))).map{String(format:"%02x",$0)}.joined(),"boundsAlpha1":arr(b),"boundsAlpha16":arr(bounds(image,threshold:16).0),"boundsAlpha128":arr(bounds(image,threshold:128).0),"alpha":a])
}
try JSONSerialization.data(withJSONObject:audits,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:output+"/alpha-audit.json"))
if args.contains("--audit-only") { print(output+"/alpha-audit.json"); exit(0) }
struct Part {
    let id: String, source: String
    let scale: CGFloat, offset: CGPoint, pivot: CGPoint
    var registered: CGImage {
        let image=sources[source]!, c=context(size,size)
        draw(image,CGRect(x:offset.x,y:offset.y,width:CGFloat(image.width)*scale,height:CGFloat(image.height)*scale),c,height:CGFloat(size))
        return c.makeImage()!
    }
}
func fit(_ id:String,_ source:String,_ rect:CGRect,_ pivot:CGPoint)->Part {
    let b=bounds(sources[source]!,threshold:16).0
    let scale=min(rect.width/b.width,rect.height/b.height)
    return Part(id:id,source:source,scale:scale,offset:CGPoint(x:rect.minX-b.minX*scale,y:rect.minY-b.minY*scale),pivot:pivot)
}
let parts:[Part] = [
    fit("wingLeft","wing-left",CGRect(x:280,y:780,width:165,height:246),CGPoint(x:375,y:810)),
    fit("wingRight","wing-right",CGRect(x:850,y:600,width:280,height:296),CGPoint(x:940,y:830)),
    fit("footLeft","foot",CGRect(x:490,y:1000,width:130,height:114),CGPoint(x:550,y:1010)),
    fit("footRight","foot",CGRect(x:755,y:965,width:130,height:114),CGPoint(x:815,y:975)),
    Part(id:"sprout",source:"sprout",scale:0.36,offset:CGPoint(x:650-790*0.36,y:430-935*0.36),pivot:CGPoint(x:650,y:430)),
    fit("body","body-clean",CGRect(x:310,y:390,width:680,height:685),CGPoint(x:650,y:740)),
    fit("eyeLeft","eye-open",CGRect(x:504,y:640,width:92,height:98),CGPoint(x:550,y:689)),
    fit("eyeRight","eye-open",CGRect(x:771,y:597,width:88,height:94),CGPoint(x:815,y:644)),
    fit("lidLeft","eyelid-closed",CGRect(x:501,y:677,width:98,height:36),CGPoint(x:550,y:695)),
    fit("lidRight","eyelid-closed",CGRect(x:768,y:632,width:94,height:35),CGPoint(x:815,y:649))
]
var registered:[String:CGImage]=[:]
for p in parts { let image=p.registered;registered[p.id]=image;save(image,output+"/"+p.id+".png") }
let referencePath=root+"/Daylog/PioWardrobe.xcassets/pio_wardrobe_basic_reference.imageset/pio_wardrobe_basic_reference.png"
let original=load(referencePath), refcontext=context(size,size)
draw(original,CGRect(x:33,y:90,width:CGFloat(original.width)*0.9,height:CGFloat(original.height)*0.9),refcontext,height:CGFloat(size))
let reference=refcontext.makeImage()!
save(reference,output+"/reference-registered.png")
let manifest:[String:Any] = ["schemaVersion":1,"status":"ART_QA_CANDIDATE_NOT_APPROVED","canvas":[size,size],"origin":"topLeft","sourceReference":referencePath,"referenceScale":0.9,"referenceOffset":[33,90],"registrationMethod":"Manual landmarks; uniform scale plus translation per independently generated part; complete source pixels retained, no alpha cleanup/repainting", "layers":parts.map{p in ["id":p.id,"source":p.source+"-v1.png","scale":Double(p.scale),"offset":[Double(p.offset.x),Double(p.offset.y)],"pivot":[Double(p.pivot.x),Double(p.pivot.y)],"z":parts.firstIndex(where:{$0.id==p.id})!] as [String:Any]}]
let manifestData = try JSONSerialization.data(withJSONObject:manifest,options:[.prettyPrinted,.sortedKeys])
try manifestData.write(to:URL(fileURLWithPath:qa+"/base-registration.json"))
try manifestData.write(to:URL(fileURLWithPath:output+"/registration.json"))
struct Pose {
    let name:String
    var closed=false
    var angles:[String:CGFloat]=[:]
    var offsets:[String:CGPoint]=[:]
}
let poses=[Pose(name:"step-right-planted",offsets:["footRight":CGPoint(x:0,y:35)]),Pose(name:"step-right-ground-lift",angles:["footRight":8],offsets:["footRight":CGPoint(x:0,y:17)]),Pose(name:"neutral"),Pose(name:"closed",closed:true),Pose(name:"right-minus12",angles:["wingRight":-12]),Pose(name:"right-plus12",angles:["wingRight":12]),Pose(name:"left-minus12",angles:["wingLeft":-12]),Pose(name:"left-plus12",angles:["wingLeft":12]),Pose(name:"step-left",angles:["footLeft":-12],offsets:["footLeft":CGPoint(x:-10,y:-24)]),Pose(name:"step-right",angles:["footRight":12],offsets:["footRight":CGPoint(x:10,y:-24)])]
let poseData:[[String:Any]] = poses.map { pose in
    ["name":pose.name,"closedEyes":pose.closed,"anglesDegrees":pose.angles.mapValues(Double.init),
     "translations":pose.offsets.mapValues{[Double($0.x),Double($0.y)]},
     "bodyTransform":"identity","sproutTransform":"identity"]
}
try JSONSerialization.data(withJSONObject:poseData,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:output+"/poses.json"))
func assemble(_ pose:Pose)->CGImage {
    let c=context(size,size)
    for p in parts {
        if p.id.hasPrefix("eye") && pose.closed {continue}
        if p.id.hasPrefix("lid") && !pose.closed {continue}
        c.saveGState()
        let move=pose.offsets[p.id] ?? .zero
        c.translateBy(x:move.x,y:-move.y)
        c.translateBy(x:p.pivot.x,y:CGFloat(size)-p.pivot.y)
        c.rotate(by:-(pose.angles[p.id] ?? 0) * .pi/180)
        c.translateBy(x:-p.pivot.x,y:-(CGFloat(size)-p.pivot.y))
        c.draw(registered[p.id]!,in:CGRect(x:0,y:0,width:size,height:size))
        c.restoreGState()
    }
    return c.makeImage()!
}
let backgrounds:[(String,CGColor)]=[("light",CGColor(red:0.98,green:0.96,blue:0.91,alpha:1)),("dark",CGColor(red:0.07,green:0.11,blue:0.10,alpha:1))]
var composites:[String:CGImage]=[:]
for pose in poses {let image=assemble(pose);composites[pose.name]=image;save(image,output+"/base-assembled-"+pose.name+"-alpha.png")}
for (theme,color) in backgrounds {
    for (name,img) in [("reference",reference)] + poses.map({($0.name,composites[$0.name]!)}) {
        let c=context(size,size);c.setFillColor(color);c.fill(CGRect(x:0,y:0,width:size,height:size));c.draw(img,in:CGRect(x:0,y:0,width:size,height:size))
        save(c.makeImage()!,output+"/base-assembled-"+name+"-"+theme+".png")
    }
    for points in [64,220] {for density in [1,3] {
        let tile=points*density, gap=24*density, top=32*density
        let images:[(String,CGImage)]=[("Original",reference),("Assembled",composites["neutral"]!),("Closed eyes",composites["closed"]!),("Right +12",composites["right-plus12"]!)]
        let w=images.count*(tile+gap)+gap,h=tile+top+gap
        let c=context(w,h);c.setFillColor(color);c.fill(CGRect(x:0,y:0,width:w,height:h))
        for (index,item) in images.enumerated() {
            let x=gap+index*(tile+gap)
            draw(item.1,CGRect(x:x,y:top,width:tile,height:tile),c,height:CGFloat(h))
            NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(cgContext:c,flipped:false)
            (item.0 as NSString).draw(at:NSPoint(x:x,y:h-top+5*density),withAttributes:[.font:NSFont.systemFont(ofSize:CGFloat(11*density)),.foregroundColor:theme=="dark" ? NSColor.white:NSColor.black])
            NSGraphicsContext.restoreGraphicsState()
        }
        save(c.makeImage()!,output+"/base-assembled-comparison-\(points)pt-\(density)x-\(theme).png")
    }}
    for pose in poses {
        let c=context(600,600);c.setFillColor(color);c.fill(CGRect(x:0,y:0,width:600,height:600))
        let area = pose.name.contains("step") ? CGRect(x:430,y:910,width:500,height:300) : pose.name.contains("right") ? CGRect(x:810,y:560,width:390,height:410) : pose.name.contains("left") ? CGRect(x:240,y:740,width:260,height:320) : CGRect(x:460,y:565,width:445,height:260)
        let scale=min(600/area.width,600/area.height)
        draw(composites[pose.name]!,CGRect(x:-area.minX*scale,y:-area.minY*scale,width:CGFloat(size)*scale,height:CGFloat(size)*scale),c,height:600)
        save(c.makeImage()!,output+"/base-assembled-joint-"+pose.name+"-"+theme+".png")
    }
}
print("ART QA candidates, not an app rig: "+output)
