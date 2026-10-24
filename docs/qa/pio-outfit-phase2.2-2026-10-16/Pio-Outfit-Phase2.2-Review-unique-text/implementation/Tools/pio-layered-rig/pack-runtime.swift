import Foundation
import CoreGraphics
import ImageIO
import CryptoKit
let root=CommandLine.arguments[1]
let input=CommandLine.arguments[2]
let outfit=CommandLine.arguments[3]
let catalog=root+"/Daylog/PioLayeredTrial.xcassets"
let fm=FileManager.default
func writeJSON(_ value:Any,_ path:String)throws {try JSONSerialization.data(withJSONObject:value,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:path))}
try fm.createDirectory(atPath:catalog,withIntermediateDirectories:true)
try writeJSON(["info":["author":"xcode","version":1]],catalog+"/Contents.json")
func load(_ path:String)->CGImage {CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(URL(fileURLWithPath:path) as CFURL,nil)!,0,nil)!}
func pixels(_ image:CGImage)->CGContext {let c=CGContext(data:nil,width:image.width,height:image.height,bitsPerComponent:8,bytesPerRow:image.width*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!;c.draw(image,in:CGRect(x:0,y:0,width:image.width,height:image.height));return c}
let manifest=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:input+"/registration.json"))) as! [String:Any]
let onlyHalf=CommandLine.arguments.contains("--only-half")
var packed:[[String:Any]]=[]
if onlyHalf {
    let current=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:catalog+"/pio_layered_"+outfit+"_registration.dataset/registration.json"))) as! [String:Any]
    packed=(current["parts"] as! [[String:Any]]).filter { !($0["id"] as! String).hasPrefix("half") }
}
for entry in (manifest["layers"] as! [[String:Any]]).filter({ !onlyHalf || ($0["id"] as! String).hasPrefix("half") }) {
    let id=entry["id"] as! String,path=input+"/"+id+".png",image=load(path),c=pixels(image),bytes=c.data!.assumingMemoryBound(to:UInt8.self)
    var x0=image.width,y0=image.height,x1 = -1,y1 = -1
    for y in 0..<image.height {for x in 0..<image.width {if bytes[y*c.bytesPerRow+x*4+3] != 0 {x0=min(x0,x);y0=min(y0,y);x1=max(x1,x);y1=max(y1,y)}}}
    precondition(x1>=x0)
    let rect=CGRect(x:x0,y:y0,width:x1-x0+1,height:y1-y0+1)
    let crop=image.cropping(to:rect)!
    let name="pio_layered_"+outfit+"_"+id,dir=catalog+"/"+name+".imageset"
    try fm.createDirectory(atPath:dir,withIntermediateDirectories:true)
    let out=dir+"/"+name+".png"
    let destination=CGImageDestinationCreateWithURL(URL(fileURLWithPath:out) as CFURL,"public.png" as CFString,1,nil)!
    CGImageDestinationAddImage(destination,crop,nil);precondition(CGImageDestinationFinalize(destination))
    let decoded=pixels(load(out)),db=decoded.data!.assumingMemoryBound(to:UInt8.self)
    for y in 0..<crop.height {for x in 0..<crop.width {for channel in 0..<4 {
        precondition(db[y*decoded.bytesPerRow+x*4+channel]==bytes[(y+y0)*c.bytesPerRow+(x+x0)*4+channel],"Packing changed decoded pixels: "+id)
    }}}
    try writeJSON(["images":[["filename":name+".png","idiom":"universal"]],"info":["author":"xcode","version":1]],dir+"/Contents.json")
    let fullHash=SHA256.hash(data:try Data(contentsOf:URL(fileURLWithPath:path))).map{String(format:"%02x",$0)}.joined()
    packed.append(["id":id,"asset":name,"rect":[x0,y0,crop.width,crop.height],"pivot":entry["pivot"]!,"z":entry["z"]!,"neutralAngleDegrees":entry["neutralAngleDegrees"] ?? 0,"fullCanvasSHA256":fullHash])
}
let datasetName="pio_layered_"+outfit+"_registration",dataset=catalog+"/"+datasetName+".dataset"
try fm.createDirectory(atPath:dataset,withIntermediateDirectories:true)
if onlyHalf {
    let order=Dictionary(uniqueKeysWithValues:(manifest["layers"] as! [[String:Any]]).map { ($0["id"] as! String,$0["z"] as! Int) })
    for index in packed.indices {packed[index]["z"]=order[packed[index]["id"] as! String]!}
    packed.sort { ($0["z"] as! Int) < ($1["z"] as! Int) }
}
let runtime:[String:Any]=["revision":outfit+(packed.contains { ($0["id"] as! String).hasPrefix("half") } ? "-pilot-v1-blink3" : "-pilot-v1"),"outfit":outfit,"canvas":1254,"stageArtID":"pilot-neutral-only","supportsGrowthStages":false,"parts":packed]
try writeJSON(runtime,dataset+"/registration.json")
try writeJSON(["data":[["filename":"registration.json","idiom":"universal"]],"info":["author":"xcode","version":1]],dataset+"/Contents.json")
print("Packed \(packed.count) layers; every decoded RGBA pixel verified unchanged; exact alpha-zero padding only.")

if !onlyHalf {
let referenceSource=input+"/reference-registered.png"
let referenceName="pio_layered_"+outfit+"_reference",referenceDir=catalog+"/"+referenceName+".imageset"
try fm.createDirectory(atPath:referenceDir,withIntermediateDirectories:true)
try Data(contentsOf:URL(fileURLWithPath:referenceSource)).write(to:URL(fileURLWithPath:referenceDir+"/"+referenceName+".png"))
try writeJSON(["images":[["filename":referenceName+".png","idiom":"universal"]],"info":["author":"xcode","version":1]],referenceDir+"/Contents.json")

}
