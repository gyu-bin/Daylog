"""Read-only image/file audit of the eight continuation candidate kits."""
from pathlib import Path
from PIL import Image
import hashlib, json, subprocess

root = Path(__file__).resolve().parents[1]
repo = root.parents[1]
ids = ['autumn', 'winter', 'halloween', 'cafe', 'student', 'fitness', 'rainyDay', 'pajamas']
rows = []
for outfit in ids:
    kit = root / (outfit + '-v1')
    sources = sorted((kit / 'source').glob('*.png'))
    layers = sorted((kit / 'registered-layers').glob('*.png')) + sorted((kit / 'registration' / 'layers').glob('*.png'))
    assert sources and layers, f'Missing source or registered layer kit: {outfit}'
    source_rows = []
    for path in sources:
        with Image.open(path) as im:
            im.load()
            assert 'A' in im.getbands(), str(path)
            alpha = im.getchannel('A').getextrema()
            assert alpha[0] == 0 and alpha[1] > 0, str(path)
            source_rows.append({'path': str(path.relative_to(root)), 'size': list(im.size), 'alpha_range': list(alpha), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    for path in layers:
        with Image.open(path) as im:
            im.load()
            assert im.size == (1254, 1254) and 'A' in im.getbands(), str(path)
    comparisons = []
    for points in [64, 220]:
        for theme in ['light', 'dark']:
            p = kit / 'registration' / f'comparison-{points}pt-3x-{theme}.png'
            with Image.open(p) as im:
                im.verify()
            comparisons.append(str(p.relative_to(root)))
    gifs = []
    for path in sorted((kit / 'registration').glob('*.gif')):
        with Image.open(path) as im:
            gifs.append({'path': str(path.relative_to(root)), 'size': list(im.size), 'frames': im.n_frames, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    original = repo / 'Daylog' / 'PioWardrobe.xcassets' / f'pio_outfit_{outfit}.imageset' / f'pio_outfit_{outfit}.png'
    rows.append({'outfit': outfit, 'status': 'PARTIAL_UNAPPROVED_ARTWORK_CANDIDATE', 'source_count_including_preserved_iterations': len(sources), 'sources': source_rows, 'registered_derivative_count': len(layers), 'registered_files': [str(p.relative_to(root)) for p in layers], 'comparisons': comparisons, 'offline_motion_proofs': gifs, 'approved_original_sha256': hashlib.sha256(original.read_bytes()).hexdigest()})

diff_hash = hashlib.sha256(subprocess.check_output(['git', 'diff', '--binary'], cwd=repo)).hexdigest()
checkpoint = hashlib.sha256((root / 'qa' / 'application-diff-checkpoint.patch').read_bytes()).hexdigest()
report = {'status': 'PARTIAL_ARTWORK_REVIEW_ONLY', 'new_source_pngs_including_iterations': sum(x['source_count_including_preserved_iterations'] for x in rows), 'registered_derivative_pngs': sum(x['registered_derivative_count'] for x in rows), 'outfits': rows, 'tracked_application_diff_unchanged': diff_hash == checkpoint, 'tracked_diff_sha256': diff_hash, 'app_builds_or_existing_tests_rerun': False, 'native_animation_performance_qa': 'NOT_TESTED'}
assert diff_hash == checkpoint, 'Tracked diff changed: inspect before reporting preservation'
(root / 'qa' / 'batch2-file-verification.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps({k: report[k] for k in ['status', 'new_source_pngs_including_iterations', 'registered_derivative_pngs', 'tracked_application_diff_unchanged']}))
