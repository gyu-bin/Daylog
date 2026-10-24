from pathlib import Path
import json,zipfile,hashlib
R=Path(__file__).resolve().parent;D=R/'compact-review';D.mkdir(exist_ok=True)
pilots=['basic','christmas','hanbok','astronaut'];actions=['idle','bounce','jump','celebrate','greet','sleepy','surprised','encourage'];names=sorted(p.parent.name for p in R.glob('*/verification.json'))
html='''<!doctype html><meta charset="utf-8"><title>Pio motion v2 compact review</title><style>body{font:17px system-ui;background:#172823;color:#f4f0dd;max-width:1060px;margin:32px auto;padding:14px}select{font:inherit;padding:8px}img,video{max-width:100%;display:block}a{color:#b4d6a0}</style><h1>피오 동작 개선 검토</h1><p>14종 전체 정지 비교 · 대표 4종 8동작 무손실 재생 · 수정 전후 영상</p><p>오프라인 PARTIAL 시안입니다. 앱 적용·성능 PASS를 의미하지 않습니다.</p><h2>대표 동작</h2><select id="pilot"></select><select id="action"></select><img id="motion" width="480"><h2>수정 전후</h2><video id="video" controls width="960" preload="none"></video><h2>14종 정지 비교</h2><select id="outfit"></select><img id="contact"><p><a href="README.md">정확한 파일 구성·한계</a></p><script>const pilots=PILOTS,actions=ACTIONS,names=NAMES;pilots.forEach(n=>pilot.add(new Option(n,n)));actions.forEach(n=>action.add(new Option(n,n)));names.forEach(n=>outfit.add(new Option(n,n)));function play(){motion.src=pilot.value+'/'+action.value+'.png';video.src=pilot.value+'/before-after-eight-actions.mp4'}pilot.onchange=action.onchange=play;outfit.onchange=()=>contact.src=outfit.value+'/eleven-actions-contact.png';play();outfit.onchange()</script>'''.replace('PILOTS',json.dumps(pilots)).replace('ACTIONS',json.dumps(actions)).replace('NAMES',json.dumps(names));(D/'review.html').write_text(html)
entries=[(D/'review.html','review.html')]
for name in names:entries.append((R/name/'eleven-actions-contact.png',name+'/eleven-actions-contact.png'))
for name in pilots:
 for action in actions:entries.append((R/name/f'{action}.png',name+f'/{action}.png'))
 for f in ['before-after-eight-actions.mp4','phase-contact.png']:entries.append((R/name/f,name+'/'+f))
entries.append((R/'artifact-verification.json','master-artifact-verification.json'))
readme='''# Compact motion review v2

Status: PARTIAL / OFFLINE ONLY. 14 outfit contact PNGs, 32 lossless action APNGs (4 representative outfits × agreed 8 core actions), 4 before/after MP4s, 4 phase contact PNGs, local interactive review, source manifest/decode verification from the larger master folder. Full master folder contains 14 × 11 sequences, but this compact ZIP intentionally contains only the selected animations above.

Open review.html after extracting the entire ZIP. APNGs play automatically in supported browsers. Each sequence is 2.24 seconds; encoders may merge identical adjacent frames while preserving duration. MP4 before/after comparisons normalize the action timelines and match character scale, so they compare choreography shape rather than original speed.

Original source artwork is unchanged. No application/runtime, Reduce Motion, CPU/memory, every shoulder seam, four distinct growth appearances, or final visual approval is certified. Christmas holds a gift with both hands and Pajamas hugs a pillow; neither is presented as a free-handed wave. Front-view stepping and frontal compression/lean are not authored 3D turns. Separate eye artwork is real; cloth, headwear and props remain rigid as documented. These are review files and must not be bundled as runtime frame animation.
''';(D/'README.md').write_text(readme);entries.append((D/'README.md','README.md'))
manifest=[{'file':arc,'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p,arc in entries];(D/'contents.json').write_text(json.dumps(manifest,indent=2));entries.append((D/'contents.json','contents.json'))
z=R.parent/'Pio-Motion-v2-Compact-Review-2026-10-23.zip'
with zipfile.ZipFile(z,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as a:
 for p,arc in entries:a.write(p,arc)
with zipfile.ZipFile(z) as a:
 bad=a.testzip();assert bad is None
 result={'zip':str(z.resolve()),'bytes':z.stat().st_size,'entries':len(a.infolist()),'crc':'PASS','selectedActionAPNGs':32,'allOutfitContacts':14,'beforeAfterMP4s':4,'phaseContacts':4,'archiveSHA256':hashlib.sha256(z.read_bytes()).hexdigest()}
(D/'zip-verification.json').write_text(json.dumps(result,indent=2));print(json.dumps(result))
