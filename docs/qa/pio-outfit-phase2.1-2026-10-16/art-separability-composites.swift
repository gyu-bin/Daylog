// Read-only source audit. Composite original pixels over QA backgrounds only.
import AppKit
import ImageIO
import CryptoKit
let root=URL(fileURLWithPath:"docs/qa/pio-outfit-phase2.1-2026-10-16")
var results:[[String:Any]]=[]
for id in ["christmas","hanbok","astronaut"] {
 let path="Daylog/PioWardrobe.xcassets/pio_outfit_\(id).imageset/pio_outfit_\(id).png"
 let data=try Data(contentsOf:URL(fileURLWithPath:path)),src=CGImageSourceCreateWithData(data as CFData,nil)!,img=CGImageSourceCreateImageAtIndex(src,0,nil)!
 results.append(["id":id,"path":path,"width":img.width,"height":img.height,"imageCount":CGImageSourceGetCount(src),"sha256":SHA256.hash(data:data).map{String(format:"%02x",$0)}.joined(),"alphaInfo":img.alphaInfo.rawValue])
 for dark in [false,true] {
  let ctx=CGContext(data:nil,width:img.width,height:img.height,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
  ctx.setFillColor((dark ? NSColor(srgbRed:0.07,green:0.12,blue:0.10,alpha:1):NSColor(srgbRed:0.98,green:0.97,blue:0.93,alpha:1)).cgColor)
  let bounds=CGRect(x:0,y:0,width:img.width,height:img.height);ctx.fill(bounds);ctx.draw(img,in:bounds)
  try NSBitmapImageRep(cgImage:ctx.makeImage()!).representation(using:.png,properties:[:])!.write(to:root.appendingPathComponent("art-separability-\(id)-\(dark ? "dark":"light").png"))
 }
}
try JSONSerialization.data(withJSONObject:results,options:[.prettyPrinted,.sortedKeys]).write(to:root.appendingPathComponent("art-separability-sources.json"))
print("Six 1:1 alpha-correct diagnostic composites; source pixels unchanged.")
