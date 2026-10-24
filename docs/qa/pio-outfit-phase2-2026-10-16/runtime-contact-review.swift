// Diagnostic assembly of actual native capture frames; no app/artwork writes.
import AppKit
import ImageIO
let root = URL(fileURLWithPath: "docs/qa/pio-outfit-phase2-2026-10-16")
func load(_ path: String) -> CGImage { CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(root.appendingPathComponent(path) as CFURL, nil)!,0,nil)! }
func contact(_ name: String, _ items: [(String,String)], _ columns: Int, _ cellW: Int, _ cellH: Int) throws {
 let rows = (items.count+columns-1)/columns, w=columns*cellW,h=rows*cellH+40
 let ctx=CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
 ctx.setFillColor(NSColor(white:0.93,alpha:1).cgColor);ctx.fill(CGRect(x:0,y:0,width:w,height:h));ctx.interpolationQuality = .high
 NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(cgContext:ctx,flipped:false)
 (name as NSString).draw(at:CGPoint(x:8,y:h-30),withAttributes:[.font:NSFont.systemFont(ofSize:16,weight:.semibold),.foregroundColor:NSColor.black])
 for (i,item) in items.enumerated(){
 let img=load(item.0),s=min(CGFloat(cellW-8)/CGFloat(img.width),CGFloat(cellH-26)/CGFloat(img.height))
 let x=CGFloat((i%columns)*cellW)+CGFloat(cellW)/2-CGFloat(img.width)*s/2
 let y=CGFloat(h-40-(i/columns+1)*cellH+24)
 ctx.draw(img,in:CGRect(x:x,y:y,width:CGFloat(img.width)*s,height:CGFloat(img.height)*s))
 (item.1 as NSString).draw(at:CGPoint(x:(i%columns)*cellW+8,y:Int(y)-20),withAttributes:[.font:NSFont.systemFont(ofSize:12),.foregroundColor:NSColor.black])
 }
 NSGraphicsContext.restoreGraphicsState()
 try NSBitmapImageRep(cgImage:ctx.makeImage()!).representation(using:.png,properties:[:])!.write(to:root.appendingPathComponent(name+".png"))
}
for theme in ["basic-wave","halloween-jump","christmas-celebration","hanbok-bounce","astronaut-jump"]{
 try contact("runtime-contact-"+theme,(1...24).map{("video-frames/\(theme)/frame-\(String(format:"%02d",$0)).png","\($0) · \(String(format:"%.2f",Double($0-1)/4))s")},4,156,350)
}
let outfits=["cherryBlossom","summerVacation","autumn","winter","halloween","christmas","hanbok","cafe","student","fitness","rainyDay","pajamas","astronaut"]
for offset in [0,8] { let subset=Array(outfits.dropFirst(offset).prefix(8));try contact("runtime-contact-mac-\(offset/8+1)",subset.map{("live-app/mac-preview-\($0).jpg",$0)},4,260,470) }
print("Created 5 native-video frame contact sheets and 2 native-Mac screenshot contacts.")
