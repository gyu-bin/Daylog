from pathlib import Path
from PIL import Image,ImageDraw
import json,hashlib,statistics
ROOT=Path(__file__).resolve().parents[2];OUT=Path(__file__).resolve().parent/'expressions';CAT=ROOT/'output/pio-character-overhaul-artwork/full-catalog-v1';BASE=ROOT/'docs/qa/pio-outfit-phase2.2-2026-10-16/candidates/base';hashes={}
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):hashes[str(p)]=sha(p);return Image.open(p).convert('RGBA')
def fit(source,target):
 im=read(source); bb=im.getchannel('A').point(lambda a:255 if a>=16 else 0).getbbox();tb=target.getchannel('A').point(lambda a:255 if a>=16 else 0).getbbox();scale=(tb[2]-tb[0])/(bb[2]-bb[0]);center=[(tb[0]+tb[2])/2,(tb[1]+tb[3])/2];off=[round(center[0]-(bb[0]+bb[2])/2*scale),round(center[1]-(bb[1]+bb[3])/2*scale)];q=Image.new('RGBA',(1254,1254));q.alpha_composite(im.resize((round(im.width*scale),round(im.height*scale)),Image.Resampling.LANCZOS),off);return q,{'source':str(source),'scale':scale,'offset':off}
for name in ['cafe','student','summerVacation']:
 folder=OUT/name;folder.mkdir(exist_ok=True);(folder/'layers').mkdir(exist_ok=True);m=json.loads((CAT/name/'registration.json').read_text());parts=m['normalizedParts'];layers={p['id']:read(CAT/name/p['file']) for p in parts};newmeta=[]
 if name in ['cafe','student']:
  for side in ['Left','Right']:
   im,fitdata=fit(BASE/'eye-half-v1.png',layers['eye'+side]);layers['half'+side]=im;im.save(folder/'layers'/('half'+side+'.png'));newmeta.append({'id':'half'+side,**fitdata})
 else:
  # Genuine nativev3 pair, original pair-relative fit. Keep frame optically on top.
  kit=ROOT/'output/pio-character-overhaul-artwork/summerVacation-v1';frame=next(p for p in json.loads((kit/'registration/optional-frame-registration.json').read_text())['layers'] if p['id']=='sunglasses');q=Image.new('RGBA',(1254,1254));src=read(OUT/'sources/summer-lenses-v3.png');q.alpha_composite(src.resize((round(src.width*.37),round(src.height*.37)),Image.Resampling.LANCZOS),(312,438));fr=read(frame['source']);fr=fr.resize((round(fr.width*frame['scale']),round(fr.height*frame['scale'])),Image.Resampling.LANCZOS);q.alpha_composite(fr,tuple(round(x) for x in frame['offset']));layers['sunglasses']=q;q.save(folder/'layers/sunglasses-v3.png');newmeta.append({'id':'sunglasses','source':str(OUT/'sources/summer-lenses-v3.png'),'scale':.37,'offset':[312,438],'frame':frame})
 if name=='summerVacation':
  for side in ['Left','Right']:
   im,fitdata=fit(BASE/'eye-half-v1.png',layers['eye'+side]);layers['half'+side]=im;im.save(folder/'layers'/('half'+side+'.png'));newmeta.append({'id':'half'+side,**fitdata})
 states={}
 for state in ['open','half','closed']:
  c=Image.new('RGBA',(1254,1254))
  for p in sorted(parts,key=lambda p:p['z']):
   id=p['id']
   if id.startswith(('lid','half')):continue
   if id.startswith('eye'):id=('eye' if state=='open' else 'half' if state=='half' else 'lid')+id[3:]
   c.alpha_composite(layers[id])
  states[state]=c;c.save(folder/(state+'-alpha.png'))
 for pt in [64,220]:
  for factor in [1,3]:
   n=pt*factor
   for theme,bg,fg in [('light','#faf6ed','#23483d'),('dark','#14251f','#f8efdb')]:
    b=Image.new('RGBA',(3*(n+25)+25,n+80),bg);d=ImageDraw.Draw(b)
    for i,(state,im) in enumerate(states.items()):b.alpha_composite(im.resize((n,n),Image.Resampling.LANCZOS),(25+i*(n+25),55));d.text((25+i*(n+25),15),state,fill=fg)
    b.convert('RGB').save(folder/f'{pt}pt-{factor}x-{theme}.png')
 (folder/'registration.json').write_text(json.dumps({'status':'UNAPPROVED_CANDIDATE','newParts':newmeta,'sourceHashes':hashes,'sourceUnchanged':True,'notAppIntegrated':True},indent=2)+'\n')
assert all(sha(p)==h for p,h in hashes.items());(OUT/'verification.json').write_text(json.dumps({'sourceHashes':hashes,'sourcesUnchanged':True,'scope':'offline artwork registration, no app tests'},indent=2)+'\n');print('Cafe/Student half-eye registrations and Summerv3 review saved')
