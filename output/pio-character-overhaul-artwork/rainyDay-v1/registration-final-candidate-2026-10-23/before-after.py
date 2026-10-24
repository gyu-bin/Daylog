from PIL import Image,ImageDraw
from pathlib import Path
D=Path(__file__).resolve().parent
for theme,bg in [('light',(250,245,232)),('dark',(18,28,26))]:
 out=Image.new('RGB',(1440,540),bg);dr=ImageDraw.Draw(out)
 for i,(name,path) in enumerate([('Approved flattened original',D.parents[3]/'Daylog/PioWardrobe.xcassets/pio_outfit_rainyDay.imageset/pio_outfit_rainyDay.png'),('Previous layered candidate',D.parent/'registration-2026-10-23/neutral-alpha.png'),('New shaft and depth candidate',D/'neutral-alpha.png')]):
  im=Image.open(path).convert('RGBA').resize((480,480),Image.Resampling.LANCZOS);out.paste(im,(480*i,40),im);dr.text((480*i+20,15),name,fill='white' if theme=='dark' else 'black')
 out.save(D/f'before-after-{theme}.png')
