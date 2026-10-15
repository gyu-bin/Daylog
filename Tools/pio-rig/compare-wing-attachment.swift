// Compose unchanged before/after render exports into review boards; never edits source artwork.
import AppKit
import ImageIO
import UniformTypeIdentifiers
let root = URL(fileURLWithPath:CommandLine.arguments[1])
let cs = CGColorSpace(name:CGColorSpace.sRGB)!
func load(_ url:URL)->CGImage { let source=CGImageSourceCreateWithURL(url as CFURL,nil)!;return CGImageSourceCreateImageAtIndex(source,0,nil)! }
func text(_ s:String,_ p:CGPoint,_ c:CGContext,_ color:NSColor){NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(cgContext:c,flipped:false);s.draw(at:p,withAttributes:[.font:NSFont.systemFont(ofSize:15),.foregroundColor:color]);NSGraphicsContext.restoreGraphicsState()}
for stage in [2,3] { for mode in ["light","dark"] { for scale in [1,3] {
 let w=570,h=640,c=CGContext(data:nil,width:w*scale,height:h*scale,bitsPerComponent:8,bytesPerRow:0,space:cs,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
 c.scaleBy(x:CGFloat(scale),y:CGFloat(scale))
 let bg=mode == "light" ? NSColor(srgbRed:0.97,green:0.96,blue:0.94,alpha:1) : NSColor(srgbRed:0.13,green:0.145,blue:0.17,alpha:1)
 let fg=mode == "light" ? NSColor.black:NSColor.white
 c.setFillColor(bg.cgColor);c.fill(CGRect(x:0,y:0,width:w,height:h))
 text("Stage \(stage) · same body scale · @\(scale)x",CGPoint(x:20,y:610),c,fg)
 text("BEFORE",CGPoint(x:95,y:570),c,fg);text("AFTER",CGPoint(x:350,y:570),c,fg)
 for (row,size) in [48,64,76,220].enumerated() {
  let y=CGFloat([485,380,260,10][row]);text("\(size)pt",CGPoint(x:10,y:y+15),c,fg)
  for (col,variant) in ["before/rendered","final"].enumerated() {
   let img=load(root.appendingPathComponent("\(variant)/sizes/\(mode)-stage\(stage)-\(size)pt-\(scale)x.png"))
   c.draw(img,in:CGRect(x:CGFloat(85+col*250),y:y,width:CGFloat(img.width)/CGFloat(scale),height:CGFloat(img.height)/CGFloat(scale)))
  }
 }
 let out=root.appendingPathComponent("stage\(stage)-before-after-\(mode)-\(scale)x.png")
 let dest=CGImageDestinationCreateWithURL(out as CFURL,UTType.png.identifier as CFString,1,nil)!;CGImageDestinationAddImage(dest,c.makeImage()!,nil);precondition(CGImageDestinationFinalize(dest))
}}}
let overview = CGContext(data:nil,width:560,height:580,bitsPerComponent:8,bytesPerRow:0,space:cs,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
overview.setFillColor(NSColor(srgbRed:0.97,green:0.96,blue:0.94,alpha:1).cgColor)
overview.fill(CGRect(x:0,y:0,width:560,height:580))
for (row,stage) in [2,3].enumerated() {
 let y=CGFloat(row == 0 ? 305:25)
 text("Stage \(stage) · BEFORE",CGPoint(x:25,y:y+230),overview,.black)
 text("Stage \(stage) · AFTER",CGPoint(x:305,y:y+230),overview,.black)
 for (col,variant) in ["before/rendered","final"].enumerated(){
  let img=load(root.appendingPathComponent("\(variant)/sizes/light-stage\(stage)-220pt-1x.png"))
  overview.draw(img,in:CGRect(x:CGFloat(25+280*col),y:y,width:CGFloat(img.width),height:CGFloat(img.height)))
 }
}
let dest=CGImageDestinationCreateWithURL(root.appendingPathComponent("before-after-overview.png") as CFURL,UTType.png.identifier as CFString,1,nil)!
CGImageDestinationAddImage(dest,overview.makeImage()!,nil);precondition(CGImageDestinationFinalize(dest))
