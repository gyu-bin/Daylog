"""Evidence for review artifacts only; does not launch or test the application."""
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw
import json,hashlib,importlib.util
D=Path(__file__).resolve().parent
m=json.loads((D/'registration-and-provenance.json').read_text())
spec=importlib.util.spec_from_file_location('rainy_registration',D/'register-and-qa.py');r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
rows=[]
for p in m['parts']:
    im=Image.open(D/'registered-layers'/p['file'])
    rows.append({'part':p['id'],'1254RGBA':im.size==(1254,1254) and im.mode=='RGBA','sourceHashMatchesPreviousSnapshot':sha(p['source'])==p['sourceSHA256'],'sourceHashMatchesCurrentManifest':sha(p['source'])==next(x['sha256'] for x in m['sourceAudit'] if x['source']==p['source']),'scaleAtMostOne':p['scale']<=1,'outsideAnyAlphaPixels':p['outsideAnyAlphaPixels'],'outsideAlpha16Pixels':p['outsideAlpha16Pixels']})
byid={p['id']:p for p in r.parts}
poses={}
for angle in [-5,0]:
    canopy=r.render(byid['umbrellaCanopy'],angle).getchannel('A');shaft=r.render(byid['umbrellaShaft'],angle).getchannel('A');hand=r.render(byid['wingRight'],angle).getchannel('A')
    both=lambda a,b:sum(ImageChops.multiply(a,b).histogram()[1:])
    poses[str(angle)]={'canopyShaftAlphaOverlapPixels':both(canopy,shaft),'handShaftAlphaOverlapPixels':both(hand,shaft)}
motionBounds=[]
for pid,angles in [('wingLeft',[-12,12]),('umbrellaCanopy',[-5,0]),('umbrellaShaft',[-5,0]),('wingRight',[-5,0])]:
 for angle in angles:
  alpha=r.render(byid[pid],angle,pad=512).getchannel('A');raw=alpha.tobytes();w=alpha.width;pad=512
  outside=raw[:pad*w]+raw[(pad+1254)*w:]
  for y in range(pad,pad+1254):outside+=raw[y*w:y*w+pad]+raw[y*w+pad+1254:(y+1)*w]
  motionBounds.append(dict(part=pid,angle=angle,outsideAnyAlphaPixels=sum(a>0 for a in outside),outsideAlpha16Pixels=sum(a>=16 for a in outside)))
gif=Image.open(D/'independent-offline-proof.gif')
sheet=Image.new('RGB',(2048,542),(18,28,26));draw=ImageDraw.Draw(sheet)
for i,f in enumerate([0,12,19,36]):
 gif.seek(f);sheet.paste(gif.convert('RGB'),(i*512,30));draw.text((i*512+10,10),f'Decoded GIF frame {f}',fill='white')
sheet.save(D/'gif-decoded-frames.png')
report={'status':'OFFLINE_ARTWORK_EVIDENCE_ONLY_NOT_APP_VERIFICATION','originalApprovedHashUnchanged':sha(m['original'])==m['originalSHA256'],'components':rows,'sharedGripPivot':all(byid[x]['pivot']==[745,875] for x in ['umbrellaCanopy','umbrellaShaft','wingRight']),'depthOrder':[p['id'] for p in r.parts if p['id'] in ['umbrellaCanopy','body','umbrellaShaft','wingRight']],'umbrellaPoses':poses,'motionBounds':motionBounds,'gif':{'size':list(gif.size),'frames':gif.n_frames,'durationMs':gif.info.get('duration'),'loop':gif.info.get('loop')},'bodyMotion':'None. Source transform and body derivative fixed for every GIF frame; only left wing, umbrella grip group, and mutually exclusive eyes change.'}
(D/'offline-verification.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
