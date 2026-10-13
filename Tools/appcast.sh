#!/bin/zsh
# Sparkle appcast를 만들고 검사한다. Tools/release.sh와 Tools/update-test.sh가 함께 쓴다.
#
#   Tools/appcast.sh <DMG> <릴리스 노트.md> <출력 폴더> <다운로드 URL 접두사> [이전 appcast.xml]
#   Tools/appcast.sh --check <같은 인자>     다시 만들지 않고, 출력 폴더에 이미 있는 appcast.xml을 검사만 한다
#
# - DMG와 릴리스 노트를 출력 폴더에 복사하고 Sparkle의 generate_appcast로 appcast.xml을 만든다.
# - 이전 appcast.xml을 주면 그 항목들을 그대로 두고 새 항목을 더한다(과거 버전의 앱도 따라올 수 있게).
# - 서명은 Sparkle의 EdDSA 개인 키로 한다. 키는 로그인 키체인에서 읽는다(Sparkle의 generate_keys가 넣어 둔 것).
#   DAYLOG_SPARKLE_KEY_FILE이 있으면 그 파일의 키를 쓴다(격리 시험용). 개인 키는 저장소에 넣지 않는다.
# - 만든 뒤 새 항목의 버전·빌드 번호·URL·파일 크기·서명을 DMG와 대조한다. 하나라도 어긋나면 실패한다.
# - 이전 appcast.xml을 주면 그 항목들이 하나도 빠지거나 바뀌지 않았는지도 본다.
# - --check: 이미 만들어 확인한 appcast를 게시 직전에 다시 만들지 않기 위한 것이다. 다시 만들면 게시 시각(pubDate)이 달라지고,
#   그때 이전 피드를 받지 못하면 과거 항목이 빠진 채로 만들어질 수 있다.
set -euo pipefail

CHECK=0
[[ "${1:-}" == "--check" ]] && { CHECK=1; shift; }
[[ $# -ge 4 ]] || { echo "사용법: Tools/appcast.sh <DMG> <노트.md> <출력 폴더> <URL 접두사> [이전 appcast.xml]" >&2; exit 2; }
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DMG="$1"; NOTES="$2"; OUT="$3"; PREFIX="${4%/}/"; PREVIOUS="${5:-}"
fail() { echo "✗ $1" >&2; exit 1; }

[[ -f "$DMG" ]] || fail "$DMG 가 없습니다."
[[ -s "$NOTES" ]] || fail "릴리스 노트($NOTES)가 없거나 비어 있습니다."

# Sparkle의 도구는 패키지를 받은 빌드 폴더 안에 있다.
BIN=""
for candidate in "$ROOT"/build/*/derived/SourcePackages/artifacts/sparkle/Sparkle/bin "$ROOT"/build*/SourcePackages/artifacts/sparkle/Sparkle/bin; do
  [[ -x "$candidate/generate_appcast" ]] && { BIN="$candidate"; break; }
done
[[ -n "$BIN" ]] || fail "Sparkle 도구(generate_appcast)를 찾지 못했습니다. 먼저 한 번 빌드하세요."

KEY_ARGS=()
if [[ -n "${DAYLOG_SPARKLE_KEY_FILE:-}" ]]; then
  [[ -f "$DAYLOG_SPARKLE_KEY_FILE" ]] || fail "DAYLOG_SPARKLE_KEY_FILE($DAYLOG_SPARKLE_KEY_FILE)이 없습니다."
  KEY_ARGS=(--ed-key-file "$DAYLOG_SPARKLE_KEY_FILE")
fi

NAME="$(basename "$DMG")"
if [[ $CHECK -eq 1 ]]; then
  [[ -s "$OUT/appcast.xml" ]] || fail "검사할 appcast($OUT/appcast.xml)가 없습니다."
  # 서명한 대상이 지금 올리려는 DMG와 같은 파일인지.
  cmp -s "$DMG" "$OUT/$NAME" || fail "appcast를 만들 때 쓴 DMG($OUT/$NAME)가 지금의 DMG와 다릅니다. Tools/release.sh 로 다시 만드세요."
else
  rm -rf "$OUT"; mkdir -p "$OUT"
  cp "$DMG" "$OUT/$NAME"
  cp "$NOTES" "$OUT/${NAME%.dmg}.md"
  [[ -n "$PREVIOUS" && -s "$PREVIOUS" ]] && cp "$PREVIOUS" "$OUT/appcast.xml"

  # 델타는 만들지 않는다(이전 DMG를 두지 않는다). 과거 항목은 넉넉히 남긴다.
  "$BIN/generate_appcast" "${KEY_ARGS[@]}" --download-url-prefix "$PREFIX" --embed-release-notes \
    --link "https://github.com/gyu-bin/Daylog/releases" --maximum-versions 10 --maximum-deltas 0 "$OUT" </dev/null \
    || fail "appcast를 만들지 못했습니다(Sparkle 서명 키를 확인하세요)."
  [[ -s "$OUT/appcast.xml" ]] || fail "appcast.xml이 만들어지지 않았습니다."
fi

# DMG 안 앱의 버전·빌드 번호를 읽어 appcast의 새 항목과 대조한다.
MOUNT=$(mktemp -d)
hdiutil attach "$DMG" -nobrowse -readonly -mountpoint "$MOUNT" >/dev/null 2>&1 || fail "DMG를 열지 못했습니다."
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$MOUNT/Daylog.app/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$MOUNT/Daylog.app/Contents/Info.plist")
hdiutil detach "$MOUNT" >/dev/null 2>&1 || true
rmdir "$MOUNT" 2>/dev/null || true

SIGNATURE=$(/usr/bin/python3 - "$OUT/appcast.xml" "$VERSION" "$BUILD" "$PREFIX$NAME" "$(stat -f %z "$DMG")" "$PREVIOUS" <<'PY'
import os, sys, xml.etree.ElementTree as ET
path, version, build, url, length, previous = sys.argv[1:7]
ns = {"sparkle": "http://www.andymatuschak.org/xml-namespaces/sparkle"}
S = "{%s}" % ns["sparkle"]
items = ET.parse(path).getroot().findall("./channel/item")
def text(item, tag):
    node = item.find("sparkle:" + tag, ns)
    return node.text.strip() if node is not None and node.text else ""
matches = [i for i in items if text(i, "version") == build]
if len(matches) != 1:
    sys.exit("appcast에 빌드 %s 항목이 %d개입니다(1개여야 합니다)." % (build, len(matches)))
item = matches[0]
enclosure = item.find("enclosure")
problems = []
if text(item, "shortVersionString") != version: problems.append("버전이 %s가 아닙니다" % version)
if enclosure is None: sys.exit("enclosure가 없습니다.")
if enclosure.get("url") != url: problems.append("URL이 %s가 아닙니다: %s" % (url, enclosure.get("url")))
if enclosure.get("length") != length: problems.append("파일 크기가 %s가 아닙니다: %s" % (length, enclosure.get("length")))
signature = enclosure.get(S + "edSignature") or ""
if not signature: problems.append("EdDSA 서명이 없습니다")
if not (item.findtext("description") or "").strip(): problems.append("릴리스 노트가 비어 있습니다")
builds = [text(i, "version") for i in items]
if len(set(builds)) != len(builds): problems.append("같은 빌드 번호가 두 번 들어 있습니다")
if any(b.isdigit() and int(b) > int(build) for b in builds if b != build): problems.append("이보다 높은 빌드 번호가 이미 있습니다")
# 지금 공개된 피드의 항목은 하나도 빠지거나 바뀌면 안 된다(과거 버전의 앱이 보는 항목이다).
# 항목 전체를 비교한다: 태그, 속성, 글자, 자식의 순서까지. 줄바꿈·들여쓰기 같은 서식만 무시한다.
# (URL·크기·서명만 보면 최소 macOS 버전이나 릴리스 노트가 바뀐 것을 놓친다.)
if previous and os.path.getsize(previous) > 0:
    def key(node):
        return (node.tag, tuple(sorted(node.attrib.items())), (node.text or "").strip(), tuple(key(child) for child in node))
    now = {text(i, "version"): key(i) for i in items}
    for old in ET.parse(previous).getroot().findall("./channel/item"):
        old_build = text(old, "version")
        if old_build == build: problems.append("빌드 %s는 이미 공개된 피드에 있습니다" % build)
        elif old_build not in now: problems.append("공개된 피드의 빌드 %s 항목이 빠졌습니다" % old_build)
        elif now[old_build] != key(old): problems.append("공개된 피드의 빌드 %s 항목이 바뀌었습니다" % old_build)
if problems: sys.exit("; ".join(problems))
print(signature)
PY
) || fail "appcast 검사 실패: 위 내용을 확인하세요."

# 서명이 실제로 이 DMG의 것인지 Sparkle 도구로 다시 확인한다.
# 입력을 닫아 둔다: 키체인의 키로 검증할 때 표준 입력을 기다리며 멈추는 일이 있었다.
"$BIN/sign_update" "${KEY_ARGS[@]}" --verify "$OUT/$NAME" "$SIGNATURE" </dev/null >/dev/null 2>&1 \
  || fail "appcast의 EdDSA 서명이 DMG와 맞지 않습니다."

echo "✓ appcast: Daylog $VERSION ($BUILD) → $PREFIX$NAME"
echo "  $OUT/appcast.xml"
