#!/bin/zsh
# Daylog 배포용 DMG를 만든다: 테스트 → 아카이브 → Developer ID 서명 → 공증 → 스테이플 → DMG → 검증 → (선택) GitHub Release.
#
#   Tools/release.sh                 DMG를 만들고 검증까지 한다. 게시하지 않는다.
#   Tools/release.sh --publish       검증을 통과하면 GitHub Release(v<버전>)에 DMG를 올린다.
#                                    앱 안의 업데이트(Sparkle)가 켜져 있으면 appcast.xml도 만들어 함께 올린다(아래 "앱 안의 업데이트").
#                                    꺼져 있을 때만, 같은 버전의 릴리스가 이미 있으면 DMG만 새것으로 바꾼다.
#   Tools/release.sh --skip-tests    전체 테스트를 건너뛴다(방금 돌린 경우).
#   Tools/release.sh --publish-only  이미 만들어 검증한 DMG(build/release)를 다시 만들지 않고 그대로 올린다.
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
# 앱 안의 업데이트(Sparkle)
# - Config/Daylog-Info.plist에 DaylogUpdatesEnabled와 공개 키(SUPublicEDKey)가 있으면 켜진 것으로 본다.
# - 서명은 두 가지이고 서로 별개다: 앱의 Developer ID 서명·공증(위), 그리고 DMG의 Sparkle EdDSA 서명(appcast에 들어간다).
#   EdDSA 개인 키는 로그인 키체인에 있다(Sparkle의 generate_keys가 넣는다). 저장소에는 공개 키만 있다.
# - 릴리스마다 버전과 빌드 번호가 올라가야 한다(Tools/bump-version.sh). 이미 게시한 버전은 다시 올리지 않는다.
# - 릴리스 노트는 docs/releases/v<버전>.md. 앱의 업데이트 창과 GitHub 릴리스에 같은 내용이 나온다.
# - 게시 순서: 초안 릴리스에 DMG와 appcast.xml을 모두 올린다 → 올라간 것을 확인한다 → 공개한다 → 공개 주소에서 다시 받아 본다.
#   앱이 보는 피드(…/releases/latest/download/appcast.xml)는 공개하는 순간 새 릴리스를 가리키고, 그때는 DMG도 이미 올라가 있다.
#
# 주의: Developer ID로 배포하는 앱은 CloudKit의 Production 환경만 쓸 수 있다(프로비저닝 프로파일이 그렇게 정한다).
#       Xcode로 직접 빌드한 앱(Development 환경)과는 서로 다른 iCloud 데이터를 본다.
set -euo pipefail

cd "$(dirname "$0")/.."
PUBLISH=0; SKIP_TESTS=0; ALLOW_UNSIGNED_DMG=0; PUBLISH_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --publish) PUBLISH=1 ;;
    --publish-only) PUBLISH=1; PUBLISH_ONLY=1 ;;
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
REPO_URL="https://github.com/gyu-bin/Daylog"
FEED_URL="$REPO_URL/releases/latest/download/appcast.xml"
SPARKLE_KEY=$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' Config/Daylog-Info.plist 2>/dev/null || true)
SPARKLE_ON=0
[[ "$(/usr/libexec/PlistBuddy -c 'Print :DaylogUpdatesEnabled' Config/Daylog-Info.plist 2>/dev/null)" == "true" && -n "$SPARKLE_KEY" ]] && SPARKLE_ON=1
NOTES_FILE="docs/releases/v$VERSION.md"

OUT="build/release"
ARCHIVE="$OUT/Daylog.xcarchive"
APP="$OUT/notarized/Daylog.app"
DMG="$OUT/Daylog-v$VERSION-macOS.dmg"

step() { echo; echo "▸ $1"; }
fail() { echo "✗ $1" >&2; exit 1; }

step "Daylog $VERSION 배포 준비"
[[ -z "$(git status --porcelain)" ]] || fail "커밋하지 않은 변경이 있습니다. 배포는 커밋된 상태에서만 합니다."
if [[ $SPARKLE_ON -eq 1 ]]; then
  echo "앱 안의 업데이트: 켜짐 (appcast를 함께 만듭니다)"
  [[ -s "$NOTES_FILE" ]] || fail "릴리스 노트($NOTES_FILE)가 없습니다. Tools/bump-version.sh가 만든 틀을 채워 커밋하세요."
  grep -q "달라진 점을 적어 주세요" "$NOTES_FILE" && fail "릴리스 노트($NOTES_FILE)가 아직 틀 그대로입니다."
  if [[ $PUBLISH -eq 1 ]]; then
    # 같은 버전·빌드 번호를 두 번 게시하지 않는다. 만들기 전에 확인해 공증 시간을 버리지 않는다.
    command -v gh >/dev/null || fail "gh(GitHub CLI)가 없습니다."
    gh release view "v$VERSION" >/dev/null 2>&1 \
      && fail "v$VERSION 은 이미 게시됐습니다. 새로 올리려면 Tools/bump-version.sh <새 버전>으로 버전을 올리세요."
  fi
else
  echo "앱 안의 업데이트: 꺼짐 (DMG만 만듭니다)"
fi

# 지금 공개돼 있는 appcast(과거 항목을 이어 가기 위해). 첫 릴리스에는 없다.
fetch_previous_appcast() {
  PREVIOUS_APPCAST="$OUT/previous-appcast.xml"
  curl -fsSL "$FEED_URL" -o "$PREVIOUS_APPCAST" 2>/dev/null || rm -f "$PREVIOUS_APPCAST"
  [[ -s "$PREVIOUS_APPCAST" ]] && echo "· 지금 공개된 appcast를 이어 씁니다." || echo "· 공개된 appcast가 아직 없습니다(첫 릴리스)."
}

make_appcast() {
  step "Sparkle 서명과 appcast"
  # 앱에 들어간 공개 키가 키체인의 개인 키와 짝인지 먼저 본다(다르면 설치된 앱이 이 업데이트를 거부한다).
  local bin keychain_key
  bin=$(ls -d "$OUT"/derived/SourcePackages/artifacts/sparkle/Sparkle/bin build/*/derived/SourcePackages/artifacts/sparkle/Sparkle/bin 2>/dev/null | head -1)
  [[ -x "$bin/generate_keys" ]] || fail "Sparkle 도구를 찾지 못했습니다."
  keychain_key=$("$bin/generate_keys" -p </dev/null 2>/dev/null) || fail "키체인에서 Sparkle 서명 키를 읽지 못했습니다(docs/UPDATES.md의 키 준비)."
  [[ "$keychain_key" == "$SPARKLE_KEY" ]] || fail "앱의 공개 키(SUPublicEDKey)가 키체인의 서명 키와 다릅니다. 게시하지 않습니다."
  fetch_previous_appcast
  Tools/appcast.sh "$DMG" "$NOTES_FILE" "$OUT/appcast" "$REPO_URL/releases/download/v$VERSION/" "${PREVIOUS_APPCAST:-}"
  APPCAST="$OUT/appcast/appcast.xml"
}

build_dmg() {
  rm -rf "$OUT"; mkdir -p "$OUT"
  # 어느 커밋으로 만든 DMG인지 남긴다(--publish-only로 나중에 올려도 맞게 적히도록).
  git rev-parse HEAD > "$OUT/build-commit"

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
  if [[ $SPARKLE_ON -eq 1 ]]; then
    # 설치 도구와 통신하는 권한, 그리고 Sparkle 안의 도구들이 앱과 같은 팀으로 서명됐는지.
    echo "$ENTITLEMENTS" | grep -q "\"$BUNDLE_ID-spks\"" || fail "Sparkle 설치 도구와 통신하는 권한(-spks)이 없습니다."
    echo "$ENTITLEMENTS" | grep -q "\"$BUNDLE_ID-spki\"" || fail "Sparkle 설치 도구와 통신하는 권한(-spki)이 없습니다."
    TEAM=$(echo "$SIGNATURE" | sed -n 's/^TeamIdentifier=//p')
    for tool in XPCServices/Installer.xpc XPCServices/Downloader.xpc Autoupdate Updater.app; do
      codesign -dvv "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/$tool" 2>&1 | grep -q "TeamIdentifier=$TEAM" \
        || fail "Sparkle의 $tool 이 앱과 같은 팀으로 서명되지 않았습니다."
    done
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$APP/Contents/Info.plist")" == "$SPARKLE_KEY" ]] || fail "앱에 들어간 Sparkle 공개 키가 다릅니다."
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' "$APP/Contents/Info.plist")" == "$FEED_URL" ]] || fail "앱의 업데이트 피드 주소가 다릅니다."
    echo "✓ Sparkle: 공개 키, 피드 주소, 설치 도구 권한과 서명"
  fi

  step "DMG 만들기"
  STAGING="$OUT/dmg"
  mkdir -p "$STAGING"
  ditto "$APP" "$STAGING/Daylog.app"
  ln -s /Applications "$STAGING/Applications"
  hdiutil create -volname "Daylog $VERSION" -srcfolder "$STAGING" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null 2>&1 \
    || fail "DMG를 만들지 못했습니다."
  rm -rf "$STAGING"

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
}

DMG_STATE="서명·공증 안 됨"
if [[ $PUBLISH_ONLY -eq 1 ]]; then
  [[ -f "$DMG" ]] || fail "$DMG 가 없습니다. 먼저 Tools/release.sh 로 만드세요."
  if xcrun stapler validate "$DMG" >/dev/null 2>&1; then DMG_STATE="서명·공증·스테이플 완료"; fi
else
  build_dmg
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

[[ $SPARKLE_ON -eq 1 ]] && make_appcast

# 공개 주소에서 실제로 받아지는지. 앱이 보는 주소 그대로 확인한다.
verify_public_release() {
  local tag="$1" size url got attempt
  size=$(stat -f %z "$DMG")
  url="$REPO_URL/releases/download/$tag/$(basename "$DMG")"
  got=$(curl -fsSLI "$url" 2>/dev/null | tr -d '\r' | awk 'tolower($1)=="content-length:"{v=$2} END{print v}')
  [[ "$got" == "$size" ]] || fail "공개된 DMG의 크기($got)가 만든 것($size)과 다릅니다: $url"
  for attempt in {1..10}; do
    curl -fsSL "$FEED_URL" 2>/dev/null | cmp -s - "$APPCAST" && { echo "✓ 공개 주소 확인: DMG $size 바이트, 피드가 새 appcast"; return 0; }
    sleep 3
  done
  fail "피드 주소($FEED_URL)가 아직 새 appcast가 아닙니다. 릴리스가 최신(latest)으로 표시됐는지 확인하세요."
}

if [[ $PUBLISH -eq 1 && $SPARKLE_ON -eq 1 ]]; then
  step "GitHub Release 게시 (DMG + appcast)"
  if [[ "$DMG_STATE" != "서명·공증·스테이플 완료" && $ALLOW_UNSIGNED_DMG -eq 0 ]]; then
    fail "DMG 자체가 서명·공증되지 않았습니다. 스크립트 위쪽의 준비 사항을 갖추거나 --allow-unsigned-dmg 를 붙이세요."
  fi
  TAG="v$VERSION"
  HEAD_SHA=$(cat "$OUT/build-commit" 2>/dev/null || git rev-parse HEAD)
  DMG_SHA=$(shasum -a 256 "$DMG" | cut -d' ' -f1)
  git branch -r --contains "$HEAD_SHA" 2>/dev/null | grep -q . || fail "이 커밋이 GitHub에 없습니다. 먼저 git push 하세요."
  gh release view "$TAG" >/dev/null 2>&1 && fail "$TAG 은 이미 게시됐습니다. 버전을 올리세요(Tools/bump-version.sh)."
  BODY=$(mktemp)
  {
    cat "$NOTES_FILE"
    printf '\n### 설치\n- 이미 쓰고 있다면: 설정 → 정보 → **업데이트 확인** (또는 메뉴의 "업데이트 확인…").\n'
    printf -- '- 처음이거나 1.5.1 이하라면: 아래 **Assets**의 `%s`를 받아 Daylog를 Applications로 끌어다 놓으세요(대치).\n' "$(basename "$DMG")"
    printf '\nmacOS 14 이상. DMG 안의 앱은 Developer ID로 서명되고 Apple 공증을 받았습니다.\n'
    printf '\nSHA-256: `%s`\n\n빌드 기준 커밋: %s\n' "$DMG_SHA" "${HEAD_SHA[1,7]}"
  } > "$BODY"
  # 초안으로 올린다: 이 동안에는 피드 주소가 아직 이전 릴리스를 가리킨다.
  gh release create "$TAG" "$DMG" "$APPCAST" --draft --target "$HEAD_SHA" --title "Daylog $VERSION" --notes-file "$BODY" >/dev/null \
    || fail "초안 릴리스를 만들지 못했습니다."
  rm -f "$BODY"
  UPLOADED=$(gh release view "$TAG" --json assets -q '.assets[] | "\(.name) \(.size)"' | sort)
  EXPECTED=$(printf '%s %s\n%s %s\n' "$(basename "$DMG")" "$(stat -f %z "$DMG")" "appcast.xml" "$(stat -f %z "$APPCAST")" | sort)
  [[ "$UPLOADED" == "$EXPECTED" ]] || fail "초안에 올라간 파일이 다릅니다. 초안을 지우고 다시 하세요(gh release delete $TAG).\n$UPLOADED"
  gh release edit "$TAG" --draft=false --latest >/dev/null || fail "릴리스를 공개하지 못했습니다(초안은 남아 있습니다)."
  verify_public_release "$TAG"
  echo "✓ 게시 완료: $(gh release view "$TAG" --json url -q .url)"
elif [[ $PUBLISH -eq 1 ]]; then
  step "GitHub Release 게시"
  if [[ "$DMG_STATE" != "서명·공증·스테이플 완료" && $ALLOW_UNSIGNED_DMG -eq 0 ]]; then
    fail "DMG 자체가 서명·공증되지 않았습니다. 스크립트 위쪽의 준비 사항을 갖추거나 --allow-unsigned-dmg 를 붙이세요."
  fi
  command -v gh >/dev/null || fail "gh(GitHub CLI)가 없습니다."
  TAG="v$VERSION"
  HEAD_SHA=$(cat "$OUT/build-commit" 2>/dev/null || git rev-parse HEAD)
  DMG_SHA=$(shasum -a 256 "$DMG" | cut -d' ' -f1)
  # Tools/update.sh가 이 줄을 읽어, 그 뒤로 앱 소스가 바뀌었을 때만 DMG를 다시 올린다.
  BUILD_LINE="빌드 기준 커밋: ${HEAD_SHA[1,7]}"
  # 릴리스의 태그와 설명이 가리키는 커밋은 GitHub에 있어야 한다.
  git branch -r --contains "$HEAD_SHA" 2>/dev/null | grep -q . || fail "이 커밋이 GitHub에 없습니다. 먼저 git push 하세요."
  if gh release view "$TAG" >/dev/null 2>&1; then
    # 같은 버전: 태그는 옮기지 않고 DMG만 바꾼다. 어느 커밋으로 만든 DMG인지는 설명에 적는다.
    gh release upload "$TAG" "$DMG" --clobber || fail "DMG를 바꾸지 못했습니다."
    # 설명은 그대로 두고 체크섬과 빌드 기준 커밋만 고친다. 읽지 못하면 설명을 덮어쓰지 않는다.
    BODY=$(gh release view "$TAG" --json body -q .body) || fail "DMG는 바꿨지만 릴리스 설명을 읽지 못했습니다. 체크섬을 직접 고치세요: $DMG_SHA"
    BODY=$(echo "$BODY" | sed -E "s/[0-9a-f]{64}/$DMG_SHA/g" | grep -v "^빌드 기준 커밋: " || true)
    [[ "$BODY" == *"$DMG_SHA"* ]] || BODY="$BODY

SHA-256: \`$DMG_SHA\`"
    NOTES=$(mktemp)
    printf '%s\n\n%s\n' "$BODY" "$BUILD_LINE" > "$NOTES"
    gh release edit "$TAG" --notes-file "$NOTES" >/dev/null || fail "DMG는 바꿨지만 릴리스 설명을 고치지 못했습니다. 체크섬을 직접 고치세요: $DMG_SHA"
    rm -f "$NOTES"
    echo "✓ $TAG 릴리스의 DMG를 바꿨습니다: $(gh release view "$TAG" --json url -q .url)"
  else
    gh release create "$TAG" "$DMG" --target "$HEAD_SHA" --title "Daylog $VERSION" \
      --notes "macOS 14 이상. DMG를 열어 Daylog를 Applications로 끌어다 놓으세요.

SHA-256: \`$DMG_SHA\`

$BUILD_LINE"
    echo "✓ 게시 완료: $(gh release view "$TAG" --json url -q .url)"
  fi
else
  echo
  echo "게시하지 않았습니다. 올리려면: Tools/release.sh --publish"
fi
