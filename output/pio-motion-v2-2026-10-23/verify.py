from pathlib import Path
from PIL import Image
import json,hashlib
R=Path(__file__).resolve().parent
rows=[]
for p in sorted(R.rglob('*.png'))+sorted(R.rglob('*.gif')):
 g=Image.open(p);d=0;hashes=set()
 for n in range(getattr(g,'n_frames',1)):
  g.seek(n);im=g.convert('RGBA');im.load();d+=g.info.get('duration',0);hashes.add(hashlib.sha256(im.tobytes()).hexdigest())
 rows.append({'file':str(p.relative_to(R)),'bytes':p.stat().st_size,'frames':getattr(g,'n_frames',1),'uniqueFrames':len(hashes),'durationMs':d,'dimensions':list(g.size)})
for j in R.glob('*/verification.json'):
 m=json.loads(j.read_text());assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==h for p,h in m['sourceHashes'].items())
(R/'artifact-verification.json').write_text(json.dumps({'status':'PASS_FILE_DECODE_AND_PRESERVATION_ONLY','outfits':14,'actionsPerOutfit':11,'images':rows,'visualStatus':'PARTIAL; offline only, pilot boards reviewed. Numeric transparent output border is not joint seam certification.'},indent=2))
print(len(rows),'decoded images',sum(x['frames'] for x in rows),'decoded frames')
