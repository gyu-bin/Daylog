from pathlib import Path
from PIL import Image,ImageDraw
import json,hashlib
for name in (__import__('sys').argv[1:] or ['cafe','student']):
 base=Path('output/pio-character-overhaul-artwork')/f'{name}-v1';out=base/'qa';out.mkdir(exist_ok=True)
 files=sorted((base/'source').glob('*.png'));rows=[]
 for p in files:
  im=Image.open(p).convert('RGBA');a=im.getchannel('A');h=a.histogram();rows.append({'file':str(p),'size':im.size,'alpha':a.getextrema(),'zeroAlpha':h[0],'alpha16Bounds':a.point(lambda x:255 if x>=16 else 0).getbbox(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
  for theme,color in [('light',(250,245,235,255)),('dark',(18,28,25,255))]:
   c=Image.new('RGBA',im.size,color);c.alpha_composite(im);c.convert('RGB').save(out/f'{p.stem}-{theme}.png')
 for theme,col in [('light',(250,245,235)),('dark',(18,28,25))]:
  c=Image.new('RGB',(1500,900),col);d=ImageDraw.Draw(c)
  for i,p in enumerate(files):
   im=Image.open(out/f'{p.stem}-{theme}.png');im.thumbnail((480,410));x=(i%3)*500;y=(i//3)*450;c.paste(im,(x+(500-im.width)//2,y+25));d.text((x+10,y+6),p.stem,fill='white' if theme=='dark' else 'black')
  c.save(out/f'components-{theme}.png')
 (out/'source-alpha-audit.json').write_text(json.dumps(rows,indent=2))
 print(name,rows)
