#!/bin/zsh
# 실제 Apple Sandbox로 피오 의상 구매를 시험하는 시뮬레이터 빌드를 만들고 띄운다(2026-10-24).
#
#   Tools/pio-storekit/run-sandbox-sim.sh <시뮬레이터 UDID>
#
# - 일반 Info.plist·프로젝트 파일은 바꾸지 않는다. 임시 Info.plist에서만 구매 환경을 sandbox로 좁혀 DaylogiOS를 빌드한다.
#   위젯 확장은 원래 Info.plist를 그대로 쓴다.
# - 로컬 StoreKit 설정(Routimori.storekit)을 붙이지 않는다. 그 설정으로 실행한 적이 있는 시뮬레이터는 설정이 남아
#   앱 영수증 환경이 Xcode로 나온다. 로그의 STORE_PROBE appTransaction 줄이 Sandbox인지 반드시 확인한다.
# - 별도 저장소(-DaylogStoreName pio-sandbox-review)를 쓴다. 실제 기록·iCloud와 섞이지 않는다.
# - 계정 로그인은 사람이 직접 한다. 이 스크립트는 계정 정보를 다루지 않는다.
#   주의(2026-10-25): iOS 27 시뮬레이터에서는 Sandbox 로그인이 기기 인증 단계에서 실패했다. 실제 결제 확인은 TestFlight 실기기로 한다.
# - 실제 iPhone에는 설치하지 않는다(같은 번들 ID라 설치된 RoutiMori와 그 데이터를 덮어쓴다).
set -euo pipefail
UDID=${1:?시뮬레이터 UDID를 주세요 (xcrun simctl list devices)}
ROOT=${0:A:h:h:h}
OUT=$HOME/Library/Caches/DaylogDev.noindex/sandbox-sim
mkdir -p "$OUT"
cd "$ROOT"
python3 - "$OUT" <<'EOF'
import plistlib, sys
from pathlib import Path
out = Path(sys.argv[1])
info = plistlib.loads(Path('Config/DaylogiOS-Info.plist').read_bytes())
# 2026-10-25부터 일반 Info.plist는 출시 구성(appStore)이다. 그 외 값이면 멈추고, 임시 사본만 sandbox로 좁힌다.
assert info.get('PioStoreKitEnvironment') in (None, 'appStore'), '일반 Info.plist의 구매 환경 키가 예상과 다르면 멈춘다'
info['PioStoreKitCatalogConfirmed'] = True
info['PioStoreKitEnvironment'] = 'sandbox'
(out / 'DaylogiOS-Sandbox-Info.plist').write_bytes(plistlib.dumps(info, sort_keys=False))
EOF
xcodebuild -project Daylog.xcodeproj -scheme DaylogiOS -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$OUT/derived" 'INFOPLIST_FILE=$(PIO_SANDBOX_INFO_$(TARGET_NAME))' \
  "PIO_SANDBOX_INFO_DaylogiOS=$OUT/DaylogiOS-Sandbox-Info.plist" \
  "PIO_SANDBOX_INFO_DaylogWidgets=$ROOT/Config/DaylogWidgets-Info.plist" build | grep -E ' error:|BUILD (SUCCEEDED|FAILED)'
APP="$OUT/derived/Build/Products/Debug-iphonesimulator/Daylog.app"
[[ "$(plutil -extract PioStoreKitEnvironment raw "$APP/Info.plist")" == sandbox ]]
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl install "$UDID" "$APP"
xcrun simctl terminate "$UDID" com.mungyubin.daylog.ios 2>/dev/null || true
echo "앱을 옷장 화면으로 띄웁니다. STORE_PROBE 줄(영수증 환경·상품 13종)이 출력됩니다. 끝내려면 Ctrl-C."
xcrun simctl launch --console-pty "$UDID" com.mungyubin.daylog.ios \
  -DaylogStoreName pio-sandbox-review -DaylogDebugSplash off -DaylogDebugScript "onboardingDone;storeProbe;section:wardrobe" \
  | grep --line-buffered STORE_PROBE
