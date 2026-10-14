#!/bin/zsh
# iPhone·iPad의 원격 UI 설정(RemoteConfig/mobile-ui.json)을 검사하고, 비교하고, 게시하고, 되돌린다.
#
#   Tools/mobile-config.sh validate [--dev]            형식·허용값·버전·앱 호환성을 검사한다
#   Tools/mobile-config.sh preview  [--dev]            지금 게시된 설정과 이 파일의 차이를 보여 준다
#   Tools/mobile-config.sh status   [--dev]            지금 게시된 설정의 버전과 주소
#   Tools/mobile-config.sh publish  [--dev] --confirm <configVersion>
#                                                      검사한 설정을 게시한다
#   Tools/mobile-config.sh rollback [--dev] --to <configVersion> --confirm <configVersion>
#                                                      전에 게시한 버전의 내용으로 되돌린다(새 버전 번호로 다시 게시)
#
# 채널
# - Production(기본): RemoteConfig/mobile-ui.json → 릴리스 mobile-config의 mobile-ui.json. TestFlight·App Store 빌드가 본다.
# - Development(--dev): RemoteConfig/mobile-ui.dev.json → 릴리스 mobile-config-dev. Debug 빌드만 본다.
# 파일을 고쳐 git push 하는 것만으로는 아무에게도 적용되지 않는다. publish를 실행해야 바뀐다.
#
# publish와 rollback은 실제 사용자의 화면을 바꾼다. 사용자 승인 없이 실행하지 않는다.
# 실수로 실행하지 않도록, 게시할 configVersion을 --confirm으로 한 번 더 적어야 한다.
# 게시한 설정은 mobile-ui-v<버전>.json으로도 남겨 두어 되돌릴 때 쓴다.
# 설정용 릴리스는 "사전 출시"로 둔다: Mac 앱의 업데이트 피드(…/releases/latest/…)가 가리키는 최신 릴리스가 되지 않게.
set -euo pipefail

cd "$(dirname "$0")/.."
REPO_URL="https://github.com/gyu-bin/Daylog"
COMMAND="${1:-}"; [[ $# -gt 0 ]] && shift
DEV=0; CONFIRM=""; TO=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dev) DEV=1 ;;
    --confirm) CONFIRM="${2:-}"; shift ;;
    --to) TO="${2:-}"; shift ;;
    *) echo "알 수 없는 옵션: $1" >&2; exit 2 ;;
  esac
  shift
done
if [[ $DEV -eq 1 ]]; then
  FILE="RemoteConfig/mobile-ui.dev.json"; TAG="mobile-config-dev"; CHANNEL="Development"
else
  FILE="RemoteConfig/mobile-ui.json"; TAG="mobile-config"; CHANNEL="Production"
fi
URL="$REPO_URL/releases/download/$TAG/mobile-ui.json"

step() { echo; echo "▸ $1"; }
fail() { echo "✗ $1" >&2; exit 1; }

# 파일을 엄격하게 검사한다(모르는 칸, 허용 목록 밖의 값, 범위 밖의 숫자, 너무 긴 문구는 모두 오류).
# 앱은 틀린 칸을 조용히 버리지만, 게시 전에는 틀린 칸이 하나도 없어야 한다. 규칙은 MobileUIConfig.swift와 같다.
validate_file() {  # <파일> → configVersion을 출력
  /usr/bin/python3 - "$1" "$(ios_build)" <<'PY'
import json, sys, re, unicodedata
path, ios_build = sys.argv[1], int(sys.argv[2])
raw = open(path, "rb").read()
errors = []
if len(raw) > 64 * 1024: errors.append("파일이 64KB를 넘습니다")
try:
    cfg = json.loads(raw.decode("utf-8"))
except Exception as e:
    sys.exit("JSON이 아닙니다: %s" % e)
if not isinstance(cfg, dict): sys.exit("최상위가 객체가 아닙니다")

CARDS = ["summary", "nextRoutine", "vacation", "routines", "meals", "achievement", "recentDays", "tomorrow", "calendar", "trend", "routineRates"]
# 나중에 생긴 카드. 순서에 적지 않아도 된다(앱이 내장 순서의 자리에 끼워 넣는다). 적으면 이 카드를 모르는 예전 앱은 건너뛴다.
OPTIONAL_CARDS = ["weeklyGrowth", "saessagiGrowth", "weeklyReview"]
ACCENTS = ["mint", "green", "blue", "purple", "coral", "orange"]
CARD_STYLES = ["bordered", "soft", "flat"]
LAYOUTS = ["standard", "compact", "airy"]
FEATURES = ["greetingIcon", "onboardingNotificationGuide"]
TEXT = {"onboarding": {"introTitle": 24, "notificationTitle": 24, "notificationBody": 40},
        "dashboard": {"greeting": 24},
        "emptyStates": {"noRoutinesToday": 40, "noRoutinesYet": 40}}

def only(obj, allowed, where):
    for key in obj:
        if key not in allowed: errors.append("%s: 모르는 칸 '%s'" % (where, key))

only(cfg, ["schemaVersion", "configVersion", "minimumSupportedAppBuild", "updatedAt", "dashboard", "appearance", "content", "features", "splash"], "최상위")
def integer(key, minimum=1):
    value = cfg.get(key)
    if type(value) is not int or value < minimum: errors.append("%s: %d 이상의 정수여야 합니다" % (key, minimum))
    return value if type(value) is int else 0
if cfg.get("schemaVersion") != 1: errors.append("schemaVersion: 1이어야 합니다")
version = integer("configVersion")
minimum_build = integer("minimumSupportedAppBuild")
if minimum_build > ios_build:
    errors.append("minimumSupportedAppBuild(%d)가 지금 iOS 빌드 번호(%d)보다 큽니다: 이 설정을 읽을 수 있는 앱이 없습니다" % (minimum_build, ios_build))
updated = cfg.get("updatedAt")
if not isinstance(updated, str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z", updated):
    errors.append("updatedAt: 2026-10-12T12:00:00Z 같은 모양이어야 합니다")

dashboard = cfg.get("dashboard", {})
if not isinstance(dashboard, dict): errors.append("dashboard: 객체여야 합니다"); dashboard = {}
only(dashboard, ["defaultCardOrder", "defaultHiddenCards", "layoutStyle", "cardSpacing", "cardPadding"], "dashboard")
order = dashboard.get("defaultCardOrder")
if order is not None:
    required = [c for c in order if c not in OPTIONAL_CARDS] if isinstance(order, list) else None
    if required is None or sorted(required) != sorted(CARDS) or len(set(order)) != len(order):
        errors.append("dashboard.defaultCardOrder: 카드 %d개를 한 번씩 모두 적어야 합니다(%s). 선택: %s" % (len(CARDS), ", ".join(CARDS), ", ".join(OPTIONAL_CARDS)))
hidden = dashboard.get("defaultHiddenCards")
if hidden is not None:
    if not isinstance(hidden, list) or len(set(hidden)) != len(hidden) or any(c not in CARDS + OPTIONAL_CARDS for c in hidden):
        errors.append("dashboard.defaultHiddenCards: 아는 카드만, 한 번씩 적어야 합니다")
    elif "routines" in hidden:
        errors.append("dashboard.defaultHiddenCards: routines 카드는 숨길 수 없습니다")
if "layoutStyle" in dashboard and dashboard["layoutStyle"] not in LAYOUTS:
    errors.append("dashboard.layoutStyle: %s 중 하나여야 합니다" % ", ".join(LAYOUTS))
for key, low, high in (("cardSpacing", 8, 24), ("cardPadding", 10, 24)):
    if key in dashboard:
        value = dashboard[key]
        if type(value) not in (int, float) or not (low <= value <= high):
            errors.append("dashboard.%s: %d~%d 사이의 숫자여야 합니다" % (key, low, high))

appearance = cfg.get("appearance", {})
if not isinstance(appearance, dict): errors.append("appearance: 객체여야 합니다"); appearance = {}
only(appearance, ["accent", "cardStyle"], "appearance")
if "accent" in appearance and appearance["accent"] not in ACCENTS:
    errors.append("appearance.accent: %s 중 하나여야 합니다" % ", ".join(ACCENTS))
if "cardStyle" in appearance and appearance["cardStyle"] not in CARD_STYLES:
    errors.append("appearance.cardStyle: %s 중 하나여야 합니다" % ", ".join(CARD_STYLES))

content = cfg.get("content", {})
if not isinstance(content, dict): errors.append("content: 객체여야 합니다"); content = {}
only(content, list(TEXT), "content")
for group, keys in TEXT.items():
    values = content.get(group, {})
    if not isinstance(values, dict): errors.append("content.%s: 객체여야 합니다" % group); continue
    only(values, list(keys), "content.%s" % group)
    for key, limit in keys.items():
        if key not in values: continue
        text = values[key]
        where = "content.%s.%s" % (group, key)
        if not isinstance(text, str) or not text.strip(): errors.append("%s: 비어 있지 않은 글이어야 합니다" % where); continue
        if text != text.strip(): errors.append("%s: 앞뒤 공백을 빼 주세요" % where)
        if len(text) > limit: errors.append("%s: %d자를 넘습니다(%d자)" % (where, limit, len(text)))
        if any(unicodedata.category(ch) in ("Cc", "Cf", "Zl", "Zp") for ch in text): errors.append("%s: 줄바꿈·제어 문자를 쓸 수 없습니다" % where)

splash = cfg.get("splash", {})
if not isinstance(splash, dict): errors.append("splash: 객체여야 합니다"); splash = {}
only(splash, ["duration"], "splash")
if "duration" in splash:
    value = splash["duration"]
    if type(value) not in (int, float) or not (0.5 <= value <= 2.0):
        errors.append("splash.duration: 0.5~2.0 사이의 숫자(초)여야 합니다")

features = cfg.get("features", {})
if not isinstance(features, dict): errors.append("features: 객체여야 합니다"); features = {}
only(features, FEATURES, "features")
for key, value in features.items():
    if type(value) is not bool: errors.append("features.%s: true 또는 false여야 합니다" % key)

if errors:
    sys.exit("\n".join("  - " + e for e in errors))
print(version)
PY
}

# 지금 프로젝트의 iOS 빌드 번호(이 번호 이하의 앱이 설정을 읽는다).
ios_build() {
  /usr/bin/python3 - <<'PY'
import re
text = open("Daylog.xcodeproj/project.pbxproj").read()
builds = []
for block in re.findall(r"isa = XCBuildConfiguration;.*?\n\t\t\};", text, re.S):
    if re.search(r"PRODUCT_BUNDLE_IDENTIFIER = com\.mungyubin\.daylog\.ios;", block):
        m = re.search(r"CURRENT_PROJECT_VERSION = (\d+);", block)
        if m: builds.append(int(m.group(1)))
print(max(builds) if builds else 0)
PY
}

# 지금 게시된 설정을 받아 온다(없으면 빈 파일). 릴리스 자산을 직접 받는다.
fetch_published() {  # <받을 파일>
  : > "$1"
  curl -fsSL "$URL?t=$(date +%s)" -o "$1" 2>/dev/null || : > "$1"
}

published_version() {  # <파일>
  [[ -s "$1" ]] && /usr/bin/python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('configVersion', 0))" "$1" 2>/dev/null || echo 0
}

do_validate() {
  [[ -f "$FILE" ]] || fail "$FILE 이 없습니다."
  local version
  version=$(validate_file "$FILE") || fail "$FILE 검사 실패"
  echo "✓ $FILE: 형식·허용값 통과 (configVersion $version, $CHANNEL)"
  VERSION="$version"
}

upload() {  # 게시: 릴리스가 없으면 사전 출시로 만들고, 현재 설정과 버전별 사본을 올린 뒤 공개 주소에서 확인한다.
  local file="$1" version="$2" work
  work=$(mktemp -d)
  cp "$file" "$work/mobile-ui.json"
  cp "$file" "$work/mobile-ui-v$version.json"
  if ! gh release view "$TAG" >/dev/null 2>&1; then
    gh release create "$TAG" --prerelease --latest=false --title "Daylog mobile UI config ($CHANNEL)" \
      --notes "iPhone·iPad 앱이 받는 UI 설정 파일입니다(앱 설치 파일이 아닙니다). 관리: Tools/mobile-config.sh, 문서: docs/MOBILE_OTA.md" \
      --target "$(git rev-parse HEAD)" >/dev/null || fail "설정용 릴리스($TAG)를 만들지 못했습니다."
  fi
  # 버전별 사본을 먼저 올린다(되돌릴 근거). 그다음에 앱이 보는 파일을 바꾼다.
  gh release upload "$TAG" "$work/mobile-ui-v$version.json" --clobber >/dev/null || fail "버전별 사본을 올리지 못했습니다."
  gh release upload "$TAG" "$work/mobile-ui.json" --clobber >/dev/null || fail "설정 파일을 올리지 못했습니다."
  local attempt
  for attempt in {1..20}; do
    curl -fsSL "$URL?t=$(date +%s)" 2>/dev/null | cmp -s - "$work/mobile-ui.json" && { rm -rf "$work"; echo "✓ 공개 주소 확인: $URL"; break; }
    [[ $attempt -eq 20 ]] && fail "올렸지만 공개 주소의 내용이 아직 다릅니다. 잠시 뒤 status로 확인하세요."
    sleep 3
  done
  # Mac 앱의 업데이트 피드가 보는 '최신 릴리스'가 설정용 릴리스로 바뀌지 않았는지 확인한다.
  local latest
  latest=$(gh release view --json tagName -q .tagName 2>/dev/null || true)
  [[ "$latest" == v* ]] || fail "최신 릴리스가 앱 릴리스가 아닙니다($latest). GitHub에서 $TAG 를 사전 출시로 되돌리세요."
  echo "✓ 최신 앱 릴리스는 그대로 $latest"
}

case "$COMMAND" in
validate)
  do_validate
  ;;
status)
  TMP=$(mktemp); fetch_published "$TMP"
  if [[ -s "$TMP" ]]; then
    echo "$CHANNEL: configVersion $(published_version "$TMP") 게시됨"
  else
    echo "$CHANNEL: 아직 게시된 설정이 없습니다(앱은 내장 기본값을 씁니다)."
  fi
  echo "주소: $URL"
  rm -f "$TMP"
  ;;
preview)
  do_validate
  TMP=$(mktemp); fetch_published "$TMP"
  step "$CHANNEL 에 게시된 설정과 $FILE 의 차이"
  if [[ ! -s "$TMP" ]]; then
    echo "아직 게시된 설정이 없습니다. 게시하면 아래 내용이 처음으로 올라갑니다."
    /usr/bin/python3 -m json.tool --no-ensure-ascii "$FILE"
  elif cmp -s "$TMP" "$FILE"; then
    echo "차이가 없습니다(게시된 것과 같습니다)."
  else
    /usr/bin/python3 -m json.tool --no-ensure-ascii --sort-keys "$TMP" > "$TMP.a"
    /usr/bin/python3 -m json.tool --no-ensure-ascii --sort-keys "$FILE" > "$TMP.b"
    diff -u --label "게시됨 (v$(published_version "$TMP"))" --label "$FILE (v$VERSION)" "$TMP.a" "$TMP.b" || true
    rm -f "$TMP.a" "$TMP.b"
  fi
  rm -f "$TMP"
  ;;
publish)
  do_validate
  command -v gh >/dev/null || fail "gh(GitHub CLI)가 없습니다."
  [[ "$CONFIRM" == "$VERSION" ]] || fail "게시하려면 --confirm $VERSION 을 붙이세요(사용자 승인을 받은 뒤에만)."
  if [[ $DEV -eq 0 ]]; then
    # Production은 커밋·push된 파일만 올린다(무엇을 언제 올렸는지 Git에 남게).
    [[ -z "$(git status --porcelain -- "$FILE")" ]] || fail "$FILE 에 커밋하지 않은 변경이 있습니다."
    git diff --quiet "@{upstream}" HEAD -- "$FILE" 2>/dev/null || fail "$FILE 의 변경을 아직 push하지 않았습니다."
  fi
  TMP=$(mktemp); fetch_published "$TMP"
  CURRENT=$(published_version "$TMP")
  if [[ -s "$TMP" ]] && cmp -s "$TMP" "$FILE"; then rm -f "$TMP"; echo "✓ 이미 같은 내용이 게시돼 있습니다(v$CURRENT)."; exit 0; fi
  rm -f "$TMP"
  [[ "$VERSION" -gt "$CURRENT" ]] || fail "configVersion($VERSION)은 게시된 버전($CURRENT)보다 커야 합니다."
  step "$CHANNEL 게시: v$CURRENT → v$VERSION"
  upload "$FILE" "$VERSION"
  echo "✓ 게시 완료. 앱은 다음에 열릴 때(확인 간격 1시간) 받아서 그다음 실행부터 적용합니다."
  ;;
rollback)
  command -v gh >/dev/null || fail "gh(GitHub CLI)가 없습니다."
  [[ "$TO" == <-> ]] || fail "되돌릴 버전을 --to <configVersion> 으로 적으세요."
  TMP=$(mktemp); fetch_published "$TMP"
  CURRENT=$(published_version "$TMP"); rm -f "$TMP"
  [[ "$CURRENT" -gt 0 ]] || fail "게시된 설정이 없습니다."
  [[ "$TO" -lt "$CURRENT" ]] || fail "--to 는 지금 게시된 버전($CURRENT)보다 작아야 합니다."
  NEXT=$((CURRENT + 1))
  WORK=$(mktemp -d)
  curl -fsSL "$REPO_URL/releases/download/$TAG/mobile-ui-v$TO.json" -o "$WORK/old.json" 2>/dev/null \
    || fail "v$TO 의 사본(mobile-ui-v$TO.json)이 게시된 적이 없습니다."
  # 옛 내용을 새 버전 번호로 다시 게시한다(번호는 늘 올라간다).
  /usr/bin/python3 - "$WORK/old.json" "$FILE" "$NEXT" <<'PY'
import json, sys, datetime
old, out, version = sys.argv[1], sys.argv[2], int(sys.argv[3])
cfg = json.load(open(old))
cfg["configVersion"] = version
cfg["updatedAt"] = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
open(out, "w").write(json.dumps(cfg, ensure_ascii=False, indent=2) + "\n")
PY
  rm -rf "$WORK"
  VERSION=$(validate_file "$FILE") || fail "되돌린 내용이 검사를 통과하지 못했습니다($FILE 을 확인하세요)."
  echo "$FILE 을 v$TO 의 내용(새 번호 v$VERSION)으로 바꿨습니다."
  [[ "$CONFIRM" == "$VERSION" ]] || fail "게시하려면 --confirm $VERSION 을 붙여 다시 실행하세요(사용자 승인을 받은 뒤에만). 파일은 이미 바뀌어 있습니다."
  step "$CHANNEL 되돌리기: v$CURRENT → v$VERSION (v$TO 의 내용)"
  upload "$FILE" "$VERSION"
  echo "✓ 되돌렸습니다. $FILE 의 변경을 커밋·push해 Git에도 남기세요."
  ;;
*)
  echo "사용법: Tools/mobile-config.sh validate|preview|status|publish|rollback [--dev] [--to N] [--confirm N]" >&2; exit 2 ;;
esac
