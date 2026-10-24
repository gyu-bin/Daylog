// Offline asset-registration proof. No application/runtime performance claims.
import Foundation
import AppKit
import ImageIO
import CryptoKit
let root=FileManager.default.currentDirectoryPath
let kit="winter-v1"
let folder=root+"/output/pio-character-overhaul-artwork/"+kit
let manifestPath=folder+"/registered-layers/manifest.json"
let manifest=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:manifestPath))) as! [String:Any]
let layers=manifest["layers"] as! [[String:Any]]
func load(_ p:String)->CGImage {CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(URL(fileURLWithPath:p) as CFURL,nil)!,0,nil)!}
let images=Dictionary(uniqueKeysWithValues:layers.map{($0["id"] as! String,load(folder+"/registered-layers/"+($0["file"] as! String)))})
func context(_ w:Int,_ h:Int)->CGContext {CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!}
func save(_ im:CGImage,_ path:String){let d=CGImageDestinationCreateWithURL(URL(fileURLWithPath:path) as CFURL,"public.png" as CFString,1,nil)!;CGImageDestinationAddImage(d,im,nil);precondition(CGImageDestinationFinalize(d))}
let pajamas=kit=="pajamas-v1"
let moving:Set<String>=pajamas ? ["wingLeft","wingRight","pillow"]:(kit=="autumn-v1" ? ["wingLeft","leaf"]:["wingRight"])
let amplitude:Double=pajamas ? 3:12
let count=24
var frames:[CGImage]=[]
for i in 0..<count {let a=amplitude*sin(Double(i)*2 * .pi/Double(count));let c=context(660,700);c.setFillColor(CGColor(red:0.07,green:0.11,blue:0.10,alpha:1));c.fill(CGRect(x:0,y:0,width:660,height:700));c.saveGState();c.translateBy(x:0,y:40);c.scaleBy(x:660/1254,y:660/1254)
 for layer in layers {let id=layer["id"] as! String;if id.hasPrefix("half"){continue};if pajamas && id.hasPrefix("eye"){continue};if !pajamas && id.hasPrefix("lid"){continue};c.saveGState();if moving.contains(id){let p=pajamas ? [820.0,900.0]:(kit=="autumn-v1" ? [390.0,860.0]:layer["pivot"] as! [Double]);c.translateBy(x:p[0],y:1254-p[1]);c.rotate(by:-a * .pi/180);c.translateBy(x:-p[0],y:-(1254-p[1]))};c.interpolationQuality = .high;c.draw(images[id]!,in:CGRect(x:0,y:0,width:1254,height:1254));c.restoreGState()};c.restoreGState()
 NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(cgContext:c,flipped:false);("Offline candidate art proof · body fixed" as NSString).draw(at:NSPoint(x:20,y:12),withAttributes:[.font:NSFont.systemFont(ofSize:16),.foregroundColor:NSColor.white]);NSGraphicsContext.restoreGraphicsState();frames.append(c.makeImage()!)
}
let gif=folder+"/registration/offline-independent-art-proof.gif"
let d=CGImageDestinationCreateWithURL(URL(fileURLWithPath:gif) as CFURL,"com.compuserve.gif" as CFString,count,nil)!
CGImageDestinationSetProperties(d,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
for frame in frames {CGImageDestinationAddImage(d,frame,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:0.1]] as CFDictionary)}
precondition(CGImageDestinationFinalize(d))
let contact=context(2640,700)
for (n,i) in [0,6,12,18].enumerated(){contact.draw(frames[i],in:CGRect(x:n*660,y:0,width:660,height:700))}
save(contact.makeImage()!,folder+"/registration/offline-independent-art-contact.png")
let source=CGImageSourceCreateWithURL(URL(fileURLWithPath:gif) as CFURL,nil)!
let proof:[String:Any]=["status":"OFFLINE_ASSET_PROOF_NOT_NATIVE_APP","frames":CGImageSourceGetCount(source),"durationSeconds":2.4,"framePixels":[660,700],"sourceCoordinateCanvas":[1254,1254],"bodyFixed":true,"movingParts":Array(moving).sorted(),"deltaAmplitudeDegrees":amplitude,"eyes":pajamas ? "closed throughout":"open throughout","registeredManifestSHA256":SHA256.hash(data:try Data(contentsOf:URL(fileURLWithPath:manifestPath))).map{String(format:"%02x",$0)}.joined(),"gifSHA256":SHA256.hash(data:try Data(contentsOf:URL(fileURLWithPath:gif))).map{String(format:"%02x",$0)}.joined(),"note":"No native timing/FPS, Reduce Motion, performance, app integration or complete animation acceptance claimed"]
try JSONSerialization.data(withJSONObject:proof,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:folder+"/registration/offline-proof-verification.json"))
print(kit+" offline proof24frames")
