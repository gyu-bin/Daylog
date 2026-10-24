"""QA artwork assembly: full-source uniform downscale/translation/rigid rotation only.
No masks, alpha cleanup, source painting, crops or upscaling. Outputs are candidates, not runtime assets.
"""
from pathlib import Path
from PIL import Image, ImageDraw
import json,math,hashlib
ROOT=Path(__file__).resolve().parents[3]
BASE=ROOT/'output/pio-character-overhaul-artwork'
SHARED=ROOT/'docs/qa/pio-outfit-phase2.2-2026-10-16/candidates/base'
S=1254
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def bounds(p):return Image.open(p).convert('RGBA').getchannel('A').point(lambda a:255 if a>=16 else 0).getbbox()
def fit(ident,path,rect,pivot,z,angle=0):
 b=bounds(path);x,y,w,h=rect;scale=min(w/(b[2]-b[0]),h/(b[3]-b[1]));assert scale<=1
 return {'id':ident,'source':str(path),'sourceSHA256':sha(path),'scale':scale,'offset':[x-b[0]*scale,y-b[1]*scale],'pivot':pivot,'angle':angle,'z':z,'fitRect':rect,'sourceAlpha16Bounds':b}
def direct(ident,path,scale,offset,pivot,z):
 return {'id':ident,'source':str(path),'sourceSHA256':sha(path),'scale':scale,'offset':offset,'pivot':pivot,'angle':0,'z':z}
def render_part(p,angle_extra=0,dy=0,state='open'):
 im=Image.open(p['source']).convert('RGBA');im=im.resize((round(im.width*p['scale']),round(im.height*p['scale'])),Image.Resampling.LANCZOS)
 c=Image.new('RGBA',(S,S));c.alpha_composite(im,(round(p['offset'][0]),round(p['offset'][1])))
 angle=p['angle']+angle_extra
 if angle:c=c.rotate(-angle,resample=Image.Resampling.BICUBIC,center=p['pivot'])
 if dy:
  m=Image.new('RGBA',(S,S));m.alpha_composite(c,(0,round(dy)));c=m
 return c
for name in (__import__('sys').argv[1:] or ['cafe','student']):
 folder=BASE/f'{name}-v1';src=folder/'source';out=folder/'registration';out.mkdir(exist_ok=True);layers=out/'layers';layers.mkdir(exist_ok=True)
 if name=='cafe':
  parts=[direct('body',src/'body-v2-candidate.png',.85,[125,180],[680,800],2),fit('headwear',src/'hat-candidate.png',[230,25,700,625],[650,420],9),fit('wingLeft',src/'left-candidate.png',[175,825,295,250],[400,880],6),fit('wingRight',src/'right-v2-candidate.png',[930,650,250,270],[1000,860],5),fit('prop',src/'cup-candidate.png',[225,735,225,310],[400,880],7)]
  eye_rects=[[490,615,100,103],[775,572,100,103]];foot_rects=[[480,1125,150,95],[770,1115,145,105]]
 else:
  parts=[direct('body',src/'body-candidate.png',.85,[103,198],[680,800],2),fit('sprout',BASE/'cherryBlossom-v2/source/sprout-v3-review.png',[280,25,670,355],[620,380],1),fit('wingLeft',src/'left-candidate.png',[210,815,280,245],[310,875],7),fit('wingRight',src/'right-candidate.png',[950,640,235,260],[990,850],6),fit('prop',src/'book-candidate.png',[395,785,190,285],[310,875],5),fit('glasses',src/'glasses-v2-candidate.png',[326,505,640,250],[650,625],9)]
  eye_rects=[[485,605,100,105],[790,565,100,105]];foot_rects=[[470,1120,150,95],[770,1095,150,110]]
 for side,rect,foot in zip(['Left','Right'],eye_rects,foot_rects):
  px=rect[0]+rect[2]/2;py=rect[1]+rect[3]/2
  parts.append(fit('eye'+side,SHARED/'eye-open-v1.png',rect,[px,py],3))
  parts.append(fit('lid'+side,SHARED/'eyelid-closed-v1.png',[rect[0],rect[1]+rect[3]*.42,rect[2],38],[px,py],4))
  parts.append(fit('foot'+side,SHARED/'foot-v1.png',foot,[foot[0]+foot[2]/2,foot[1]+foot[3]/2],0,-20 if side=='Right' else 0))
 grip=['wingLeft','prop'];manifest={'status':'ARTWORK_CANDIDATE_NOT_APPROVED_NOT_RUNTIME','canvas':[S,S],'origin':'topLeft','method':'Full source unchanged; uniform downscale/translation and rigid articulated rotation only','reference':str(ROOT/f'Daylog/PioWardrobe.xcassets/pio_outfit_{name}.imageset/pio_outfit_{name}.png'),'parts':parts,'grip':{'parts':grip,'pivot':next(p['pivot'] for p in parts if p['id']=='wingLeft'),'endpointAngle':-6,'endpointTranslation':[0,-25]},'limitations':['Reconstruction differs from approved original pixels','No native app or performance verification','Garment details baked into body','Shared feet and eyes differ slightly from original']}
 (out/'registration-candidate.json').write_text(json.dumps(manifest,indent=2))
 for p in parts:render_part(p).save(layers/f'{p["id"]}-1254.png')
 def assemble(wing=0,raised=False,eyes='open'):
  c=Image.new('RGBA',(S,S))
  for p in sorted(parts,key=lambda a:a['z']):
   if p['id'].startswith('eye') and eyes!='open':continue
   if p['id'].startswith('lid') and eyes!='closed':continue
   extra=wing if p['id']=='wingRight' else -6 if raised and p['id'] in grip else 0
   dy=-25 if raised and p['id'] in grip else 0
   c.alpha_composite(render_part(p,extra,dy))
  return c
 poses={'neutral':assemble(),'wing-minus12':assemble(-12),'wing-plus12':assemble(12),'prop-raised':assemble(raised=True),'eyes-closed':assemble(eyes='closed')}
 original=Image.open(manifest['reference']).convert('RGBA')
 for theme,color in [('light',(250,245,235,255)),('dark',(18,28,25,255))]:
  for label,im in poses.items():
   if theme=='light':im.save(out/f'{label}-alpha.png')
   c=Image.new('RGBA',(S,S),color);c.alpha_composite(im);c.convert('RGB').save(out/f'{label}-{theme}.png')
  for pt in [64,220]:
   tile=pt*3;gap=60;top=90;items=[('Original',original)]+[(k,v) for k,v in poses.items()];board=Image.new('RGBA',(len(items)*(tile+gap)+gap,tile+top+gap),color);d=ImageDraw.Draw(board)
   for i,(label,im) in enumerate(items):
    x=gap+i*(tile+gap);board.alpha_composite(im.resize((tile,tile),Image.Resampling.LANCZOS),(x,top));d.text((x,35),label,fill='white' if theme=='dark' else 'black')
   board.convert('RGB').save(out/f'comparison-{pt}pt-3x-{theme}.png')
 # Source hashes are verified again after every compositor operation.
 assert all(sha(p['source'])==p['sourceSHA256'] for p in parts)
 inventory=[]
 for p in sorted(out.rglob('*.png')):
  im=Image.open(p);inventory.append({'path':str(p.relative_to(folder)),'dimensions':im.size,'bytes':p.stat().st_size,'sha256':sha(p)})
 (out/'png-verification.json').write_text(json.dumps({'sourcesUnchanged':True,'files':inventory},indent=2))
 print(name,'rendered',len(inventory),'PNG files')
