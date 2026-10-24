// Candidate derivative export only. Does not modify any source art or application file.
import Foundation
import AppKit
import ImageIO
import CryptoKit
let root=FileManager.default.currentDirectoryPath
let size=1254
func load(_ path:String)->CGImage {CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(URL(fileURLWithPath:path) as CFURL,nil)!,0,nil)!}
func context(_ w:Int,_ h:Int)->CGContext {CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!}
func save(_ im:CGImage,_ p:String){let d=CGImageDestinationCreateWithURL(URL(fileURLWithPath:p) as CFURL,"public.png" as CFString,1,nil)!;CGImageDestinationAddImage(d,im,nil);precondition(CGImageDestinationFinalize(d))}
func hash(_ p:String)->String {SHA256.hash(data:try! Data(contentsOf:URL(fileURLWithPath:p))).map{String(format:"%02x",$0)}.joined()}
func bounds(_ im:CGImage,_ threshold:UInt8=16)->CGRect{let c=context(im.width,im.height);c.draw(im,in:CGRect(x:0,y:0,width:im.width,height:im.height));let b=c.data!.assumingMemoryBound(to:UInt8.self);var x0=im.width,y0=im.height,x1 = -1,y1 = -1;for y in 0..<im.height{for x in 0..<im.width{if b[y*c.bytesPerRow+x*4+3]>=threshold{x0=min(x0,x);x1=max(x1,x);y0=min(y0,y);y1=max(y1,y)}}};return CGRect(x:x0,y:y0,width:x1-x0+1,height:y1-y0+1)}
struct Part {let id,path:String;let scale:CGFloat,offset,pivot:CGPoint;let angle:CGFloat}
func fit(_ id:String,_ path:String,_ rect:CGRect,_ pivot:CGPoint)->Part{let b=bounds(load(path));let s=min(rect.width/b.width,rect.height/b.height);precondition(s<=1);return Part(id:id,path:path,scale:s,offset:CGPoint(x:rect.minX-b.minX*s,y:rect.minY-b.minY*s),pivot:pivot,angle:0)}
func render(_ p:Part,_ padding:Int=0)->CGImage{let n=size+padding*2,c=context(n,n);c.translateBy(x:CGFloat(padding),y:CGFloat(padding));c.translateBy(x:p.pivot.x,y:CGFloat(size)-p.pivot.y);c.rotate(by:-p.angle * .pi/180);c.translateBy(x:-p.pivot.x,y:-(CGFloat(size)-p.pivot.y));let im=load(p.path);let r=CGRect(x:p.offset.x,y:CGFloat(size)-p.offset.y-CGFloat(im.height)*p.scale,width:CGFloat(im.width)*p.scale,height:CGFloat(im.height)*p.scale);c.interpolationQuality = .high;c.draw(im,in:r);return c.makeImage()!}
for kit in ["pajamas-v1"] {
 let folder=root+"/output/pio-character-overhaul-artwork/"+kit
 let out=folder+"/registered-layers"
 try FileManager.default.createDirectory(atPath:out,withIntermediateDirectories:true)
 let manifestPath=folder+"/registration/registration-candidate.json"
 let data=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:manifestPath))) as! [String:Any]
 let list=(data["layers"] ?? data["parts"]) as! [[String:Any]]
 var parts=list.map {d -> Part in let path=d["source"] as! String;let o=d["offset"] as! [Double],v=d["pivot"] as! [Double];let p=path.hasPrefix("/") ? path:root+"/"+path;return Part(id:d["id"] as! String,path:p,scale:d["scale"] as! Double,offset:CGPoint(x:o[0],y:o[1]),pivot:CGPoint(x:v[0],y:v[1]),angle:(d["neutralAngleDegrees"] ?? d["angle"]) as! Double)}
 if kit=="summerVacation-v1" {
  let base=root+"/docs/qa/pio-outfit-phase2.2-2026-10-16/candidates/base"
  for side in ["Left","Right"] {let e=parts.first{$0.id=="eye"+side}!;let b=bounds(load(e.path),128);let t=CGRect(x:e.offset.x+b.minX*e.scale,y:e.offset.y+b.minY*e.scale,width:b.width*e.scale,height:b.height*e.scale);let s=t.width/658;parts.append(Part(id:"half"+side,path:base+"/eye-half-v1.png",scale:s,offset:CGPoint(x:t.midX-627*s,y:t.maxY-1017*s),pivot:CGPoint(x:t.midX,y:t.midY),angle:0));parts.append(fit("lid"+side,base+"/eyelid-closed-v1.png",CGRect(x:t.minX,y:t.midY,width:t.width,height:t.width*0.38),CGPoint(x:t.midX,y:t.midY+t.width*0.19)))}
 }
 var records:[[String:Any]]=[]
 for (z,p) in parts.enumerated(){precondition(p.scale<=1);let im=render(p);let path=out+"/"+p.id+".png";save(im,path)
  // Expanded native raster diagnoses any meaningful alpha that would fall outside1254².
  let padding=512,wide=render(p,padding),c=context(wide.width,wide.height);c.draw(wide,in:CGRect(x:0,y:0,width:wide.width,height:wide.height));let b=c.data!.assumingMemoryBound(to:UInt8.self);var outside=0,outsideAny=0
  for y in 0..<wide.height{for x in 0..<wide.width{if x<padding || y<padding || x>=padding+size || y>=padding+size{let a=b[y*c.bytesPerRow+x*4+3];if a>0{outsideAny+=1};if a>=16{outside+=1}}}}
  records.append(["id":p.id,"file":p.id+".png","source":p.path,"sourceSHA256":hash(p.path),"sourcePixels":[load(p.path).width,load(p.path).height],"scale":Double(p.scale),"offset":[Double(p.offset.x),Double(p.offset.y)],"pivot":[Double(p.pivot.x),Double(p.pivot.y)],"neutralAngleDegrees":Double(p.angle),"z":z,"width":im.width,"height":im.height,"sha256":hash(path),"outsideCanvasAlpha16Pixels":outside,"outsideCanvasAnyAlphaPixels":outsideAny,"warning":outside>0 ? "VISIBLE_SOURCE_OUTSIDE_CANVAS_REVIEW_REQUIRED":"none"]) 
 }
 let result:[String:Any]=["status":"UNAPPROVED_CANDIDATE_REGISTERED_DERIVATIVES","canvas":[size,size],"origin":"topLeft","sourceRegistration":manifestPath,"sourceRegistrationSHA256":hash(manifestPath),"newlyAuthoredSourceCount":0,"notes":["These are derivative exports, not newly authored source artwork","Neutral rigid rotations baked into derivative canvas; retain pivots for future motion","Full source artwork preserved unchanged; no masks or painting","Eye open/half/closed are mutually exclusive alternatives, not simultaneously visible layers","Summer primary opaque lenses obscure eye alternatives","Summer added half/closed registration is a provisional static fit, not native blink approval","Partial transparency preserved; outside-canvas counts warn rather than silently ignore clipped source"],"layers":records]
 try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:out+"/manifest.json"))
 print(kit+": "+String(records.count)+" actual transparent derivative PNGs")
 for r in records where r["outsideCanvasAlpha16Pixels"] as! Int>0 {print("WARNING "+(r["id"] as! String)+": "+String(r["outsideCanvasAlpha16Pixels"] as! Int)+" alpha16 pixels outside canvas")}
}
