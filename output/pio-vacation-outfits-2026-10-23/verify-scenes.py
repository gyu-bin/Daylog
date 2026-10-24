from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
import hashlib,json,math,re
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(__file__).resolve().parent
ids=['christmas','hanbok','astronaut','cherryBlossom','summerVacation','autumn','winter','halloween','cafe','student','fitness','rainyDay','pajamas']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
report={'scope':'Offline original-art candidates; not app integrated; all sources are flattened foregrounds, NOT independently rigged characters.','expected_source_count':26,'assets':[],'missing':[],'original_registration':{'canvas':[1024,1536],'day':{'attachment':[968,484],'focus':[512,740]},'night':{'attachment':[68,465],'focus':[512,845]},'note':'Generation can shift geometry despite same canvas. Original anchors are reference only; do not use as verified candidate pivots.'},'backgrounds':{}}
font=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',18)
for mode in ['day','night']:
 suffix='_night' if mode=='night' else ''
 bp=ROOT/f'Daylog/RoutimoriTrial.xcassets/routimori_vacation_background{suffix}.imageset/routimori_vacation_background{suffix}.png'
 bg=Image.open(bp).convert('RGBA');report['backgrounds'][mode]={'path':str(bp.relative_to(ROOT)),'sha256':sha(bp)}
 sheet=Image.new('RGB',(4*256,4*412),(246,244,237) if mode=='day' else (15,27,45));draw=ImageDraw.Draw(sheet)
 draw.text((12,8),'13 outfit vacation '+mode+' | CANDIDATES - NOT APP INTEGRATED',font=font,fill=(45,70,55) if mode=='day' else 'white')
 for n,id in enumerate(ids):
  version='v2' if id=='astronaut' else 'v1'
  p=OUT/f'source/{id}-{mode}-{version}.png'
  if not p.exists():report['missing'].append(str(p.relative_to(OUT)));continue
  with Image.open(p) as im:im.load();im=im.convert('RGBA')
  a=im.getchannel('A');ext=a.getextrema();hist=a.histogram();ap=bg.copy()
  item={'id':id,'mode':mode,'path':str(p.relative_to(OUT)),'native_size':list(im.size),'rgba':True,'alpha_extrema':list(ext),'transparent_pixels':hist[0],'semitransparent_pixels':sum(hist[1:255]),'alpha_bbox':a.getbbox(),'sha256':sha(p),'native_bytes':p.stat().st_size,'canvas_matches':im.size==bg.size,'approval':'PARTIAL - authored candidate; exact rope registration and design fidelity need approval','independent_motion':False}
  gp=Path(str(p)+'.generation.json')
  if not gp.exists():gp=p.with_suffix('.generation.json')
  provenance=json.loads(gp.read_text())
  matches=re.findall(r'/Users/[^\s]+\.png',provenance.get('output_hint',''))
  original=Path(matches[-1]) if matches else None
  item['generation_provenance']=str(gp.relative_to(OUT))
  item['native_copy_unchanged']=bool(original and original.exists() and sha(original)==sha(p))
  ref=ROOT/f'Daylog/PioWardrobe.xcassets/pio_outfit_{id}.imageset/pio_outfit_{id}.png'
  item['approved_costume_reference']={'path':str(ref.relative_to(ROOT)),'sha256':sha(ref)}
  item['active_candidate_version']=version
  if id=='astronaut':item['supersedes']={'path':f'source/astronaut-{mode}-v1.png','status':'REJECTED for visor/straw logic; preserved unchanged'}
  report['assets'].append(item)
  if im.size!=bg.size:continue
  ap.alpha_composite(im);ap.save(OUT/f'qa/{id}-{mode}-assembly-{version}.png')
  thumb=ap.resize((256,384),Image.Resampling.LANCZOS).convert('RGB');x=(n%4)*256;y=40+(n//4)*400
  sheet.paste(thumb,(x,y));draw.text((x+8,y+384),id,font=font,fill=(45,70,55) if mode=='day' else 'white')
 sheet.save(OUT/f'qa/all-13-{mode}-assemblies.png')
report['actual_source_count']=len(report['assets']);report['file_validation']='PASS' if not report['missing'] and all(a['canvas_matches'] and a['transparent_pixels']>0 and a['native_copy_unchanged'] for a in report['assets']) else 'PARTIAL'
(OUT/'manifest.json').write_text(json.dumps(report,indent=2))
print(json.dumps({'sources':len(report['assets']),'missing':report['missing'],'file_validation':report['file_validation']},indent=2))
