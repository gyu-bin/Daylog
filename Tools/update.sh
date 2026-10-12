#!/bin/zsh
# 지금 소스를 빌드해 이 Mac의 /Applications/Daylog.app을 바로 바꾼다. 공증과 DMG는 건너뛴다.
#
#   Tools/update.sh              빌드 → Developer ID 서명 → 실행 중인 Daylog 종료 → 교체 → 실행
#   Tools/update.sh --no-open    교체만 하고 실행하지 않는다
#   Tools/update.sh --check-release
#                                빌드하지 않고, 설치된 앱의 버전과 GitHub Release의 DMG 버전만 비교한다
#
# 교체가 끝나면 GitHub Release에 올라가 있는 DMG의 버전도 확인해 알려 준다(다르다고 멈추지는 않는다).
# 다른 Mac은 그 DMG로 설치하므로, 버전이 뒤처져 있으면 Tools/release.sh로 새 DMG를 올릴 때다.
#
# 공증은 다른 Mac에 나눠 줄 때만 필요하다(Tools/release.sh). 이 Mac에서 만든 앱은 격리 표시가 없어 공증 없이 열린다.
# 서명은 배포판과 같은 Developer ID로 한다: 그래야 iCloud의 Production 환경을 쓰고, 지금 쓰는 기록과 그대로 이어진다.
# (Tools/install.sh의 개발 서명은 Development 환경이라, 배포판으로 쓰던 저장소는 섞이지 않게 열리지 않는다.)
# 빌드 결과를 build/update에 남겨 두므로 두 번째부터는 바뀐 파일만 다시 컴파일한다.
set -euo pipefail

cd "$(dirname "$0")/.."
BUNDLE_ID="com.mungyubin.daylog"
INSTALLED="${DAYLOG_INSTALL_DIR:-/Applications}/Daylog.app"
OUT="build/update"
ARCHIVE="$OUT/Daylog.xcarchive"
APP="$OUT/export/Daylog.app"

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
    echo "  같은 버전이어도 이 Mac의 앱은 방금 빌드한 최신 소스이고, DMG는 릴리스 당시의 소스입니다."
  else
    echo "! GitHub 최신 릴리스는 $latest, 이 Mac의 앱은 v$version 입니다. 다른 Mac은 DMG로 설치하므로 $latest 그대로입니다."
    echo "  새 DMG를 올리려면: Tools/release.sh (공증 빌드) → Tools/release.sh --publish-only"
  fi
}

if [[ "${1:-}" == "--check-release" ]]; then
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

if [[ "${1:-}" == "--no-open" ]]; then
  check_release "$VERSION"
  exit 0
fi

step "실행"
open "$INSTALLED"
# 공증하지 않은 앱이라, 실제로 떠서 살아 있는지 확인한다.
sleep 5
pgrep -f "^$INSTALLED/Contents/MacOS/Daylog" >/dev/null \
  || fail "Daylog가 실행되지 않았습니다. 되돌리려면: rm -rf $INSTALLED && mv $OUT/previous.app $INSTALLED (또는 Tools/release.sh로 공증 빌드)"
echo "✓ 실행 중"

check_release "$VERSION"
