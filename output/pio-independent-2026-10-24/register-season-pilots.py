"""Register genuine Cherry/autumn/winter cloud reconstructions non-destructively.
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
'cherryBlossom':dict({'samples': {'Left': [30, 740, 547, 389], 'Right': [682, 740, 544, 389]}, 'targets': {'Left': [265, 844, 290, 230], 'Right': [790, 844, 290, 230]}, 'tablet': [490, 800, 366, 249], 'tabletOriginalBBox': [490, 800, 856, 1045], 'pivot': [673, 925], 'shoulders': {'Left': [300, 855], 'Right': [1040, 855]}, 'notes': ['First arm atlas had extraneous cape/collar flaps; rejected. Refined genuine short floral sleeves preserve cream cuff and mitten design.', 'Original cape remains in torso, so separate front sleeves have no duplicate collar/cape panels.']}, torso=GEN/'exec-2ce4b6dc-bd5e-4349-8a8d-6e204e35ba0d.png', armPair=GEN/'exec-37ad68d6-417a-4cf2-878a-4fbf153ad74c.png'),
'autumn':dict({'samples': {'Left': [43, 533, 536, 442], 'Right': [677, 533, 534, 442]}, 'targets': {'Left': [255, 842, 300, 230], 'Right': [790, 842, 290, 230]}, 'tablet': [495, 807, 362, 247], 'tabletOriginalBBox': [498, 810, 854, 1051], 'pivot': [676, 930], 'shoulders': {'Left': [290, 860], 'Right': [1040, 860]}, 'notes': ['Outfit-specific genuine tartan sleeves match warm wool plaid scarf; no Basic arms or fur cuff redesign.', 'Beret, maple leaf, scarf, fringe and feet remain in restored torso.']}, torso=GEN/'exec-3223844c-04a9-496a-97da-cee8cfabd466.png', armPair=GEN/'exec-d57eba3e-efc0-4e07-bbef-9ff4654e7fe3.png'),
'winter':dict({'samples': {'Left': [58, 566, 541, 426], 'Right': [656, 565, 539, 427]}, 'targets': {'Left': [255, 842, 300, 230], 'Right': [790, 842, 290, 230]}, 'tablet': [495, 808, 362, 247], 'tabletOriginalBBox': [498, 811, 854, 1052], 'pivot': [676, 930], 'shoulders': {'Left': [290, 860], 'Right': [1040, 860]}, 'notes': ['Genuine blue knitted sleeves and ivory cuff edges match approved snowflake knit costume.', 'Cap, pompom, sprout, snowflake scarf and fringe remain in torso; no independent hat or scarf claim.']}, torso=GEN/'exec-2d309583-30c2-4244-b9ab-b1078338262a.png', armPair=GEN/'exec-a2c9a7d7-a017-41b6-b17e-bb9dd5e6e610.png'),
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
