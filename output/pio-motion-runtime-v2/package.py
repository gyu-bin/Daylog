from pathlib import Path
from PIL import Image
import hashlib,json
root=Path('output/pio-character-overhaul-artwork/full-catalog-v1');out=Path('Daylog/PioOverhaulTrial.xcassets');out.mkdir(exist_ok=True)
meta={'info':{'version':1,'author':'xcode'}};(out/'Contents.json').write_text(json.dumps(meta))
rows=[]
for reg in sorted(root.glob('*/registration.json')):
 m=json.loads(reg.read_text());parts=list(m['normalizedParts']);ids={p['id'] for p in parts}
 for side in ('Left','Right'):
  eye=next(p for p in parts if p['id']=='eye'+side)
  if 'happy'+side not in ids and (reg.parent/'layers'/('happy'+side+'.png')).exists():parts.append(dict(eye,id='happy'+side,file='layers/happy'+side+'.png'))
 manifest={'outfit':m['outfit'],'canvas':1254,'revision':'runtime-v2-candidate','parts':[]}
 for p in parts:
  src=reg.parent/p['file'];im=Image.open(src).convert('RGBA');box=im.getchannel('A').getbbox();assert box
  asset='pio_overhaul_'+m['outfit']+'_'+p['id'];d=out/(asset+'.imageset');d.mkdir(exist_ok=True);cropped=im.crop(box);cropped.save(d/(asset+'.png'))
  (d/'Contents.json').write_text(json.dumps({'info':meta['info'],'images':[{'filename':asset+'.png','idiom':'universal'}]}))
  rebuilt=Image.new('RGBA',im.size);rebuilt.paste(cropped,box[:2]);assert rebuilt.getchannel('A').tobytes()==im.getchannel('A').tobytes()
  # Only RGB beneath zero alpha is discarded; every visible pixel is lossless.
  assert all(a==b for a,b in zip(im.getdata(),rebuilt.getdata()) if a[3])
  part={'id':p['id'],'asset':asset,'rect':[box[0],box[1],box[2]-box[0],box[3]-box[1]],'pivot':p['pivot'],'z':p['z']}
  manifest['parts'].append(part);rows.append({'source':str(src),'sourceSHA256':hashlib.sha256(src.read_bytes()).hexdigest(),'asset':asset,'rect':part['rect']})
 d=out/('pio_overhaul_'+m['outfit']+'_registration.dataset');d.mkdir(exist_ok=True);(d/'registration.json').write_text(json.dumps(manifest,indent=2));(d/'Contents.json').write_text(json.dumps({'info':meta['info'],'data':[{'filename':'registration.json','idiom':'universal'}]}))
Path('output/pio-motion-runtime-v2/asset-verification.json').write_text(json.dumps({'status':'PASS_VISIBLE_PIXEL_PRESERVATION','outfits':14,'parts':len(rows),'method':'Crop alpha-zero padding only; source art untouched; full visible RGBA equality verified','items':rows},indent=2))
print(len(rows),'parts')
