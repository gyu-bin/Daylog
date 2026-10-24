// QA-only compositor. Does not modify source artwork, app resources or manifests.
import Foundation
import AppKit
import ImageIO
import CryptoKit
let root = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath
let folder = root + "/output/pio-outfit-assets/cherryBlossom/v1"
let output = folder + "/registration-preview"
let base = root + "/docs/qa/pio-outfit-phase2.2-2026-10-16/candidates/base"
let size = 1254
try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
func load(_ path:String)->CGImage { let s=CGImageSourceCreateWithURL(URL(fileURLWithPath:path) as CFURL,nil)!;return CGImageSourceCreateImageAtIndex(s,0,nil)! }
func context(_ w:Int,_ h:Int)->CGContext { CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)! }
func save(_ image:CGImage,_ path:String) {let d=CGImageDestinationCreateWithURL(URL(fileURLWithPath:path) as CFURL,"public.png" as CFString,1,nil)!;CGImageDestinationAddImage(d,image,nil);precondition(CGImageDestinationFinalize(d))}
func draw(_ image:CGImage,_ rect:CGRect,_ c:CGContext,_ h:CGFloat){c.interpolationQuality = .high;c.draw(image,in:CGRect(x:rect.minX,y:h-rect.maxY,width:rect.width,height:rect.height))}
func alphaBounds(_ image:CGImage,_ threshold:UInt8=16)->CGRect {let c=context(image.width,image.height);c.draw(image,in:CGRect(x:0,y:0,width:image.width,height:image.height));let b=c.data!.assumingMemoryBound(to:UInt8.self);var x0=image.width,y0=image.height,x1 = -1,y1 = -1;for y in 0..<image.height {for x in 0..<image.width {if b[y*c.bytesPerRow+x*4+3]>=threshold{x0=min(x0,x);x1=max(x1,x);y0=min(y0,y);y1=max(y1,y)}}};return x1<0 ? .zero:CGRect(x:x0,y:y0,width:x1-x0+1,height:y1-y0+1)}
func arr(_ r:CGRect)->[Double]{[r.minX,r.minY,r.width,r.height].map(Double.init)}
struct Part {let id:String,path:String;let scale:CGFloat,offset:CGPoint,pivot:CGPoint;var angle:CGFloat=0;var image:CGImage{load(path)}}
func rooted(_ id:String,_ path:String,_ scale:CGFloat,_ sourceRoot:CGPoint,_ pivot:CGPoint,_ angle:CGFloat=0)->Part {Part(id:id,path:path,scale:scale,offset:CGPoint(x:pivot.x-sourceRoot.x*scale,y:pivot.y-sourceRoot.y*scale),pivot:pivot,angle:angle)}
func fit(_ id:String,_ path:String,_ rect:CGRect,_ pivot:CGPoint)->Part {let b=alphaBounds(load(path));let s=min(rect.width/b.width,rect.height/b.height);precondition(s<=1,"Source upscaling is not permitted");return Part(id:id,path:path,scale:s,offset:CGPoint(x:rect.minX-b.minX*s,y:rect.minY-b.minY*s),pivot:pivot)}
var parts:[Part]=[
 rooted("wingRight",folder+"/wing-right-candidate.png",0.25,CGPoint(x:250,y:1000),CGPoint(x:965,y:830)),
 fit("footLeft",base+"/foot-v1.png",CGRect(x:466,y:1073,width:152,height:114),CGPoint(x:540,y:1110)),
 fit("footRight",base+"/foot-v1.png",CGRect(x:748,y:1033,width:145,height:120),CGPoint(x:815,y:1075)),
 rooted("sprout",base+"/sprout-v1.png",0.385,CGPoint(x:790,y:935),CGPoint(x:620,y:400)),
 Part(id:"body",path:folder+"/body-v3-candidate.png",scale:1,offset:.zero,pivot:CGPoint(x:650,y:780)),
 fit("eyeLeft",base+"/eye-open-v1.png",CGRect(x:475,y:612,width:101,height:104),CGPoint(x:526,y:663)),
 fit("eyeRight",base+"/eye-open-v1.png",CGRect(x:762,y:574,width:100,height:103),CGPoint(x:812,y:625)),
 fit("lidLeft",base+"/eyelid-closed-v1.png",CGRect(x:474,y:654,width:103,height:38),CGPoint(x:526,y:673)),
 fit("lidRight",base+"/eyelid-closed-v1.png",CGRect(x:761,y:616,width:103,height:38),CGPoint(x:812,y:635)),
 rooted("wingLeft",folder+"/wing-left-candidate.png",0.26,CGPoint(x:900,y:260),CGPoint(x:310,y:790),-15)
]
// Match the approved raised right-foot pose with a local rigid rotation.
if let i=parts.firstIndex(where:{$0.id=="footRight"}) {parts[i].angle = -25}
// Both shoulder roots sit behind the clean body and baked cape.
if let i=parts.firstIndex(where:{$0.id=="wingLeft"}) {let wing=parts.remove(at:i);parts.insert(wing,at:0)}
// Half-eye alignment follows the established pipeline's authored globe landmarks.
for side in ["Left","Right"] {let e=parts.first{$0.id=="eye"+side}!;let b=alphaBounds(e.image,128);let target=CGRect(x:e.offset.x+b.minX*e.scale,y:e.offset.y+b.minY*e.scale,width:b.width*e.scale,height:b.height*e.scale);let s=target.width/658;parts.append(Part(id:"half"+side,path:base+"/eye-half-v1.png",scale:s,offset:CGPoint(x:target.midX-627*s,y:target.maxY-1017*s),pivot:CGPoint(x:target.midX,y:target.midY)))}
// A real separately generated flower is required; no replacement drawing is made here.
let flowerPath=folder+"/head-flower-candidate.png"
let hasFlower=FileManager.default.fileExists(atPath:flowerPath)
if hasFlower {parts.append(fit("headFlower",flowerPath,CGRect(x:668,y:265,width:221,height:190),CGPoint(x:765,y:390)))}
let referencePath=root+"/Daylog/PioWardrobe.xcassets/pio_outfit_cherryBlossom.imageset/pio_outfit_cherryBlossom.png"
let reference=load(referencePath)
let sourceHashes=Dictionary(uniqueKeysWithValues:Set(parts.map{$0.path}).map {p in (p,SHA256.hash(data:try! Data(contentsOf:URL(fileURLWithPath:p))).map{String(format:"%02x",$0)}.joined())})
let manifest:[String:Any]=["schemaVersion":1,"canvas":[size,size],"origin":"topLeft","status":"QA_CANDIDATE_NOT_APPROVED","sourceReference":referencePath,"referenceTransform":"identity","missingParts":hasFlower ? []:["headFlower"],"method":"QA compositor using unchanged full-resolution generated source artwork, uniform downscale/translation and measured candidate pivots; no alpha masks, painting or low-resolution crops","notes":["Manual landmark registration requires visual approval","Cape and front bow remain baked into body","Not a runtime resource manifest; no app integration","New body and wings are reconstruction candidates, not pixel-identical approved originals"],"layers":parts.enumerated().map {i,p in ["id":p.id,"source":p.path,"sourceSHA256":sourceHashes[p.path]!,"scale":Double(p.scale),"offset":[Double(p.offset.x),Double(p.offset.y)],"pivot":[Double(p.pivot.x),Double(p.pivot.y)],"neutralAngleDegrees":Double(p.angle),"z":i] as [String:Any]}]
try JSONSerialization.data(withJSONObject:manifest,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:output+"/registration-candidate.json"))
func assemble(_ state:String="open",_ wingAngle:CGFloat=0)->CGImage {let c=context(size,size);for p in parts {if p.id.hasPrefix("eye") && state != "open" {continue};if p.id.hasPrefix("lid") && state != "closed" {continue};if p.id.hasPrefix("half") && state != "half" {continue};c.saveGState();c.translateBy(x:p.pivot.x,y:CGFloat(size)-p.pivot.y);c.rotate(by:-(p.angle+(p.id.hasPrefix("wing") ? wingAngle:0)) * .pi/180);c.translateBy(x:-p.pivot.x,y:-(CGFloat(size)-p.pivot.y));let image=p.image;draw(image,CGRect(x:p.offset.x,y:p.offset.y,width:CGFloat(image.width)*p.scale,height:CGFloat(image.height)*p.scale),c,CGFloat(size));c.restoreGState()};return c.makeImage()!}
let poses:[(String,CGImage)]=[("neutral",assemble()),("half",assemble("half")),("closed",assemble("closed")),("wings-minus12",assemble("open",-12)),("wings-plus12",assemble("open",12))]
for (name,image) in poses {save(image,output+"/"+name+"-alpha.png")}
for (theme,color) in [("light",CGColor(red:0.98,green:0.96,blue:0.91,alpha:1)),("dark",CGColor(red:0.07,green:0.11,blue:0.10,alpha:1))] {
 for (name,image) in poses {let c=context(size,size);c.setFillColor(color);c.fill(CGRect(x:0,y:0,width:size,height:size));c.draw(image,in:CGRect(x:0,y:0,width:size,height:size));save(c.makeImage()!,output+"/"+name+"-"+theme+".png")}
 for points in [64,220] {let density=3,tile=points*density,gap=20*density,top=36*density;let images=[("Approved original",reference)]+poses.map{($0.0,$0.1)};let w=images.count*(tile+gap)+gap,h=tile+top+gap;let c=context(w,h);c.setFillColor(color);c.fill(CGRect(x:0,y:0,width:w,height:h));for (i,item) in images.enumerated(){let x=gap+i*(tile+gap);draw(item.1,CGRect(x:x,y:top,width:tile,height:tile),c,CGFloat(h));NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(cgContext:c,flipped:false);(item.0 as NSString).draw(at:NSPoint(x:x,y:h-top+10),withAttributes:[.font:NSFont.systemFont(ofSize:CGFloat(10*density)),.foregroundColor:theme=="dark" ? NSColor.white:NSColor.black]);NSGraphicsContext.restoreGraphicsState()};save(c.makeImage()!,output+"/comparison-\(points)pt-3x-\(theme).png")}
}
print("QA candidate renders saved to "+output+"; headFlower present: \(hasFlower)")
