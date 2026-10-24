from pathlib import Path
from PIL import Image,ImageDraw
import json,hashlib
BASE=Path(__file__).resolve().parents[2];ROOT=BASE.parents[1];OUT=Path(__file__).resolve().parent
NAMES=['halloween','fitness','autumn','winter','cafe','student','rainyDay','pajamas']
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
rows=[]
for name in NAMES:
 folder=BASE/f'{name}-v1';ref=ROOT/f'Daylog/PioWardrobe.xcassets/pio_outfit_{name}.imageset/pio_outfit_{name}.png';reg=folder/'registration/registration-candidate.json';manifest=json.loads(reg.read_text()) if reg.exists() else {};parts=manifest.get('parts',manifest.get('layers',[]));sources=sorted((folder/'source').glob('*.png'));registered=list((folder/'registered-layers').glob('*.png')) or list((folder/'registration/layers').glob('*.png'))
 manifest_sources={p.get('source',p.get('path')) for p in parts};active_generated={str(p) for p in sources}&manifest_sources
 row={'activeGeneratedSourceCount':len(active_generated),'supersededOrUnusedGeneratedSourceCount':len(sources)-len(active_generated),'sourceHashChecks':[{ 'source':p.get('source',p.get('path')),'matchesManifest':sha(p.get('source',p.get('path')))==p.get('sourceSHA256') }for p in parts if p.get('sourceSHA256') and Path(p.get('source',p.get('path'))).exists()],'outfit':name,'generatedSourcePNGCount':len(sources),'generatedSourceFiles':[{'file':str(p),'size':Image.open(p).size,'sha256':sha(p)} for p in sources],'registeredDerivativePNGCount':len(registered),'registeredSizes':sorted(set(Image.open(p).size for p in registered)),'uniqueManifestSources':len({p.get('source',p.get('path')) for p in parts}),'neutralAvailable':(folder/'registration/neutral-alpha.png').exists(),'approvedReferenceExists':ref.exists(),'approvedReferenceSHA256':sha(ref) if ref.exists() else None,'registrationSHA256':sha(reg) if reg.exists() else None};rows.append(row)
for theme,color in [('light',(250,245,235,255)),('dark',(18,28,25,255))]:
 c=Image.new('RGBA',(1200,1400),color);d=ImageDraw.Draw(c)
 for i,name in enumerate(NAMES):
  x=(i%2)*600;y=(i//2)*350;d.text((x+12,y+8),f'{name}: Original | Candidate',fill='white' if theme=='dark' else 'black')
  paths=[ROOT/f'Daylog/PioWardrobe.xcassets/pio_outfit_{name}.imageset/pio_outfit_{name}.png',BASE/f'{name}-v1/registration/neutral-alpha.png']
  for j,p in enumerate(paths):
   if p.exists():c.alpha_composite(Image.open(p).convert('RGBA').resize((280,280),Image.Resampling.LANCZOS),(x+10+j*295,y+40))
   else:d.text((x+10+j*295,y+100),'NO REGISTERED IMAGE YET',fill='white' if theme=='dark' else 'black')
 c.convert('RGB').save(OUT/f'neutral-reference-review-{theme}.png')
(OUT/'inventory-snapshot.json').write_text(json.dumps(rows,indent=2));print(json.dumps([{k:v for k,v in r.items() if k!='generatedSourceFiles'}for r in rows],indent=2))
