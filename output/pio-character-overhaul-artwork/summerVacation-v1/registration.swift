// QA-only compositor. Does not modify source artwork, app resources or manifests.
import Foundation
import AppKit
import ImageIO
import CryptoKit
let root = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath
let folder = root + "/output/pio-character-overhaul-artwork/summerVacation-v1"
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
 fit("footLeft",base+"/foot-v1.png",CGRect(x:445,y:1090,width:165,height:125),CGPoint(x:520,y:1135)),
 fit("footRight",base+"/foot-v1.png",CGRect(x:750,y:1110,width:140,height:105),CGPoint(x:815,y:1145)),
 Part(id:"body",path:source+"/body-candidate.png",scale:1,offset:.zero,pivot:CGPoint(x:650,y:800)),
 fit("eyeLeft",base+"/eye-open-v1.png",CGRect(x:485,y:575,width:110,height:120),CGPoint(x:540,y:635)),
 fit("eyeRight",base+"/eye-open-v1.png",CGRect(x:790,y:530,width:110,height:120),CGPoint(x:845,y:590)),
 fit("sunglasses",source+"/sunglasses-candidate.png",CGRect(x:290,y:500,width:685,height:255),CGPoint(x:650,y:625)),
 rooted("wingLeft",source+"/wing-left-candidate.png",0.26,CGPoint(x:1100,y:550),CGPoint(x:360,y:885)),
 fit("drink",source+"/drink-candidate.png",CGRect(x:930,y:605,width:270,height:355),CGPoint(x:1000,y:930)),
 rooted("wingRight",source+"/wing-right-candidate.png",0.22,CGPoint(x:300,y:650),CGPoint(x:1000,y:930),-35),
 fit("headwear",source+"/headwear-v2-candidate.png",CGRect(x:170,y:88.5,width:931,height:698.25),CGPoint(x:650,y:440))
]
if let i=parts.firstIndex(where:{$0.id=="wingRight"}) {let arm=parts.remove(at:i);parts.insert(arm,at:2)}
let referencePath=root+"/Daylog/PioWardrobe.xcassets/pio_outfit_summerVacation.imageset/pio_outfit_summerVacation.png"
let reference=load(referencePath)
func assemble(_ left:CGFloat=0,_ drink:CGFloat=0,_ lift:CGFloat=0)->CGImage {let c=context(size,size);for p in parts {let grip=["wingRight","drink"].contains(p.id);let angle=p.angle+(p.id=="wingLeft" ? left:0)+(grip ? drink:0);c.saveGState();if grip {c.translateBy(x:0,y:-lift)};c.translateBy(x:p.pivot.x,y:CGFloat(size)-p.pivot.y);c.rotate(by:-angle * .pi/180);c.translateBy(x:-p.pivot.x,y:-(CGFloat(size)-p.pivot.y));let im=p.image;draw(im,CGRect(x:p.offset.x,y:p.offset.y,width:CGFloat(im.width)*p.scale,height:CGFloat(im.height)*p.scale),c,CGFloat(size));c.restoreGState()};return c.makeImage()!}
let poses:[(String,CGImage)]=[("neutral",assemble()),("wing-minus12",assemble(-12)),("wing-plus12",assemble(12)),("drink-raised",assemble(0,-6,-25))]
for (name,im) in poses {save(im,output+"/"+name+"-alpha.png")}
let sourceHashes=Dictionary(uniqueKeysWithValues:Set(parts.map{$0.path}).map {p in (p,SHA256.hash(data:try! Data(contentsOf:URL(fileURLWithPath:p))).map{String(format:"%02x",$0)}.joined())})
let manifest:[String:Any]=["status":"QA_CANDIDATE_NOT_APPROVED","canvas":[1254,1254],"origin":"topLeft","original":referencePath,"parts":parts.enumerated().map{i,p in ["id":p.id,"source":p.path,"sourceSHA256":sourceHashes[p.path]!,"scale":Double(p.scale),"offset":[Double(p.offset.x),Double(p.offset.y)],"pivot":[Double(p.pivot.x),Double(p.pivot.y)],"angle":Double(p.angle),"z":i] as [String:Any]},"grip":["parts":["drink","wingRight"],"pivot":[1000,930],"endpointAngleDegrees":-6,"endpointTranslation":[0,-25]],"notes":["Hat and sprout are combined; no independent sprout motion","Whole source alpha preserved","Only uniformly downscaled full source art","Eye blinking not evidenced behind sunglasses"]]
try JSONSerialization.data(withJSONObject:manifest,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:output+"/registration-candidate.json"))
for (theme,color) in [("light",CGColor(red:0.98,green:0.96,blue:0.91,alpha:1)),("dark",CGColor(red:0.07,green:0.11,blue:0.10,alpha:1))] {
 for (name,im) in poses {let c=context(size,size);c.setFillColor(color);c.fill(CGRect(x:0,y:0,width:size,height:size));c.draw(im,in:CGRect(x:0,y:0,width:size,height:size));save(c.makeImage()!,output+"/"+name+"-"+theme+".png")}
 for points in [64,220] {let tile=points*3,gap=60,top=108;let images=[("Original",reference)]+poses;let w=images.count*(tile+gap)+gap,h=tile+top+gap;let c=context(w,h);c.setFillColor(color);c.fill(CGRect(x:0,y:0,width:w,height:h));for(i,item)in images.enumerated(){let x=gap+i*(tile+gap);draw(item.1,CGRect(x:x,y:top,width:tile,height:tile),c,CGFloat(h));NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(cgContext:c,flipped:false);(item.0 as NSString).draw(at:NSPoint(x:x,y:h-top+10),withAttributes:[.font:NSFont.systemFont(ofSize:24),.foregroundColor:theme=="dark" ? NSColor.white:NSColor.black]);NSGraphicsContext.restoreGraphicsState()};save(c.makeImage()!,output+"/comparison-\(points)pt-3x-\(theme).png")}
}
// Separate optional empty-frame proposal; primary tinted artwork is unchanged.
let primaryParts=parts
let optionalFrame=fit("sunglasses",source+"/sunglasses-frame-only-candidate.png",CGRect(x:290,y:500,width:685,height:255),CGPoint(x:650,y:625))
parts=parts.map {p in
 if p.id=="sunglasses" {return optionalFrame}
 if p.id=="eyeLeft" {return fit("eyeLeft",base+"/eye-open-v1.png",CGRect(x:475,y:590,width:110,height:120),CGPoint(x:530,y:650))}
 if p.id=="eyeRight" {return fit("eyeRight",base+"/eye-open-v1.png",CGRect(x:760,y:540,width:110,height:120),CGPoint(x:815,y:600))}
 return p
}
let optionalOpen=assemble()
let optionalOpenParts=parts
parts=parts.map {p in
 if p.id=="eyeLeft" {return fit("eyeLeft",base+"/eyelid-closed-v1.png",CGRect(x:475,y:635,width:110,height:38),CGPoint(x:530,y:654))}
 if p.id=="eyeRight" {return fit("eyeRight",base+"/eyelid-closed-v1.png",CGRect(x:760,y:585,width:110,height:38),CGPoint(x:815,y:604))}
 return p
}
let optionalClosed=assemble()
let optionalParts=parts
parts=primaryParts
save(optionalOpen,output+"/optional-frame-open-alpha.png");save(optionalClosed,output+"/optional-frame-closed-alpha.png")
let optionalManifest:[String:Any] = ["status":"OPTIONAL_DESIGN_NOT_APPROVED","notes":["Lens tint absent; genuine empty frame and eyes are separate","Does not replace primary sunglasses","Static eye states only; no native blink proof"],"layers":(optionalOpenParts+optionalParts.filter{$0.id.hasPrefix("eye")}).map{p in ["id":p.id,"source":p.path,"sourceSHA256":SHA256.hash(data:try! Data(contentsOf:URL(fileURLWithPath:p.path))).map{String(format:"%02x",$0)}.joined(),"scale":Double(p.scale),"offset":[Double(p.offset.x),Double(p.offset.y)],"pivot":[Double(p.pivot.x),Double(p.pivot.y)]] as [String:Any]}]
try JSONSerialization.data(withJSONObject:optionalManifest,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:output+"/optional-frame-registration.json"))
for (theme,color) in [("light",CGColor(red:0.98,green:0.96,blue:0.91,alpha:1)),("dark",CGColor(red:0.07,green:0.11,blue:0.10,alpha:1))] {
 for (name,im) in [("open",optionalOpen),("closed",optionalClosed)] {let c=context(size,size);c.setFillColor(color);c.fill(CGRect(x:0,y:0,width:size,height:size));c.draw(im,in:CGRect(x:0,y:0,width:size,height:size));save(c.makeImage()!,output+"/optional-frame-"+name+"-"+theme+".png")}
 for points in [64,220] {let tile=points*3,gap=60,top=108;let images=[("Original",reference),("Opaque lens",poses[0].1),("Frame open",optionalOpen),("Frame closed",optionalClosed)];let w=images.count*(tile+gap)+gap,h=tile+top+gap;let c=context(w,h);c.setFillColor(color);c.fill(CGRect(x:0,y:0,width:w,height:h));for(i,item)in images.enumerated(){let x=gap+i*(tile+gap);draw(item.1,CGRect(x:x,y:top,width:tile,height:tile),c,CGFloat(h));NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(cgContext:c,flipped:false);(item.0 as NSString).draw(at:NSPoint(x:x,y:h-top+10),withAttributes:[.font:NSFont.systemFont(ofSize:24),.foregroundColor:theme=="dark" ? NSColor.white:NSColor.black]);NSGraphicsContext.restoreGraphicsState()};save(c.makeImage()!,output+"/optional-frame-comparison-\(points)pt-3x-\(theme).png")}
}
var alphaAudit:[[String:Any]]=[]
for path in Set((parts+optionalOpenParts+optionalParts).map{$0.path}) {let im=load(path);let c=context(im.width,im.height);c.draw(im,in:CGRect(x:0,y:0,width:im.width,height:im.height));let b=c.data!.assumingMemoryBound(to:UInt8.self);var transparent=0,partial=0,opaque=0;for y in 0..<im.height{for x in 0..<im.width{let a=b[y*c.bytesPerRow+x*4+3];if a==0{transparent+=1}else if a==255{opaque+=1}else{partial+=1}}};alphaAudit.append(["source":path,"sourceSHA256":SHA256.hash(data:try! Data(contentsOf:URL(fileURLWithPath:path))).map{String(format:"%02x",$0)}.joined(),"width":im.width,"height":im.height,"alphaZero":transparent,"alphaPartial":partial,"alphaOpaque":opaque,"alpha16Bounds":arr(alphaBounds(im))])}
try JSONSerialization.data(withJSONObject:alphaAudit,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:output+"/source-alpha-audit.json"))
print("Summer QA candidate complete")
