#!/bin/zsh
# Mac 앱의 버전을 올린다. iPhone·iPad 앱과 위젯의 버전은 건드리지 않는다.
#
#   Tools/bump-version.sh            지금의 Mac 버전과 빌드 번호를 출력한다("1.5.1 1")
#   Tools/bump-version.sh 1.5.2      버전을 1.5.2로 바꾸고 빌드 번호를 1 올린다
#
# 앱 안의 업데이트(Sparkle)는 빌드 번호가 커져야 새 버전으로 본다. 그래서 릴리스마다 이 스크립트로 올린다.
# 릴리스 노트 파일(docs/releases/v<버전>.md)이 없으면 빈 틀을 만든다. 내용을 채운 뒤 커밋한다.
set -euo pipefail
cd "$(dirname "$0")/.."

/usr/bin/python3 - "${1:-}" <<'PY'
import re, sys, pathlib
new_version = sys.argv[1]
path = pathlib.Path("Daylog.xcodeproj/project.pbxproj")
text = path.read_text()
MAC_IDS = {"com.mungyubin.daylog", "com.mungyubin.daylog.tests"}
pattern = re.compile(r"(\t\t\w+ /\* \w+ \*/ = \{\n\t\t\tisa = XCBuildConfiguration;.*?\n\t\t\};)", re.S)
versions, builds = set(), set()
def field(block, key):
    m = re.search(key + r" = ([^;]+);", block)
    return m.group(1).strip('"') if m else None
def rewrite(match):
    block = match.group(1)
    if field(block, "PRODUCT_BUNDLE_IDENTIFIER") not in MAC_IDS:
        return block
    versions.add(field(block, "MARKETING_VERSION")); builds.add(field(block, "CURRENT_PROJECT_VERSION"))
    if not new_version:
        return block
    block = re.sub(r"MARKETING_VERSION = [^;]+;", "MARKETING_VERSION = %s;" % new_version, block)
    return re.sub(r"CURRENT_PROJECT_VERSION = [^;]+;", lambda m: "CURRENT_PROJECT_VERSION = %d;" % (int(field(block, "CURRENT_PROJECT_VERSION")) + 1), block)
updated = pattern.sub(rewrite, text)
if len(versions) != 1 or len(builds) != 1 or None in versions | builds:
    sys.exit("Mac 설정의 버전·빌드 번호가 서로 다르거나 읽히지 않습니다: %s / %s" % (versions, builds))
version, build = versions.pop(), int(builds.pop())
if not new_version:
    print(version, build); sys.exit(0)
if not re.fullmatch(r"\d+\.\d+\.\d+", new_version):
    sys.exit("버전은 1.5.2 같은 모양이어야 합니다.")
if tuple(map(int, new_version.split("."))) <= tuple(map(int, version.split("."))):
    sys.exit("새 버전(%s)은 지금 버전(%s)보다 커야 합니다." % (new_version, version))
path.write_text(updated)
notes = pathlib.Path("docs/releases/v%s.md" % new_version)
if not notes.exists():
    notes.parent.mkdir(parents=True, exist_ok=True)
    notes.write_text("## Daylog %s\n\n- (달라진 점을 적어 주세요. 이 내용이 앱의 업데이트 창과 GitHub 릴리스에 그대로 나옵니다.)\n" % new_version)
    print("릴리스 노트 틀: %s" % notes)
print("Mac: %s (%d) → %s (%d)" % (version, build, new_version, build + 1))
PY
