"""Artwork-only motion proof; no application/runtime claims."""
from pathlib import Path
from PIL import Image,ImageDraw
import math,json,hashlib
BASE=Path(__file__).resolve().parent.parent
S=440
for name in (__import__('sys').argv[1:] or ['cafe','student']):
 folder=BASE/f'{name}-v1';out=folder/'registration';m=json.loads((out/'registration-candidate.json').read_text());r=S/m['canvas'][0];parts=m['parts'];scaled={}
 for p in parts:
  im=Image.open(p['source']).convert('RGBA');scaled[p['id']]=im.resize((round(im.width*p['scale']*r),round(im.height*p['scale']*r)),Image.Resampling.LANCZOS)
 frames=[];frameinfo=[]
 for f in range(40):
  phase=f/40;amount=(1-math.cos(phase*math.tau))/2;angle=-6*amount;dy=-25*amount;wing=12*math.sin(phase*math.tau*2);closed=f in [10,11,30,31];c=Image.new('RGBA',(S,S),(18,28,25,255))
  for p in sorted(parts,key=lambda a:a['z']):
   ident=p['id']
   if ident.startswith('eye') and closed:continue
   if ident.startswith('lid') and not closed:continue
   layer=Image.new('RGBA',(S,S));layer.alpha_composite(scaled[ident],(round(p['offset'][0]*r),round(p['offset'][1]*r)))
   extra=wing if ident=='wingRight' else angle if ident in m['grip']['parts'] else 0
   total=p['angle']+extra
   if total:layer=layer.rotate(-total,resample=Image.Resampling.BICUBIC,center=[p['pivot'][0]*r,p['pivot'][1]*r])
   if ident in m['grip']['parts']:
    translated=Image.new('RGBA',(S,S));translated.alpha_composite(layer,(0,round(dy*r)));layer=translated
   c.alpha_composite(layer)
  d=ImageDraw.Draw(c);d.text((8,5),'OFFLINE ARTWORK CANDIDATE | body fixed',fill='white');frames.append(c.convert('RGB'));frameinfo.append({'frame':f,'eyes':'closed' if closed else 'open','rightWingDegrees':wing,'leftGripDegrees':angle,'leftGripTranslateY':dy})
 frames[0].save(out/'offline-independent-proof.gif',save_all=True,append_images=frames[1:],duration=80,loop=0,optimize=False)
 contact=Image.new('RGB',(S*3,S),(18,28,25));d=ImageDraw.Draw(contact)
 for j,k in enumerate([0,10,20]):contact.paste(frames[k],(j*S,0));d.text((j*S+8,25),f'frame{k} eyes {frameinfo[k]["eyes"]}',fill='white')
 contact.save(out/'offline-motion-frames.png')
 sourceproof={p['source']:hashlib.sha256(Path(p['source']).read_bytes()).hexdigest()==p['sourceSHA256'] for p in parts};assert all(sourceproof.values())
 (out/'offline-motion-proof.json').write_text(json.dumps({'status':'OFFLINE_ARTWORK_CANDIDATE_NOT_NATIVE_APP','dimensions':[S,S],'frameCount':40,'frameMilliseconds':80,'sourceHashesUnchanged':sourceproof,'bodyTransform':'fixed','notes':['Right wing rotates independently','Left prop and arm share pivot/angle/translation','Eyes switch genuine open/closed artwork; no whole-body flattened rotation','No native performance or animation approval'],'frames':frameinfo},indent=2))
 print(name,'offline GIF saved')
