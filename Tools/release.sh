#!/bin/zsh
# Daylog 배포용 DMG를 만든다: 테스트 → 아카이브 → Developer ID 서명 → 공증 → 스테이플 → DMG → 검증 → (선택) GitHub Release.
#
#   Tools/release.sh                 DMG를 만들고 검증까지 한다. 게시하지 않는다.
#   Tools/release.sh --publish       검증을 통과하면 GitHub Release(v<버전>)에 DMG를 올린다.
#   Tools/release.sh --skip-tests    전체 테스트를 건너뛴다(방금 돌린 경우).
#   Tools/release.sh --allow-unsigned-dmg
#                                    DMG 자체를 서명·공증하지 못해도 게시를 허용한다(안의 앱은 반드시 공증돼 있어야 한다).
#
# 필요한 것
# - Xcode에 Apple 개발자 계정이 로그인되어 있을 것. 앱의 Developer ID 서명과 공증은 Xcode 계정으로 한다
#   (인증서는 Apple이 보관하는 "Cloud Managed Developer ID Application").
# - DMG 자체까지 서명·공증하려면(선택) 이 Mac의 키체인에 두 가지가 더 있어야 한다. 저장소에는 아무것도 넣지 않는다.
#     1) "Developer ID Application" 인증서: Xcode > Settings > Accounts > Manage Certificates > + 로 만든다.
#     2) 공증 자격 증명: xcrun notarytool store-credentials daylog-notary --apple-id <Apple ID> --team-id <팀 ID>
#        (프로파일 이름은 DAYLOG_NOTARY_PROFILE 환경 변수로 바꿀 수 있다.)
#
# 주의: Developer ID로 배포하는 앱은 CloudKit의 Production 환경만 쓸 수 있다(프로비저닝 프로파일이 그렇게 정한다).
#       Xcode로 직접 빌드한 앱(Development 환경)과는 서로 다른 iCloud 데이터를 본다.
set -euo pipefail

cd "$(dirname "$0")/.."
PUBLISH=0; SKIP_TESTS=0; ALLOW_UNSIGNED_DMG=0
for arg in "$@"; do
  case "$arg" in
    --publish) PUBLISH=1 ;;
    --skip-tests) SKIP_TESTS=1 ;;
    --allow-unsigned-dmg) ALLOW_UNSIGNED_DMG=1 ;;
    *) echo "알 수 없는 옵션: $arg" >&2; exit 2 ;;
  esac
done

BUNDLE_ID="com.mungyubin.daylog"
ICLOUD_CONTAINER="iCloud.$BUNDLE_ID"
NOTARY_PROFILE="${DAYLOG_NOTARY_PROFILE:-daylog-notary}"
VERSION=$(sed -n 's/.*MARKETING_VERSION = \(.*\);/\1/p' Daylog.xcodeproj/project.pbxproj | head -1)
[[ -n "$VERSION" ]] || { echo "버전을 읽지 못했습니다." >&2; exit 1; }

OUT="build/release"
ARCHIVE="$OUT/Daylog.xcarchive"
APP="$OUT/notarized/Daylog.app"
DMG="$OUT/Daylog-v$VERSION-macOS.dmg"

step() { echo; echo "▸ $1"; }
fail() { echo "✗ $1" >&2; exit 1; }

step "Daylog $VERSION 배포 준비"
[[ -z "$(git status --porcelain)" ]] || fail "커밋하지 않은 변경이 있습니다. 배포는 커밋된 상태에서만 합니다."
rm -rf "$OUT"; mkdir -p "$OUT"

if [[ $SKIP_TESTS -eq 0 ]]; then
  step "전체 테스트"
  xcodebuild -project Daylog.xcodeproj -scheme Daylog -derivedDataPath build -allowProvisioningUpdates test 2>&1 \
    | grep -E " error: |✘|Test run with|TEST (SUCCEEDED|FAILED)" || true
  [[ ${pipestatus[1]} -eq 0 ]] || fail "테스트가 실패했습니다."
fi

step "Release 아카이브"
xcodebuild -project Daylog.xcodeproj -scheme Daylog -configuration Release -derivedDataPath "$OUT/derived" \
  -archivePath "$ARCHIVE" -allowProvisioningUpdates archive 2>&1 | grep -E " error: |ARCHIVE (SUCCEEDED|FAILED)" || true
[[ -d "$ARCHIVE" ]] || fail "아카이브에 실패했습니다."

step "Developer ID 서명 + 공증 요청"
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
	<string>upload</string>
</dict>
</plist>
PLIST
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$OUT/upload" -exportOptionsPlist "$OUT/ExportOptions.plist" \
  -allowProvisioningUpdates 2>&1 | grep -E "error|EXPORT (SUCCEEDED|FAILED)|Uploaded" || true
[[ ${pipestatus[1]} -eq 0 ]] || fail "Developer ID 서명 또는 공증 업로드에 실패했습니다(배포용 인증서·프로파일을 확인하세요)."

step "공증 결과 기다리는 중"
for attempt in {1..45}; do
  rm -rf "$OUT/notarized"
  xcodebuild -exportNotarizedApp -archivePath "$ARCHIVE" -exportPath "$OUT/notarized" >/dev/null 2>&1 || true
  [[ -d "$APP" ]] && break
  sleep 20
done
[[ -d "$APP" ]] || fail "공증이 끝나지 않았거나 거부됐습니다. Xcode의 Organizer에서 상태를 확인하세요."

step "앱 검증"
codesign --verify --deep --strict "$APP" || fail "codesign 검증 실패"
SIGNATURE=$(codesign -dvv "$APP" 2>&1)
echo "$SIGNATURE" | grep -q "Authority=Developer ID Application" || fail "Developer ID 서명이 아닙니다."
echo "$SIGNATURE" | grep -q "flags=.*runtime" || fail "Hardened Runtime이 켜져 있지 않습니다."
ENTITLEMENTS=$(codesign -d --entitlements - --xml "$APP" 2>/dev/null | plutil -convert json -o - -)
echo "$ENTITLEMENTS" | grep -q "\"$ICLOUD_CONTAINER\"" || fail "iCloud 컨테이너 권한이 없습니다."
echo "$ENTITLEMENTS" | grep -q '"CloudKit"' || fail "CloudKit 권한이 없습니다."
echo "$ENTITLEMENTS" | grep -q '"com.apple.security.app-sandbox":true' || fail "App Sandbox 권한이 없습니다."
[[ -f "$APP/Contents/embedded.provisionprofile" ]] || fail "배포용 프로비저닝 프로파일이 없습니다."
security cms -D -i "$APP/Contents/embedded.provisionprofile" 2>/dev/null | grep -q "$ICLOUD_CONTAINER" \
  || fail "프로파일에 iCloud 컨테이너가 없습니다."
xcrun stapler validate "$APP" >/dev/null 2>&1 || fail "앱에 공증 티켓이 붙어 있지 않습니다."
spctl -a -vv "$APP" 2>&1 | grep -q "source=Notarized Developer ID" || fail "Gatekeeper가 앱을 받아들이지 않습니다."
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")" == "$BUNDLE_ID" ]] || fail "번들 ID가 다릅니다."
echo "✓ Developer ID 서명, Hardened Runtime, CloudKit 권한, 공증 티켓, Gatekeeper 통과"

step "DMG 만들기"
STAGING="$OUT/dmg"
mkdir -p "$STAGING"
ditto "$APP" "$STAGING/Daylog.app"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "Daylog $VERSION" -srcfolder "$STAGING" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null 2>&1 \
  || fail "DMG를 만들지 못했습니다."
rm -rf "$STAGING"

DMG_STATE="서명·공증 안 됨"
if security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
  step "DMG 서명"
  codesign --force --sign "Developer ID Application" --timestamp "$DMG"
  DMG_STATE="서명됨, 공증 안 됨"
  if xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    step "DMG 공증"
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait | grep -E "status:|id:" || true
    xcrun stapler staple "$DMG" >/dev/null || fail "DMG 공증에 실패했습니다."
    spctl -a -t open --context context:primary-signature -vv "$DMG" 2>&1 | grep -q "source=Notarized Developer ID" \
      || fail "Gatekeeper가 DMG를 받아들이지 않습니다."
    DMG_STATE="서명·공증·스테이플 완료"
  fi
fi

step "DMG 검증"
hdiutil verify "$DMG" >/dev/null 2>&1 || fail "DMG가 손상됐습니다."
MOUNT=$(mktemp -d)
hdiutil attach "$DMG" -nobrowse -readonly -mountpoint "$MOUNT" >/dev/null 2>&1 || fail "DMG를 열지 못했습니다."
{
  [[ -L "$MOUNT/Applications" ]] || fail "DMG에 Applications 바로가기가 없습니다."
  codesign --verify --deep --strict "$MOUNT/Daylog.app" || fail "DMG 안의 앱 서명이 깨졌습니다."
  xcrun stapler validate "$MOUNT/Daylog.app" >/dev/null 2>&1 || fail "DMG 안의 앱에 공증 티켓이 없습니다."
  spctl -a -vv "$MOUNT/Daylog.app" 2>&1 | grep -q "source=Notarized Developer ID" || fail "Gatekeeper가 DMG 안의 앱을 받아들이지 않습니다."
} always {
  hdiutil detach "$MOUNT" >/dev/null 2>&1 || true
  rmdir "$MOUNT" 2>/dev/null || true
}
echo "✓ $DMG"
echo "  크기 $(du -h "$DMG" | cut -f1 | tr -d ' '), SHA-256 $(shasum -a 256 "$DMG" | cut -d' ' -f1)"
echo "  DMG 상태: $DMG_STATE (안의 앱: 공증·스테이플 완료)"

if [[ $PUBLISH -eq 1 ]]; then
  step "GitHub Release 게시"
  if [[ "$DMG_STATE" != "서명·공증·스테이플 완료" && $ALLOW_UNSIGNED_DMG -eq 0 ]]; then
    fail "DMG 자체가 서명·공증되지 않았습니다. 스크립트 위쪽의 준비 사항을 갖추거나 --allow-unsigned-dmg 를 붙이세요."
  fi
  command -v gh >/dev/null || fail "gh(GitHub CLI)가 없습니다."
  TAG="v$VERSION"
  gh release view "$TAG" >/dev/null 2>&1 && fail "$TAG 릴리스가 이미 있습니다."
  gh release create "$TAG" "$DMG" --target "$(git rev-parse HEAD)" --title "Daylog $VERSION" \
    --notes "macOS 14 이상. DMG를 열어 Daylog를 Applications로 끌어다 놓으세요.

SHA-256: \`$(shasum -a 256 "$DMG" | cut -d' ' -f1)\`"
  echo "✓ 게시 완료: $(gh release view "$TAG" --json url -q .url)"
else
  echo
  echo "게시하지 않았습니다. 올리려면: Tools/release.sh --publish"
fi
