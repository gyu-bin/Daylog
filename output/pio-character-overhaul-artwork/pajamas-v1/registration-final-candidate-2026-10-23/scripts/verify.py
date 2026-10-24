from PIL import Image,ImageDraw
from pathlib import Path
import json,hashlib
O=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
m=json.loads((O/'registration-candidate.json').read_text());sources=[]
for p in m['parts']:
 sources.append({'id':p['id'],'source':p['source'],'matchesRecordedSHA256':sha(p['source'])==p['sourceSHA256']})
files=[]
for p in sorted(O.glob('*.png'))+sorted((O/'exports').glob('*.png')):
 with Image.open(p) as im:
  im.load();files.append({'file':str(p.relative_to(O)),'size':im.size,'mode':im.mode,'sha256':sha(p)})
g=Image.open(O/'sleepy-hug-offline.gif');frames=[];hashes=[];dur=[]
for n in range(g.n_frames):
 g.seek(n);im=g.convert('RGB');hashes.append(hashlib.sha256(im.tobytes()).hexdigest());dur.append(g.info.get('duration'))
 if n in [0,8,16,24]:frames.append((n,im.copy()))
s=Image.new('RGB',(440*4,470),'#172823');d=ImageDraw.Draw(s)
for k,(n,im) in enumerate(frames):s.paste(im,(k*440,30));d.text((k*440+10,10),f'Decoded GIF frame {n}',fill='white')
s.save(O/'gif-decoded-frames.png')
r={'status':'PARTIAL_ARTWORK_CANDIDATE','sourceHashesUnchanged':all(p['matchesRecordedSHA256'] for p in sources),'sources':sources,'registeredLayerCount':len(list((O/'exports').glob('*.png'))),'files':files,'gif':{'size':g.size,'frames':g.n_frames,'durationMilliseconds':dur,'distinctDecodedFrames':len(set(hashes)),'frameSHA256':hashes},'notTested':['Mac app rendering','iPhone simulator','runtime performance','Reduce Motion','walking/jumping/landing'],'method':'Pillow offline whole-image downscale, affine placement and mirror only; genuine native source alpha preserved; no masking, repainting, crop, upscaling or alpha cleanup.'}
(O/'artifact-audit.json').write_text(json.dumps(r,indent=2));print(json.dumps({k:r[k] for k in ['status','sourceHashesUnchanged','registeredLayerCount']},indent=2))
