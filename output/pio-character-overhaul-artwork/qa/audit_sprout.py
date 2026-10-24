"""QA only: alpha statistics and native-size background compositing. Never edits source."""
from PIL import Image
from pathlib import Path
import json
SOURCE = Path('/Users/mungyubin/.codex/generated_images/01a13e4c-eb2f-7c33-a58c-004a195b88c3/exec-ff2d09af-23fe-4753-a435-280c93c7b475.png')
OUT = Path(__file__).resolve().parent
im = Image.open(SOURCE).convert('RGBA')
alpha = im.getchannel('A')
hist = alpha.histogram()
thresholds = {}
for threshold in [1, 2, 5, 10, 32, 128, 240, 250, 254]:
    mask = alpha.point(lambda value: 255 if value >= threshold else 0)
    thresholds[str(threshold)] = {'pixels': sum(hist[threshold:]), 'bbox': mask.getbbox()}
stats = {'source': str(SOURCE), 'size': im.size, 'mode': Image.open(SOURCE).mode,
         'alpha_extrema': alpha.getextrema(), 'zero_alpha': hist[0],
         'full_alpha': hist[255], 'partial_alpha': sum(hist[1:255]),
         'alpha_bbox': alpha.getbbox(), 'thresholds': thresholds}
(OUT / 'sprout-alpha.json').write_text(json.dumps(stats, indent=2))
for name, color in [('light', (247,245,239,255)), ('dark', (22,29,34,255))]:
    bg = Image.new('RGBA', im.size, color)
    bg.alpha_composite(im)
    bg.convert('RGB').save(OUT / f'sprout-{name}-native.png')
print(json.dumps(stats, indent=2))
