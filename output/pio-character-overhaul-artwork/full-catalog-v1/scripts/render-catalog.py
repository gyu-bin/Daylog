"""Offline full-catalog artwork review; never writes app assets or native sources."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json, hashlib, math
ROOT=Path(__file__).resolve().parents[4]; ART=ROOT/'output/pio-character-overhaul-artwork'; OUT=ART/'full-catalog-v1'; S=1254
IDS=['basic','cherryBlossom','summerVacation','autumn','winter','halloween','christmas','hanbok','astronaut','rainyDay','cafe','student','fitness','pajamas']
LABELS=['Basic','Cherry Blossom','Summer','Autumn','Winter','Halloween','Christmas','Hanbok','Astronaut','Rainy Day','Cafe','Student','Fitness','Pajamas']
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
sources={}; manifest=[]; allposes={}
HAPPY=ART/'shared-expression-v1/source/eye-happy-v1.png'
FONT=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',20)
SMALL=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',14)

def read(p):
 p=Path(p); sources[str(p)]=sha(p); return Image.open(p).convert('RGBA')

def registered(p):
 im=read(p['source']); im=im.transpose(Image.Transpose.FLIP_LEFT_RIGHT) if p.get('mirrorX') else im; sc=p.get('scale',1); im=im.resize((round(im.width*sc),round(im.height*sc)),Image.Resampling.LANCZOS)
 c=Image.new('RGBA',(S,S)); c.alpha_composite(im,tuple(round(x) for x in p.get('offset',[0,0])))
 angle=p.get('angle',p.get('neutralAngleDegrees',0))
 if angle: c=c.rotate(-angle,Image.Resampling.BICUBIC,center=tuple(p['pivot']))
 return c

def loadkit(outfit):
 if outfit in ['basic','christmas','hanbok','astronaut']:
  cat=ROOT/'Daylog/PioLayeredTrial.xcassets'; path=cat/f'pio_layered_{outfit}_registration.dataset/registration.json'; d=json.loads(path.read_text()); meta=d['parts']; layers={}
  for p in meta:
   im=read(cat/(p['asset']+'.imageset')/(p['asset']+'.png')); x,y,w,h=p['rect']; assert im.size==(w,h),(p['id'],im.size,(w,h)); c=Image.new('RGBA',(S,S));c.alpha_composite(im,(x,y))
   if p.get('neutralAngleDegrees'): c=c.rotate(-p['neutralAngleDegrees'],Image.Resampling.BICUBIC,center=tuple(p['pivot']))
   layers[p['id']]=c
  return path,meta,layers
 folder=ART/(outfit+('-v2' if outfit=='cherryBlossom' else '-v1'))
 dated=folder/'registration-final-candidate-2026-10-23'
 # Final candidate is adopted only when its own manifest explicitly marks selection.
 if dated.exists() and (dated/'SELECTED.json').exists(): folderreg=dated
 else: folderreg=folder/('registration-2026-10-23' if outfit in ['rainyDay','pajamas'] else 'registration')
 if outfit=='cherryBlossom':
  path=folder/'registered-layers/manifest.json'; d=json.loads(path.read_text());meta=d['layers']; layers={p['id']:read(path.parent/p['file']) for p in meta}
 elif outfit=='rainyDay':
  path=folderreg/'registration-and-provenance.json';d=json.loads(path.read_text());meta=d['parts'];layers={p['id']:read(folderreg/'registered-layers'/p['file']) for p in meta}
 else:
  path=folderreg/'registration-candidate.json';d=json.loads(path.read_text());meta=d['parts'];layers={p['id']:registered(p) for p in meta}
 if outfit=='summerVacation':
  # Selected review alternative, not replacing primary source registration.
  opt=json.loads((folder/'registration/optional-frame-registration.json').read_text())['layers']
  frame=next(p for p in opt if p['id']=='sunglasses')
  c=registered({'source':str(folder/'source/lenses-v2-candidate.png'),'scale':.37,'offset':[312,438]});c.alpha_composite(registered(frame));layers['sunglasses']=c
  for id in ['eyeLeft','eyeRight']:
   p=next(p for p in opt if p['id']==id and 'eye-open' in p['source']); layers[id]=registered(p)
   q=next(p for p in opt if p['id']==id and 'eyelid-closed' in p['source']); layers['lid'+id[3:]]=registered(q)
 return path,meta,layers

def eye_layer(target):
 # Full generated source fitted uniformly by its alpha16 bounds, no pixel crop/mask.
 im=read(HAPPY); bb=im.getchannel('A').point(lambda a:255 if a>=16 else 0).getbbox();tb=target.getchannel('A').point(lambda a:255 if a>=16 else 0).getbbox(); assert bb and tb
 width=(tb[2]-tb[0])*1.03; scale=width/(bb[2]-bb[0]); center=((tb[0]+tb[2])/2,(tb[1]+tb[3])/2+5)
 offset=(center[0]-(bb[0]+bb[2])/2*scale,center[1]-(bb[1]+bb[3])/2*scale)
 p={'source':str(HAPPY),'scale':scale,'offset':offset}; return registered(p),p

for outfit,label in zip(IDS,LABELS):
 path,meta,layers=loadkit(outfit); meta=sorted(meta,key=lambda p:p['z']); directory=OUT/outfit; directory.mkdir(parents=True,exist_ok=True); (directory/'layers').mkdir(exist_ok=True)
 normalized=[]
 for part in meta:
  id=part['id']; layers[id].save(directory/'layers'/(id+'.png'));normalized.append({'id':id,'file':'layers/'+id+'.png','z':part['z'],'pivot':part['pivot'],'neutralTransformBaked':True})
 for side in ['Left','Right']:
  id='lid'+side
  if id not in [p['id'] for p in meta]:
   layers[id].save(directory/'layers'/(id+'.png')); ep=next(p for p in meta if p['id']=='eye'+side);normalized.append({'id':id,'file':'layers/'+id+'.png','z':ep['z'],'pivot':ep['pivot'],'neutralTransformBaked':True})
 # Eye alternatives replace each original eye slot; never append on top of glasses/visor.
 happy={}; fits={}
 for side in ['Left','Right']:
  happy[side],fits[side]=eye_layer(layers['eye'+side]);happy[side].save(directory/'layers'/('happy'+side+'.png'))
 def composite(state):
  c=Image.new('RGBA',(S,S))
  for p in meta:
   id=p['id']
   if id.startswith(('lid','half')): continue
   layer=layers[id]
   if id.startswith('eye'):
    side=id[3:]
    if state=='happy' or (state=='wink' and side=='Right'):layer=happy[side]
    elif state=='closed':layer=layers['lid'+side]
   c.alpha_composite(layer)
  return c
 poses={state:composite(state) for state in ['open','closed','happy','wink']};allposes[outfit]=poses
 for state,im in poses.items():im.save(directory/(state+'-1254-alpha.png'))
 for pt in [64,220]:
  for factor in [1,3]:
   tile=pt*factor; margin=24; head=60
   for theme,bg,fg in [('light','#faf6ed','#23483d'),('dark','#14251f','#f8efdb')]:
    board=Image.new('RGBA',(4*(tile+margin)+margin,tile+head+margin),bg);draw=ImageDraw.Draw(board);draw.text((margin,8),f'{label} | {pt}pt @{factor}x | OFFLINE CANDIDATE',font=SMALL,fill=fg)
    for i,(state,im) in enumerate(poses.items()):
     x=margin+i*(tile+margin);board.alpha_composite(im.resize((tile,tile),Image.Resampling.LANCZOS),(x,head));draw.text((x,34),state,font=SMALL,fill=fg)
    board.convert('RGB').save(directory/f'expressions-{pt}pt-{factor}x-{theme}.png')
 # Separate eyes only, body/props fixed. Intentional holds make actual decoded frames sparse.
 frames=[]; seq=['open']*8+['closed']*2+['open']*4+['happy']*8+['wink']*6+['open']*4
 for i,state in enumerate(seq):
  fr=Image.new('RGBA',(300,340),'#14251f');fr.alpha_composite(poses[state].resize((300,300),Image.Resampling.LANCZOS));dr=ImageDraw.Draw(fr);dr.text((8,305),label+' | eyes only',font=SMALL,fill='white');frames.append(fr.convert('RGB'))
 frames[0].save(directory/'independent-expression-offline.gif',save_all=True,append_images=frames[1:],duration=90,loop=0,disposal=2,optimize=False)
 with Image.open(directory/'independent-expression-offline.gif') as gif:
  n=gif.n_frames
  for k in range(n):gif.seek(k);gif.convert('RGBA').load()
 data={'outfit':outfit,'status':'UNAPPROVED_ARTWORK_CANDIDATE','sourceRegistration':str(path),'canvas':[S,S],'happyEyeFits':fits,'normalizedParts':normalized,'primarySourcesUnchanged':True,'neutralPoseNote':'Pajamas default remains sleepy in original kit; open is optional review expression','offlineOnly':True,'decodedGIFFrames':n,'summerNote':'Uses optional translucent v2 lens candidate' if outfit=='summerVacation' else None,'exportedLayers':['happyLeft','happyRight'],'expressionSourceCount':1}
 (directory/'registration.json').write_text(json.dumps(data,indent=2)+'\n');manifest.append(data)
# Whole catalog overviews (actual composites, not generated concept sheets)
for state in ['open','happy']:
 for theme,bg,fg in [('light','#faf6ed','#23483d'),('dark','#14251f','#f8efdb')]:
  board=Image.new('RGBA',(1680,820),bg);draw=ImageDraw.Draw(board);draw.text((20,14),'Basic + 13 outfits | '+state+' expression | OFFLINE ARTWORK CANDIDATES',font=FONT,fill=fg)
  for i,(outfit,label) in enumerate(zip(IDS,LABELS)):
   x=(i%7)*240;y=60+(i//7)*370; im=allposes[outfit][state].resize((240,300)) if False else allposes[outfit][state].resize((240,240),Image.Resampling.LANCZOS);board.alpha_composite(im,(x,y));draw.text((x+12,y+250),label,font=SMALL,fill=fg)
  board.convert('RGB').save(OUT/f'catalog-{state}-{theme}.png')
assert all(sha(p)==h for p,h in sources.items())
report={'status':'PARTIAL_VISUAL_APPROVAL_PENDING','catalogCount':len(manifest),'newNativeExpressionSources':1,'registeredHappyEyeDerivatives':28,'sourceSHA256':sources,'sourcesUnchanged':True,'items':manifest,'scope':'Art-only expression registration, no application integration or performance certification'}
(OUT/'catalog-manifest.json').write_text(json.dumps(report,indent=2)+'\n');print('Saved14 expression sets,28 registered eye layers,14 offlineGIFs; source hashes unchanged')
