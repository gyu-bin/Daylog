# 피오 의상 앱 아이콘 (2026-10-25)

방향 A로 만들었다. 공식 아이콘의 장면(크림 배경, 양옆 잎, 덤불, 풀 언덕)을 피오 없이 다시 그리고, 그 위에 기존 의상 그림 13장을 공식 피오 크기로 얹었다. 원화는 새로 그리지 않았다.

- `draft-1/`
  - 시안 1024px(투명 채널 있음), 비교용 기본, 배경 `plate.png`
  - 한눈에 보는 `contact-sheet.png`
- 앱에 들어간 것
  - `Daylog/Assets.xcassets/AppIcon-<의상>.appiconset` 13개. iOS가 쓰는 크기만 넣었다(20~180px, 알파 없음).
    - 1024 한 장만 두면 actool이 iPhone·iPad용으로 1024를 두 번 저장해 앱이 약 40MB 커졌다. 지금은 약 +6MB(미리보기 포함).
  - `Daylog/PioWardrobe.xcassets/pio_icon_preview_<의상>.imageset`: 옷장 '앱 아이콘' 탭 미리보기(360px)
  - iOS 타깃 빌드 설정 `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`(13개), `INCLUDE_ALL_APPICON_ASSETS = NO` → Info.plist `CFBundleIcons`·`CFBundleIcons~ipad`에 13개
- 동작 (`PioAppIconService`)
  - 산 의상의 아이콘만 고를 수 있다. 기본 아이콘으로는 언제든 돌아갈 수 있다.
  - 성공하면 iOS가 "아이콘을 변경했습니다" 창을 띄운다. 앱은 따로 알리지 않는다.
  - 앱 시작·복귀·구매 내역 변경 때 `reconcile`이 돈다. 지금 아이콘이 소유하지 않은 의상이면 기본으로 되돌리고, 소유한 의상이면 옷장 표시를 맞춘다. 검증된 구매 내역일 때만 움직인다.
  - Mac(iPad 앱으로 실행 포함)은 지원하지 않는다.
- 검증 (`evidence/`)
  - 로컬 StoreKit 시뮬레이터(iPhone 17)에서 확인: 벚꽃 구매 → 아이콘 탭 → 홈 화면 아이콘 변경, 재설치·재실행 후 "지금 아이콘 · 벚꽃" 유지, 기본으로 되돌리기
  - 단위 테스트: 13종 이름·파일·빌드 설정 일치, 미등록·미소유는 선택 불가
  - **NOT_TESTED**: 환불 직후 아이콘이 기본으로 돌아가는 실제 동작. 코드 경로만 있고, 실기기·Sandbox 환불로 확인해야 한다.
