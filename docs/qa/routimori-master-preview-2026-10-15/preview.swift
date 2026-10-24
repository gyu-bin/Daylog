import AppKit
import ImageIO
import UniformTypeIdentifiers

// Review composition only: uniformly downsample the complete character and
// composite onto review backgrounds. Preserve the original PNG unchanged.
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let src = CGImageSourceCreateWithURL(root.appendingPathComponent("routimori-master-v1.png") as CFURL, nil)!
let img = CGImageSourceCreateImageAtIndex(src, 0, nil)!
let rgb = CGColorSpace(name: CGColorSpace.sRGB)!
func ctx(_ w: Int, _ h: Int) -> CGContext {
    CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w*4,
              space: rgb, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}
let scan = ctx(img.width,img.height)
scan.draw(img,in:CGRect(x:0,y:0,width:img.width,height:img.height))
let px = scan.data!.assumingMemoryBound(to: UInt8.self)
var x0=img.width,y0=img.height,x1=0,y1=0
for y in 0..<img.height { for x in 0..<img.width where px[(y*img.width+x)*4+3]>8 {
    x0=min(x0,x);x1=max(x1,x);y0=min(y0,y);y1=max(y1,y)
} }
let crop=img.cropping(to:CGRect(x:x0,y:y0,width:x1-x0+1,height:y1-y0+1))!
for scale in [1,3] {
    let w=860,h=620,c=ctx(w*scale,h*scale)
    c.scaleBy(x:CGFloat(scale),y:CGFloat(scale));c.interpolationQuality = .high
    for (row,dark) in [false,true].enumerated() {
        let bottom=CGFloat(row==0 ? 310 : 0)
        let bg=dark ? NSColor(srgbRed:0.13,green:0.145,blue:0.17,alpha:1) : NSColor(srgbRed:0.97,green:0.96,blue:0.94,alpha:1)
        c.setFillColor(bg.cgColor);c.fill(CGRect(x:0,y:bottom,width:CGFloat(w),height:310))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current=NSGraphicsContext(cgContext:c,flipped:false)
        let ink: NSColor=dark ? .white : .black
        let attr: [NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize:15),.foregroundColor:ink]
        (dark ? "Dark" : "Light" as NSString).draw(at:CGPoint(x:20,y:bottom+280),withAttributes:attr)
        for (i,size) in [48,64,120,220].enumerated() {
            let center=CGFloat([95,270,465,690][i]), sh=CGFloat(size)
            let sw=CGFloat(crop.width)*sh/CGFloat(crop.height)
            c.draw(crop,in:CGRect(x:center-sw/2,y:bottom+45,width:sw,height:sh))
            let text="\(size)pt" as NSString
            text.draw(at:CGPoint(x:center-text.size(withAttributes:attr).width/2,y:bottom+18),withAttributes:attr)
        }
        NSGraphicsContext.restoreGraphicsState()
    }
    let out=root.appendingPathComponent("size-preview-\(scale)x.png")
    let dest=CGImageDestinationCreateWithURL(out as CFURL,UTType.png.identifier as CFString,1,nil)!
    CGImageDestinationAddImage(dest,c.makeImage()!,nil)
    precondition(CGImageDestinationFinalize(dest));print(out.path)
}
