#!/bin/zsh
# 앱 안의 업데이트(Sparkle)를 실제 앱·기록·GitHub와 분리해 처음부터 끝까지 시험한다.
#
#   Tools/update-test.sh prepare   옛 버전과 새 버전의 검증용 앱을 만들고, 새 버전의 DMG와 appcast를 만든다
#   Tools/update-test.sh serve     이 Mac에서만 보이는 시험용 피드를 띄운다(127.0.0.1)
#   Tools/update-test.sh launch    옛 버전을 시험용 폴더에 놓고 실행한다
#   Tools/update-test.sh script "<명령…;quit>"
#                                  시험용 번들의 Debug 빌드로 검증 스크립트를 돌려 기록을 넣거나 읽는다
#   Tools/update-test.sh status    시험용 폴더에 있는 앱의 버전과 실행 여부
#   Tools/update-test.sh stop      시험용 앱과 피드를 끝낸다
#   Tools/update-test.sh clean     시험용 앱·빌드·시험 전용 키를 지운다
#
# - 번들 ID는 시험 전용(com.daylog.updatetest)이고 iCloud 권한이 없다. 기록은 이 번들의 컨테이너에만 생긴다.
# - 시험용 앱은 ~/Library/Caches/DaylogUpdateTest 아래에 놓는다(실제 /Applications는 건드리지 않는다).
# - 서명 키는 이 시험에서만 쓰는 것을 build/update-test에 새로 만든다. 배포용 키(키체인)는 건드리지 않는다.
# - 피드는 http://127.0.0.1 뿐이고, 앱은 검증 전용 번들일 때만 이 주소를 받아들인다(UpdateConfiguration).
# - 설치·다시 열기는 Sparkle이 한다. 이 스크립트는 준비와 확인만 한다.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
T="$ROOT/build/update-test"
PORT="${DAYLOG_UPDATE_TEST_PORT:-8765}"
FEED="http://127.0.0.1:$PORT"
# 시험용 앱을 놓는 곳. 데스크탑·문서 폴더 밖이어야 설치 도구가 접근 허가를 묻지 않는다.
APPS="${DAYLOG_UPDATE_TEST_APPS:-$HOME/Library/Caches/DaylogUpdateTest/Applications}"
# 시험 전용 번들 ID. 검증 번들(com.daylog.verify)과 서명이 달라 컨테이너를 따로 쓴다.
BUNDLE_ID="com.daylog.updatetest"
INSTALLED="$APPS/Daylog.app"
OLD_VERSION="${DAYLOG_TEST_OLD_VERSION:-9.0.0}"; OLD_BUILD="${DAYLOG_TEST_OLD_BUILD:-900}"
NEW_VERSION="${DAYLOG_TEST_NEW_VERSION:-9.0.1}"; NEW_BUILD="${DAYLOG_TEST_NEW_BUILD:-901}"

# 서명: 배포판처럼 앱과 Sparkle의 도구들이 같은 팀으로 서명돼야 한다(강화 런타임은 팀이 다른 라이브러리를 싣지 않는다).
# 이 Mac의 개발 인증서를 쓴다. 검증 전용 권한에는 프로파일이 필요한 것이 없다.
IDENTITY="${DAYLOG_UPDATE_TEST_IDENTITY:-Apple Development}"
TEAM="${DAYLOG_UPDATE_TEST_TEAM:-6YASPU77L7}"

step() { echo; echo "▸ $1"; }
fail() { echo "✗ $1" >&2; exit 1; }

build_app() {  # <버전> <빌드 번호> <결과 폴더>
  local version="$1" build="$2" dest="$3"
  xcodebuild -project Daylog.xcodeproj -scheme Daylog -configuration Release -derivedDataPath "$T/derived" \
    PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" CODE_SIGN_IDENTITY="$IDENTITY" CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="$TEAM" \
    PROVISIONING_PROFILE_SPECIFIER= CODE_SIGN_ENTITLEMENTS=Config/Verify.entitlements \
    INFOPLIST_FILE="$T/Info.plist" MARKETING_VERSION="$version" CURRENT_PROJECT_VERSION="$build" build 2>&1 \
    | grep -E " error: |BUILD (SUCCEEDED|FAILED)" || true
  local built="$T/derived/Build/Products/Release/Daylog.app"
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$built/Contents/Info.plist" 2>/dev/null)" == "$build" ]] \
    || fail "빌드 $build 를 만들지 못했습니다."
  rm -rf "$dest"; mkdir -p "$dest"
  ditto "$built" "$dest/Daylog.app"
  # 배포용 내보내기(Developer ID)는 Sparkle 안의 도구들까지 같은 팀으로 다시 서명한다. 여기서는 손으로 같은 일을 한다
  # (Sparkle 문서의 수동 서명 순서: 안쪽부터, 마지막에 앱).
  local sparkle="$dest/Daylog.app/Contents/Frameworks/Sparkle.framework"
  codesign -f -s "$IDENTITY" -o runtime "$sparkle/Versions/B/XPCServices/Installer.xpc" 2>/dev/null
  codesign -f -s "$IDENTITY" -o runtime --preserve-metadata=entitlements "$sparkle/Versions/B/XPCServices/Downloader.xpc" 2>/dev/null
  codesign -f -s "$IDENTITY" -o runtime "$sparkle/Versions/B/Autoupdate" 2>/dev/null
  codesign -f -s "$IDENTITY" -o runtime "$sparkle/Versions/B/Updater.app" 2>/dev/null
  codesign -f -s "$IDENTITY" -o runtime "$sparkle" 2>/dev/null
  codesign -f -s "$IDENTITY" --preserve-metadata=entitlements,flags "$dest/Daylog.app" 2>/dev/null
  codesign --verify --deep --strict "$dest/Daylog.app" || fail "서명 검증 실패: $dest"
}

case "${1:-}" in
prepare)
  mkdir -p "$T"
  step "시험용 서명 키"
  if [[ ! -f "$T/test-key" ]]; then
    swift - > "$T/keys.txt" <<'SWIFT'
import CryptoKit
import Foundation
let key = Curve25519.Signing.PrivateKey()
print(key.rawRepresentation.base64EncodedString())
print(key.publicKey.rawRepresentation.base64EncodedString())
SWIFT
    sed -n 1p "$T/keys.txt" > "$T/test-key"; sed -n 2p "$T/keys.txt" > "$T/test-key.pub"; rm "$T/keys.txt"
    chmod 600 "$T/test-key"
  fi
  echo "✓ 공개 키 $(cat "$T/test-key.pub") (이 시험 전용)"

  step "검증용 Info.plist"
  cp Config/Daylog-Info.plist "$T/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :DaylogUpdatesEnabled true" -c "Set :SUPublicEDKey $(cat "$T/test-key.pub")" \
    -c "Set :SUFeedURL $FEED/appcast.xml" \
    -c "Add :NSAppTransportSecurity dict" -c "Add :NSAppTransportSecurity:NSAllowsLocalNetworking bool true" "$T/Info.plist"
  # DAYLOG_UPDATE_TEST_SILENT=1: 화면을 누를 수 없을 때 쓰는 변형. Sparkle이 스스로 내려받아 두었다가 앱을 끝낼 때 설치한다.
  # (배포판은 늘 사용자가 [설치]를 눌러야 한다. 이 값은 시험용 Info.plist에만 들어간다.)
  if [[ "${DAYLOG_UPDATE_TEST_SILENT:-0}" == "1" ]]; then
    /usr/libexec/PlistBuddy -c "Set :SUAutomaticallyUpdate true" "$T/Info.plist"
    echo "· 조용한 설치 변형(SUAutomaticallyUpdate)"
  fi

  step "옛 버전 $OLD_VERSION ($OLD_BUILD)"
  build_app "$OLD_VERSION" "$OLD_BUILD" "$T/old"
  step "새 버전 $NEW_VERSION ($NEW_BUILD)"
  build_app "$NEW_VERSION" "$NEW_BUILD" "$T/new"

  step "새 버전의 DMG와 appcast"
  rm -rf "$T/dmg" "$T/feed"; mkdir -p "$T/dmg"
  ditto "$T/new/Daylog.app" "$T/dmg/Daylog.app"
  ln -s /Applications "$T/dmg/Applications"
  DMG="$T/Daylog-v$NEW_VERSION-macOS.dmg"
  hdiutil create -volname "Daylog $NEW_VERSION" -srcfolder "$T/dmg" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null 2>&1 \
    || fail "DMG를 만들지 못했습니다."
  rm -rf "$T/dmg"
  printf '## Daylog %s\n\n- 업데이트 시험용 빌드입니다.\n- 설치 뒤 버전이 %s (%s)로 바뀌어야 합니다.\n' "$NEW_VERSION" "$NEW_VERSION" "$NEW_BUILD" > "$T/notes.md"
  DAYLOG_SPARKLE_KEY_FILE="$T/test-key" Tools/appcast.sh "$DMG" "$T/notes.md" "$T/feed" "$FEED/"
  ;;
script)
  # 시험용 번들의 Debug 빌드로 검증 스크립트를 돌린다(Release 빌드에는 스크립트 실행기가 없다).
  # 같은 번들 ID·같은 서명이라 같은 저장소를 쓴다: 업데이트 앞뒤로 기록을 넣고 읽는 데 쓴다.
  [[ -n "${2:-}" ]] || fail "사용법: Tools/update-test.sh script \"<명령;명령;…;quit>\""
  mkdir -p "$T"
  xcodebuild -project Daylog.xcodeproj -scheme Daylog -configuration Debug -derivedDataPath "$T/derived-debug" \
    PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" CODE_SIGN_IDENTITY="$IDENTITY" CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="$TEAM" \
    PROVISIONING_PROFILE_SPECIFIER= CODE_SIGN_ENTITLEMENTS=Config/Verify.entitlements build 2>&1 \
    | grep -E " error: |BUILD (SUCCEEDED|FAILED)" || true
  DEBUG_APP="$(dirname "$APPS")/Debug/Daylog.app"
  rm -rf "$(dirname "$DEBUG_APP")"; mkdir -p "$(dirname "$DEBUG_APP")"
  ditto "$T/derived-debug/Build/Products/Debug/Daylog.app" "$DEBUG_APP"
  pgrep -f "^$INSTALLED/Contents/MacOS/Daylog" >/dev/null && fail "시험용 앱이 실행 중입니다(저장소는 한 번에 한 앱만 연다). 먼저 stop 하세요."
  open -g -n -W --stdout "$T/script.log" --stderr "$T/script.err" "$DEBUG_APP" --args -DaylogDebugToday 2026-10-11 -DaylogDebugScript "$2"
  grep -vE "linkd|autoShortcut" "$T/script.log" || true
  ;;
serve)
  [[ -f "$T/feed/appcast.xml" ]] || fail "먼저 prepare를 실행하세요."
  echo "피드: $FEED/appcast.xml (Ctrl-C로 끝냄)"
  exec /usr/bin/python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$T/feed"
  ;;
launch)
  [[ -d "$T/old/Daylog.app" ]] || fail "먼저 prepare를 실행하세요."
  pgrep -f "^$INSTALLED/Contents/MacOS/Daylog" >/dev/null && fail "시험용 앱이 이미 실행 중입니다. 먼저 stop 하세요."
  rm -rf "$APPS"; mkdir -p "$APPS"
  ditto "$T/old/Daylog.app" "$INSTALLED"
  shift
  open -g -n "$INSTALLED" --args "$@"
  echo "✓ 실행: $INSTALLED"
  ;;
status)
  if [[ -d "$INSTALLED" ]]; then
    echo "설치된 시험용 앱: $(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INSTALLED/Contents/Info.plist") ($(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INSTALLED/Contents/Info.plist"))"
    codesign --verify --deep --strict "$INSTALLED" && echo "서명: 유효"
  else
    echo "설치된 시험용 앱 없음"
  fi
  pgrep -fl "^$INSTALLED/Contents/MacOS/Daylog" || echo "실행 중 아님"
  ;;
stop)
  for pid in $(pgrep -f "^$INSTALLED/Contents/MacOS/Daylog" || true); do
    osascript -l JavaScript -e "ObjC.import('AppKit'); \$.NSRunningApplication.runningApplicationWithProcessIdentifier($pid).terminate" >/dev/null
  done
  pkill -f "http.server $PORT --bind 127.0.0.1" 2>/dev/null || true
  echo "✓ 끝냄"
  ;;
clean)
  # 시험용 앱·빌드·이 시험 전용 키를 지운다. 시험용 번들의 컨테이너(~/Library/Containers/com.daylog.updatetest)는 남는다.
  "$0" stop >/dev/null
  rm -rf "$(dirname "$APPS")" "$T"
  echo "✓ 지움"
  ;;
*)
  echo "사용법: Tools/update-test.sh prepare | serve | launch [실행 인자…] | status | stop | clean" >&2; exit 2 ;;
esac
