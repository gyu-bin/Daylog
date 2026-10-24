"""QA composites and alpha statistics only. Sources remain untouched."""
from pathlib import Path
from PIL import Image,ImageDraw
import json
base=Path(__file__).resolve().parent.parent
out=Path(__file__).resolve().parent/'summerVacation-v1';out.mkdir(exist_ok=True)
files=sorted((base/'summerVacation-v1'/'source').glob('*.png'))
stats=[]
for p in files:
 im=Image.open(p).convert('RGBA'); a=im.getchannel('A'); h=a.histogram()
 row={'file':str(p),'size':im.size,'alpha_range':a.getextrema(),'transparent_pixels':h[0],'almost_opaque_pixels':sum(h[240:]),'bounds_alpha2':a.point(lambda v:255 if v>=2 else 0).getbbox()}
 stats.append(row)
 for mode,bg in [('light',(247,245,239,255)),('dark',(22,29,34,255))]:
  canvas=Image.new('RGBA',im.size,bg);canvas.alpha_composite(im);canvas.convert('RGB').save(out/f'{p.stem}-{mode}.png')
for mode,bg in [('light',(247,245,239)),('dark',(22,29,34))]:
 sheet=Image.new('RGB',(1400,((len(files)+2)//3)*380),bg);d=ImageDraw.Draw(sheet)
 for i,p in enumerate(files):
  thumb=Image.open(out/f'{p.stem}-{mode}.png');thumb.thumbnail((450,335));x=(i%3)*466;y=(i//3)*380
  sheet.paste(thumb,(x+(450-thumb.width)//2,y+30));d.text((x+8,y+8),p.stem,fill='white' if mode=='dark' else 'black')
 sheet.save(out/f'component-sheet-{mode}.png')
(out/'alpha-audit.json').write_text(json.dumps(stats,indent=2))
print(json.dumps(stats,indent=2))
