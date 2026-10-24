from pathlib import Path
from PIL import Image,ImageDraw
import json
O=Path(__file__).resolve().parents[1];m=json.loads((O/'basic/motion-manifest.json').read_text());g=Image.open(O/'basic/eight-actions-offline.gif')
def at(ms):
 total=0
 for n in range(g.n_frames):
  g.seek(n);total+=g.info.get('duration',0)
  if total>ms:return g.convert('RGB').copy()
 return g.convert('RGB').copy()
board=Image.new('RGB',(4*200,8*230),'#172823');d=ImageDraw.Draw(board)
for row,seq in enumerate(m['sequences']):
 for col,t in enumerate([0,.25,.5,.8]):
  ms=seq['startMs']+(seq['endMs']-seq['startMs'])*t;im=at(ms).resize((200,215),Image.Resampling.LANCZOS);x=200*col;y=230*row;board.paste(im,(x,y+15));d.text((x+4,y+1),f"{seq['action']} {t:.0%}",fill='white')
board.save(O/'basic-eight-action-decoded-trajectories.png')
# Inspect proof boundary for every generated full-color frame, all costumes.
import importlib.util
spec=importlib.util.spec_from_file_location('motion_render',O/'scripts/render.py');mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
# Each PNG keypose is loaded independently; native-layer preservation is in summary.
rows=[]
for D in O.iterdir():
 if not (D/'motion-manifest.json').exists():continue
 rows.append({'outfit':D.name,'keyposesWithAlphaTouchingBoundary':[p.name for p in D.glob('*-keypose-alpha.png') if (lambda b:b and (b[0]==0 or b[1]==0 or b[2]==400 or b[3]==400))(Image.open(p).getchannel('A').getbbox())]})
(O/'trajectory-review.json').write_text(json.dumps({'status':'PARTIAL_OFFLINE_STUDIES','keyposeBoundaryAudit':rows,'allKeyposesClearOf400pxBoundary':all(not r['keyposesWithAlphaTouchingBoundary'] for r in rows),'actualReview':'14 contact boards plus actual decoded GIF all14 greet montage; decoded Basic/Rainy/Christmas/Pajamas/Fitness sample strips and Basic eight-action time-based trajectories.','limits':'Whole-body affine squash/lift/lean is explicitly whole-body; no face reconstruction or fullclothdeformation claimed.'},indent=2))
