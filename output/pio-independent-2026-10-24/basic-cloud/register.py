"""Non-destructive catalog registration and geometry metadata only.

PNG copies are byte-identical. Pillow/NumPy only inspect alpha; no raster changes.
Runtime contentsRect samples independently generated transparent parts from atlases.
"""
from pathlib import Path
import json, hashlib, shutil
from PIL import Image
import numpy as np

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
CATALOG=ROOT/'Daylog/PioOverhaulTrial.xcassets'
GEN=Path('/Users/mungyubin/.codex/generated_images/01a13e4c-eb2f-7c33-a58c-004a195b88c3')
sources={
 'body':GEN/'exec-cc957b0d-fa8a-416b-ab58-275d51b12a33.png',
 'openPair':GEN/'exec-ec8dd001-6239-489d-9c83-cb8b5a39c2b6.png',
 'closedPair':Path('/Users/mungyubin/.codex/generated_images/01a167e0-d86f-7633-94a1-40ac5235c4f4/exec-ef710958-dda3-4053-9e9a-dba250a55ad4.png'),
 'browLeft':ROOT/'output/pio-completion-2026-10-23/cloud/christmas/layers/browLeft.png',
 'browRight':ROOT/'output/pio-completion-2026-10-23/cloud/christmas/layers/browRight.png',
 'torso':GEN/'exec-0b6287d5-3b86-422c-a82a-3fe7a7cf42cb.png',
 'tablet':GEN/'exec-534f3cda-8438-48ac-8ff4-62721dafb006.png',
 'armPair':GEN/'exec-f802b01b-15fb-4301-b3f2-7685c6004118.png',
 'feetPair':HERE/'source/feetPair-v1.png',
}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def copy_unchanged(src,dst):
 dst.parent.mkdir(parents=True,exist_ok=True)
 if dst.exists():assert sha(src)==sha(dst),f'Refusing to overwrite differing file {dst}'
 else:shutil.copyfile(src,dst)
 assert sha(src)==sha(dst)

meta=[]
for pid,source in sources.items():
 dest=HERE/'source'/f'{pid}-v1.png';copy_unchanged(source,dest)
 name=f'pio_cloud_basic_v1_{pid}'
 imagepath=CATALOG/f'{name}.imageset'/f'{name}.png'
 copy_unchanged(source,imagepath)
 contents=imagepath.parent/'Contents.json'
 payload={'images':[{'filename':imagepath.name,'idiom':'universal'}],'info':{'author':'xcode','version':1}}
 if contents.exists():assert json.loads(contents.read_text())==payload
 else:contents.write_text(json.dumps(payload,indent=2)+'\n')
 with Image.open(source) as im:
  a=np.array(im.getchannel('A'));ys,xs=np.where(a>=16)
  meta.append({'id':pid,'asset':name,'original':str(source),'workspace':str(dest.relative_to(ROOT)),
   'catalog':str(imagepath.relative_to(ROOT)),'sha256':sha(source),'size':list(im.size),
   'mode':im.mode,'alpha_extrema':list(im.getchannel('A').getextrema()),
   'visible_alpha16_bbox':[int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)],
   'method':'existing genuine donor copy' if pid.startswith('brow') else 'built-in imagegen artwork; source PNG copied unchanged',
   'pixel_edits':False,'approved':False})

def part(pid,source,rect,pivot,z,sampler=None):
 p={'id':pid,'asset':f'pio_cloud_basic_v1_{source}','rect':rect,'pivot':pivot,'z':z}
 if sampler:p['contentsRect']=[v/1254 for v in sampler]
 return p

parts=[part('body','body',[0,0,1254,1254],[627,627],0),
 part('eyeLeft','openPair',[440,692,108,108],[494,746],1,[432,748,143,143]),
 part('eyeRight','openPair',[751,692,108,108],[805,746],2,[779,748,142,143]),
 part('lidLeft','closedPair',[440,720,108,52.36],[494,746],3,[371,787,198,96]),
 part('lidRight','closedPair',[751,720,108,51.91],[805,746],4,[747,791,195,93]),
 part('browLeft','browLeft',[440,672,90,49.83],[485,697],5,[449,571,121,67]),
 part('browRight','browRight',[746,672,90,50],[791,697],6,[769,562,117,65])]

common={
 'outfit':'basic','canvas':1254,
 'approval':'CANDIDATE_REQUIRES_NATIVE_64_220_LIGHT_DARK_EYE_STATE_QA',
 'samplerContract':'normalized texture rectangles, top-left-origin source image. PNG bytes unchanged.',
 'partsAreIndividualRuntimeLayers':True,
 'pairAtlasNote':'openPair/closedPair/armPair are genuine transparent atlas PNGs, not falsely labeled one-part PNG files. Independent CALayer samplers select one piece.',
 'originalSource':'Daylog/RoutimoriTrial.xcassets/routimori_sync_loading.imageset/routimori_sync_loading.png',
 'originalEyeDarkBounds':{'Left':[444,695,544,797],'Right':[755,695,854,797]},
 'newEyeSlotCenters':{'Left':[494,746],'Right':[805,746]},
 'halfEyeSupported':False,
 'bodySourceHasBakedEyes':False,
 'safeTransformRange':{'eyes':'opacity one-hot; geometry fixed','brows':'failure only'},
 'qualityNotes':['Clean-face and torso preserve original1254canvas; minor alpha-edge drift~1-3px; native visual approval pending.','Open-pair generated positions differ from original; runtime eye samples are registered into original measured slots.','Closed eyelids use genuine new imagegen pair; no vector/flat/alpha-squash substitute.','New shoulder mapping for v2 is a provisional candidate, not measured biological joint proof.'],
}
v1={**common,'revision':'basic-eyes-v1','parts':parts,
 'independent':['eyes','closed eyelids','failure brows'],
 'unsupported':['independent arms','independent tablet','half-eye state']}
v2parts=[part('body','torso',[0,0,1254,1254],[627,627],0)]+[p for p in parts if p['id']!='body']
v2parts+=[part('tablet','tablet',[466,851,366,316],[650,1000],10,[289,509,680,546]),
 part('armLeft','armPair',[217,832,285,228],[650,1000],11,[31,568,449,444]),
 part('armRight','armPair',[788,832,255,228],[650,1000],12,[781,568,446,445]),
 part('footLeft','feetPair',[370,1059,145,123],[443,1120],20,[287,989,221,184]),
 part('footRight','feetPair',[764,1059,145,123],[836,1120],21,[792,994,222,179])]
v2={**common,'revision':'basic-hands-v2','parts':v2parts,
 'independent':['eyes','closed eyelids','failure brows','torso separated from arms and tablet'],
 'holdGroup':{'ids':['tablet','armLeft','armRight'],'pivot':[650,1000],'degrees':1.5},
 'safeTransformRange':{'holdGroup':'at most±2deg as candidate, MUST inspect neutral and endpoints; no hand release/wave claim','eyes':'opacity one-hot'},
 'unsupported':['free hand release/waving','half-eye state'],
 'candidateShoulderLocations':{'Left':[270,850],'Right':[1000,850]},
 'candidateShoulderLocationsApproved':False}
v2['foregroundFeetNote']='New genuine foot pair restores original foreground-over-tablet layering. Body still contains original baked feet underneath; reject if native neutral/endpoints show doubled toes or unmatched roots. Original visible orange bounds Left[373,1062,512,1179],Right[767,1062,906,1179].'
for version,data in [('v1',v1),('v2',v2)]:
 path=HERE/f'registration-{version}.json';path.write_text(json.dumps(data,indent=2)+'\n')
 folder=CATALOG/f'pio_cloud_basic_{version}_registration.dataset';folder.mkdir(exist_ok=True)
 (folder/'registration.json').write_text(path.read_text())
 (folder/'Contents.json').write_text(json.dumps({'data':[{'filename':'registration.json','idiom':'universal'}],'info':{'author':'xcode','version':1}},indent=2)+'\n')
(HERE/'provenance.json').write_text(json.dumps({'sources':meta,'sourcePngPixelEdits':False,'approved':False,'newGenerationTool':'built-in image_gen','existingProtectedPngOverwrites':0},indent=2)+'\n')
print(json.dumps({'assets':len(meta),'datasets':2,'registeredParts':{'v1':len(v1['parts']),'v2':len(v2['parts'])},'allSourceCopiesSHAIdentical':True},indent=2))
