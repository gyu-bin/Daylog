import Foundation
import AppKit
import ImageIO
import CryptoKit

let args = CommandLine.arguments
let root = args.count > 1 ? args[1] : FileManager.default.currentDirectoryPath
let qa = root + "/docs/qa/pio-outfit-phase2.2-2026-10-16"
let output = args.count > 2 ? args[2] : qa + "/registered/hanbok-a"
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
let names=["body-clean","sleeve-left","sleeve-right","eye-open","eyelid-closed","foot","sprout"]
var sources:[String:CGImage]=[:], audits:[[String:Any]]=[]
var sourceFiles:[String:String]=[:]
for name in names {
    let folder = ["body-clean","sleeve-left","sleeve-right"].contains(name) ? "hanbok" : "base"
    let version=name == "sleeve-left" ? "v3" : name == "sleeve-right" ? "v2" : "v1"
    let relative="candidates/"+folder+"/"+name+"-"+version+".png"
    let path=qa+"/"+relative
    guard FileManager.default.fileExists(atPath: path) else {
        if args.contains("--audit-only") { audits.append(["name":name,"source":relative,"missing":true]); continue }
        fatalError("Required independent source missing: " + relative)
    }
    let image=load(path)
    sourceFiles[name]=relative; sources[name]=image
    let (b,a)=bounds(image,threshold:1)
    audits.append(["name":name,"source":relative,"width":image.width,"height":image.height,"sha256":SHA256.hash(data:try Data(contentsOf:URL(fileURLWithPath:path))).map{String(format:"%02x",$0)}.joined(),"boundsAlpha1":arr(b),"boundsAlpha16":arr(bounds(image,threshold:16).0),"boundsAlpha128":arr(bounds(image,threshold:128).0),"alpha":a])
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
    let scale=min(1,min(rect.width/b.width,rect.height/b.height))
    return Part(id:id,source:source,scale:scale,offset:CGPoint(x:rect.minX-b.minX*scale,y:rect.minY-b.minY*scale),pivot:pivot)
}
var parts:[Part] = [
    fit("footLeft","foot",CGRect(x:450,y:1080,width:160,height:140),CGPoint(x:530,y:1100)),
    fit("footRight","foot",CGRect(x:745,y:1080,width:150,height:131),CGPoint(x:817,y:1095)),
    Part(id:"sprout",source:"sprout",scale:0.37,offset:CGPoint(x:625-790*0.37,y:365-935*0.37),pivot:CGPoint(x:625,y:365)),
    fit("body","body-clean",CGRect(x:195,y:300,width:946,height:865),CGPoint(x:650,y:780)),
    fit("eyeLeft","eye-open",CGRect(x:488,y:579,width:102,height:105),CGPoint(x:539,y:631)),
    fit("eyeRight","eye-open",CGRect(x:775,y:541,width:98,height:102),CGPoint(x:824,y:592)),
    fit("lidLeft","eyelid-closed",CGRect(x:487,y:620,width:104,height:38),CGPoint(x:539,y:639)),
    fit("lidRight","eyelid-closed",CGRect(x:774,y:580,width:100,height:37),CGPoint(x:824,y:598)),
    fit("wingLeft","sleeve-left",CGRect(x:225,y:740,width:225,height:245),CGPoint(x:400,y:790)),
    Part(id:"wingRight",source:"sleeve-right",scale:0.27,offset:CGPoint(x:857.55,y:558.9),pivot:CGPoint(x:975,y:810))
]
parts = parts.filter { $0.id == "wingRight" } + parts.filter { $0.id != "wingRight" }
if args.contains("--wings-behind-body") {
    let wings = parts.filter { $0.id.hasPrefix("wing") }
    parts = wings + parts.filter { !$0.id.hasPrefix("wing") }
}
var registered:[String:CGImage]=[:]
for p in parts {precondition(p.scale<=1);let image=p.registered;registered[p.id]=image;save(image,output+"/"+p.id+".png")}
let referencePath=root+"/Daylog/PioWardrobe.xcassets/pio_outfit_hanbok.imageset/pio_outfit_hanbok.png"
let reference=load(referencePath)
precondition(reference.width==size && reference.height==size)
save(reference,output+"/reference-registered.png")
let manifest:[String:Any] = ["schemaVersion":1,"status":"ART_QA_CANDIDATE_NOT_APPROVED","canvas":[size,size],"origin":"topLeft","sourceReference":referencePath,"referenceScale":1,"referenceOffset":[0,0],"registrationMethod":"Independent uniform downscale/translation; no painting, alpha cleanup or source deformation","bakedDetails":["hair flower","hair tassel","waist flower","waist bow","skirt"],"layers":parts.map{p in ["id":p.id,"source":sourceFiles[p.source]!,"scale":Double(p.scale),"offset":[Double(p.offset.x),Double(p.offset.y)],"pivot":[Double(p.pivot.x),Double(p.pivot.y)],"neutralAngleDegrees":p.id == "wingRight" ? -20 : 0,"z":parts.firstIndex(where:{$0.id==p.id})!] as [String:Any]}]
try JSONSerialization.data(withJSONObject:manifest,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:output+"/registration.json"))
struct Pose {
    let name:String
    var closed=false
    var angles:[String:CGFloat]=[:]
    var offsets:[String:CGPoint]=[:]
}
let poses=[Pose(name:"neutral"),Pose(name:"closed",closed:true),Pose(name:"right-minus12",angles:["wingRight":-12]),Pose(name:"right-plus12",angles:["wingRight":12]),Pose(name:"left-minus12",angles:["wingLeft":-12]),Pose(name:"left-plus12",angles:["wingLeft":12]),Pose(name:"sprout-minus4",angles:["sprout":-4]),Pose(name:"sprout-plus4",angles:["sprout":4]),Pose(name:"step-left",angles:["footLeft":-8],offsets:["footLeft":CGPoint(x:0,y:-18)]),Pose(name:"step-right",angles:["footRight":8],offsets:["footRight":CGPoint(x:0,y:-18)])]
let poseData:[[String:Any]]=poses.map{pose in ["name":pose.name,"closedEyes":pose.closed,"anglesDegrees":pose.angles.mapValues(Double.init),"translations":pose.offsets.mapValues{[Double($0.x),Double($0.y)]},"bodyTransform":"identity"]}
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
        c.rotate(by:-((pose.angles[p.id] ?? 0)+(p.id == "wingRight" ? -20 : 0)) * .pi/180)
        c.translateBy(x:-p.pivot.x,y:-(CGFloat(size)-p.pivot.y))
        c.draw(registered[p.id]!,in:CGRect(x:0,y:0,width:size,height:size))
        c.restoreGState()
    }
    return c.makeImage()!
}
let backgrounds:[(String,CGColor)]=[("light",CGColor(red:0.98,green:0.96,blue:0.91,alpha:1)),("dark",CGColor(red:0.07,green:0.11,blue:0.10,alpha:1))]
var composites:[String:CGImage]=[:]
for pose in poses {let image=assemble(pose);composites[pose.name]=image;save(image,output+"/hanbok-assembled-"+pose.name+"-alpha.png")}
for (theme,color) in backgrounds {
    for (name,img) in [("reference",reference)] + poses.map({($0.name,composites[$0.name]!)}) {
        let c=context(size,size);c.setFillColor(color);c.fill(CGRect(x:0,y:0,width:size,height:size));c.draw(img,in:CGRect(x:0,y:0,width:size,height:size))
        save(c.makeImage()!,output+"/hanbok-assembled-"+name+"-"+theme+".png")
    }
    for points in [64,220] {for density in [1,3] {
        let tile=points*density,gap=24*density,top=32*density
        for pose in poses {
            let thumbnail=context(tile,tile)
            thumbnail.setFillColor(color);thumbnail.fill(CGRect(x:0,y:0,width:tile,height:tile))
            draw(composites[pose.name]!,CGRect(x:0,y:0,width:tile,height:tile),thumbnail,height:CGFloat(tile))
            save(thumbnail.makeImage()!,output+"/hanbok-assembled-\(pose.name)-\(points)pt-\(density)x-\(theme).png")
        }
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
        save(c.makeImage()!,output+"/hanbok-assembled-comparison-\(points)pt-\(density)x-\(theme).png")
    }}
    for pose in poses {
        let area: CGRect
        if pose.name.contains("step") {area=CGRect(x:400,y:1030,width:530,height:200)}
        else if pose.name.contains("sprout") {area=CGRect(x:90,y:120,width:1000,height:650)}
        else if pose.name.contains("right") || pose.name.contains("left") {area=CGRect(x:160,y:480,width:1090,height:570)}
        else {area=CGRect(x:465,y:530,width:445,height:270)}
        let c=context(800,650);c.setFillColor(color);c.fill(CGRect(x:0,y:0,width:800,height:650))
        let scale=min(800/area.width,650/area.height)
        draw(composites[pose.name]!,CGRect(x:-area.minX*scale,y:-area.minY*scale,width:CGFloat(size)*scale,height:CGFloat(size)*scale),c,height:650)
        save(c.makeImage()!,output+"/hanbok-assembled-joint-"+pose.name+"-"+theme+".png")
    }
}
print("ART QA Hanbok candidates, not an app rig: "+output)
