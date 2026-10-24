"""Offline grip transform QA; source files untouched, no native app claims."""
from pathlib import Path
from PIL import Image,ImageDraw
import json,math,hashlib
base=Path(__file__).resolve().parent.parent
out=Path(__file__).resolve().parent/'summer-motion';out.mkdir(exist_ok=True)
m=json.loads((base/'summerVacation-v1/registration/registration-candidate.json').read_text())
S=440;r=S/m['canvas'][0]
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
hashes={p['source']:sha(p['source']) for p in m['parts']}
scaled={}
for p in m['parts']:
 im=Image.open(p['source']).convert('RGBA');scaled[p['id']]=im.resize((round(im.width*p['scale']*r),round(im.height*p['scale']*r)),Image.Resampling.LANCZOS)
frames=[];states=[]
for f in range(48):
 t=f/48;amount=(1-math.cos(t*math.tau))/2;delta=-6*amount;dy=-25*amount
 c=Image.new('RGBA',(S,S),(18,28,25,255))
 for p in sorted(m['parts'],key=lambda p:p['z']):
  ident=p['id'];layer=Image.new('RGBA',(S,S));layer.alpha_composite(scaled[ident],(round(p['offset'][0]*r),round(p['offset'][1]*r)))
  # Neutral local articulation first; drink and sleeve then receive identical world transform.
  if p['angle']:layer=layer.rotate(-p['angle'],resample=Image.Resampling.BICUBIC,center=(p['pivot'][0]*r,p['pivot'][1]*r))
  if ident in m['grip']['parts']:
   layer=layer.rotate(-delta,resample=Image.Resampling.BICUBIC,center=(m['grip']['pivot'][0]*r,m['grip']['pivot'][1]*r))
   moved=Image.new('RGBA',(S,S));moved.alpha_composite(layer,(0,round(dy*r)));layer=moved
  elif ident=='wingLeft':layer=layer.rotate(-12*math.sin(t*math.tau*2),resample=Image.Resampling.BICUBIC,center=(p['pivot'][0]*r,p['pivot'][1]*r))
  c.alpha_composite(layer)
 d=ImageDraw.Draw(c);d.text((8,5),'OFFLINE CANDIDATE | shared cup/hand grip',fill=(230,230,215))
 frames.append(c.convert('RGB'));states.append({'frame':f,'shared_grip_angle':delta,'shared_grip_translation':[0,dy]})
frames[0].save(out/'summer-grip-offline-proof.gif',save_all=True,append_images=frames[1:],duration=80,loop=0,optimize=False)
contact=Image.new('RGB',(S*3,S),(18,28,25));d=ImageDraw.Draw(contact)
for j,k in enumerate([0,12,24]):contact.paste(frames[k],(j*S,0));d.text((j*S+8,25),f'frame {k}, grip {states[k]["shared_grip_angle"]:.1f} degrees',fill='white')
contact.save(out/'summer-grip-frame-proof.png')
unchanged={p:sha(p)==h for p,h in hashes.items()};assert all(unchanged.values())
(out/'motion-proof.json').write_text(json.dumps({'status':'OFFLINE_CANDIDATE_PROOF_NOT_RUNTIME_QA','size':[S,S],'frames':states,'body_source_hash':hashes[next(p['source'] for p in m['parts'] if p['id']=='body')],'sources_unchanged':unchanged,'limits':['Opaque sunglasses do not demonstrate visible blink','Hat and sprout remain combined','No native app performance or timing QA','Source source-over only; no alpha edits']},indent=2))
print(out)
