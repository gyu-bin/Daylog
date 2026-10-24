import Foundation
import ImageIO
import CoreGraphics
let folder=CommandLine.arguments[1]
func rgba(_ name:String)->(CGContext,UnsafeMutablePointer<UInt8>){
    let src=CGImageSourceCreateWithURL(URL(fileURLWithPath:folder+"/"+name+".png") as CFURL,nil)!
    let img=CGImageSourceCreateImageAtIndex(src,0,nil)!
    let c=CGContext(data:nil,width:img.width,height:img.height,bitsPerComponent:8,bytesPerRow:img.width*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.draw(img,in:CGRect(x:0,y:0,width:img.width,height:img.height))
    return(c,c.data!.assumingMemoryBound(to:UInt8.self))
}
let (gc,g)=rgba("gift"), (lc,l)=rgba("handLeft"), (rc,r)=rgba("handRight"), (bc,b)=rgba("body")
func overlap(_ first:UnsafeMutablePointer<UInt8>,_ second:UnsafeMutablePointer<UInt8>)->[String:Any]{
    var count=0,x0=1254,y0=1254,x1 = -1,y1 = -1
    for y in 0..<1254 {for x in 0..<1254 {
        let i=(y*1254+x)*4
        if first[i+3]>=128 && second[i+3]>=128 {count+=1;x0=min(x0,x);y0=min(y0,y);x1=max(x1,x);y1=max(y1,y)}
    }}
    return ["intersectionPixelsAlpha128":count,"intersectionBoundsTopLeft":count==0 ? [] : [x0,y0,x1-x0+1,y1-y0+1]]
}
let report:[String:Any] = ["leftHandGift":overlap(l,g),"rightHandGift":overlap(r,g),"leftHandBody":overlap(l,b),"rightHandBody":overlap(r,b),"limitation":"Alpha intersection confirms actual geometric coverage, not aesthetic approval or a dynamic walking/IK proof. Inspect visible palm and shoulder closeups. Left-hand/gift identical integer translation preserves their mutual overlap in grip poses; right-wave leaves both fixed."]
let data=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
try data.write(to:URL(fileURLWithPath:folder+"/contact-audit.json"))
print(String(data:data,encoding:.utf8)!)
withExtendedLifetime([gc,lc,rc,bc]) {}
