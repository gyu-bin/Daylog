#!/bin/zsh
# 지금 소스를 빌드해 이 Mac의 /Applications/Daylog.app을 바로 바꾸고, GitHub Release의 DMG도 맞춘다.
#
#   Tools/update.sh              빌드 → Developer ID 서명 → 실행 중인 Daylog 종료 → 교체 → 실행 → GitHub DMG 게시
#   Tools/update.sh --no-open    교체만 하고 실행하지 않는다
#   Tools/update.sh --no-publish GitHub에는 올리지 않고, 올라가 있는 DMG의 버전만 확인한다
#   Tools/update.sh --check-release
#                                빌드하지 않고, 설치된 앱의 버전과 GitHub Release의 DMG 버전만 비교한다
#
# 이 Mac의 앱은 공증 없이 바로 바꾼다(1~2분). 이 Mac에서 만든 앱은 격리 표시가 없어 공증 없이 열린다.
# 서명은 배포판과 같은 Developer ID로 한다: 그래야 iCloud의 Production 환경을 쓰고, 지금 쓰는 기록과 그대로 이어진다.
# (Tools/install.sh의 개발 서명은 Development 환경이라, 배포판으로 쓰던 저장소는 섞이지 않게 열리지 않는다.)
# 빌드 결과를 build/update에 남겨 두므로 두 번째부터는 바뀐 파일만 다시 컴파일한다.
#
# 교체가 끝나면 다른 Mac이 받는 GitHub Release의 DMG도 같은 소스로 맞춘다. 이쪽은 공증이 필요해 몇 분 더 걸린다
# (Tools/release.sh --skip-tests --publish --allow-unsigned-dmg). 다음 경우에는 올리지 않고 이유를 알려 준다:
# 커밋하지 않은 변경이 있을 때, 커밋을 아직 push하지 않았을 때, 올라가 있는 DMG 이후로 앱 소스가 바뀌지 않았을 때.
# 게시가 실패해도 이 Mac의 앱은 이미 바뀐 뒤다. 실패는 숨기지 않고 0이 아닌 값으로 끝낸다.
set -euo pipefail

cd "$(dirname "$0")/.."
BUNDLE_ID="com.mungyubin.daylog"
INSTALLED="${DAYLOG_INSTALL_DIR:-/Applications}/Daylog.app"
OUT="build/update"
ARCHIVE="$OUT/Daylog.xcarchive"
APP="$OUT/export/Daylog.app"

# 앱에 들어가는 소스. 여기가 바뀌지 않았으면 DMG를 다시 올리지 않는다.
APP_SOURCES=(Daylog DaylogShared DaylogWidgets Config Daylog.xcodeproj)

OPEN=1; PUBLISH=1; CHECK_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --no-open) OPEN=0 ;;
    --no-publish) PUBLISH=0 ;;
    --check-release) CHECK_ONLY=1 ;;
    *) echo "알 수 없는 옵션: $arg" >&2; exit 2 ;;
  esac
done

step() { echo; echo "▸ $1"; }
fail() { echo "✗ $1" >&2; exit 1; }

# GitHub Release의 최신 DMG가 이 버전과 같은지 알려 준다. 확인하지 못해도(오프라인, gh 없음) 실패로 치지 않는다.
check_release() {
  local version="$1"
  step "GitHub Release의 DMG 버전 확인"
  if ! command -v gh >/dev/null; then
    echo "· gh(GitHub CLI)가 없어 확인하지 못했습니다."
    return 0
  fi
  local latest assets
  latest=$(gh release view --json tagName -q .tagName 2>/dev/null) || latest=""
  if [[ -z "$latest" ]]; then
    echo "· GitHub Release를 읽지 못했습니다(네트워크나 로그인 상태를 확인하세요)."
    return 0
  fi
  assets=$(gh release view "$latest" --json assets -q '.assets[].name' 2>/dev/null | tr '\n' ' ')
  if [[ "$latest" == "v$version" ]]; then
    if [[ "$assets" == *"Daylog-v$version-macOS.dmg"* ]]; then
      echo "✓ GitHub 최신 릴리스도 $latest 입니다 (Daylog-v$version-macOS.dmg)."
    else
      echo "! GitHub 최신 릴리스는 $latest 인데 DMG(Daylog-v$version-macOS.dmg)가 없습니다. 올라간 파일: ${assets:-없음}"
    fi
    local built
    built=$(gh release view "$latest" --json body -q .body 2>/dev/null | sed -n 's/^빌드 기준 커밋: \([0-9a-f]*\).*/\1/p' | tail -1) || built=""
    if [[ -n "$built" ]] && git cat-file -e "$built^{commit}" 2>/dev/null; then
      if git diff --quiet "$built" HEAD -- $APP_SOURCES && [[ -z "$(git status --porcelain -- $APP_SOURCES)" ]]; then
        echo "  DMG는 $built 에서 만들었고, 그 뒤로 앱 소스는 바뀌지 않았습니다."
      else
        echo "! DMG는 $built 에서 만들었고, 그 뒤로 앱 소스가 바뀌었습니다. 다른 Mac은 이전 소스의 앱을 받습니다."
      fi
    else
      echo "  DMG를 어느 커밋으로 만들었는지 릴리스 설명에 없어, 지금 소스와 같은지는 확인하지 못했습니다."
    fi
  else
    echo "! GitHub 최신 릴리스는 $latest, 이 Mac의 앱은 v$version 입니다. 다른 Mac은 DMG로 설치하므로 $latest 그대로입니다."
    echo "  새 DMG를 올리려면: Tools/update.sh (자동 게시) 또는 Tools/release.sh --publish"
  fi
}

# GitHub Release의 DMG를 지금 소스로 맞춘다. 올릴 수 없거나 올릴 필요가 없으면 이유를 말하고 넘어간다.
publish_release() {
  local version="$1" tag="v$1" built
  step "GitHub Release에 DMG 게시"
  if ! command -v gh >/dev/null; then
    echo "· gh(GitHub CLI)가 없어 올리지 않았습니다."
    return 0
  fi
  if [[ -n "$(git status --porcelain)" ]]; then
    echo "· 커밋하지 않은 변경이 있어 올리지 않았습니다. 이 Mac의 앱에만 반영됐습니다. 커밋·push 뒤 다시 실행하면 올라갑니다."
    return 0
  fi
  if ! git branch -r --contains HEAD 2>/dev/null | grep -q .; then
    echo "· 아직 push하지 않은 커밋이라 올리지 않았습니다. git push 뒤 다시 실행하면 올라갑니다."
    return 0
  fi
  # 올라가 있는 DMG를 만든 커밋 이후로 앱 소스가 그대로면(문서·도구만 바뀜) 다시 올리지 않는다.
  built=$(gh release view "$tag" --json body -q .body 2>/dev/null | sed -n 's/^빌드 기준 커밋: \([0-9a-f]*\).*/\1/p' | tail -1) || built=""
  if [[ -n "$built" ]] && git cat-file -e "$built^{commit}" 2>/dev/null \
    && git diff --quiet "$built" HEAD -- $APP_SOURCES; then
    echo "✓ $tag 의 DMG($built)가 이미 지금 앱 소스와 같습니다. 다시 올리지 않았습니다."
    return 0
  fi
  echo "공증을 거쳐 올립니다. 몇 분 걸립니다."
  if Tools/release.sh --skip-tests --publish --allow-unsigned-dmg; then
    return 0
  fi
  echo "✗ GitHub 게시에 실패했습니다. 이 Mac의 앱은 이미 $version 으로 바뀌었고, GitHub의 DMG는 그대로입니다." >&2
  return 1
}

if [[ $CHECK_ONLY -eq 1 ]]; then
  [[ -d "$INSTALLED" ]] || fail "$INSTALLED 가 없습니다."
  check_release "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INSTALLED/Contents/Info.plist")"
  exit 0
fi

step "Release 아카이브"
rm -rf "$ARCHIVE" "$OUT/export"
mkdir -p "$OUT"
xcodebuild -project Daylog.xcodeproj -scheme Daylog -configuration Release -derivedDataPath "$OUT/derived" \
  -archivePath "$ARCHIVE" -allowProvisioningUpdates archive 2>&1 | grep -E " error: |ARCHIVE (SUCCEEDED|FAILED)" || true
[[ -d "$ARCHIVE" ]] || fail "아카이브에 실패했습니다."

step "Developer ID 서명 (공증 없음)"
cat > "$OUT/ExportOptions.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>developer-id</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>destination</key>
	<string>export</string>
</dict>
</plist>
PLIST
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$OUT/export" -exportOptionsPlist "$OUT/ExportOptions.plist" \
  -allowProvisioningUpdates 2>&1 | grep -E "error|EXPORT (SUCCEEDED|FAILED)" || true
[[ -d "$APP" ]] || fail "Developer ID 서명에 실패했습니다(Xcode에 Apple 개발자 계정이 로그인되어 있는지 확인하세요)."

step "앱 검증"
codesign --verify --deep --strict "$APP" || fail "codesign 검증 실패"
# 출력을 먼저 받아 둔다: pipefail에서 grep -q가 먼저 끝나면 codesign이 SIGPIPE로 실패한 것처럼 보인다.
SIGNATURE=$(codesign -dvv "$APP" 2>&1)
echo "$SIGNATURE" | grep -q "Authority=Developer ID Application" || fail "Developer ID 서명이 아닙니다."
ENTITLEMENTS=$(codesign -d --entitlements - --xml "$APP" 2>/dev/null | plutil -convert json -o - -)
echo "$ENTITLEMENTS" | grep -q '"com.apple.developer.icloud-container-environment":"Production"' \
  || fail "iCloud 환경이 Production이 아닙니다. 지금 쓰는 기록과 어긋나므로 교체하지 않습니다."
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")" == "$BUNDLE_ID" ]] || fail "번들 ID가 다릅니다."
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")
echo "✓ Daylog $VERSION, Developer ID 서명, iCloud Production"

# 저장소 하나를 두 버전이 동시에 열지 않게, 설치된 앱의 프로세스를 PID로 끝내고 사라진 것을 확인한다.
step "실행 중인 Daylog 종료"
for pid in $(pgrep -f "^$INSTALLED/Contents/MacOS/Daylog" || true); do
  osascript -l JavaScript -e "ObjC.import('AppKit'); \$.NSRunningApplication.runningApplicationWithProcessIdentifier($pid).terminate" >/dev/null
  for _ in {1..20}; do kill -0 "$pid" 2>/dev/null || break; sleep 0.5; done
  kill -0 "$pid" 2>/dev/null && fail "Daylog(pid $pid)가 종료되지 않았습니다. 직접 종료한 뒤 다시 실행하세요."
  echo "✓ pid $pid 종료"
done
pgrep -f "^$INSTALLED/Contents/MacOS/Daylog" >/dev/null && fail "Daylog가 아직 실행 중입니다."

step "교체"
if [[ -d "$INSTALLED" ]]; then
  # 직전 앱 하나만 되돌리기용으로 남긴다.
  rm -rf "$OUT/previous.app"
  mv "$INSTALLED" "$OUT/previous.app"
fi
ditto "$APP" "$INSTALLED"
codesign --verify --deep --strict "$INSTALLED" || fail "설치한 앱의 서명이 깨졌습니다. 되돌리려면: mv $OUT/previous.app $INSTALLED"
echo "✓ Daylog $VERSION 설치 완료 (직전 앱: $OUT/previous.app)"

if [[ $OPEN -eq 1 ]]; then
  step "실행"
  open "$INSTALLED"
  # 공증하지 않은 앱이라, 실제로 떠서 살아 있는지 확인한다.
  sleep 5
  pgrep -f "^$INSTALLED/Contents/MacOS/Daylog" >/dev/null \
    || fail "Daylog가 실행되지 않았습니다. 되돌리려면: rm -rf $INSTALLED && mv $OUT/previous.app $INSTALLED (또는 Tools/release.sh로 공증 빌드)"
  echo "✓ 실행 중"
fi

PUBLISH_FAILED=0
if [[ $PUBLISH -eq 1 ]]; then
  publish_release "$VERSION" || PUBLISH_FAILED=1
fi
check_release "$VERSION"
[[ $PUBLISH_FAILED -eq 0 ]] || exit 3
