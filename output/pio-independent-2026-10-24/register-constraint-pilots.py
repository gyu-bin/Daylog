"""Register genuine Hanbok/Astronaut cloud reconstructions non-destructively.
No raster editing: only copies, alpha measurements and runtime sampler metadata.
"""
from pathlib import Path
from PIL import Image
import json,hashlib,shutil
import numpy as np
BASE=Path(__file__).resolve().parent
ROOT=BASE.parents[1]
CAT=ROOT/'Daylog/PioOverhaulTrial.xcassets'
GEN=Path('/Users/mungyubin/.codex/generated_images/01a167e0-d86f-7633-94a1-40ac5235c4f4')
CONFIG={
 'hanbok':{
  'torso':GEN/'exec-59f8de6c-18df-44bb-a72c-2435ebb24d1f.png',
  'armPair':GEN/'exec-6738e81f-aa0c-49dc-b55c-f5bfe690b1d9.png',
  'samples':{'Left':[39,590,566,435],'Right':[698,595,517,434]},
  'targets':{'Left':[285,835,275,210],'Right':[792,835,265,210]},
  'tablet':[494,785,362,243], 'tabletOriginalBBox':[497,787,853,1025],
  'pivot':[675,910], 'shoulders':{'Left':[320,855],'Right':[1010,855]},
  'notes':['Generated sleeve-pair v1 contained extraneous loose collar flaps and was NOT registered. Refined source has rounded complete sleeve roots.','Hidden pink floral torso and darkblue waist bow are genuinely reconstructed; no original source pixels overwritten.']},
 'astronaut':{
  'torso':GEN/'exec-aad30872-f766-4409-9e5c-cce581c1126f.png',
  'armPair':GEN/'exec-1c0f2f6c-62f4-4c88-87df-b295b3c7555f.png',
  'armAsset':'pio_cloud_astronaut_v2_armPairCompact','armVersion':2,
  'samples':{'Left':[163,853,404,271],'Right':[690,852,401,273]},
  'targets':{'Left':[275,850,280,210],'Right':[790,850,265,210]},
  'tablet':[493,804,366,249], 'tabletOriginalBBox':[496,807,856,1049],
  'pivot':[676,930], 'shoulders':{'Left':[310,865],'Right':[1020,865]},
  'notes':['Existing separate visor/optics layer and existing genuine eyes are preserved; helmet is not replaced by a Basic-Pio face.','Initial1388x1133long-arm atlas created miniature mitten proportions and duplicate-padding impression in native review; NOT promoted. New compact genuine1254arm atlas repairs proportions without erasing approved side/hip padding.','Optics z9 is above face/eyes but behind held tablet z10, preventing visor bottom rim from painting over the device. Source visor PNG unchanged.','No drink/straw/open visor or new suit controls added. Rounded padded suit roots/cuffs require native review.']},
}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def copy_safe(src,dst):
 dst.parent.mkdir(parents=True,exist_ok=True)
 if dst.exists():assert sha(src)==sha(dst),f'Refusing differing overwrite{dst}'
 else:shutil.copyfile(src,dst)
 assert sha(src)==sha(dst)
def pdef(pid,asset,rect,pivot,z,sample=None,size=(1254,1254)):
 p={'id':pid,'asset':asset,'rect':rect,'pivot':pivot,'z':z}
 if sample:p['contentsRect']=[sample[0]/size[0],sample[1]/size[1],sample[2]/size[0],sample[3]/size[1]]
 return p
summary=[]
for oid,c in CONFIG.items():
 out=BASE/f'{oid}-cloud';out.mkdir(exist_ok=True)
 prov=[];sizes={}
 for component in ['torso','armPair']:
  source=c[component];version=c.get('armVersion',1) if component=='armPair' else 1
  local=out/'source'/f'{component}-candidate-v{version}.png';copy_safe(source,local)
  asset=c.get('armAsset',f'pio_cloud_{oid}_v2_{component}') if component=='armPair' else f'pio_cloud_{oid}_v2_{component}'
  folder=CAT/f'{asset}.imageset';folder.mkdir(exist_ok=True)
  dest=folder/f'{asset}.png';copy_safe(source,dest)
  (folder/'Contents.json').write_text(json.dumps({'images':[{'filename':dest.name,'idiom':'universal'}],'info':{'author':'xcode','version':1}},indent=2)+'\n')
  with Image.open(source) as im:
   assert im.mode=='RGBA'
   if component=='torso':assert im.size==(1254,1254)
   sizes[component]=im.size;a=np.array(im.getchannel('A'));yy,xx=np.where(a>=16)
   prov.append({'part':component,'generatorOutput':str(source),'source':str(local.relative_to(ROOT)),
     'asset':asset,'catalog':str(dest.relative_to(ROOT)),'nativeSize':list(im.size),'mode':im.mode,
     'alphaExtrema':list(im.getchannel('A').getextrema()),'alpha16bbox':[int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1)],
     'sha256':sha(source),'pixelsChanged':False,'approved':False})
 parts=[pdef('body',f'pio_cloud_{oid}_v2_torso',[0,0,1254,1254],[627,627],0)]
 for z,pid in enumerate(['eyeLeft','eyeRight','lidLeft','lidRight','halfLeft','halfRight','browLeft','browRight'],1):
  assert (CAT/f'pio_cloud_{oid}_{pid}.imageset').exists()
  parts.append(pdef(pid,f'pio_cloud_{oid}_{pid}',[0,0,1254,1254],[627,627],z))
 parts.append(pdef('tablet','pio_cloud_basic_v1_tablet',c['tablet'],c['pivot'],10,[289,509,680,546]))
 for z,side in enumerate(['Left','Right'],11):
  parts.append(pdef('arm'+side,c.get('armAsset',f'pio_cloud_{oid}_v2_armPair'),c['targets'][side],c['pivot'],z,c['samples'][side],sizes['armPair']))
 if (CAT/f'pio_cloud_{oid}_optics.imageset').exists():
  parts.append(pdef('optics',f'pio_cloud_{oid}_optics',[0,0,1254,1254],[627,627],9))
 data={'outfit':oid,'canvas':1254,'revision':f'{oid}-hands-v2','parts':parts,
   'holdGroup':{'ids':['tablet','armLeft','armRight'],'pivot':c['pivot'],'degrees':1.5},
   'approval':'CANDIDATE_PENDING_NATIVE_64_220_LIGHT_DARK_NEUTRAL_AND_EXTREME_QA',
   'sourcePixelEdits':False,'source':f'output/pio-completion-2026-10-23/cloud/{oid}/layers/body.png',
   'newActualParts':['restored torso','outfit-specific sleeve/cuff/mitten pair'],
   'reusedActualParts':['existing genuine eyes/lids/half/brows','new complete green tablet'],
   'candidateShoulderLocations':c['shoulders'],'candidateShoulderLocationsApproved':False,
   'originalTabletVisibleBBox':c['tabletOriginalBBox'],
   'safeTransformRange':'shared occupied-hand/tablet group±1.5deg; reject seams, no hand release or per-arm choreography claim',
   'atlasNote':'Two genuine sleeves in a transparent atlas. Each runtime arm samples a separate measured rect. No claim of one-part-per-PNG files.',
   'limits':['headwear/sprout and feet remain in torso','no free-hand release/waving','existing eye half-state sources reused but only open/closed animated by current rig'],
   'notes':c['notes']}
 (out/'registration-v2.json').write_text(json.dumps(data,indent=2)+'\n')
 (out/'provenance.json').write_text(json.dumps(prov,indent=2)+'\n')
 folder=CAT/f'pio_cloud_{oid}_v2_registration.dataset';folder.mkdir(exist_ok=True)
 (folder/'registration.json').write_text(json.dumps(data,indent=2)+'\n')
 (folder/'Contents.json').write_text(json.dumps({'data':[{'filename':'registration.json','idiom':'universal'}],'info':{'author':'xcode','version':1}},indent=2)+'\n')
 summary.append({'outfit':oid,'newPngs':2,'parts':len(parts),'rigCanvas':1254,'armAtlasNativeSize':list(sizes['armPair']),'shaCopiesIdentical':True})
print(json.dumps(summary,indent=2))
