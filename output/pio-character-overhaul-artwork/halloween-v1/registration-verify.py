"""Read-only PNG/GIF audit; writes only candidate verification JSON in supplied output folder."""
from PIL import Image
from pathlib import Path
import json,hashlib,sys
p=Path(sys.argv[1])
rows=[]
for f in sorted([*p.joinpath('registration').glob('*.png'),*p.joinpath('registered-layers').glob('*.png')]):
 with Image.open(f) as im:
  im.load();rows.append(dict(path=str(f),size=list(im.size),mode=im.mode,bytes=f.stat().st_size,sha256=hashlib.sha256(f.read_bytes()).hexdigest()))
with Image.open(p/'registration/independent-offline-proof.gif')as im:gif=dict(frames=im.n_frames,size=list(im.size),duration=im.info.get('duration'))
(p/'registration/png-verification.json').write_text(json.dumps(dict(pngCount=len(rows),pngs=rows,gif=gif),indent=2))
print(str(p),len(rows),gif)
