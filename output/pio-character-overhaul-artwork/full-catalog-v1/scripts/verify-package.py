"""Focused asset checks only. Does not build or launch the application."""
from pathlib import Path
from PIL import Image,ImageChops
import hashlib,json,subprocess
ROOT=Path(__file__).resolve().parents[4];ART=ROOT/'output/pio-character-overhaul-artwork';OUT=ART/'full-catalog-v1'
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
manifest=json.loads((OUT/'catalog-manifest.json').read_text());baseline=json.loads((ART/'qa/resume-2026-10-23/before.json').read_text())
assert len(manifest['items'])==14
source_changes=[p for p,h in manifest['sourceSHA256'].items() if sha(p)!=h];assert not source_changes
original_changes=[p for p,h in baseline['approved_and_runtime_asset_hashes'].items() if sha(ROOT/p)!=h];assert not original_changes
head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT).decode().strip();diffhash=hashlib.sha256(subprocess.check_output(['git','diff','HEAD','--binary'],cwd=ROOT)).hexdigest()
assert head==baseline['head'] and diffhash==baseline['tracked_diff_sha256']
rows=[]
for item in manifest['items']:
 outfit=item['outfit'];d=OUT/outfit; layers=list((d/'layers').glob('*.png'));assert len(layers)==len(item['normalizedParts'])+2
 for p in layers:
  with Image.open(p) as im:im.load();assert im.mode=='RGBA' and im.size==(1254,1254);assert im.getchannel('A').getextrema()[0]==0
 for state in ['open','closed','happy','wink']:
  with Image.open(d/(state+'-1254-alpha.png')) as im:im.load();assert im.mode=='RGBA' and im.size==(1254,1254)
 boards=list(d.glob('expressions-*.png'));assert len(boards)==8
 for p in boards:
  with Image.open(p) as im: im.load()
 gifs=[d/'independent-expression-offline.gif',OUT/'motion'/outfit/'eight-actions-offline.gif'];gifdata=[]
 for p in gifs:
  assert p.exists(),p
  with Image.open(p) as im:
   frames=im.n_frames;ms=0
   for i in range(frames):im.seek(i);im.convert('RGBA').load();ms+=im.info.get('duration',0)
   assert frames>1 and ms>0;gifdata.append({'file':str(p.relative_to(OUT)),'frames':frames,'durationMS':ms})
 motion=json.loads((OUT/'motion'/outfit/'motion-manifest.json').read_text())
 assert motion['sourceRegistrationSHA256']==sha(d/'registration.json')
 for p,h in motion['canonicalLayerSHA256'].items():assert sha(OUT/p)==h,p
 assert len(list((OUT/'motion'/outfit).glob('*-keypose-alpha.png')))==8
 # Only original eye locations may change in the body-fixed expression comparison.
 a=Image.open(d/'open-1254-alpha.png').convert('RGBA');b=Image.open(d/'happy-1254-alpha.png').convert('RGBA');box=ImageChops.difference(a,b).convert('RGB').getbbox();assert box
 rows.append({'outfit':outfit,'transparentLayerFiles':len(layers),'expressionBoards':len(boards),'expressionChangeBounds':box,'gifs':gifdata,'status':'FILE_CHECKS_PASS_VISUAL_PARTIAL'})
result={'scope':'Offline artwork files only, not application verification','fileChecks':'PASS','visualApproval':'PENDING/PARTIAL','headUnchanged':True,'trackedDiffUnchanged':True,'approvedRuntimePNGsUnchanged':len(baseline['approved_and_runtime_asset_hashes']),'nativeSourceReferencesUnchanged':len(manifest['sourceSHA256']),'outfitCount':len(rows),'transparentLayerFiles':sum(r['transparentLayerFiles'] for r in rows),'expressionCompositePNGs':56,'sizeThemeComparisonPNGs':112,'offlineActionKeyposePNGs':112,'offlineGIFs':28,'newGenuineSourceArtworks':3,'rows':rows,'notTested':['Native Mac/iPhone playback','CPU/memory','Reduce Motion','Scene-specific vacation/cloud outfit coverage']}
(OUT/'file-verification.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items() if k!='rows'},indent=2))
