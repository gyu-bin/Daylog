"""Artwork-only QA compositor. Whole-source uniform downscales + rigid transforms only."""
from PIL import Image, ImageDraw
from pathlib import Path
import math, json, hashlib
ROOT=Path(__file__).resolve().parents[5]
FOLDER=ROOT/'output/pio-character-overhaul-artwork/pajamas-v1'
OUT=FOLDER/'registration-2026-10-23'; EXP=OUT/'exports'; EXP.mkdir(exist_ok=True)
N=1254
manifest=json.loads((FOLDER/'registration/registration-candidate.json').read_text())
parts=manifest['parts']
def img(p):return Image.open(p).convert('RGBA')
def bounds(im,t=16):return im.getchannel('A').point(lambda a:255 if a>=t else 0).getbbox()
def fit(p,path,box):
    im=img(path); b=bounds(im); s=min(box[2]/(b[2]-b[0]),box[3]/(b[3]-b[1])); assert s<=1
    p.update(source=str(path),scale=s,offset=[box[0]-b[0]*s,box[1]-b[1]*s],angle=0)
for p in parts:
    if p['id']=='wingLeft':fit(p,FOLDER/'source/wing-left-candidate-v4.png',(425,835,300,212))
    if p['id']=='wingRight':fit(p,FOLDER/'source/wing-right-candidate-v2.png',(875,835,265,200))
    p['sourceSHA256']=hashlib.sha256(Path(p['source']).read_bytes()).hexdigest()
# Output each complete source on a 1254 top-left canvas without trimming or altering its pixels.
def layer(p):
    im=img(p['source']);s=p['scale'];ox,oy=p['offset'];px,py=p['pivot'];a=math.radians(p['angle']);c=math.cos(a);sn=math.sin(a)
    # inverse source lookup, for output top-left pixel coordinates
    coeff=(c/s,sn/s,(px-c*px-sn*py-ox)/s,-sn/s,c/s,(py+sn*px-c*py-oy)/s)
    return im.transform((N,N),Image.Transform.AFFINE,coeff,Image.Resampling.BICUBIC)
layers={p['id']:layer(p) for p in parts}
for name,im in layers.items():im.save(EXP/(name+'-1254.png'))
static=Image.new('RGBA',(N,N));hug=Image.new('RGBA',(N,N))
for p in parts:
    id=p['id']
    if id.startswith('eye') or id.startswith('half'):continue
    (hug if id in ['wingLeft','wingRight','pillow'] else static).alpha_composite(layers[id])
def assemble(a=0):
    moved=hug.rotate(-a,Image.Resampling.BICUBIC,center=(820,900)) if a else hug
    im=static.copy();im.alpha_composite(moved);return im
poses={'neutral':assemble(),'hug-minus3':assemble(-3),'hug-plus3':assemble(3)}
for name,im in poses.items():im.save(OUT/(name+'-alpha.png'))
original=img(ROOT/'Daylog/PioWardrobe.xcassets/pio_outfit_pajamas.imageset/pio_outfit_pajamas.png')
old=img(FOLDER/'registration/neutral-alpha.png')
items=[('Approved original',original),('Prior candidate',old)]+[(k,v)for k,v in poses.items()]
for theme,bg in [('dark','#172823'),('light','#faf5e8')]:
    for name,im in poses.items():
        canvas=Image.new('RGBA',(N,N),bg);canvas.alpha_composite(im);canvas.convert('RGB').save(OUT/(name+'-'+theme+'.png'))
    for points in [64,220]:
        tile=points*3; gap=28; top=45; sheet=Image.new('RGB',(len(items)*(tile+gap)+gap,tile+top+gap),bg);d=ImageDraw.Draw(sheet)
        for i,(name,im) in enumerate(items):
            x=gap+i*(tile+gap);d.text((x,15),name,fill='white' if theme=='dark' else '#202820');small=im.resize((tile,tile),Image.Resampling.LANCZOS);sheet.paste(small,(x,top),small)
        sheet.save(OUT/f'comparison-{points}pt-3x-{theme}.png')
frames=[]
for k in range(32):
    a=3*math.sin(2*math.pi*k/32);im=assemble(a).resize((440,440),Image.Resampling.LANCZOS);frame=Image.new('RGBA',(440,440),'#172823');frame.alpha_composite(im);frames.append(frame.convert('RGB'))
frames[0].save(OUT/'sleepy-hug-offline.gif',save_all=True,append_images=frames[1:],duration=90,loop=0)
manifest.update(status='ARTWORK_CANDIDATE_PENDING_USER_VISUAL_APPROVAL',parts=parts,notes=['Top-left 1254 canvas; whole source affine transforms only, no source crop/mask/painting/alpha cleanup/upscale.','Five functional native parts, two newly generated arm replacements this pass. Existing body/headwear/pillow and shared eyelids/feet reused.','Default closed eyes and existing open beak. Both hands + pillow move together by ±3 degrees; body fixed.','Offline compositing proof only; app animation and target rendering not tested.'])
(OUT/'registration-candidate.json').write_text(json.dumps(manifest,indent=2))
audit=[]
for path in sorted(set(p['source']for p in parts)):
    im=img(path);hist=im.getchannel('A').histogram();audit.append(dict(source=path,sha256=hashlib.sha256(Path(path).read_bytes()).hexdigest(),size=im.size,alphaZero=hist[0],alphaPartial=sum(hist[1:255]),alphaOpaque=hist[255],alpha16Bounds=bounds(im)))
(OUT/'source-alpha-audit.json').write_text(json.dumps(audit,indent=2))
print(OUT)
