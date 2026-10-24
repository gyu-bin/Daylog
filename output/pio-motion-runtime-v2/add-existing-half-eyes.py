from pathlib import Path
from PIL import Image
import hashlib,json
out=Path('Daylog/PioOverhaulTrial.xcassets');report=Path('output/pio-motion-runtime-v2/asset-verification.json');data=json.loads(report.read_text())
for outfit in ('cafe','student','summerVacation'):
 mp=out/f'pio_overhaul_{outfit}_registration.dataset/registration.json';m=json.loads(mp.read_text())
 for side in ('Left','Right'):
  id='half'+side
  if any(p['id']==id for p in m['parts']):continue
  source=Path('output/pio-completion-2026-10-23/expressions')/outfit/'layers'/(id+'.png');im=Image.open(source).convert('RGBA');assert im.size==(1254,1254)
  box=im.getchannel('A').getbbox();c=im.crop(box);rebuilt=Image.new('RGBA',im.size);rebuilt.paste(c,box[:2]);assert rebuilt.getchannel('A').tobytes()==im.getchannel('A').tobytes();assert all(a==b for a,b in zip(im.getdata(),rebuilt.getdata()) if a[3])
  asset=f'pio_overhaul_{outfit}_{id}';d=out/(asset+'.imageset');d.mkdir(exist_ok=True);c.save(d/(asset+'.png'));(d/'Contents.json').write_text(json.dumps({'info':{'version':1,'author':'xcode'},'images':[{'filename':asset+'.png','idiom':'universal'}]}))
  eye=next(p for p in m['parts'] if p['id']=='eye'+side);part=dict(eye,id=id,asset=asset,rect=[box[0],box[1],box[2]-box[0],box[3]-box[1]]);m['parts'].append(part);data['items'].append({'source':str(source),'sourceSHA256':hashlib.sha256(source.read_bytes()).hexdigest(),'asset':asset,'rect':part['rect']})
 mp.write_text(json.dumps(m,indent=2))
data['parts']=len(data['items']);report.write_text(json.dumps(data,indent=2));print(data['parts'])
