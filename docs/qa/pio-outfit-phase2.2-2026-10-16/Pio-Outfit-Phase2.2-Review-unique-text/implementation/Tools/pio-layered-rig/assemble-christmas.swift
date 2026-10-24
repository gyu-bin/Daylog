import Foundation
import AppKit
import ImageIO
import CryptoKit

let args = CommandLine.arguments
let root = args.count > 1 ? args[1] : FileManager.default.currentDirectoryPath
let qa = root + "/docs/qa/pio-outfit-phase2.2-2026-10-16"
let output = args.count > 2 ? args[2] : qa + "/registered/christmas-a"
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
let names=["body-clean","hat","gift","hand-left","hand-right","eye-open","eyelid-closed","foot","sprout"] + (args.contains("--headwear-v2") ? ["headwear"] : [])
var sources:[String:CGImage]=[:], audits:[[String:Any]]=[]
var sourceFiles:[String:String]=[:]
for name in names {
    let folder = ["eye-open","eyelid-closed","foot","sprout"].contains(name) ? "base" : "christmas"
    let version = (name.hasPrefix("hand-") && args.contains("--hands-v2")) || name == "headwear" ? "v2" : "v1"
    let path=qa+"/candidates/"+folder+"/"+name+"-"+version+".png", image=load(path)
    sourceFiles[name] = "candidates/"+folder+"/"+name+"-"+version+".png"
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
var parts:[Part] = [
    fit("footLeft","foot",CGRect(x:442,y:1050,width:165,height:145),CGPoint(x:530,y:1070)),
    fit("footRight","foot",CGRect(x:740,y:1060,width:150,height:131),CGPoint(x:817,y:1070)),
    fit("body","body-clean",CGRect(x:185,y:330,width:900,height:812),CGPoint(x:650,y:780)),
    fit("hat","hat",CGRect(x:115,y:125,width:930,height:590),CGPoint(x:660,y:450)),
    Part(id:"sprout",source:"sprout",scale:0.31,offset:CGPoint(x:650-790*0.31,y:330-935*0.31),pivot:CGPoint(x:650,y:330)),
    fit("eyeLeft","eye-open",CGRect(x:502,y:602,width:98,height:101),CGPoint(x:551,y:652)),
    fit("eyeRight","eye-open",CGRect(x:785,y:569,width:96,height:99),CGPoint(x:833,y:618)),
    fit("lidLeft","eyelid-closed",CGRect(x:500,y:639,width:102,height:38),CGPoint(x:551,y:658)),
    fit("lidRight","eyelid-closed",CGRect(x:783,y:604,width:100,height:37),CGPoint(x:833,y:622)),
    fit("gift","gift",CGRect(x:750,y:715,width:275,height:297),CGPoint(x:790,y:925)),
    fit("handLeft","hand-left",CGRect(x:360,y:710,width:405,height:326),CGPoint(x:430,y:770)),
    fit("handRight","hand-right",CGRect(x:895,y:750,width:180,height:170),CGPoint(x:1040,y:780))
]
if args.contains("--hands-v2") {
    parts[10] = fit("handLeft","hand-left",CGRect(x:468,y:790,width:330,height:230),CGPoint(x:513,y:870))
    parts[11] = Part(id:"handRight",source:"hand-right",scale:0.26,offset:CGPoint(x:790,y:634),pivot:CGPoint(x:1050,y:790))
}
if args.contains("--headwear-v2") {
    parts[3] = fit("hat","headwear",CGRect(x:100,y:40,width:950,height:700),CGPoint(x:660,y:450))
    parts.remove(at:4)
}
let rightNeutralAngle: CGFloat = args.contains("--hands-v2") ? -60 : -25
if args.contains("--sprout-behind-hat") { parts.swapAt(3,4) }
var registered:[String:CGImage]=[:]
for p in parts {let image=p.registered;registered[p.id]=image;save(image,output+"/"+p.id+".png")}
let referencePath=root+"/Daylog/PioWardrobe.xcassets/pio_outfit_christmas.imageset/pio_outfit_christmas.png"
let reference=load(referencePath)
precondition(reference.width==size && reference.height==size)
save(reference,output+"/reference-registered.png")
let manifest:[String:Any] = ["schemaVersion":1,"status":"ART_QA_CANDIDATE_NOT_APPROVED","canvas":[size,size],"origin":"topLeft","sourceReference":referencePath,"referenceScale":1,"referenceOffset":[0,0],"registrationMethod":"Independent uniform downscale/translation; no painting, alpha cleanup or source deformation", "hasIndependentSprout": !args.contains("--headwear-v2"), "headwearMotion": "Entire genuine headwear texture rotates locally; no separate leaf or pom motion is claimed", "giftConstraint":"gift and handLeft share translation; handRight may move independently only while leftgrip continues to carry gift", "layers":parts.map{p in ["id":p.id,"source":sourceFiles[p.source]!,"scale":Double(p.scale),"offset":[Double(p.offset.x),Double(p.offset.y)],"pivot":[Double(p.pivot.x),Double(p.pivot.y)],"neutralAngleDegrees":p.id == "handRight" ? rightNeutralAngle : 0,"z":parts.firstIndex(where:{$0.id==p.id})!] as [String:Any]}]
let manifestData=try JSONSerialization.data(withJSONObject:manifest,options:[.prettyPrinted,.sortedKeys])
try manifestData.write(to:URL(fileURLWithPath:output+"/registration.json"))
struct Pose {
    let name:String
    var closed=false
    var angles:[String:CGFloat]=[:]
    var offsets:[String:CGPoint]=[:]
}
let poses=[Pose(name:"grip-flap-minus6",angles:["handLeft":-6,"gift":-6,"handRight":12]),Pose(name:"grip-flap-plus6",angles:["handLeft":6,"gift":6,"handRight":-12]),Pose(name:"neutral"),Pose(name:"closed",closed:true),Pose(name:"right-minus12",angles:["handRight":-12]),Pose(name:"right-plus12",angles:["handRight":12]),Pose(name:"hat-minus4",angles:["hat":-4]),Pose(name:"hat-plus4",angles:["hat":4]),Pose(name:"grip-up",offsets:["gift":CGPoint(x:-4,y:-8),"handLeft":CGPoint(x:-4,y:-8)]),Pose(name:"grip-down",offsets:["gift":CGPoint(x:4,y:8),"handLeft":CGPoint(x:4,y:8)]),Pose(name:"step-left",angles:["footLeft":-8],offsets:["footLeft":CGPoint(x:-5,y:-18)]),Pose(name:"step-right",angles:["footRight":8],offsets:["footRight":CGPoint(x:5,y:-18)])]
let poseData:[[String:Any]]=poses.map{pose in ["name":pose.name,"closedEyes":pose.closed,"anglesDegrees":pose.angles.mapValues(Double.init),"translations":pose.offsets.mapValues{[Double($0.x),Double($0.y)]},"bodyTransform":"identity","leftGripRotationPivot":pose.name.hasPrefix("grip-flap") ? [513,870] : []]}
try JSONSerialization.data(withJSONObject:poseData,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:output+"/poses.json"))
func assemble(_ pose:Pose)->CGImage {
    let c=context(size,size)
    for p in parts {
        if p.id.hasPrefix("eye") && pose.closed {continue}
        if p.id.hasPrefix("lid") && !pose.closed {continue}
        c.saveGState()
        let move=pose.offsets[p.id] ?? .zero
        c.translateBy(x:move.x,y:-move.y)
        let pivot = pose.name.hasPrefix("grip-flap") && ["gift","handLeft"].contains(p.id) ? CGPoint(x:513,y:870) : p.pivot
        c.translateBy(x:pivot.x,y:CGFloat(size)-pivot.y)
        c.rotate(by:-((pose.angles[p.id] ?? 0) + (p.id == "handRight" ? rightNeutralAngle : 0)) * .pi/180)
        c.translateBy(x:-pivot.x,y:-(CGFloat(size)-pivot.y))
        c.draw(registered[p.id]!,in:CGRect(x:0,y:0,width:size,height:size))
        c.restoreGState()
    }
    return c.makeImage()!
}
let backgrounds:[(String,CGColor)]=[("light",CGColor(red:0.98,green:0.96,blue:0.91,alpha:1)),("dark",CGColor(red:0.07,green:0.11,blue:0.10,alpha:1))]
var composites:[String:CGImage]=[:]
for pose in poses {let image=assemble(pose);composites[pose.name]=image;save(image,output+"/christmas-assembled-"+pose.name+"-alpha.png")}
for (theme,color) in backgrounds {
    for (name,img) in [("reference",reference)] + poses.map({($0.name,composites[$0.name]!)}) {
        let c=context(size,size);c.setFillColor(color);c.fill(CGRect(x:0,y:0,width:size,height:size));c.draw(img,in:CGRect(x:0,y:0,width:size,height:size))
        save(c.makeImage()!,output+"/christmas-assembled-"+name+"-"+theme+".png")
    }
    for points in [64,220] {for density in [1,3] {
        let tile=points*density,gap=24*density,top=32*density
        for pose in poses {
            let thumbnail=context(tile,tile)
            thumbnail.setFillColor(color);thumbnail.fill(CGRect(x:0,y:0,width:tile,height:tile))
            draw(composites[pose.name]!,CGRect(x:0,y:0,width:tile,height:tile),thumbnail,height:CGFloat(tile))
            save(thumbnail.makeImage()!,output+"/christmas-assembled-\(pose.name)-\(points)pt-\(density)x-\(theme).png")
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
        save(c.makeImage()!,output+"/christmas-assembled-comparison-\(points)pt-\(density)x-\(theme).png")
    }}
    for pose in poses {
        let area: CGRect
        if pose.name.contains("step") {area=CGRect(x:400,y:1030,width:530,height:200)}
        else if pose.name.contains("hat") {area=CGRect(x:90,y:120,width:1000,height:650)}
        else if pose.name.contains("right") || pose.name.contains("grip") {area=CGRect(x:330,y:690,width:830,height:430)}
        else {area=CGRect(x:465,y:530,width:445,height:270)}
        let c=context(800,650);c.setFillColor(color);c.fill(CGRect(x:0,y:0,width:800,height:650))
        let scale=min(800/area.width,650/area.height)
        draw(composites[pose.name]!,CGRect(x:-area.minX*scale,y:-area.minY*scale,width:CGFloat(size)*scale,height:CGFloat(size)*scale),c,height:650)
        save(c.makeImage()!,output+"/christmas-assembled-joint-"+pose.name+"-"+theme+".png")
    }
}
print("ART QA Christmas candidates, not an app rig: "+output)
