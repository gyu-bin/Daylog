"""Register new genuine Café candidate PNGs unchanged; reuse existing eyes.
No source pixels are changed or resampled. Runtime samplers perform registration.
"""
from pathlib import Path
import json,hashlib,shutil
from PIL import Image
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
OUT=ROOT/'output/pio-independent-2026-10-24/cafe-cloud'
CAT=ROOT/'Daylog/PioOverhaulTrial.xcassets'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
provenance=[]
for part,filename in [('torso','torso-candidate-v1.png'),('armPair','arms-candidate-v1.png')]:
 source=OUT/filename;name=f'pio_cloud_cafe_v2_{part}'
 folder=CAT/f'{name}.imageset';folder.mkdir(exist_ok=True)
 dest=folder/f'{name}.png'
 if dest.exists():assert sha(dest)==sha(source)
 else:shutil.copyfile(source,dest)
 assert sha(dest)==sha(source)
 (folder/'Contents.json').write_text(json.dumps({'images':[{'filename':dest.name,'idiom':'universal'}],'info':{'author':'xcode','version':1}},indent=2)+'\n')
 with Image.open(source) as im:
  assert im.size==(1254,1254) and im.mode=='RGBA'
  provenance.append({'source':str(source.relative_to(ROOT)),'catalog':str(dest.relative_to(ROOT)),
    'size':list(im.size),'sha256':sha(source),'sourcePixelsChanged':False,'approved':False})
def part(pid,asset,rect,pivot,z,sampler=None):
 p={'id':pid,'asset':asset,'rect':rect,'pivot':pivot,'z':z}
 if sampler:p['contentsRect']=[v/1254 for v in sampler]
 return p
parts=[part('body','pio_cloud_cafe_v2_torso',[0,0,1254,1254],[627,627],0)]
for z,pid in enumerate(['eyeLeft','eyeRight','lidLeft','lidRight','halfLeft','halfRight','browLeft','browRight'],1):
 parts.append(part(pid,f'pio_cloud_cafe_{pid}',[0,0,1254,1254],[627,627],z))
parts.extend([
 part('tablet','pio_cloud_basic_v1_tablet',[495,850,362,238],[676,970],10,[289,509,680,546]),
 part('armLeft','pio_cloud_cafe_v2_armPair',[282,850,270,228],[676,970],11,[143,713,397,410]),
 part('armRight','pio_cloud_cafe_v2_armPair',[803,850,260,228],[676,970],12,[738,711,404,416]),
])
data={'outfit':'cafe','canvas':1254,'revision':'cafe-hands-v2',
 'approval':'CANDIDATE_REQUIRES_NATIVE_NEUTRAL_AND_HOLD_EXTREME_QA_NOT_PROMOTED',
 'originalSource':'output/pio-completion-2026-10-23/cloud/cafe/layers/body.png',
 'parts':parts,'holdGroup':{'ids':['tablet','armLeft','armRight'],'pivot':[676,970],'degrees':1.5},
 'independent':['existing genuine eyes/lids/brows','genuine newly restored torso','separate generated arms and complete tablet'],
 'tableSourceNote':'Reuses new Basic green tablet source; registered to original Café tablet visible bbox[498,853,854,1085]. Not a flat geometric replacement.',
 'candidateShoulderLocations':{'Left':[350,865],'Right':[1000,865]},
 'candidateShoulderLocationsApproved':False,
 'unsupported':['free hand release/wave','independently moving two hands while both grip tablet','Café coffee-cup action in seated tablet pose'],
 'sourcePixelEdits':False,
 'safeTransformRange':{'holdGroup':'±1.5deg candidate; reject if shoulders/sleeves detach','eyes':'existing one-hot opacity; no body transform'},
 'qualityNotes':['Existing Café costume/beret/sprout/collar/apron/feet preserved by generated torso candidate.','Generated detached arms larger than reference; runtime sampler/target rectangles register to original cuff/hand positions. No upscale claim.','Shoulder root continuity and cuff bulk require actual native neutral/extreme visual review before promotion.']}
(OUT/'registration-v2.json').write_text(json.dumps(data,indent=2)+'\n')
(OUT/'registration-provenance.json').write_text(json.dumps(provenance,indent=2)+'\n')
folder=CAT/'pio_cloud_cafe_v2_registration.dataset';folder.mkdir(exist_ok=True)
(folder/'registration.json').write_text(json.dumps(data,indent=2)+'\n')
(folder/'Contents.json').write_text(json.dumps({'data':[{'filename':'registration.json','idiom':'universal'}],'info':{'author':'xcode','version':1}},indent=2)+'\n')
print(json.dumps({'newPNGAssets':2,'reusedEyeLayers':8,'sharedGeneratedTablet':True,'candidateParts':len(parts),'pixelEdits':False}))
