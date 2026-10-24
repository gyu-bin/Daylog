"""Offline QA only. Independent layer transforms; never changes source pixels/files."""
from pathlib import Path
from PIL import Image,ImageDraw
import json,math,hashlib
base=Path(__file__).resolve().parent.parent
out=Path(__file__).resolve().parent/'cherry-motion';out.mkdir(exist_ok=True)
m=json.loads((base/'cherryBlossom-v2/registration/registration-candidate.json').read_text())
pm=json.loads((base/'cherryBlossom-v2/registration/signature-static.json').read_text())
S=440;r=S/m['canvas'][0]
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
hashes={p['source']:sha(p['source']) for p in m['layers']};hashes[pm['source']]=sha(pm['source'])
scaled={}
for p in m['layers']:
 im=Image.open(p['source']).convert('RGBA');scaled[p['id']]=im.resize((round(im.width*p['scale']*r),round(im.height*p['scale']*r)),Image.Resampling.LANCZOS)
petal=Image.open(pm['source']).convert('RGBA')
frames=[];states=[]
for frame in range(48):
 t=frame/48;wave=12*math.sin(t*math.tau*2)
 # Two authored blink samples, with actual half/closed assets, no squash substitute.
 state='half' if frame in [10,13,34,37] else 'closed' if frame in [11,12,35,36] else 'open'
 c=Image.new('RGBA',(S,S),(18,28,25,255))
 for p in sorted(m['layers'],key=lambda p:p['z']):
  ident=p['id']
  if ident.startswith('eye') and state!='open':continue
  if ident.startswith('lid') and state!='closed':continue
  if ident.startswith('half') and state!='half':continue
  layer=Image.new('RGBA',(S,S));layer.alpha_composite(scaled[ident],(round(p['offset'][0]*r),round(p['offset'][1]*r)))
  angle=p['neutralAngleDegrees']+(wave if ident.startswith('wing') else 0)
  if angle:layer=layer.rotate(-angle,resample=Image.Resampling.BICUBIC,center=(p['pivot'][0]*r,p['pivot'][1]*r))
  c.alpha_composite(layer)
 for i,p in enumerate(pm['instances']):
  im=petal.resize((round(petal.width*p['scale']*r),round(petal.height*p['scale']*r)),Image.Resampling.LANCZOS)
  dx=10*math.sin(t*math.tau+i);dy=15*math.sin(t*math.tau+i*.8)
  c.alpha_composite(im,(round(p['offset'][0]*r+dx),round(p['offset'][1]*r+dy)))
 # Label lives outside art bounds; output is explicitly QA proof.
 d=ImageDraw.Draw(c);d.text((8,5),'OFFLINE ARTWORK CANDIDATE | body fixed',fill=(230,230,215))
 frames.append(c.convert('RGB'));states.append({'frame':frame,'eyes':state,'wingDeltaDegrees':wave})
frames[0].save(out/'cherry-independent-offline-proof.gif',save_all=True,append_images=frames[1:],duration=80,loop=0,optimize=False)
contact=Image.new('RGB',(S*3,S*2),(18,28,25));d=ImageDraw.Draw(contact)
for j,k in enumerate([0,6,10,11,18,36]):contact.paste(frames[k],((j%3)*S,(j//3)*S));d.text(((j%3)*S+8,(j//3)*S+25),f'frame {k}: {states[k]["eyes"]}, wing {states[k]["wingDeltaDegrees"]:.1f}',fill='white')
contact.save(out/'cherry-motion-frame-proof.png')
unchanged={p:sha(p)==h for p,h in hashes.items()};assert all(unchanged.values())
report={'status':'OFFLINE_CANDIDATE_PROOF_NOT_RUNTIME_QA','dimensions':[S,S],'frame_count':len(frames),'duration_ms':3840,'body_transform':'fixed at registered offset, scale1; no frame-varying motion','body_source_hash':hashes[next(p['source'] for p in m['layers'] if p['id']=='body')],'all_source_hashes_unchanged':unchanged,'frames':states,'limits':['No native app playback','No performance, walk, jump, landing or production approval','Petal drift uses one unchanged source instanced three times','GIF palette reduction is QA export only; original source PNGs untouched']}
(out/'motion-proof.json').write_text(json.dumps(report,indent=2))
print(out)
