// QA-only compositor. Does not modify source artwork, app resources or manifests.
import Foundation
import AppKit
import ImageIO
import CryptoKit
let root = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath
let folder = root + "/output/pio-character-overhaul-artwork/winter-v1"
let output = folder + "/registration"
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
let source=folder+"/source"
var parts:[Part]=[
rooted("wingRight",source+"/wing-right-candidate.png",0.25,CGPoint(x:350,y:1000),CGPoint(x:975,y:915)),
 rooted("wingLeft",source+"/wing-left-candidate.png",0.25,CGPoint(x:1000,y:400),CGPoint(x:430,y:865)),
 fit("footLeft",base+"/foot-v1.png",CGRect(x:425,y:1085,width:165,height:125),CGPoint(x:500,y:1130)),
 fit("footRight",base+"/foot-v1.png",CGRect(x:740,y:1085,width:155,height:118),CGPoint(x:815,y:1130)),
 Part(id:"body",path:source+"/body-candidate.png",scale:0.93,offset:CGPoint(x:45,y:84),pivot:CGPoint(x:650,y:800)),
 fit("eyeLeft",base+"/eye-open-v1.png",CGRect(x:459,y:632,width:103,height:113),CGPoint(x:510,y:688)),
 fit("eyeRight",base+"/eye-open-v1.png",CGRect(x:747,y:595,width:100,height:110),CGPoint(x:797,y:650)),
 fit("headwear",source+"/headwear-candidate.png",CGRect(x:200,y:20,width:900,height:790),CGPoint(x:650,y:430))
]
if let i=parts.firstIndex(where:{$0.id=="wingLeft"}) {let arm=parts.remove(at:i);parts.insert(arm,at:4)}
for side in ["Left","Right"] {let e=parts.first{$0.id=="eye"+side}!;let b=alphaBounds(e.image,128);let t=CGRect(x:e.offset.x+b.minX*e.scale,y:e.offset.y+b.minY*e.scale,width:b.width*e.scale,height:b.height*e.scale);let v=t.width/658;parts.append(Part(id:"half"+side,path:base+"/eye-half-v1.png",scale:v,offset:CGPoint(x:t.midX-627*v,y:t.maxY-1017*v),pivot:CGPoint(x:t.midX,y:t.midY)));parts.append(fit("lid"+side,base+"/eyelid-closed-v1.png",CGRect(x:t.minX,y:t.midY,width:t.width,height:t.width*0.38),CGPoint(x:t.midX,y:t.midY)))}
let referencePath=root+"/Daylog/PioWardrobe.xcassets/pio_outfit_winter.imageset/pio_outfit_winter.png"
let reference=load(referencePath)
let sourceHashes=Dictionary(uniqueKeysWithValues:Set(parts.map{$0.path}).map {p in (p,SHA256.hash(data:try! Data(contentsOf:URL(fileURLWithPath:p))).map{String(format:"%02x",$0)}.joined())})
let manifest:[String:Any]=["status":"QA_CANDIDATE_NOT_APPROVED","canvas":[1254,1254],"origin":"topLeft","original":referencePath,"parts":parts.enumerated().map{i,p in ["id":p.id,"source":p.path,"sourceSHA256":sourceHashes[p.path]!,"scale":Double(p.scale),"offset":[Double(p.offset.x),Double(p.offset.y)],"pivot":[Double(p.pivot.x),Double(p.pivot.y)],"angle":Double(p.angle),"z":i] as [String:Any]},"notes":["Headwear and sprout are one genuine texture","Scarf stays baked in clean body; no independent fabric motion","Native artwork source alpha unchanged; uniform downscales and rigid transforms only","Shared eye/lid/feet originals reused and not newly authored"]]
try JSONSerialization.data(withJSONObject:manifest,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:output+"/registration-candidate.json"))
func drawPart(_ p:Part,_ c:CGContext,_ angle:CGFloat=0,_ lift:CGFloat=0){c.saveGState();c.translateBy(x:0,y:-lift);c.translateBy(x:p.pivot.x,y:CGFloat(size)-p.pivot.y);c.rotate(by:-(p.angle+angle) * .pi/180);c.translateBy(x:-p.pivot.x,y:-(CGFloat(size)-p.pivot.y));let im=p.image;draw(im,CGRect(x:p.offset.x,y:p.offset.y,width:CGFloat(im.width)*p.scale,height:CGFloat(im.height)*p.scale),c,CGFloat(size));c.restoreGState()}
func assemble(_ state:String="open",_ wingAngle:CGFloat=0,_ gripAngle:CGFloat=0)->CGImage {let c=context(size,size);for p in parts {if p.id.hasPrefix("eye") && state != "open"{continue};if p.id.hasPrefix("lid") && state != "closed"{continue};if p.id.hasPrefix("half") && state != "half"{continue};let a=p.id=="wingRight" ? wingAngle:(["wingLeft","leaf"].contains(p.id) ? gripAngle:0);drawPart(p,c,a)};return c.makeImage()!}
let poses:[(String,CGImage)]=[("neutral",assemble()),("half",assemble("half")),("closed",assemble("closed")),("right-minus12",assemble("open",-12)),("right-plus12",assemble("open",12)),("left-minus12",assemble("open",0,-12)),("left-plus12",assemble("open",0,12))]
for(name,im)in poses{save(im,output+"/"+name+"-alpha.png")}
for(theme,color)in[("light",CGColor(red:0.98,green:0.96,blue:0.91,alpha:1)),("dark",CGColor(red:0.07,green:0.11,blue:0.10,alpha:1))]{for(name,im)in poses{let c=context(size,size);c.setFillColor(color);c.fill(CGRect(x:0,y:0,width:size,height:size));c.draw(im,in:CGRect(x:0,y:0,width:size,height:size));save(c.makeImage()!,output+"/"+name+"-"+theme+".png")};for points in [64,220]{let tile=points*3,gap=60,top=108;let images=[("Original",reference)]+poses;let w=images.count*(tile+gap)+gap,h=tile+top+gap;let c=context(w,h);c.setFillColor(color);c.fill(CGRect(x:0,y:0,width:w,height:h));for(i,item)in images.enumerated(){let x=gap+i*(tile+gap);draw(item.1,CGRect(x:x,y:top,width:tile,height:tile),c,CGFloat(h));NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(cgContext:c,flipped:false);(item.0 as NSString).draw(at:NSPoint(x:x,y:h-top+10),withAttributes:[.font:NSFont.systemFont(ofSize:20),.foregroundColor:theme=="dark" ? NSColor.white:NSColor.black]);NSGraphicsContext.restoreGraphicsState()};save(c.makeImage()!,output+"/comparison-\(points)pt-3x-\(theme).png")}}
var alphaAudit:[[String:Any]]=[]
for path in Set(parts.map{$0.path}){let im=load(path);let c=context(im.width,im.height);c.draw(im,in:CGRect(x:0,y:0,width:im.width,height:im.height));let b=c.data!.assumingMemoryBound(to:UInt8.self);var zero=0,partial=0,opaque=0;for y in 0..<im.height{for x in 0..<im.width{let a=b[y*c.bytesPerRow+x*4+3];if a==0{zero+=1}else if a==255{opaque+=1}else{partial+=1}}};alphaAudit.append(["source":path,"sourceSHA256":sourceHashes[path]!,"width":im.width,"height":im.height,"alphaZero":zero,"alphaPartial":partial,"alphaOpaque":opaque,"alpha16Bounds":arr(alphaBounds(im))])}
try JSONSerialization.data(withJSONObject:alphaAudit,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:output+"/source-alpha-audit.json"))
print("Candidate renders complete: "+output)
