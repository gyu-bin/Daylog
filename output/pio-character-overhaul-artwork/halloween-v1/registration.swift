// Candidate-only full-source rigid registration. No source edits, masks, cleanup or painting.
import Foundation
import AppKit
import ImageIO
import CryptoKit
let root=FileManager.default.currentDirectoryPath
let folder=root+"/output/pio-character-overhaul-artwork/halloween-v1"
let output=folder+"/registration",registered=folder+"/registered-layers"
let base=root+"/docs/qa/pio-outfit-phase2.2-2026-10-16/candidates/base"
let size=1254
for path in [output,registered]{try FileManager.default.createDirectory(atPath:path,withIntermediateDirectories:true)}
func load(_ path:String)->CGImage{CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(URL(fileURLWithPath:path) as CFURL,nil)!,0,nil)!}
func context(_ w:Int,_ h:Int)->CGContext{CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!}
func save(_ image:CGImage,_ path:String){let d=CGImageDestinationCreateWithURL(URL(fileURLWithPath:path) as CFURL,"public.png" as CFString,1,nil)!;CGImageDestinationAddImage(d,image,nil);precondition(CGImageDestinationFinalize(d))}
func hash(_ p:String)->String{SHA256.hash(data:try! Data(contentsOf:URL(fileURLWithPath:p))).map{String(format:"%02x",$0)}.joined()}
func draw(_ im:CGImage,_ r:CGRect,_ c:CGContext,_ h:CGFloat){c.interpolationQuality = .high;c.draw(im,in:CGRect(x:r.minX,y:h-r.maxY,width:r.width,height:r.height))}
func bounds(_ im:CGImage,_ threshold:UInt8=16)->CGRect{let c=context(im.width,im.height);c.draw(im,in:CGRect(x:0,y:0,width:im.width,height:im.height));let b=c.data!.assumingMemoryBound(to:UInt8.self);var x0=im.width,y0=im.height,x1 = -1,y1 = -1;for y in 0..<im.height{for x in 0..<im.width{if b[y*c.bytesPerRow+x*4+3]>=threshold{x0=min(x0,x);x1=max(x1,x);y0=min(y0,y);y1=max(y1,y)}}};return CGRect(x:x0,y:y0,width:x1-x0+1,height:y1-y0+1)}
struct Part{let id,path:String;let scale:CGFloat,offset,pivot:CGPoint;var angle:CGFloat=0}
func fit(_ id:String,_ p:String,_ r:CGRect,_ pivot:CGPoint)->Part{let b=bounds(load(p));let s=min(r.width/b.width,r.height/b.height);precondition(s<=1);return Part(id:id,path:p,scale:s,offset:CGPoint(x:r.minX-b.minX*s,y:r.minY-b.minY*s),pivot:pivot)}
func rooted(_ id:String,_ p:String,_ s:CGFloat,_ source:CGPoint,_ pivot:CGPoint,_ angle:CGFloat=0)->Part{precondition(s<=1);return Part(id:id,path:p,scale:s,offset:CGPoint(x:pivot.x-source.x*s,y:pivot.y-source.y*s),pivot:pivot,angle:angle)}
let source=folder+"/source"
var parts:[Part]=[
fit("footLeft",base+"/foot-v1.png",CGRect(x:425,y:1075,width:180,height:130),CGPoint(x:500,y:1150)),
fit("footRight",base+"/foot-v1.png",CGRect(x:725,y:1075,width:165,height:125),CGPoint(x:800,y:1150)),
Part(id:"body",path:source+"/body-candidate.png",scale:1,offset:.zero,pivot:CGPoint(x:640,y:800)),
fit("eyeLeft",base+"/eye-open-v1.png",CGRect(x:475,y:610,width:100,height:105),CGPoint(x:525,y:662)),
fit("eyeRight",base+"/eye-open-v1.png",CGRect(x:765,y:568,width:100,height:105),CGPoint(x:815,y:620)),
fit("headwear",source+"/headwear-candidate.png",CGRect(x:230,y:45,width:785,height:615),CGPoint(x:630,y:470)),
rooted("wingLeft",source+"/wing-left-candidate.png",0.20,CGPoint(x:850,y:950),CGPoint(x:300,y:850)),
rooted("wingRight",source+"/wing-right-candidate.png",0.23,CGPoint(x:450,y:800),CGPoint(x:970,y:840)),
fit("bag",source+"/basket-candidate.png",CGRect(x:920,y:745,width:285,height:375),CGPoint(x:970,y:840))]
if let i=parts.firstIndex(where:{$0.id=="headwear"}){let p=parts[i];parts[i]=Part(id:p.id,path:p.path,scale:p.scale*0.95,offset:CGPoint(x:p.pivot.x+(p.offset.x-p.pivot.x)*0.95,y:p.pivot.y+(p.offset.y-p.pivot.y)*0.95-25),pivot:p.pivot,angle:-6)}
if let index=parts.firstIndex(where:{$0.id=="wingRight"}) {let hand=parts.remove(at:index);parts.append(hand)}
if let i=parts.firstIndex(where:{$0.id=="wingLeft"}){let p=parts.remove(at:i);parts.insert(p,at:2)}
let referencePath=root+"/Daylog/PioWardrobe.xcassets/pio_outfit_halloween.imageset/pio_outfit_halloween.png"
let reference=load(referencePath)
func alternative(_ p:Part,_ state:String)->Part{if !p.id.hasPrefix("eye") || state=="open"{return p};let b=bounds(load(p.path));let r=CGRect(x:p.offset.x+b.minX*p.scale,y:p.offset.y+b.minY*p.scale,width:b.width*p.scale,height:b.height*p.scale);let s=p.id.hasSuffix("Left") ? "Left":"Right";return fit((state=="closed" ? "lid":"half")+s,base+(state=="closed" ? "/eyelid-closed-v1.png":"/eye-half-v1.png"),CGRect(x:r.minX,y:r.midY,width:r.width,height:state=="closed" ? 38:65),p.pivot)}
func render(_ p:Part,_ c:CGContext,_ w:CGFloat,_ left:CGFloat=0,_ grip:CGFloat=0,_ eye:String="open"){let p=alternative(p,eye);let angle=p.angle+(p.id=="wingLeft" ? left:0)+(["wingRight","bag"].contains(p.id) ? grip:0);c.saveGState();c.translateBy(x:p.pivot.x,y:w-p.pivot.y);c.rotate(by:-angle * .pi/180);c.translateBy(x:-p.pivot.x,y:-(w-p.pivot.y));let im=load(p.path);draw(im,CGRect(x:p.offset.x,y:p.offset.y,width:CGFloat(im.width)*p.scale,height:CGFloat(im.height)*p.scale),c,w);c.restoreGState()}
func assemble(_ left:CGFloat=0,_ grip:CGFloat=0,_ eye:String="open")->CGImage{let c=context(size,size);for p in parts{render(p,c,CGFloat(size),left,grip,eye)};return c.makeImage()!}
let poses:[(String,CGImage)]=[("neutral",assemble()),("closed",assemble(0,0,"closed")),("wing-minus12",assemble(-12)),("wing-plus12",assemble(12)),("bag-raised",assemble(0,-8))]
for(name,im) in poses{save(im,output+"/"+name+"-alpha.png")}
let gifPath=output+"/independent-offline-proof.gif"
let gif=CGImageDestinationCreateWithURL(URL(fileURLWithPath:gifPath) as CFURL,"com.compuserve.gif" as CFString,48,nil)!
CGImageDestinationSetProperties(gif,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
for frame in 0..<48{let phase=CGFloat(frame)*2 * .pi/48,eye=(frame>=18 && frame<=20) ? "closed":"open",im=assemble(12*sin(phase),-8*max(0,sin(phase)),eye),c=context(512,512);c.setFillColor(CGColor(red:0.07,green:0.11,blue:0.10,alpha:1));c.fill(CGRect(x:0,y:0,width:512,height:512));c.interpolationQuality = .high;c.draw(im,in:CGRect(x:0,y:0,width:512,height:512));CGImageDestinationAddImage(gif,c.makeImage()!,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:0.0625]] as CFDictionary)}
precondition(CGImageDestinationFinalize(gif))
let primary=parts
for p in primary where p.id.hasPrefix("eye"){for state in ["half","closed"]{parts.append(alternative(p,state))}}
var records:[[String:Any]]=[]
var audits:[[String:Any]]=[]
for path in Set(parts.map{$0.path}){let im=load(path),c=context(im.width,im.height);c.draw(im,in:CGRect(x:0,y:0,width:im.width,height:im.height));let bytes=c.data!.assumingMemoryBound(to:UInt8.self);var zero=0,partial=0,opaque=0;for y in 0..<im.height{for x in 0..<im.width{let a=bytes[y*c.bytesPerRow+x*4+3];if a==0{zero+=1}else if a==255{opaque+=1}else{partial+=1}}};audits.append(["source":path,"sha256":hash(path),"pixels":[im.width,im.height],"alphaZero":zero,"alphaPartial":partial,"alphaOpaque":opaque])}
try JSONSerialization.data(withJSONObject:audits,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:output+"/source-alpha-audit.json"))
for(z,p)in parts.enumerated(){let c=context(size,size);render(p,c,CGFloat(size));let path=registered+"/"+p.id+".png";save(c.makeImage()!,path);let padded=context(size+1024,size+1024);padded.translateBy(x:512,y:512);render(p,padded,CGFloat(size));let pixels=padded.data!.assumingMemoryBound(to:UInt8.self);var outside16=0,outsideAny=0;for y in 0..<size+1024{for x in 0..<size+1024{if x<512 || y<512 || x>=size+512 || y>=size+512{let a=pixels[y*padded.bytesPerRow+x*4+3];if a>0{outsideAny+=1};if a>=16{outside16+=1}}}};records.append(["id":p.id,"file":p.id+".png","source":p.path,"sourceSHA256":hash(p.path),"sourcePixels":[load(p.path).width,load(p.path).height],"scale":Double(p.scale),"offset":[Double(p.offset.x),Double(p.offset.y)],"pivot":[Double(p.pivot.x),Double(p.pivot.y)],"neutralAngleDegrees":Double(p.angle),"z":z,"sha256":hash(path),"outsideAnyAlphaPixels":outsideAny,"outsideAlpha16Pixels":outside16])}
let manifest:[String:Any]=["status":"UNAPPROVED_ARTWORK_CANDIDATE","canvas":[1254,1254],"origin":"topLeft","original":referencePath,"parts":records,"grip":["parts":["wingRight","bag"],"pivot":[970,840],"endpointDegrees":-8],"notes":["Eyes/open/half/closed alternatives are mutually exclusive","Complete generated source alpha preserved","Source body remains identity registered; no upscale, masks or painting","Hat and sprout combined, not independently animated","Derivative registered PNGs are not new source artwork"]]
for path in [output+"/registration-candidate.json",registered+"/manifest.json"]{try JSONSerialization.data(withJSONObject:manifest,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:path))}
for(theme,color)in[("light",CGColor(red:0.98,green:0.96,blue:0.91,alpha:1)),("dark",CGColor(red:0.07,green:0.11,blue:0.1,alpha:1))]{for(name,im)in poses{let c=context(size,size);c.setFillColor(color);c.fill(CGRect(x:0,y:0,width:size,height:size));c.draw(im,in:CGRect(x:0,y:0,width:size,height:size));save(c.makeImage()!,output+"/"+name+"-"+theme+".png")};for points in [64,220]{let tile=points*3,gap=60,top=108,images=[("Original",reference)]+poses,w=images.count*(tile+gap)+gap,h=tile+top+gap,c=context(w,h);c.setFillColor(color);c.fill(CGRect(x:0,y:0,width:w,height:h));for(i,item)in images.enumerated(){let x=gap+i*(tile+gap);draw(item.1,CGRect(x:x,y:top,width:tile,height:tile),c,CGFloat(h));NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(cgContext:c,flipped:false);(item.0 as NSString).draw(at:NSPoint(x:x,y:h-top+10),withAttributes:[.font:NSFont.systemFont(ofSize:24),.foregroundColor:theme=="dark" ? NSColor.white:NSColor.black]);NSGraphicsContext.restoreGraphicsState()};save(c.makeImage()!,output+"/comparison-\(points)pt-3x-\(theme).png")}}
print("Halloween candidate registration exported")
