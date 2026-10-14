#!/bin/zsh
# 개발·검증용 빌드를 늘 같은 자리, 같은 식별자로 만든다. 실제 앱(/Applications/Daylog.app)과 그 기록은 건드리지 않는다.
#
#   Tools/dev.sh build [Debug|Release]   검증용 Mac 앱을 빌드한다(번들 ID com.daylog.verify, iCloud 없음)
#   Tools/dev.sh test [xcodebuild 인자…]  같은 자리에서 단위 테스트를 돌린다(예: -only-testing:DaylogTests/RoutineSkipTests)
#   Tools/dev.sh path [Debug|Release|Perf] 검증용 Mac 앱의 경로를 출력한다
#   Tools/dev.sh perf                    성능 측정용: Release 최적화 그대로에 검증용 실행 인자(DEBUG 조건)만 켠 Mac 앱을 빌드한다
#   Tools/dev.sh ios [Debug|Release]     iPhone·iPad 시뮬레이터용 앱을 빌드한다(build-ios)
#   Tools/dev.sh apps                    이 Mac에 있는 Daylog 앱 묶음과 시스템에 등록된 경로를 보여 준다(읽기만 한다)
#
# 왜 한곳인가: 빌드할 때마다 다른 폴더를 쓰면 그만큼 Daylog.app이 늘어난다. Xcode는 빌드한 앱을 시스템(LaunchServices)에
# 등록하고, Spotlight가 보는 곳에 있으면 저장 공간 목록에도 따로 나온다. 그래서 자리를 하나로 정하고 색인되지 않는 폴더에 둔다.
#
# - 검증용 Mac 빌드는 ~/Library/Caches/DaylogDev.noindex/verify 에 둔다. 프로젝트 폴더(데스크탑) 안에 두면 샌드박스된
#   테스트 호스트가 폴더 접근 허가를 기다리며 멈춘다. DAYLOG_DEV_DIR로 바꿀 수 있다.
# - 저장소 안의 build, build-ios, build-verify는 `.noindex` 폴더를 가리키는 링크다(Tools/noindex.sh).
set -euo pipefail

cd "$(dirname "$0")/.."
source Tools/noindex.sh

DEV_DIR="${DAYLOG_DEV_DIR:-$HOME/Library/Caches/DaylogDev.noindex}"
VERIFY_DERIVED="$DEV_DIR/verify"
PERF_DERIVED="$DEV_DIR/verify-perf"
VERIFY_ID="com.daylog.verify"
VERIFY_ARGS=(-project Daylog.xcodeproj -scheme Daylog -derivedDataPath "$VERIFY_DERIVED"
  PRODUCT_BUNDLE_IDENTIFIER="$VERIFY_ID" CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=
  PROVISIONING_PROFILE_SPECIFIER= CODE_SIGN_ENTITLEMENTS=Config/Verify.entitlements)

usage() { sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

configuration() {
  case "${1:-Debug}" in
    Debug|Release) echo "${1:-Debug}" ;;
    *) echo "구성은 Debug 또는 Release입니다: $1" >&2; exit 2 ;;
  esac
}

case "${1:-}" in
  build)
    config=$(configuration "${2:-}")
    mkdir -p "$DEV_DIR"
    xcodebuild "${VERIFY_ARGS[@]}" -configuration "$config" build
    echo "$VERIFY_DERIVED/Build/Products/$config/Daylog.app"
    ;;
  test)
    shift
    mkdir -p "$DEV_DIR"
    xcodebuild "${VERIFY_ARGS[@]}" test "$@"
    ;;
  path)
    if [[ "${2:-}" == Perf ]]; then echo "$PERF_DERIVED/Build/Products/Release/Daylog.app"; exit 0; fi
    echo "$VERIFY_DERIVED/Build/Products/$(configuration "${2:-}")/Daylog.app"
    ;;
  perf)
    # 순수 Release는 화면 검증용 실행 인자(-DaylogDebug…)가 빠져 측정할 화면을 띄울 수 없다. 최적화(-O, 전체 모듈)는 Release
    # 그대로 두고 DEBUG 조건만 덧붙인다. 검증 앱과 같은 번들 ID·저장소 규칙을 쓰고, 빌드는 따로 둔다(Release 산출물을 덮지 않는다).
    mkdir -p "$DEV_DIR"
    # 임시 서명(adhoc)이라 강화된 런타임의 라이브러리 검증이 Sparkle을 막는다. 실행 속도와 무관해 측정용 빌드에서만 끈다.
    xcodebuild "${VERIFY_ARGS[@]/$VERIFY_DERIVED/$PERF_DERIVED}" -configuration Release 'OTHER_SWIFT_FLAGS=$(inherited) -DDEBUG' \
      ENABLE_HARDENED_RUNTIME=NO build
    echo "$PERF_DERIVED/Build/Products/Release/Daylog.app"
    ;;
  ios)
    config=$(configuration "${2:-}")
    daylog_noindex_dir build-ios
    xcodebuild -project Daylog.xcodeproj -scheme DaylogiOS -configuration "$config" -derivedDataPath build-ios \
      -destination 'generic/platform=iOS Simulator' build
    echo "build-ios/Build/Products/$config-iphonesimulator/Daylog.app"
    ;;
  apps)
    LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
    echo "== Spotlight가 보는 Daylog 앱 묶음(저장 공간 목록에 나오는 것)"
    mdfind "kMDItemContentType == 'com.apple.application-bundle' && kMDItemFSName == 'Daylog*.app'c" 2>/dev/null | sort | while read -r app; do
      plist="$app/Contents/Info.plist"; [[ -f "$plist" ]] || plist="$app/Info.plist"
      version=$(/usr/bin/defaults read "${plist%.plist}" CFBundleShortVersionString 2>/dev/null || echo "?")
      identifier=$(/usr/bin/defaults read "${plist%.plist}" CFBundleIdentifier 2>/dev/null || echo "?")
      echo "  $version  $identifier  $(du -sh "$app" 2>/dev/null | cut -f1)  $app"
    done
    echo "== 시스템(LaunchServices)에 등록된 경로. '없음'은 파일이 사라지고 등록만 남은 것"
    "$LSREGISTER" -dump 2>/dev/null | sed -n 's/^path: *\(.*Daylog[^/]*\.app\) (0x[0-9a-f]*)$/\1/p' | sort -u | while read -r app; do
      if [[ -d "$app" ]]; then echo "  있음  $app"; else echo "  없음  $app"; fi
    done
    echo "등록만 남은 것은 시스템이 알아서 정리한다. 바로 지우려면: $LSREGISTER -u <경로>"
    ;;
  -h|--help|help) usage ;;
  *) usage 2 ;;
esac
