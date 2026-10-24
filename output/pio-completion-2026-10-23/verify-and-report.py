from pathlib import Path
from PIL import Image,ImageDraw
import json,hashlib,subprocess,zipfile
ROOT=Path(__file__).resolve().parents[2];OUT=Path(__file__).resolve().parent;OLD=ROOT/'output/pio-character-overhaul-artwork';sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();baseline=json.loads((OLD/'qa/resume-2026-10-23/before.json').read_text());sources=list((OUT/'cloud').glob('*/source/seated-clean-face-v1.png'));assert len(sources)==13
rows=[]
for source in sorted(sources):
 folder=source.parents[1];m=json.loads((folder/'registration.json').read_text())
 for p,h in m['sourceHashes'].items():assert sha(p)==h
 for name in ['receiving','blink','failure','success']:
  with Image.open(folder/(name+'-alpha.png')) as im:im.load();assert im.mode=='RGBA' and im.size==(1254,1254)
 g=Image.open(folder/'independent-eye-proof.gif');duration=0
 for n in range(g.n_frames):g.seek(n);g.convert('RGBA').load();duration+=g.info.get('duration',0)
 rows.append({'outfit':folder.name,'source':str(source.relative_to(OUT)),'sourceSHA256':sha(source),'independent':['eye states','concerned brows'],'baked':['hands/tablet','clothing','feet','headwear'],'gifDecodedFrames':g.n_frames,'gifDurationMS':duration,'status':'PARTIAL_NOT_IN_APP'})
for theme,bg,fg in [('light','#faf6ed','#23483d'),('dark','#14251f','#f8efdb')]:
 for state in ['receiving','failure']:
  b=Image.new('RGBA',(1500,1050),bg);d=ImageDraw.Draw(b)
  for i,row in enumerate(rows):
   x=i%5*300;y=i//5*350;p=OUT/'cloud'/row['outfit']/(state+'-alpha.png');b.alpha_composite(Image.open(p).resize((300,300),Image.Resampling.LANCZOS),(x,y+20));d.text((x+12,y+325),row['outfit']+' / '+state,fill=fg)
  b.convert('RGB').save(OUT/f'cloud-{state}-overview-{theme}.png')
for p,h in baseline['approved_and_runtime_asset_hashes'].items():assert sha(ROOT/p)==h
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT).decode().strip()==baseline['head'];assert hashlib.sha256(subprocess.check_output(['git','diff','HEAD','--binary'],cwd=ROOT)).hexdigest()==baseline['tracked_diff_sha256']
newPngs=list(OUT.rglob('*.png'))
for p in newPngs:
 with Image.open(p) as im:im.load()
report={'fileChecks':'PASS','visualStatus':'PARTIAL','cloudOutfits':13,'cloudStateCandidates':39,'eyeProofGIFs':13,'independentHandMotion':False,'approvedRuntimePNGsUnchanged':69,'trackedDiffUnchanged':True,'newFolderPNGsDecoded':len(newPngs),'applicationIntegration':'NOT_APPLIED_NOT_TESTED','rows':rows}
(OUT/'verification.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:v for k,v in report.items() if k!='rows'},indent=2))
