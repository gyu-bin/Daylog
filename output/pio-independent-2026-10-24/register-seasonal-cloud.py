"""Copy genuine generated PNG bytes and register runtime samplers; no pixel edits."""
from pathlib import Path
import json,hashlib,shutil,subprocess
ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'output/pio-independent-2026-10-24'
CAT=ROOT/'Daylog/PioOverhaulTrial.xcassets'
rows=json.loads((BASE/'seasonal-cloud-sources.json').read_text())
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
specs={
 'summerVacation': {'left':[70,815,465,399],'right':[790,815,429,399],'targetLeft':[210,824,342,250],'targetRight':[800,824,313,250],'tablet':[496,808,360,242]},
 'halloween': {'left':[25,820,485,379],'right':[745,820,484,379],'targetLeft':[221,850,331,221],'targetRight':[800,850,290,221],'tablet':[500,850,350,213]},
 'pajamas': {'left':[150,816,405,360],'right':[729,816,380,360],'targetLeft':[222,862,331,215],'targetRight':[800,862,291,215],'tablet':[499,813,357,238]}}
for outfit,spec in specs.items():
 out=BASE/(outfit+'-cloud');out.mkdir(exist_ok=True)
 provenance=[]
 for row in [r for r in rows if r['outfit']==outfit]:
  source=Path(row['path']); dest=out/(row['part']+'-candidate-v1.png');shutil.copyfile(source,dest)
  metadata=subprocess.check_output(['sips','-g','pixelWidth','-g','pixelHeight','-g','hasAlpha',str(dest)],text=True)
  assert 'pixelWidth: 1254' in metadata and 'pixelHeight: 1254' in metadata and 'hasAlpha: yes' in metadata,metadata
  part='armPair' if row['part']=='arms' else 'torso';name=f'pio_cloud_{outfit}_v2_{part}'
  folder=CAT/(name+'.imageset');folder.mkdir(exist_ok=True);copy=folder/(name+'.png');shutil.copyfile(dest,copy)
  assert sha(copy)==sha(source)
  (folder/'Contents.json').write_text(json.dumps({'images':[{'filename':copy.name,'idiom':'universal'}],'info':{'author':'xcode','version':1}},indent=2)+'\n')
  provenance.append({'generatedOriginal':str(source),'output':str(dest.relative_to(ROOT)),'sha256':sha(source),'catalogCopyByteIdentical':True,'metadata':metadata,'prompt':row['prompt']})
 def part(pid,asset,rect,z,sample=None):
  p={'id':pid,'asset':asset,'rect':rect,'pivot':[676,970] if z>=10 else [627,627],'z':z}
  if sample:p['contentsRect']=[v/1254 for v in sample]
  return p
 parts=[part('body',f'pio_cloud_{outfit}_v2_torso',[0,0,1254,1254],0)]
 ids=['eyeLeft','eyeRight','lidLeft','lidRight','halfLeft','halfRight','browLeft','browRight']
 if outfit=='summerVacation':ids.append('optics')
 for z,pid in enumerate(ids,1):parts.append(part(pid,f'pio_cloud_{outfit}_{pid}',[0,0,1254,1254],z))
 parts += [part('tablet','pio_cloud_basic_v1_tablet',spec['tablet'],10,[289,509,680,546]),part('armLeft',f'pio_cloud_{outfit}_v2_armPair',spec['targetLeft'],11,spec['left']),part('armRight',f'pio_cloud_{outfit}_v2_armPair',spec['targetRight'],12,spec['right'])]
 data={'outfit':outfit,'canvas':1254,'revision':outfit+'-hands-v2','parts':parts,'holdGroup':{'ids':['tablet','armLeft','armRight'],'pivot':[676,970],'degrees':1.5},'approval':'CANDIDATE_NATIVE_QA_REQUIRED_NOT_PROMOTED','sourcePixelEdits':False,'hiddenPixels':'Newly generated reconstruction, not recovered original pixels','shoulderRegistration':'provisional sampler/target geometry; reject visible seams at native extremes','unsupported':['free hand release or independent wave','independent gripping hands relative to tablet'],'originalSource':f'output/pio-completion-2026-10-23/cloud/{outfit}/layers/body.png'}
 folder=CAT/(f'pio_cloud_{outfit}_v2_registration.dataset');folder.mkdir(exist_ok=True)
 for target in [folder/'registration.json',out/'registration-v2.json']:target.write_text(json.dumps(data,indent=2)+'\n')
 (folder/'Contents.json').write_text(json.dumps({'data':[{'filename':'registration.json','idiom':'universal'}],'info':{'author':'xcode','version':1}},indent=2)+'\n')
 (out/'provenance.json').write_text(json.dumps(provenance,indent=2)+'\n')
 (out/'REVIEW.md').write_text('# '+outfit+' cloud candidate\n\nPARTIAL: generated two genuine RGBA PNGs and registered unchanged copies in DEBUG trial catalog. Original approved art unchanged. Torso restores hidden garment pixels and retains source facial layout; arms are separate generated atlas parts. Runtime samplers register these to the original pose without editing PNGs.\n\nNative 64/220pt light/dark neutral and hold endpoints NOT_TESTED at registration time. Shoulder roots are provisional; no release promotion. Existing eyes/lids/brows reused; Summer additionally preserves existing opaque optics layer (blink visibility under opaque sunglasses must not be claimed). Head clothing and feet visually retain original design, newly visible shirt/pajama buttons and pumpkin torso are generated hidden content.\n\nFull prompts, generated paths, SHA256 and source metadata: provenance.json. No tests or runtime files changed.\n')
 print(outfit,'registered',len(parts),'parts, 2 byte-identical new PNG copies')
