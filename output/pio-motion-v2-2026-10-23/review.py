from pathlib import Path
from PIL import Image,ImageDraw
import json,hashlib,subprocess
ROOT=Path(__file__).resolve().parent;SRC=ROOT.parent/'pio-character-overhaul-artwork/full-catalog-v1/motion';CORE=['idle','bounce','jump','celebrate','greet','sleepy','surprised','encourage']
CACHE={}
def timed(g,ms):
 key=g.filename
 if key not in CACHE:
  arr=[];elapsed=0
  for n in range(g.n_frames):
   g.seek(n);im=g.convert('RGB');elapsed+=g.info.get('duration',70);arr.append((elapsed,im))
  CACHE[key]=arr
 for end,im in CACHE[key]:
  if end>ms:return im
 return CACHE[key][-1][1]
for name in ['basic','christmas','hanbok','astronaut']:
 old=Image.open(SRC/name/'eight-actions-offline.gif');manifest=json.loads((SRC/name/'motion-manifest.json').read_text());seqs={s['action']:s for s in manifest['sequences']};offset={};k=0
 for s in manifest['sequences']:offset[s['action']]=k;k+=s['sampledFrames']
 frames=[]
 for action in CORE:
  new=Image.open(ROOT/name/f'{action}.png');seq=seqs[action]
  for i in range(32):
   oim=timed(old,seq['startMs']+i/32*(seq['endMs']-seq['startMs']));nim=timed(new,i/32*2240)
   bg=Image.new('RGB',(960,516),'#172823');o=oim.crop((0,30,400,430)).resize((467,467),Image.Resampling.LANCZOS);bg.paste(o,(6,42));bg.paste(nim.crop((0,36,480,516)),(480,36));dr=ImageDraw.Draw(bg);dr.text((12,12),f'BEFORE / {name} / {action}',fill='white');dr.text((492,12),f'AFTER / {name} / {action}',fill='white');frames.append(bg)
 palette=frames[100].quantize(colors=256,method=Image.Quantize.MEDIANCUT);q=[f.quantize(palette=palette,dither=Image.Dither.NONE) for f in frames];q[0].save(ROOT/name/'before-after-eight-actions.gif',save_all=True,append_images=q[1:],duration=70,loop=0,optimize=False,disposal=2)
 # H.264 convenience version, PNG/APNG remains lossless master.
 subprocess.run(['/opt/homebrew/bin/ffmpeg','-v','error','-i',str(ROOT/name/'before-after-eight-actions.gif'),'-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(ROOT/name/'before-after-eight-actions.mp4')],check=True)
 contact=Image.new('RGB',(480*5,516*3),'#172823');dr=ImageDraw.Draw(contact)
 for row,action in enumerate(['greet','jump','special']):
  g=Image.open(ROOT/name/f'{action}.png')
  for col,n in enumerate([0,6,14,24,31]):contact.paste(timed(g,n/32*2240),(col*480,row*516));dr.text((col*480+12,row*516+32),['start','anticipation','action','recovery','neutral'][col],fill='#b6d4ab')
 contact.save(ROOT/name/'phase-contact.png')
 print(name,flush=True)
