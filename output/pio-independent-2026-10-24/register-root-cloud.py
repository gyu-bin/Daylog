"""Byte-identical new artwork import; metadata registration only, no raster editing."""
from pathlib import Path
import json, shutil, hashlib
from PIL import Image
import numpy as np
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
CAT=ROOT/'Daylog/PioOverhaulTrial.xcassets'
GEN=Path('/Users/mungyubin/.codex/generated_images/01a13e4c-eb2f-7c33-a58c-004a195b88c3')
def save(p,data):p.write_text(json.dumps(data,indent=2)+'\n')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def part(pid,asset,rect,pivot,z,sampler=None):
 d=dict(id=pid,asset=asset,rect=rect,pivot=pivot,z=z)
 if sampler:d['contentsRect']=sampler
 return d
for outfit,names in json.loads((HERE/'root-cloud-sources.json').read_text()).items():
 out=HERE/f'{outfit}-cloud';provenance=[]
 for key,name in zip(['torso','armPair'],names):
  source=out/f'{key}-candidate-v1.png'
  if source.exists():assert sha(source)==sha(GEN/name)
  else:shutil.copyfile(GEN/name,source)
  asset=f'pio_cloud_{outfit}_v2_{key}';folder=CAT/f'{asset}.imageset';folder.mkdir(exist_ok=True)
  dest=folder/f'{asset}.png'
  if dest.exists():assert sha(dest)==sha(source)
  else:shutil.copyfile(source,dest)
  save(folder/'Contents.json',{'images':[{'filename':dest.name,'idiom':'universal'}],'info':{'author':'xcode','version':1}})
  with Image.open(source) as im:
   assert im.mode=='RGBA' and im.getchannel('A').getextrema()==(0,255)
   provenance.append(dict(source=str(source.relative_to(ROOT)),asset=asset,dimensions=list(im.size),sha256=sha(source),sourcePixelsChanged=False))
 parts=[part('body',f'pio_cloud_{outfit}_v2_torso',[0,0,1254,1254],[627,627],0)]
 for z,pid in enumerate(['eyeLeft','eyeRight','lidLeft','lidRight','halfLeft','halfRight','browLeft','browRight'],1):
  parts.append(part(pid,f'pio_cloud_{outfit}_{pid}',[0,0,1254,1254],[627,627],z))
 # Per-outfit target rectangles refer to original seated source, not universal shoulder correction.
 configs={
  'student':([496,888,360,220],[270,835,282,240],[800,835,262,240],[676,1000]),
  'fitness':([496,808,360,242],[278,850,274,210],[800,850,255,210],[676,940]),
  'rainyDay':([496,808,360,242],[290,850,262,212],[800,850,247,212],[676,940])}
 tablet,left,right,pivot=configs[outfit]
 parts.append(part('tablet','pio_cloud_basic_v1_tablet',tablet,pivot,10,[289/1254,509/1254,680/1254,546/1254]))
 with Image.open(out/'armPair-candidate-v1.png') as im:
  a=np.array(im);w,h=im.size
  for side,(lo,hi,target) in enumerate([(0,w//2,left),(w//2,w,right)]):
   ys,xs=np.where(a[:,lo:hi,3]>8)
   x=max(0,int(xs.min()+lo)-4);y=max(0,int(ys.min())-4)
   x2=min(w,int(xs.max()+lo)+5);y2=min(h,int(ys.max())+5)
   parts.append(part('armLeft' if side==0 else 'armRight',f'pio_cloud_{outfit}_v2_armPair',target,pivot,11+side,[x/w,y/h,(x2-x)/w,(y2-y)/h]))
 optics=CAT/f'pio_cloud_{outfit}_optics.imageset'
 if optics.exists():parts.append(part('optics',f'pio_cloud_{outfit}_optics',[0,0,1254,1254],[627,627],30))
 data=dict(outfit=outfit,canvas=1254,revision=f'{outfit}-hands-v2',approval='CANDIDATE_PENDING_NATIVE_VISUAL_QA',parts=parts,holdGroup=dict(ids=['tablet','armLeft','armRight'],pivot=pivot,degrees=1.5),source=f'output/pio-completion-2026-10-23/cloud/{outfit}/layers/body.png',sourcePixelEdits=False,samplerContract='Top-left source coordinates normalized to actual PNG dimensions, canonical target1254',unsupported=['hand release/free waving','independent headwear/feet'],safeTransformRange='shared hand/tablet occupied grip ±1.5 degrees only; verify shoulder continuity',candidateShoulderLocations=dict(Left=left[:2],Right=right[:2]),candidateShoulderLocationsApproved=False)
 save(out/'registration-v2.json',data);save(out/'provenance.json',provenance)
 folder=CAT/f'pio_cloud_{outfit}_v2_registration.dataset';folder.mkdir(exist_ok=True)
 save(folder/'registration.json',data);save(folder/'Contents.json',{'data':[{'filename':'registration.json','idiom':'universal'}],'info':{'author':'xcode','version':1}})
 print(outfit,len(parts),provenance)
