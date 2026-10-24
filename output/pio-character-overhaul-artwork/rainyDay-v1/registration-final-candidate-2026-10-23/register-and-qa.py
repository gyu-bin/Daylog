"""Offline whole-source artwork registration. No masks, crops, cleanup or artwork painting."""
from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
import json, hashlib, math
ROOT=Path(__file__).resolve().parents[4]
HOME=Path(__file__).resolve().parent
OLD=HOME.parent
N=1254
manifest=json.loads((OLD/'registered-layers/manifest.json').read_text())
parts=manifest['parts']
for p in parts:
    if p['id']=='umbrellaShaft':
        p.update(scale=.4163,offset=[726.2,449.4],source=str(HOME.parent/'source/umbrella-shaft-v3-candidate.png'));p['sourceSHA256']=hashlib.sha256(Path(p['source']).read_bytes()).hexdigest();p['sourcePixels']=[1254,1254]
    if p['id']=='wingRight':
        p['offset'][1]-=35
shaft=next(p for p in parts if p['id']=='umbrellaShaft')
parts.remove(shaft)
parts.insert(3,shaft)
for depth,p in enumerate(parts):p['z']=depth
THEMES={'light':(250,245,232,255),'dark':(18,28,26,255)}
def digest(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def matrix(p,delta=0):
    s=p['scale']; a=math.radians(p['neutralAngleDegrees']+delta);c=math.cos(a);q=math.sin(a)
    x,y=p['offset'];u,v=p['pivot']
    return [s*c,-s*q,u+c*(x-u)-q*(y-v),s*q,s*c,v+q*(x-u)+c*(y-v)]
def render(p,delta=0,pad=0):
    a,b,c,d,e,f=matrix(p,delta);det=a*e-b*d
    c+=pad;f+=pad
    inv=(e/det,-b/det,(b*f-e*c)/det,-d/det,a/det,(d*c-a*f)/det)
    return Image.open(p['source']).convert('RGBA').transform((N+pad*2,N+pad*2),Image.Transform.AFFINE,inv,Image.Resampling.BICUBIC)
def assemble(left=0,grip=0,eye='open'):
    im=Image.new('RGBA',(N,N))
    for p in parts:
        pid=p['id']
        if pid.startswith(('half','lid')):continue
        if pid.startswith('eye') and eye!='open':
            p=next(x for x in parts if x['id']==('lid' if eye=='closed' else 'half')+pid[3:])
        delta=left if pid=='wingLeft' else grip if pid in ['wingRight','umbrellaCanopy','umbrellaShaft'] else 0
        im.alpha_composite(render(p,delta))
    return im
if __name__=='__main__':
    out=HOME/'registered-layers';out.mkdir(exist_ok=True)
    records=[]
    for p in parts:
        im=render(p);im.save(out/(p['id']+'.png'))
        alpha=render(p,pad=512).getchannel('A');hist=alpha.histogram();inner=im.getchannel('A').histogram()
        record=dict(p); record.update(matrixTopLeft=matrix(p),sha256=digest(out/(p['id']+'.png')),outsideAnyAlphaPixels=sum(hist[1:])-sum(inner[1:]),outsideAlpha16Pixels=sum(hist[16:])-sum(inner[16:]))
        records.append(record)
    poses={'neutral':assemble(),'closed':assemble(eye='closed'),'half':assemble(eye='half'),'wing-minus12':assemble(-12),'wing-plus12':assemble(12),'umbrella-minus5':assemble(grip=-5)}
    for name,im in poses.items():
        im.save(HOME/(name+'-alpha.png'))
        for theme,bg in THEMES.items():
            canvas=Image.new('RGBA',(N,N),bg);canvas.alpha_composite(im);canvas.convert('RGB').save(HOME/(name+'-'+theme+'.png'))
    original=Image.open(manifest['original']).convert('RGBA')
    for pt in [64,220]:
        tile=pt*3;gap=36;top=50
        items=[('Original approved',original)]+list(poses.items())
        for theme,bg in THEMES.items():
            sheet=Image.new('RGBA',(len(items)*(tile+gap)+gap,tile+top+gap),bg);d=ImageDraw.Draw(sheet)
            for i,(name,im) in enumerate(items):
                x=gap+i*(tile+gap);sheet.alpha_composite(im.resize((tile,tile),Image.Resampling.LANCZOS),(x,top));d.text((x,15),name,fill='white' if theme=='dark' else 'black')
            sheet.convert('RGB').save(HOME/f'comparison-{pt}pt-3x-{theme}.png')
    frames=[]
    for f in range(48):
        phase=f*2*math.pi/48
        im=assemble(12*math.sin(phase),-5*max(0,math.sin(phase)),'closed' if 18<=f<=20 else 'open')
        canvas=Image.new('RGBA',(N,N),THEMES['dark']);canvas.alpha_composite(im)
        frames.append(canvas.resize((512,512),Image.Resampling.LANCZOS).convert('RGB'))
    frames[0].save(HOME/'independent-offline-proof.gif',save_all=True,append_images=frames[1:],duration=65,loop=0,disposal=2)
    audit=[]
    for source in sorted(set(p['source'] for p in parts)):
        im=Image.open(source);h=im.convert('RGBA').getchannel('A').histogram()
        meta=Path(source+'.generation.json')
        audit.append(dict(source=source,sha256=digest(source),size=list(im.size),alphaZero=h[0],alphaPartial=sum(h[1:255]),alphaOpaque=h[255],generationMetadata=json.loads(meta.read_text()) if meta.exists() else None))
    new=dict(manifest);new['notes']=['Whole source alpha preserved; no painting, masking, crop or upscale.','Depth corrected: shaft/J behind canopy and body, with hand frontmost.','Right hand raised35px; visible J below palm.','Source shaft-v3 is genuine reconstruction; original v2 preserved; see offline-verification for exact motion bounds.','Canvas1254 top-left.'];new.update(parts=records,status='UNAPPROVED_ARTWORK_REVIEW',originalSHA256=digest(manifest['original']),sourceAudit=audit,registrationMethod='Whole native source via single uniform scale + rigid rotation and translation; no crop, masks, cleanup, painting, or upscale.',grip=dict(parts=['umbrellaCanopy','umbrellaShaft','wingRight'],pivot=[745,875],endpointDegrees=[0,-5]))
    (HOME/'registration-and-provenance.json').write_text(json.dumps(new,indent=2))
    print('Exported',HOME)
