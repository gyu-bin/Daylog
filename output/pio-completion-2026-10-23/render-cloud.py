from pathlib import Path
from PIL import Image,ImageDraw,ImageOps
import json,hashlib
ROOT=Path(__file__).resolve().parents[2];OUT=Path(__file__).resolve().parent;S=1254
BASE=ROOT/'docs/qa/pio-outfit-phase2.2-2026-10-16/candidates/base';allhash={}
def read(p):
 p=Path(p);allhash[str(p)]=hashlib.sha256(p.read_bytes()).hexdigest();return Image.open(p).convert('RGBA')
def fit(source,center,width,mirror=False):
 im=read(source)
 if mirror:im=ImageOps.mirror(im)
 bb=im.getchannel('A').point(lambda a:255 if a>=16 else 0).getbbox();sc=width/(bb[2]-bb[0]);offset=[round(center[0]-(bb[0]+bb[2])/2*sc),round(center[1]-(bb[1]+bb[3])/2*sc)];native=im.resize((round(im.width*sc),round(im.height*sc)),Image.Resampling.LANCZOS);c=Image.new('RGBA',(S,S));c.alpha_composite(native,offset)
 return c,{'source':str(source),'center':center,'width':width,'scale':sc,'offset':offset,'mirrorX':mirror}
for source in (OUT/'cloud').glob('*/source/seated-clean-face-v1.png'):
 folder=source.parents[1];name=folder.name;body=read(source); assert body.size==(S,S); layers={'body':body};meta=[]
 for side,xy,w in [('Left',(510,650),104),('Right',(827,640),100)]:
  for state,file in [('eye','eye-open-v1.png'),('half','eye-half-v1.png'),('lid','eyelid-closed-v1.png')]:
   c,p=fit(BASE/file,xy,w);layers[state+side]=c;meta.append({'id':state+side,**p})
  c,p=fit(OUT/'expressions/shared/concerned-brow-v1.png',(xy[0],xy[1]-45),w*1.08,side=='Right');layers['brow'+side]=c;meta.append({'id':'brow'+side,**p})
 optics=None
 if name in ['student','summerVacation','astronaut']:
  CAT=ROOT/'output/pio-character-overhaul-artwork/full-catalog-v1'
  kind='glasses' if name=='student' else 'sunglasses' if name=='summerVacation' else 'visor'
  opticalSource=(OUT/'expressions/summerVacation/layers/sunglasses-v3.png') if name=='summerVacation' else CAT/name/'layers'/(kind+'.png')
  old={'student':((535,657.5),(840,617.5)),'summerVacation':((540,635),(845,590)),'astronaut':((550,679),(799,642))}[name];new=((510,650),(827,640));dx=old[1][0]-old[0][0];dy=old[1][1]-old[0][1];nx=new[1][0]-new[0][0];ny=new[1][1]-new[0][1];den=dx*dx+dy*dy;a=(nx*dx+ny*dy)/den;b=(ny*dx-nx*dy)/den;tx=new[0][0]-a*old[0][0]+b*old[0][1];ty=new[0][1]-b*old[0][0]-a*old[0][1];v=a*a+b*b
  optics=read(opticalSource).transform((S,S),Image.Transform.AFFINE,(a/v,b/v,(-a*tx-b*ty)/v,-b/v,a/v,(b*tx-a*ty)/v),Image.Resampling.BICUBIC);layers['optics']=optics;meta.append({'id':'optics','source':str(opticalSource),'similarityForward':[a,-b,tx,b,a,ty],'z':'above eyes/brows'})
 (folder/'layers').mkdir(exist_ok=True)
 for key,im in layers.items():im.save(folder/'layers'/(key+'.png'))
 states={}
 for state in ['receiving','blink','failure']:
  c=body.copy()
  for side in ['Left','Right']:
   c.alpha_composite(layers[('lid' if state=='blink' else 'eye')+side])
   if state=='failure':c.alpha_composite(layers['brow'+side])
  if optics is not None:c.alpha_composite(optics)
  states[state]=c;c.save(folder/(state+'-alpha.png'))
 for pt in [64,220]:
  for factor in [1,3]:
   n=pt*factor
   for theme,bg,fg in [('light','#faf6ed','#23483d'),('dark','#14251f','#f8efdb')]:
    board=Image.new('RGBA',(3*(n+25)+25,n+80),bg);d=ImageDraw.Draw(board)
    for i,(state,im) in enumerate(states.items()):board.alpha_composite(im.resize((n,n),Image.Resampling.LANCZOS),(25+i*(n+25),55));d.text((25+i*(n+25),15),state,fill=fg)
    board.convert('RGB').save(folder/f'cloud-{pt}pt-{factor}x-{theme}.png')
 ready=read(ROOT/'output/pio-character-overhaul-artwork/full-catalog-v1'/name/'happy-1254-alpha.png');ready.save(folder/'success-alpha.png')
 frames=[]
 for i in range(32):
  state='blink' if i in [10,11,25,26] else 'failure' if i>=18 else 'receiving';f=Image.new('RGBA',(400,400),'#14251f');f.alpha_composite(states[state].resize((400,400),Image.Resampling.LANCZOS));frames.append(f.convert('RGB'))
 frames[0].save(folder/'independent-eye-proof.gif',save_all=True,append_images=frames[1:],duration=100,loop=0,optimize=False,disposal=2)
 (folder/'registration.json').write_text(json.dumps({'status':'PARTIAL_ARTWORK_CANDIDATE_NOT_APP_INTEGRATED','canvas':[S,S],'parts':meta,'baked':['clothed seated torso','tablet','hands','feet','headwear/sprout','closed beak'],'independent':['eyes','eyelids','concerned brows'],'handMotionSupported':False,'sourcesUnchanged':True,'sourceHashes':allhash},indent=2)+'\n')
assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==h for p,h in allhash.items())
print('Cloud clean-face source composed with genuine eye and brow layers, sources unchanged')
