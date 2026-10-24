from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import math,json,hashlib,sys
ROOT=Path(__file__).resolve().parent
SRC=ROOT.parent/'pio-character-overhaul-artwork/full-catalog-v1'
F=480;S=350;R=S/1254;OX=65;OY=85
ACTIONS=['idle','greet','walk','bounce','jump','celebrate','bow','sleepy','surprised','encourage','special']
N=32;MS=70
SPECIAL={'basic':'peek and wink','christmas':'present held gift','hanbok':'formal greeting bow','astronaut':'weightless float','cherryBlossom':'spring greeting','summerVacation':'held drink toast','autumn':'show held maple leaf','winter':'cozy shoulder tuck','halloween':'show held candy bag','cafe':'held coffee toast','student':'present held book','fitness':'paired weight lift','rainyDay':'umbrella shelter','pajamas':'sleepy pillow hug'}
def smooth(x): x=max(0,min(1,x));return x*x*(3-2*x)
def env(t,a=.18,b=.78):return smooth(t/a)*(1-smooth((t-b)/(1-b)))
def sh(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def motion(action,t,name):
 e=env(t);w=math.sin(t*math.tau);d={'dx':0,'dy':0,'lean':0,'sx':1,'sy':1,'left':0,'right':0,'footLeft':0,'footRight':0,'eye':'open','specialLift':0}
 if action=='idle':d.update(sy=1+.009*w,eye='closed' if .70<t<.80 else 'open')
 if action=='greet':d.update(lean=-3*e,right=(12+9*math.sin(t*math.tau*3))*e,eye='happy' if t>.2 and t<.85 else 'open')
 if action=='walk':d.update(dx=24*math.sin(t*math.tau)*e,dy=-4*abs(math.sin(t*math.tau*3))*e,lean=2*math.sin(t*math.tau*3)*e,left=-7*math.sin(t*math.tau*3)*e,right=-7*math.sin(t*math.tau*3)*e,footLeft=13*math.sin(t*math.tau*3)*e,footRight=-13*math.sin(t*math.tau*3)*e)
 if action=='bounce':
  q=t*2%1; lift=math.sin(max(0,min(1,(q-.18)/.56))*math.pi) if .18<q<.74 else 0;squash=math.sin(q/.18*math.pi) if q<.18 else math.sin((q-.74)/.26*math.pi) if q>.74 else 0
  d.update(dy=-19*lift,sx=1+.035*squash,sy=1-.08*squash,left=-6*lift,right=6*lift)
 if action=='jump':
  if t<.22:q=smooth(t/.22);d.update(sx=1+.055*q,sy=1-.12*q,dy=3*q,left=3*q,right=-3*q)
  elif t<.7:q=(t-.22)/.48;d.update(dy=-73*math.sin(q*math.pi),left=-15*math.sin(q*math.pi),right=15*math.sin(q*math.pi),footLeft=-9*math.sin(q*math.pi),footRight=9*math.sin(q*math.pi),eye='happy')
  elif t<.86:q=math.sin((t-.7)/.16*math.pi);d.update(sx=1+.055*q,sy=1-.12*q,dy=3*q)
 if action=='celebrate':d.update(eye='happy',dx=9*math.sin(t*math.tau*3)*e,lean=5*math.sin(t*math.tau*3)*e,left=-(10+7*math.sin(t*math.tau*3))*e,right=(10+7*math.sin(t*math.tau*3))*e,dy=-11*abs(math.sin(t*math.tau*3))*e)
 if action=='bow':d.update(eye='closed' if e>.3 else 'open',lean=7*e,sy=1-.065*e,dy=9*e,left=4*e,right=-4*e)
 if action=='sleepy':d.update(eye='half' if t<.2 else 'closed',lean=5*e,sy=1-.025*e,dy=7*e,left=3*e,right=-3*e)
 if action=='surprised':
  q=smooth(t/.1)*(1-smooth((t-.5)/.5));d.update(dx=-23*q,lean=-7*q,dy=-10*q,left=-8*q,right=8*q,sy=1+.02*q)
 if action=='encourage':d.update(eye='happy',lean=3.5*e,dy=4*e+3*math.sin(t*math.tau*2)*e,left=-11*e,right=11*e)
 if action=='special':
  d.update(eye='happy',specialLift=e)
  if name=='astronaut':d.update(dy=-38*e+5*w*e,lean=6*w*e,left=-12*e,right=12*e,footLeft=-8*w*e,footRight=8*w*e)
  elif name=='hanbok':d.update(lean=8*e,dy=11*e,sy=1-.075*e,left=5*e,right=-5*e,eye='closed' if e>.4 else 'open')
  elif name=='pajamas':d.update(eye='closed',sy=1-.015*e,dy=4*e,lean=2*w*e)
  elif name=='winter':d.update(eye='closed',left=7*e,right=-7*e,dy=4*e,sy=1-.02*e)
  elif name=='rainyDay':d.update(lean=-3*e,eye='closed' if .4<t<.5 else 'open',left=-9*e)
  else:d.update(lean=-3*e,dy=-3*e,left=-12*e,right=12*e,eye='wink' if name in ['basic','cherryBlossom'] and .4<t<.72 else 'happy')
 return d

def render(name):
 D=SRC/name; out=ROOT/name;out.mkdir(exist_ok=True)
 reg=json.loads((D/'registration.json').read_text());parts=reg['normalizedParts']; piv={p['id']:p['pivot'] for p in parts}
 ims={};hashes={}
 for p in parts:
  path=D/p['file'];hashes[str(path)]=sh(path);im=Image.open(path).convert('RGBA').resize((S,S),Image.Resampling.LANCZOS);canvas=Image.new('RGBA',(F,F));canvas.alpha_composite(im,(OX,OY));ims[p['id']]=canvas
 for side in ['Left','Right']:
  path=D/f'layers/happy{side}.png'
  if path.exists():
   hashes[str(path)]=sh(path);im=Image.open(path).convert('RGBA').resize((S,S),Image.Resampling.LANCZOS);canvas=Image.new('RGBA',(F,F));canvas.alpha_composite(im,(OX,OY));ims['happy'+side]=canvas
 def frame(act,t):
  d=motion(act,t,name);angles={'wingLeft':d['left'],'wingRight':d['right'],'footLeft':d['footLeft'],'footRight':d['footRight']};pivots={};shifts={}
  # Separate anatomy remains genuine; props never release from the corresponding arm.
  if act=='greet' and name in ['summerVacation','halloween','rainyDay']:angles['wingLeft']=-d['right'];angles['wingRight']=0
  groups={'fitness':[('dumbbellLeft','wingLeft'),('dumbbellRight','wingRight')],'cafe':[('prop','wingLeft')],'student':[('prop','wingLeft')],'summerVacation':[('drink','wingRight')],'halloween':[('bag','wingRight')],'autumn':[('leaf','wingLeft')]}
  for prop,hand in groups.get(name,[]):
   a=max(-5,min(5,angles.get(hand,0)));angles[prop]=angles[hand]=a;pivots[prop]=piv[hand]
   if act=='special':
    # Rigid shoulder raise only, complete authored arm+held prop remain one group.
    lift=-9*d['specialLift'];shifts[prop]=shifts[hand]=(0,lift)
  if name=='christmas':
   a=2*math.sin(t*math.tau)*env(t) if act in ['celebrate','special'] else 0
   lift=-10*d['specialLift'] if act=='special' else 0
   for id in ['gift','handLeft','handRight']:angles[id]=a;pivots[id]=(790,925);shifts[id]=(0,lift)
  if name=='pajamas':
   a=2*math.sin(t*math.tau)*env(t) if act in ['sleepy','special'] else 0
   for id in ['pillow','wingLeft','wingRight']:angles[id]=a;pivots[id]=(820,900)
  if name=='rainyDay':
   a=-4*env(t) if act in ['greet','special','celebrate'] else 0
   for id in ['umbrellaCanopy','umbrellaShaft','wingRight']:angles[id]=a;pivots[id]=(745,875)
  im=Image.new('RGBA',(F,F))
  for p in sorted(parts,key=lambda p:p['z']):
   id=p['id']
   if id.startswith(('lid','half')):continue
   if id.startswith('eye'):
    side=id[3:];eid=('lid'+side if d['eye']=='closed' or d['eye']=='wink' and side=='Right' else 'half'+side if d['eye']=='half' else 'happy'+side if d['eye']=='happy' else id);lay=ims.get(eid,ims[id])
   else:
    lay=ims[id];a=angles.get(id,0)
    if a:
     pv=pivots.get(id,p['pivot']);lay=lay.rotate(-a,Image.Resampling.BICUBIC,center=(pv[0]*R+OX,pv[1]*R+OY))
    if id in shifts:
     tmp=Image.new('RGBA',(F,F));tmp.alpha_composite(lay,tuple(round(x) for x in shifts[id]));lay=tmp
   im.alpha_composite(lay)
  if d['sx']!=1 or d['sy']!=1:
   sx=d['sx'];sy=d['sy'];scaled=im.resize((round(F*sx),round(F*sy)),Image.Resampling.BICUBIC);im=Image.new('RGBA',(F,F));im.alpha_composite(scaled,(round(240-240*sx),round(400-400*sy)))
  if d['lean']:im=im.rotate(-d['lean'],Image.Resampling.BICUBIC,center=(240,370))
  final=Image.new('RGBA',(F,F));final.alpha_composite(im,(round(d['dx']),round(d['dy'])));return final
 allf=[];keyposes=[];borders=[]
 for act in ACTIONS:
  fs=[]
  for i in range(N):
   rgba=frame(act,i/(N-1));a=rgba.getchannel('A');borders.append(max(a.crop(b).getextrema()[1] for b in [(0,0,F,1),(0,F-1,F,F),(0,0,1,F),(F-1,0,F,F)]))
   bg=Image.new('RGB',(F,F+36),'#172823');bg.paste(rgba,(0,36),rgba);ImageDraw.Draw(bg).text((12,12),f'{name} / {act}'+(' - '+SPECIAL[name] if act=='special' else ''),fill='white');fs.append(bg)
  key=frame(act,.42 if act in ['jump','special'] else .3 if act=='greet' else .5);key.save(out/f'{act}-keypose-alpha.png');keyposes.append((act,key));allf+=fs
  # Lossless RGBA/APNG-equivalent RGB PNG animation, no GIF quantization.
  fs[0].save(out/f'{act}.png',save_all=True,append_images=fs[1:],duration=MS,loop=0,format='PNG')
 contact=Image.new('RGB',(F*4,(F+36)*3),'#172823');dr=ImageDraw.Draw(contact)
 for i,(act,key) in enumerate(keyposes):x=i%4*F;y=i//4*(F+36);contact.paste(key,(x,y+36),key);dr.text((x+12,y+12),act,fill='white')
 contact.save(out/'eleven-actions-contact.png');palette=contact.quantize(colors=256,method=Image.Quantize.MEDIANCUT);q=[f.quantize(palette=palette,dither=Image.Dither.NONE) for f in allf];q[0].save(out/'eleven-actions.gif',save_all=True,append_images=q[1:],duration=MS,loop=0,optimize=False,disposal=2)
 assert all(sh(Path(p))==h for p,h in hashes.items())
 result={'outfit':name,'status':'PARTIAL_OFFLINE_STUDY','canonicalSourcesUnchanged':True,'sourceHashes':hashes,'actions':ACTIONS,'specialAction':SPECIAL[name],'framesPerAction':N,'durationMs':MS,'maxAlphaOnFrameBorder':max(borders),'canvas':[F,F+36],'characterCanvas':[S,S],'limits':['2D front-view stepping, no authored turn or gait occlusion change.','Bow is frontal lean/compression, not a reconstructed 3D head turn.','Hat and fabric stay rigid with torso.','Held props rigidly follow hands; no release or articulation.','No app/runtime/performance claim.']}
 (out/'verification.json').write_text(json.dumps(result,indent=2));print(name,max(borders),flush=True)
if __name__=='__main__':
 for name in sys.argv[1:] or SPECIAL:render(name)
