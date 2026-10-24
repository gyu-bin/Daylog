"""Package selected, verified Phase 2.2 evidence without altering application files."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import subprocess
import zipfile

qa = Path(__file__).resolve().parent
repo = qa.parents[2]
selected = {}

def add(path, archive=None):
    path = Path(path)
    assert path.is_file(), path
    archive = archive or path.relative_to(qa).as_posix()
    assert archive not in selected or selected[archive] == path
    selected[archive] = path

docs = [
    'RESULTS.md', 'PERFORMANCE.md', 'RIGGING.md', 'review.html',
    'selected-assets.json', 'generation-prompts.json', 'final-art-gate.md',
    'code-review.md', 'growth-stage-readiness.md', 'half-eye-art-review.md',
    'hanbok-art-review.md', 'astronaut-art-review.md', 'base-art-audit.md',
    'base-candidate-review.md', 'christmas-assembly-review.md',
    'exact-existing-diff-check.txt', 'preservation-final.json',
    'before-hashes.json', 'before-status.txt', 'after-status.txt',
    'mac-build-final.log', 'ios-build-final.log', 'focused-tests-final.log',
    'performance-sample.py', 'launch-layered-verification.py',
    'inspect-native-video.py', 'preservation-check.py', 'package-review.py',
]
for name in docs:
    add(qa / name)
for p in qa.glob('performance-*.json'):
    add(p)

kits = ['base-half-a', 'christmas-half-a', 'hanbok-half-a', 'astronaut-half-a']
part_count = 0
for kit in kits:
    folder = qa / 'registered' / kit
    for p in folder.iterdir():
        if p.is_file():
            add(p)
    registration = json.loads((folder / 'registration.json').read_text())
    for part in registration['layers']:
        part_count += 1
        source = Path(part['source'])
        if len(source.parts) == 1:
            source = Path('candidates/base') / source
        add(qa / source)
assert part_count == 51

# Include final endpoint/comparison evidence, not rejected candidate packages.
for kit in ['christmas-f', 'christmas-g', 'hanbok-e', 'astronaut-c', 'base-walk-ground']:
    for p in (qa / 'registered' / kit).iterdir():
        if p.is_file() and (p.suffix == '.json' or any(w in p.name for w in ['comparison', 'joint'])):
            add(p)

for p in (qa / 'runtime').iterdir():
    if not p.is_file():
        continue
    if (p.name.startswith('final-') and p.suffix in ['.jpg', '.txt', '.json']) or p.name.startswith('preview-') or 'system-reduce-motion' in p.name or p.name == 'video-inspection.json':
        add(p)

for outfit in ['basic', 'christmas', 'hanbok', 'astronaut']:
    src = repo / f'Daylog/PioLayeredTrial.xcassets/pio_layered_{outfit}_registration.dataset/registration.json'
    dst = qa / f'runtime-manifests/{outfit}-final.json'
    shutil.copyfile(src, dst)
    add(dst)

for name in ['Daylog/Components/PioLayeredCharacter.swift', 'Daylog/Components/PioLayeredDiagnosticsView.swift', 'DaylogTests/PioLayeredRigTests.swift']:
    add(repo / name, 'implementation/' + name)
for folder in ['Tools/pio-layered-rig', 'Daylog/PioLayeredTrial.xcassets']:
    for p in (repo / folder).rglob('*'):
        if p.is_file() and p.name != '.DS_Store':
            add(p, 'implementation/' + p.relative_to(repo).as_posix())

html_links = re.findall(r'(?:src|href)="([^"]+)"', (qa / 'review.html').read_text())
for link in html_links:
    assert link in selected, ('missing HTML dependency', link)
for name, p in selected.items():
    if p.suffix == '.png':
        with p.open('rb') as f:
            assert f.read(8) == b'\x89PNG\r\n\x1a\n', name

video_info = []
for p in sorted((qa / 'runtime').glob('preview-*-8s.mp4')):
    data = json.loads(subprocess.check_output(['/opt/homebrew/bin/ffprobe', '-v', 'error', '-show_entries', 'format=duration:stream=width,height,codec_name', '-of', 'json', str(p)], text=True))
    assert 7.90 <= float(data['format']['duration']) <= 8.05
    video_info.append({'file': p.relative_to(qa).as_posix(), **data})
assert len(video_info) == 3

readme = qa / 'START-HERE.md'
readme.write_text('''# 피오 Phase 2.2 검토 패키지

ZIP을 풀고 `review.html`을 열면 원본 비교와 실제 앱 영상 3개를 볼 수 있습니다.
`RESULTS.md`에 완료 범위와 남은 제한, `PERFORMANCE.md`에 측정값과 해석이 있습니다.

`registered/*-half-a/`는 선택된 51개 투명 부품과 열린 눈·반눈·감은 눈 합성입니다.
`candidates/`는 그 부품에 실제로 사용한 고해상도 생성 원본입니다.
기본 피오 등록 파일의 단순 소스 파일명은 `candidates/base/`를 기준으로 해석합니다.
`selected-assets.json`의 registeredFile은 원래 프로젝트 기준 경로입니다.
패키지에서는 `docs/qa/pio-outfit-phase2.2-2026-10-16/` 접두어를 제거하면 됩니다.

`runtime/preview-*-8s.mp4`는 실제 iPhone 시뮬레이터 녹화에서 재생 속도를 바꾸지 않고 발췌한 영상입니다. 실제 길이는 크리스마스 7.933초, 한복·우주복 각각 8.000초입니다.
`runtime/final-*`은 실제 앱 캡처와 진단값입니다. 원본 전체 길이 녹화는 프로젝트 QA 폴더에 보존되어 있습니다.
`runtime-manifests/*-final.json`은 최종 앱 등록값이며, `implementation/`에는 새 공유 리그·검토 화면·테스트·에셋·제작 도구가 있습니다.
이 코드 묶음 자체가 독립적으로 빌드되는 전체 앱 프로젝트는 아닙니다.

검토 문서는 이전 실패 후보와 이후 수정 경과를 함께 기록합니다. 최종 선택은 `final-art-gate.md`를 기준으로 합니다.
`generation-prompts.json`에는 거절된 후보도 포함한 생성 이력이 있으며, 모든 과거 후보 파일을 이 ZIP에 넣지는 않았습니다.

현재는 단일 체형의 DEBUG 파일럿입니다. 성장 1–4단계, 나머지 10종, 기존 상점 전체 교체, 종합 성능 통과를 뜻하지 않습니다.
기존 원화와 미커밋 변경을 보존했고 커밋·푸시·배포하지 않았습니다.
''')
add(readme)

manifest = {'partCount': part_count, 'htmlDependenciesVerified': html_links, 'videos': video_info, 'files': []}
for name, p in sorted(selected.items()):
    manifest['files'].append({'path': name, 'bytes': p.stat().st_size, 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()})
manifest_path = qa / 'PACKAGE-MANIFEST.json'
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2))
add(manifest_path)

archive = qa / 'Pio-Outfit-Phase2.2-Review.zip'
assert not archive.exists(), 'Do not silently replace an existing review package'
with zipfile.ZipFile(archive, 'x', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as z:
    for name, p in sorted(selected.items()):
        z.write(p, name)
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    assert len(z.namelist()) == len(selected)
    for entry in manifest['files']:
        assert hashlib.sha256(z.read(entry['path'])).hexdigest() == entry['sha256']
result = {'zip': str(archive), 'bytes': archive.stat().st_size, 'sha256': hashlib.sha256(archive.read_bytes()).hexdigest(), 'files': len(selected), 'transparentParts': part_count, 'zipCRCAndSHA256': 'PASS', 'htmlLinks': 'PASS', 'threeApproximatelyEightSecondVideos': 'PASS'}
(qa / 'PACKAGE-VERIFICATION.json').write_text(json.dumps(result, indent=2))
print(json.dumps(result, indent=2))
