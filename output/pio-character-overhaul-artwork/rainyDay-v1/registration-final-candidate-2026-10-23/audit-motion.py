from pathlib import Path
from PIL import Image
import json,math,importlib.util
D=Path(__file__).resolve().parent
s=importlib.util.spec_from_file_location('r',D/'register-and-qa.py');r=importlib.util.module_from_spec(s);s.loader.exec_module(r)
rows=[]
for i in range(48):
 phase=i*2*math.pi/48;grip=-5*max(0,math.sin(phase));left=12*math.sin(phase)
 for p in r.parts:
  if p['id'] not in ['wingLeft','umbrellaCanopy','umbrellaShaft','wingRight']:continue
  angle=left if p['id']=='wingLeft' else grip
  a=r.render(p,angle,pad=512).getchannel('A');h=a.histogram();inside=a.crop((512,512,1766,1766)).histogram()
  rows.append({'frame':i,'part':p['id'],'angle':angle,'outsideAnyAlphaPixels':sum(h[1:])-sum(inside[1:]),'outsideAlpha16Pixels':sum(h[16:])-sum(inside[16:])})
report={'method':'Bounds count from one padded raster then exact1254crop (not subtracting separately interpolated renders).','frames':48,'rows':rows,'maxOutsideAnyAlphaPixels':max(x['outsideAnyAlphaPixels'] for x in rows),'maxOutsideAlpha16Pixels':max(x['outsideAlpha16Pixels'] for x in rows)}
(D/'all-frames-motion-bounds.json').write_text(json.dumps(report,indent=2));print(report['maxOutsideAnyAlphaPixels'],report['maxOutsideAlpha16Pixels'])
