"""Offline animation studies from genuine pre-registered parts. No application integration."""
from pathlib import Path
from PIL import Image,ImageDraw
import math,json,hashlib
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'motion';S=300;F=400;R=S/1254
ACTIONS=['idle','bounce','jump','celebrate','greet','sleepy','surprised','encourage']
TIMING={'idle':(24,90),'bounce':(12,70),'jump':(18,70),'celebrate':(22,80),'greet':(20,80),'sleepy':(26,100),'surprised':(12,70),'encourage':(24,90)}
KEY={'idle':.25,'bounce':.25,'jump':.45,'celebrate':.2,'greet':.3,'sleepy':.5,'surprised':.35,'encourage':.5}
def smooth(t):
 t=max(0,min(1,t));return t*t*(3-2*t)
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def pad(im):
 out=Image.new('RGBA',(F,F));out.alpha_composite(im,(50,70));return out
def move(im,angle,pivot):return im.rotate(-angle,Image.Resampling.BICUBIC,center=(pivot[0]*R+50,pivot[1]*R+70)) if angle else im

def render(outfit):
 D=ROOT/outfit;m=json.loads((D/'registration.json').read_text());parts=m['normalizedParts'];ims={p['id']:pad(Image.open(D/p['file']).convert('RGBA').resize((S,S),Image.Resampling.LANCZOS)) for p in parts}
 for side in ['Left','Right']:
  p=D/f'layers/happy{side}.png'
  if p.exists():ims['happy'+side]=pad(Image.open(p).convert('RGBA').resize((S,S),Image.Resampling.LANCZOS))
 hashes={str((D/p['file']).relative_to(ROOT)):digest(D/p['file']) for p in parts}
 for side in ['Left','Right']:
  p=D/f'layers/happy{side}.png'
  if p.exists():hashes[str(p.relative_to(ROOT))]=digest(p)
 def frame(action,t):
  sn=math.sin(t*math.tau);angles={};pivots={};eye='open';dy=0;dx=0;lean=0;sx=sy=1;wing=0
  if action=='idle':
   eye='closed' if .70<t<.83 else 'open';sy=1+.007*math.sin(t*math.tau);sx=1-.002*math.sin(t*math.tau)
  if action=='bounce':
   phase=(t*2)%1
   if phase<.16:sy=1-.07*math.sin(phase/.16*math.pi/2);sx=1.025
   elif phase<.78:dy=-11*math.sin((phase-.16)/.62*math.pi)
   elif phase<.93:sy=1-.06*math.sin((phase-.78)/.15*math.pi);sx=1.025
   wing=2*math.sin(t*math.tau*2)
  if action=='jump':
   if t<.18:sy=1-.09*smooth(t/.18);sx=1+.04*smooth(t/.18);dy=2
   elif t<.72:dy=-48*math.sin((t-.18)/.54*math.pi);wing=4*math.sin((t-.18)/.54*math.pi)
   elif t<.88:sy=1-.10*math.sin((t-.72)/.16*math.pi);sx=1+.04*math.sin((t-.72)/.16*math.pi);dy=2
  if action=='celebrate':
   eye='happy';envelope=math.sin(t*math.pi);dx=6*math.sin(t*math.tau*3)*envelope;lean=2*math.sin(t*math.tau*3)*envelope;wing=8*math.sin(t*math.tau*2)
  if action=='greet':
   eye='happy';hold=smooth(t/.18)*(1-smooth((t-.80)/.20));lean=-2*hold;wing=10*math.sin(t*math.tau*3)*hold
  if action=='sleepy':
   eye='closed';hold=smooth(t/.3)*(1-smooth((t-.80)/.20));lean=3*hold;dy=3*hold;sy=1-.012*hold;dx=1*hold
  if action=='surprised':
   recoil=smooth(t/.16)*(1-smooth((t-.65)/.35));dx=-16*recoil;lean=-3*recoil;dy=-2*recoil;wing=2*recoil
  if action=='encourage':
   eye='happy';hold=smooth(t/.30)*(1-smooth((t-.78)/.22));lean=2.5*hold;dx=4*hold;dy=2*hold+1.5*math.sin(t*math.pi*2)*hold;wing=5*hold
  # Small independent genuine wing rotations; hand-held objects use same angular transform.
  angles['wingLeft']=-wing;angles['wingRight']=wing
  if action=='greet':
   angles['wingLeft']=0;angles['wingRight']=wing
   if outfit in ['summerVacation','halloween','rainyDay']:angles['wingLeft']=-wing;angles['wingRight']=0
  if outfit=='christmas':
   a=max(-2,min(2,wing/4)) if action not in ['idle','surprised'] else 0
   for id in ['gift','handLeft','handRight']:angles[id]=a;pivots[id]=(790,925)
  if outfit=='pajamas':
   a=max(-2,min(2,wing/4)) if action!='idle' else .3*sn
   for id in ['pillow','wingLeft','wingRight']:angles[id]=a;pivots[id]=(820,900)
  if outfit=='rainyDay':
   a=-min(4,abs(wing)/2) if action not in ['idle','sleepy'] else 0
   for id in ['umbrellaCanopy','umbrellaShaft','wingRight']:angles[id]=a;pivots[id]=(745,875)
  groups={'fitness':[('dumbbellLeft','wingLeft'),('dumbbellRight','wingRight')],'cafe':[('prop','wingLeft')],'student':[('prop','wingLeft')],'summerVacation':[('drink','wingRight')],'halloween':[('bag','wingRight')],'autumn':[('leaf','wingLeft')]}
  for prop,hand in groups.get(outfit,[]):
   hp=next(p for p in parts if p['id']==hand);angles[prop]=angles[hand];pivots[prop]=hp['pivot']
  if outfit=='fitness':
   angles['dumbbellLeft']=angles['wingLeft']=min(4,max(-4,angles['wingLeft']))
   angles['dumbbellRight']=angles['wingRight']=min(4,max(-4,angles['wingRight']))
  if outfit in ['cafe','student','summerVacation','halloween','autumn']:
   for prop,hand in groups.get(outfit,[]):angles[prop]=angles[hand]=min(4,max(-4,angles[hand]))
  im=Image.new('RGBA',(F,F));done=set()
  for p in sorted(parts,key=lambda p:p['z']):
   id=p['id']
   if id.startswith(('half','lid')):continue
   if id.startswith('eye'):
    side=id[3:];eid=('lid'+side if eye=='closed' else 'happy'+side if eye=='happy' else id)
    layer=ims.get(eid,ims[id]);im.alpha_composite(layer);continue
   im.alpha_composite(move(ims[id],angles.get(id,0),pivots.get(id,p['pivot'])))
  # Whole-body study transforms are explicit; they do not constitute independent cloth motion.
  if sx!=1 or sy!=1:
   nw,nh=round(F*sx),round(F*sy);scaled=im.resize((nw,nh),Image.Resampling.BICUBIC);tmp=Image.new('RGBA',(F,F));tmp.alpha_composite(scaled,(round(200-200*sx),round(350-350*sy)));im=tmp
  if lean:im=im.rotate(-lean,Image.Resampling.BICUBIC,center=(200,310))
  out=Image.new('RGBA',(F,F));out.alpha_composite(im,(round(dx),round(dy)));return out
 OD=OUT/outfit;OD.mkdir(exist_ok=True);frames=[];keys=[];durations=[];sequences=[];elapsed=0;borderChecks=[]
 for action in ACTIONS:
  key=frame(action,KEY[action]);key.save(OD/f'{action}-keypose-alpha.png');keys.append((action,key))
  count,duration=TIMING[action];sequences.append({'action':action,'sampledFrames':count,'sampleDurationMs':duration,'startMs':elapsed,'endMs':elapsed+count*duration});elapsed+=count*duration
  for n in range(count):
   im=Image.new('RGB',(F,F+30),'#172823');layer=frame(action,n/(count-1));alpha=layer.getchannel('A');edgeMax=max(alpha.crop(b).getextrema()[1] for b in [(0,0,F,1),(0,F-1,F,F),(0,0,1,F),(F-1,0,F,F)]);borderChecks.append({'action':action,'sample':n,'maxAlphaOnBorder':edgeMax});im.paste(layer,(0,30),layer);ImageDraw.Draw(im).text((10,10),f'{outfit} / {action}',fill='white');frames.append(im);durations.append(duration)
 contact=Image.new('RGB',(F*4,(F+30)*2),'#172823');dr=ImageDraw.Draw(contact)
 for i,(action,key) in enumerate(keys):
  x=(i%4)*F;y=(i//4)*(F+30);contact.paste(key,(x,y+30),key);dr.text((x+10,y+10),action,fill='white')
 contact.save(OD/'eight-actions-contact.png')
 # One palette sampled from all actions reduces distracting per-frame quantization shifts.
 palette=contact.quantize(colors=256,method=Image.Quantize.MEDIANCUT)
 q=[f.quantize(palette=palette,dither=Image.Dither.NONE) for f in frames]
 q[0].save(OD/'eight-actions-offline.gif',save_all=True,append_images=q[1:],duration=durations,loop=0,optimize=False,disposal=2)
 g=Image.open(OD/'eight-actions-offline.gif');proof=Image.new('RGB',(F*4,F+30),'#172823');dechashes=[]
 for n in range(g.n_frames):
  g.seek(n);dechashes.append(hashlib.sha256(g.convert('RGB').tobytes()).hexdigest())
 for i,n in enumerate([round((g.n_frames-1)*f) for f in [.12,.35,.6,.85]]):g.seek(n);proof.paste(g.convert('RGB'),(i*F,0))
 proof.save(OD/'decoded-gif-samples.png')
 assert all(digest(ROOT/p)==h for p,h in hashes.items())
 report={'outfit':outfit,'status':'PARTIAL_OFFLINE_ARTWORK_MOTION_STUDY','actions':ACTIONS,'sourceRegistrationSHA256':digest(D/'registration.json'),'canonicalLayerSHA256':hashes,'canonicalLayersUnchanged':True,'proofCanvas':[F,F+30],'sourceArtCanvas':[1254,1254],'animationLayerProcessing':'Existing neutral transforms baked; whole layers downscaled once to300px and padded into400px at(50,70) BEFORE any rotation; pivots offset accordingly; wholebody transforms stay on400px. No source crop, repaint, mask or regeneration.','independentMotion':'Eye open/closed/happy substitution; genuine separate wing rotation subject to held-prop constraints. Whole-body translation/lean is explicitly whole-body motion.','borderAlphaCheck':{'checkedFrames':len(borderChecks),'maxAlphaOnBorder':max(r['maxAlphaOnBorder'] for r in borderChecks),'allBordersTransparent':all(r['maxAlphaOnBorder']==0 for r in borderChecks),'note':'Output border numeric check only, not strict source-bound or all-alpha clipping certification.'},'sampledFrameCount':len(frames),'sequences':sequences,'totalDurationMs':elapsed,'actionDescriptions':{'idle':'Gentle whole-body breath scale and independent blink,2.16s','bounce':'Two low hops with compression before/after each,0.84s','jump':'Crouch,single48px lift,landing squash,recovery,1.26s','celebrate':'Happy eyes,independent wings,horizontal wiggle,no jump,1.76s','greet':'One free-wing3-cycle wave with held whole-body tilt,1.6s','sleepy':'Closed eyes,slow forward/down lean,hold,recovery,2.6s','surprised':'Fast backward horizontal recoil,hold,slower recovery;existing face,0.84s','encourage':'Slow forward lean,wing hold,subtle nod and recovery,2.16s'},'constraints':['No full turns, hand release, finger gripping, cloth deformation or app animation claimed.','Hat, helmet, sprout and clothing stay aligned with torso. Visor remains in original z-order.','Pajamas arms+pillow group±2deg; Christmas gift+both hands group±2deg; Rainy canopy+shaft+right hand0to-4deg; other held props share hand pivot and max4deg.','Happy/sleepy are real separate eye artwork. Surprised action has no bespoke eyebrows or mouth; supplied base face is retained.','GIF is palette-limited diagnostic; PNG keyposes retain full RGBA color.'],'gif':{'frames':g.n_frames,'uniqueDecodedFrames':len(set(dechashes)),'frameSHA256':dechashes},'notTested':['Application integration','Mac/iPhone runtime','CPU/memory','Reduce Motion','broader joint range']}
 (OD/'motion-manifest.json').write_text(json.dumps(report,indent=2));print(outfit,flush=True);return report
if __name__=='__main__':
 import sys
 names=sys.argv[1:] or [p.parent.name for p in ROOT.glob('*/registration.json')]
 for n in names:render(n)
