"""Optional lens artwork fit diagnostic, no source pixel edits/masks/crops."""
from pathlib import Path
from PIL import Image,ImageDraw
import json,hashlib
BASE=Path(__file__).resolve().parent.parent;OUT=Path(__file__).resolve().parent;S=1254
m=json.loads((BASE/'registration/registration-candidate.json').read_text());o=json.loads((BASE/'registration/optional-frame-registration.json').read_text())
parts=m['parts'];optional=o['layers'];lens=BASE/'source/lenses-v1-candidate.png';rim=next(p for p in optional if p['id']=='sunglasses')
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def layer(p):
 im=Image.open(p['source']).convert('RGBA');im=im.resize((round(im.width*p['scale']),round(im.height*p['scale'])),Image.Resampling.LANCZOS);c=Image.new('RGBA',(S,S));c.alpha_composite(im,(round(p['offset'][0]),round(p['offset'][1])))
 if p.get('angle'):c=c.rotate(-p['angle'],resample=Image.Resampling.BICUBIC,center=p['pivot'])
 return c
# Whole-pair center-align versus diameter-fit: cannot independently move individual panes.
fits=[{'name':'centers-fit','scale':.37,'offset':[312,438]},{'name':'diameters-fit','scale':.28,'offset':[388,480]}]
for theme,color in [('light',(250,245,235,255)),('dark',(18,28,25,255))]:
 for fit in fits:
  c=Image.new('RGBA',(S,S),color)
  for p in sorted(parts,key=lambda a:a['z']):
   if p['id']=='sunglasses':
    c.alpha_composite(layer({'source':str(lens),'scale':fit['scale'],'offset':fit['offset']}));c.alpha_composite(layer(rim))
   elif p['id'].startswith('eye'):
    p=next(a for a in optional if a['id']==p['id'] and 'eye-open' in a['source']);c.alpha_composite(layer(p))
   else:c.alpha_composite(layer(p))
  c.convert('RGB').save(OUT/f'optional-{fit["name"]}-{theme}.png')
 # Standalone full-pair compositing confirms source is translucent rather than gray background.
 im=Image.open(lens).convert('RGBA');c=Image.new('RGBA',im.size,color);c.alpha_composite(im);c.convert('RGB').save(OUT/f'new-lenses-native-{theme}.png')
(OUT/'attempted-transforms.json').write_text(json.dumps({'status':'DIAGNOSTIC_NOT_APPROVED','canvas':[S,S],'lensSource':str(lens),'lensSourceSHA256':sha(lens),'frameSource':rim['source'],'frameSourceSHA256':sha(rim['source']),'frameTransform':rim,'fits':fits,'method':'Whole pair uniform downscale/translation only; no pane separation, masks, pixel changes or upscaling','primaryRegistrationSHA256':sha(BASE/'registration/registration-candidate.json')},indent=2))
print('Optional diagnostics saved; primary registration untouched')
# Credible whole-pair fit: actual native cyan diagnostic shows no obvious pane overhang.
fit=fits[0]
outputs={}
for state in ['open','closed']:
 c=Image.new('RGBA',(S,S))
 for p in sorted(parts,key=lambda a:a['z']):
  if p['id']=='sunglasses':
   c.alpha_composite(layer({'source':str(lens),'scale':fit['scale'],'offset':fit['offset']}));c.alpha_composite(layer(rim))
  elif p['id'].startswith('eye'):
   p=next(a for a in optional if a['id']==p['id'] and ('eye-open' in a['source'] if state=='open' else 'eyelid-closed' in a['source']));c.alpha_composite(layer(p))
  else:c.alpha_composite(layer(p))
 outputs[state]=c;c.save(OUT/f'optional-tinted-{state}-alpha.png')
 for theme,color in [('light',(250,245,235,255)),('dark',(18,28,25,255))]:
  bg=Image.new('RGBA',(S,S),color);bg.alpha_composite(c);bg.convert('RGB').save(OUT/f'optional-tinted-{state}-{theme}.png')
reference=Image.open(m['original']).convert('RGBA')
for theme,color in [('light',(250,245,235,255)),('dark',(18,28,25,255))]:
 for pt in [64,220]:
  tile=pt*3;gap=60;top=90;items=[('Approved original',reference),('Optional tinted open',outputs['open']),('Optional tinted closed',outputs['closed'])];c=Image.new('RGBA',(len(items)*(tile+gap)+gap,tile+top+gap),color);d=ImageDraw.Draw(c)
  for i,(title,im) in enumerate(items):
   x=gap+i*(tile+gap);c.alpha_composite(im.resize((tile,tile),Image.Resampling.LANCZOS),(x,top));d.text((x,35),title,fill='white' if theme=='dark' else 'black')
  c.convert('RGB').save(OUT/f'optional-tint-comparison-{pt}pt-3x-{theme}.png')
verification=[]
for p in OUT.glob('*.png'):
 im=Image.open(p);verification.append({'file':p.name,'dimensions':im.size,'bytes':p.stat().st_size,'sha256':sha(p)})
(OUT/'png-verification.json').write_text(json.dumps({'sourceHashesUnchanged':{str(lens):sha(lens)==json.loads((OUT/'attempted-transforms.json').read_text())['lensSourceSHA256'],rim['source']:sha(rim['source'])==rim['sourceSHA256']},'files':verification},indent=2))
