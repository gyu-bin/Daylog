import Foundation
import AppKit
import ImageIO
import CryptoKit
let root=CommandLine.arguments[1],input=CommandLine.arguments[2],output=CommandLine.arguments[3]
let size=1254
let fm=FileManager.default
try fm.createDirectory(atPath:output,withIntermediateDirectories:true)
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

let sourcePath=root+"/docs/qa/pio-outfit-phase2.2-2026-10-16/candidates/base/eye-half-v1.png"
let source=load(sourcePath)
var manifest=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:input+"/registration.json"))) as! [String:Any]
try Data(contentsOf:URL(fileURLWithPath:input+"/reference-registered.png")).write(to:URL(fileURLWithPath:output+"/reference-registered.png"))
var layers=manifest["layers"] as! [[String:Any]],images:[String:CGImage]=[:]
for part in layers {let id=part["id"] as! String;images[id]=load(input+"/"+id+".png");save(images[id]!,output+"/"+id+".png")}
var halfParts:[[String:Any]]=[]
for side in ["Left","Right"] {
    let id="half"+side,eye=images["eye"+side]!,target=bounds(eye,threshold:128).0
    // Match the visible globe's width and lower edge, not the large fur cap bounds.
    let scale=target.width/658
    let offset=CGPoint(x:target.midX-627*scale,y:target.maxY-1017*scale)
    let c=context(size,size)
    draw(source,CGRect(x:offset.x,y:offset.y,width:CGFloat(source.width)*scale,height:CGFloat(source.height)*scale),c,height:CGFloat(size))
    images[id]=c.makeImage()!;save(images[id]!,output+"/"+id+".png")
    halfParts.append(["id":id,"source":"candidates/base/eye-half-v1.png","scale":Double(scale),"offset":[Double(offset.x),Double(offset.y)],"pivot":[Double(target.midX),Double(target.midY)],"neutralAngleDegrees":0,"z":layers.count,"targetOpenEyeBounds":arr(target),"sourceGlobeWidth":658,"sourceGlobeBottom":1017])
}
let insertion=(layers.lastIndex { ($0["id"] as! String).hasPrefix("lid") } ?? layers.count-1)+1
layers.insert(contentsOf:halfParts,at:insertion)
for index in layers.indices {layers[index]["z"]=index}
manifest["layers"]=layers;manifest["status"]="HALF_EYE_ART_QA_PENDING";manifest["eyeHalfSourceSHA256"]=SHA256.hash(data:try Data(contentsOf:URL(fileURLWithPath:sourcePath))).map{String(format:"%02x",$0)}.joined()
try JSONSerialization.data(withJSONObject:manifest,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:output+"/registration.json"))
let audit:[String:Any]=["width":source.width,"height":source.height,"alpha":bounds(source,threshold:1).1,"boundsAlpha16":arr(bounds(source,threshold:16).0),"method":"Uniform registration of genuine independent source; no alpha cleanup or cap masking"]
try JSONSerialization.data(withJSONObject:audit,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:output+"/alpha-audit.json"))
var poses:[String:CGImage]=[:]
for state in ["open","half","closed"] {
    let c=context(size,size)
    for part in layers {
        let id=part["id"] as! String
        if id.hasPrefix("eye") && state != "open" {continue}
        if id.hasPrefix("half") && state != "half" {continue}
        if id.hasPrefix("lid") && state != "closed" {continue}
        let pivot=part["pivot"] as! [Double],angle=part["neutralAngleDegrees"] as? Double ?? 0
        c.saveGState();c.translateBy(x:pivot[0],y:Double(size)-pivot[1]);c.rotate(by:-angle * .pi/180);c.translateBy(x:-pivot[0],y:-(Double(size)-pivot[1]));c.draw(images[id]!,in:CGRect(x:0,y:0,width:size,height:size));c.restoreGState()
    }
    poses[state]=c.makeImage()!;save(poses[state]!,output+"/"+state+"-alpha.png")
}
for (theme,color) in [("light",CGColor(red:0.98,green:0.96,blue:0.91,alpha:1)),("dark",CGColor(red:0.07,green:0.11,blue:0.10,alpha:1))] {
    for state in ["open","half","closed"] {
        let c=context(size,size);c.setFillColor(color);c.fill(CGRect(x:0,y:0,width:size,height:size));c.draw(poses[state]!,in:CGRect(x:0,y:0,width:size,height:size));save(c.makeImage()!,output+"/"+state+"-"+theme+".png")
        let face=context(700,400);face.setFillColor(color);face.fill(CGRect(x:0,y:0,width:700,height:400));draw(poses[state]!,CGRect(x:-430*1.4,y:-520*1.4,width:CGFloat(size)*1.4,height:CGFloat(size)*1.4),face,height:400);save(face.makeImage()!,output+"/face-"+state+"-"+theme+".png")
    }
    for points in [64,220] {for density in [1,3] {
        let tile=points*density,gap=20*density,top=30*density,w=3*tile+4*gap,h=tile+top+gap
        let c=context(w,h);c.setFillColor(color);c.fill(CGRect(x:0,y:0,width:w,height:h))
        for (index,state) in ["open","half","closed"].enumerated() {
            let x=gap+index*(tile+gap);draw(poses[state]!,CGRect(x:x,y:top,width:tile,height:tile),c,height:CGFloat(h))
            NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(cgContext:c,flipped:false)
            (state as NSString).draw(at:NSPoint(x:x,y:h-top+4*density),withAttributes:[.font:NSFont.systemFont(ofSize:CGFloat(11*density)),.foregroundColor:theme=="dark" ? NSColor.white:NSColor.black]);NSGraphicsContext.restoreGraphicsState()
        }
        save(c.makeImage()!,output+"/comparison-\(points)pt-\(density)x-\(theme).png")
    }}
}
print(output)
