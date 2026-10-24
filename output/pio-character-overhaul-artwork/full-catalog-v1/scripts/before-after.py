from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,ImageOps
import json
ROOT=Path(__file__).resolve().parents[4];OUT=ROOT/'output/pio-character-overhaul-artwork/full-catalog-v1';D=OUT/'before-after';D.mkdir(exist_ok=True)
cat=json.loads((OUT/'catalog-manifest.json').read_text());font=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',18)
items=[]
for p in cat['items']:
 name=p['outfit'];asset='pio_wardrobe_basic_reference' if name=='basic' else 'pio_outfit_'+name;old=Image.open(ROOT/f'Daylog/PioWardrobe.xcassets/{asset}.imageset/{asset}.png').convert('RGBA');new=Image.open(OUT/name/('closed-1254-alpha.png' if name=='pajamas' else 'open-1254-alpha.png')).convert('RGBA');items.append((name,old,new))
 for theme,bg,fg in [('light','#faf6ed','#23483d'),('dark','#14251f','#f8efdb')]:
  b=Image.new('RGBA',(1404,744),bg);dr=ImageDraw.Draw(b);dr.text((28,12),name+' | approved original / layered candidate | 220pt @3x',font=font,fill=fg)
  for i,im in enumerate([old,new]):
   fit=ImageOps.contain(im,(660,660),Image.Resampling.LANCZOS);b.alpha_composite(fit,(28+i*688+(660-fit.width)//2,62+(660-fit.height)//2))
  b.convert('RGB').save(D/f'{name}-220pt-3x-{theme}.png')
for theme,bg,fg in [('light','#faf6ed','#23483d'),('dark','#14251f','#f8efdb')]:
 b=Image.new('RGBA',(1920,1400),bg);dr=ImageDraw.Draw(b);dr.text((20,12),'All14 | approved original (left) / layered candidate (right) | NOT APP INTEGRATION',font=font,fill=fg)
 for n,(name,old,new) in enumerate(items):
  x=n%4*480;y=55+n//4*330;dr.text((x+16,y),name,font=font,fill=fg)
  for i,im in enumerate([old,new]):
   fit=ImageOps.contain(im,(230,260),Image.Resampling.LANCZOS);b.alpha_composite(fit,(x+i*240+(240-fit.width)//2,y+35+(260-fit.height)//2))
 b.convert('RGB').save(D/f'all14-before-after-{theme}.png')
print('Saved28 original/candidate comparison PNGs and2 overview boards; aspect ratio preserved')
