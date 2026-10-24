"""Offline source-preserving rig composition. Does not edit native source art."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import hashlib, json, statistics

out = Path(__file__).resolve().parent
kit = out.parent
S = 1254
m = json.loads((kit/'registration/registration-candidate.json').read_text())
opt = json.loads((kit/'registration/optional-frame-registration.json').read_text())['layers']
parts = sorted(m['parts'], key=lambda p:p['z'])
frame = next(p for p in opt if p['id']=='sunglasses')
lenses = [kit/'source/lenses-v1-candidate.png', kit/'source/lenses-v2-candidate.png']
sources = {Path(p['source']) for p in parts+opt} | set(lenses)
sha = lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
before = {str(p):sha(p) for p in sources}

def layer(p):
    im = Image.open(p['source']).convert('RGBA')
    im = im.resize((round(im.width*p['scale']),round(im.height*p['scale'])),Image.Resampling.LANCZOS)
    c = Image.new('RGBA',(S,S))
    c.alpha_composite(im,(round(p['offset'][0]),round(p['offset'][1])))
    if p.get('angle'):
        c = c.rotate(-p['angle'],resample=Image.Resampling.BICUBIC,center=p['pivot'])
    return c

def assemble(state, lens):
    c = Image.new('RGBA',(S,S))
    for p in parts:
        if p['id']=='sunglasses':
            c.alpha_composite(layer({'source':str(lens),'scale':.37,'offset':[312,438]}))
            c.alpha_composite(layer(frame))
        elif p['id'].startswith('eye'):
            match = 'eye-open' if state=='open' else 'eyelid-closed'
            q = next(a for a in opt if a['id']==p['id'] and match in a['source'])
            c.alpha_composite(layer(q))
        else:
            c.alpha_composite(layer(p))
    return c

themes = [('light',(250,245,235,255)),('dark',(18,28,25,255))]
images = {}
for n,lens in enumerate(lenses,1):
    for state in ['open','closed']:
        c=assemble(state,lens); images[f'v{n}-{state}']=c
        c.save(out/f'v{n}-{state}-alpha.png')
        for theme,color in themes:
            bg=Image.new('RGBA',(S,S),color); bg.alpha_composite(c)
            bg.convert('RGB').save(out/f'v{n}-{state}-{theme}.png')
reference=Image.open(m['original']).convert('RGBA')
for points in [64,220]:
    tile=points*3; gap=45; top=85
    items=[('Approved original',reference),('Prior pale lenses',images['v1-open']),('New dark lenses',images['v2-open']),('New dark closed eyes',images['v2-closed'])]
    for theme,color in themes:
        board=Image.new('RGBA',(4*(tile+gap)+gap,tile+top+gap),color);d=ImageDraw.Draw(board)
        for i,(title,im) in enumerate(items):
            x=gap+i*(tile+gap);board.alpha_composite(im.resize((tile,tile),Image.Resampling.LANCZOS),(x,top));d.text((x,32),title,fill='white' if theme=='dark' else 'black')
        board.convert('RGB').save(out/f'comparison-{points}pt-3x-{theme}.png')
frames=[]
for i in range(24):
    state='closed' if 10<=i<=11 else 'open'
    c=Image.new('RGBA',(440,440),themes[1][1]);c.alpha_composite(images['v2-'+state].resize((440,440),Image.Resampling.LANCZOS));d=ImageDraw.Draw(c);d.text((5,5),'OFFLINE LENS CANDIDATE | body fixed',fill='white');frames.append(c.convert('RGB'))
frames[0].save(out/'lens-v2-blink-offline.gif',save_all=True,append_images=frames[1:],duration=80,loop=0,optimize=False,disposal=2)
sheet=Image.new('RGB',(1320,440),themes[1][1][:3])
for j,i in enumerate([0,10,12]):sheet.paste(frames[i],(440*j,0))
sheet.save(out/'blink-frame-proof.png')
stats=[]
for p in lenses:
    im=Image.open(p).convert('RGBA');a=im.getchannel('A');probes=[]
    for name,box in [('left',(450,470,650,600)),('right',(1220,350,1420,480))]:
        v=list(a.crop(box).getdata());probes.append({'name':name,'box':box,'min':min(v),'max':max(v),'median':statistics.median(v),'mean':statistics.mean(v)})
    stats.append({'source':str(p),'size':list(im.size),'probes':probes})
report={'status':'CANDIDATE_REQUIRES_VISUAL_REVIEW','method':'Full source canvases, whole-pair uniform downscale and translation; native alpha retained, no masks/cleanup/painting/source-upscaling','canvas':[S,S],'lensTransform':{'scale':.37,'offset':[312,438]},'frameTransform':frame,'alphaStats':stats,'nativeSourcesUnchanged':all(sha(p)==h for p,h in before.items()),'sourceSHA256':before,'primaryRegistrationUnchanged':True,'files':[{'file':str(p.name),'sha256':sha(p),'bytes':p.stat().st_size} for p in sorted(out.glob('*')) if p.suffix in ['.png','.gif']]}
(out/'verification.json').write_text(json.dumps(report,indent=2)+'\n')
assert report['nativeSourcesUnchanged']
print('Saved source-preserving Summer lens review:',out)
