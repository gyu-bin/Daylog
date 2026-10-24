from pathlib import Path
import json,shutil,hashlib,struct,subprocess
q=Path(__file__).resolve().parent
root=q.parents[2]/'Daylog/PioWardrobe.xcassets'
manifest=[]
for f in sorted(q.glob('sources-batch*.json')):
 for a in json.loads(f.read_text()):
  src=Path(a['source']);d=root/(a['asset']+'.imageset'); d.mkdir(exist_ok=True)
  p=d/(a['asset']+'.png')
  if p.exists(): assert p.read_bytes()==src.read_bytes(),f'Unexpected existing asset: {p}'
  else: shutil.copy2(src,p)
  content={'images':[{'filename':p.name,'idiom':'universal'}],'info':{'author':'xcode','version':1}}
  (d/'Contents.json').write_text(json.dumps(content,indent=2)+'\n')
  raw=p.read_bytes();dims=struct.unpack('>II',raw[16:24]);manifest.append(dict(a,path=str(p),width=dims[0],height=dims[1],sha256=hashlib.sha256(raw).hexdigest()))
(q/'asset-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
pngs=[a['path'] for a in manifest]
r=subprocess.run(['/tmp/pio-outfit-inspect-alpha-20261016',*pngs],check=True,capture_output=True,text=True)
(q/'alpha-validation.json').write_text(r.stdout)
stats=json.loads(r.stdout)
for s in stats: print(Path(s['path']).stem,s['width'],s['height'],'alpha+padding',s['passesTransparencyAndPadding'])
assert all(s['passesTransparencyAndPadding'] for s in stats),'Asset transparency/padding failure'
print('Imported:',len(manifest),'unchanged PNGs')
