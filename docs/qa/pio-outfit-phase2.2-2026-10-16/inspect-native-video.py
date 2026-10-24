from PIL import Image,ImageDraw
import subprocess,io,json
from pathlib import Path
q=Path(__file__).parent/'runtime'; ff='/opt/homebrew/bin/ffmpeg'
for outfit,motion in [('hanbok','flap'),('astronaut','flap')]:
 frames=[]
 for t in [0,.5,1,1.5,2,2.5,3,3.5]:
  b=subprocess.check_output([ff,'-v','error','-ss',str(t),'-i',str(q/f'preview-{outfit}-{motion}-8s.mp4'),'-frames:v','1','-f','image2pipe','-vcodec','png','-'])
  frames.append(Image.open(io.BytesIO(b)).convert('RGB').crop((110,610,470,1000)))
 out=Image.new('RGB',(1440,820),'#12241f');d=ImageDraw.Draw(out)
 for i,im in enumerate(frames):out.paste(im,((i%4)*360,(i//4)*410+20));d.text(((i%4)*360+8,(i//4)*410+2),f'{i*.5:.1f}s',fill='white')
 out.save(q/f'preview-{outfit}-motion-contact.png')
raw=subprocess.check_output([ff,'-v','error','-i',str(q/'preview-christmas-blink-8s.mp4'),'-vf','crop=400:390:110:610,fps=30','-f','rawvideo','-pix_fmt','rgb24','-'])
frames=[Image.frombytes('RGB',(400,390),raw[i:i+400*390*3]) for i in range(0,len(raw),400*390*3)]
scores=[sum(1 for rgb in im.crop((140,160,270,235)).getdata() if max(rgb)<85) for im in frames]
low=min(range(len(scores)),key=lambda i:scores[i]);ids=[max(0,low-5),max(0,low-2),low,min(len(frames)-1,low+3)]
out=Image.new('RGB',(1600,415),'#12241f');d=ImageDraw.Draw(out)
for j,i in enumerate(ids):out.paste(frames[i],(j*400,25));d.text((j*400+8,5),f'Native clip frame{i} ({i/30:.3f}s)',fill='white')
out.save(q/'preview-christmas-blink-contact.png')
(q/'video-inspection.json').write_text(json.dumps({'excerpts':'Unretimed first1–9s of genuine native DeviceHub videos, downscaled and exported30fps. Not an app FPS measurement.','wingSampleSeconds':[0,.5,1,1.5,2,2.5,3,3.5],'blinkSelectedFrameIndices':ids,'blinkDarkPixelRange':[min(scores),max(scores)]},indent=2))
print('Native sampled motion contacts saved')
