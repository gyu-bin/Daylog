#!/bin/zsh
# Daylog를 Release로 빌드해 응용 프로그램 폴더에 설치한다.
#
#   Tools/install.sh              빌드 → /Applications/Daylog.app 설치 → 실행
#   Tools/install.sh --no-open    설치만 하고 실행하지 않는다
#
# 기록은 앱 묶음이 아니라 ~/Library/Containers/com.mungyubin.daylog 에 있어서, 앱을 다시 설치해도 그대로 남는다.
# 실행 중인 Daylog가 있으면 멈춘다(저장소 하나를 두 버전이 동시에 열지 않도록 직접 종료한 뒤 다시 실행한다).
set -euo pipefail

cd "$(dirname "$0")/.."
# 빌드 폴더를 Spotlight가 보지 않게 한다(안의 Daylog.app이 저장 공간 목록에 따로 나오지 않게).
source Tools/noindex.sh
daylog_noindex_dir build
INSTALL_DIR="${DAYLOG_INSTALL_DIR:-/Applications}"
DERIVED="build/install"
PRODUCT="$DERIVED/Build/Products/Release/Daylog.app"

if pgrep -x Daylog >/dev/null; then
  echo "Daylog가 실행 중입니다. 먼저 종료(⌘Q)한 뒤 다시 실행해 주세요." >&2
  exit 1
fi

echo "빌드 중…"
xcodebuild -project Daylog.xcodeproj -scheme Daylog -configuration Release \
  -derivedDataPath "$DERIVED" -allowProvisioningUpdates build 2>&1 \
  | grep -E " error: |BUILD (SUCCEEDED|FAILED)" || true
[[ -d "$PRODUCT" ]] || { echo "빌드 결과물을 찾지 못했습니다: $PRODUCT" >&2; exit 1; }

echo "설치 중… $INSTALL_DIR/Daylog.app"
mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALL_DIR/Daylog.app"
ditto "$PRODUCT" "$INSTALL_DIR/Daylog.app"
codesign --verify --deep --strict "$INSTALL_DIR/Daylog.app"

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INSTALL_DIR/Daylog.app/Contents/Info.plist")
echo "Daylog $VERSION 설치 완료"
[[ "${1:-}" == "--no-open" ]] || open "$INSTALL_DIR/Daylog.app"
