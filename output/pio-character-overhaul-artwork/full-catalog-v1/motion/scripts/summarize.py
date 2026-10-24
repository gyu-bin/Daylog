from pathlib import Path
from PIL import Image,ImageDraw
import json,hashlib
O=Path(__file__).resolve().parents[1];R=O.parent
names=['basic','cherryBlossom','summerVacation','autumn','winter','halloween','christmas','hanbok','astronaut','rainyDay','cafe','student','fitness','pajamas']
summary=[];montage=Image.new('RGB',(7*200,2*230),'#172823');draw=ImageDraw.Draw(montage)
for i,name in enumerate(names):
 D=O/name;m=json.loads((D/'motion-manifest.json').read_text());checks=[]
 for rel,h in m['canonicalLayerSHA256'].items():checks.append(hashlib.sha256((R/rel).read_bytes()).hexdigest()==h)
 checks.append(hashlib.sha256((R/name/'registration.json').read_bytes()).hexdigest()==m['sourceRegistrationSHA256'])
 for p in list(D.glob('*-keypose-alpha.png'))+[D/'eight-actions-contact.png',D/'decoded-gif-samples.png']:
  with Image.open(p) as im:im.load()
 with Image.open(D/'eight-actions-offline.gif') as g:
  elapsed=0
  for n in range(g.n_frames):
   g.seek(n);elapsed+=g.info.get('duration',90)
   if elapsed>=6480:break
  im=g.convert('RGB').resize((200,218),Image.Resampling.LANCZOS)
 x=(i%7)*200;y=(i//7)*230;montage.paste(im,(x,y+12));draw.text((x+5,y+2),name,fill='white')
 summary.append({'outfit':name,'status':m['status'],'keyposePNGCount':len(list(D.glob('*-keypose-alpha.png'))),'gifFrames':m['gif']['frames'],'sampledFrames':m['sampledFrameCount'],'borderAlphaCheck':m['borderAlphaCheck'],'durationMs':m['totalDurationMs'],'sequences':m['sequences'],'uniqueGIFFrames':m['gif']['uniqueDecodedFrames'],'allCanonicalInputsUnchanged':all(checks)})
montage.save(O/'all14-decoded-greet-samples.png')
res={'status':'PARTIAL_OFFLINE_ACTION_STUDIES_ONLY','catalogCount':len(summary),'actionCount':8,'keyposePNGCount':sum(r['keyposePNGCount'] for r in summary),'gifCount':len(summary),'allCanonicalInputsUnchanged':all(r['allCanonicalInputsUnchanged'] for r in summary),'outfits':summary}
(O/'motion-summary.json').write_text(json.dumps(res,indent=2));print(json.dumps(res,indent=2))
