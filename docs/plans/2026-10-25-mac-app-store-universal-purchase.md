# 계획서: Mac 앱을 Mac App Store로 옮겨 의상을 함께 팔기 (유니버설 구매)

작성 2026-10-25 · 상태: **승인 대기** (이 문서를 승인받기 전에는 코드·App Store Connect를 바꾸지 않는다)

## 1. 목표

- Mac에서도 피오 의상을 판다.
- **한 번 사면 iPhone·iPad·Mac 모두에서 입는다.** 상품은 지금의 13종을 그대로 쓰고, 결제·환불·복원은 Apple이 맡는다.
- 루틴 기록과 iCloud 동기화는 끊기지 않게 옮긴다. 기존 DMG 사용자도 기록을 잃지 않는다.

## 2. 지금 구조 (2026-10-25 확인)

| 항목 | Mac 앱 (DMG) | iPhone·iPad 앱 |
|---|---|---|
| 번들 ID | `com.mungyubin.daylog` | `com.mungyubin.daylog.ios` |
| 배포 | GitHub DMG + Sparkle 자동 업데이트 | App Store (앱 6821788787) |
| iCloud 저장소 | `iCloud.com.mungyubin.daylog` (`iCloud.$(CFBundleIdentifier)`) | `iCloud.com.mungyubin.daylog` (같음) |
| 샌드박스 | 켜짐 + Sparkle용 임시 예외(mach-lookup) | 켜짐 |
| 의상 구매 | 꺼짐(`#if os(macOS)` → disabled) | 켜짐(`appStore`) |
| 상품 확인 | — | `PioProductRegistry.verifiedBundleID = com.mungyubin.daylog.ios` |

**핵심:** Apple의 앱 내 구입은 App Store로 배포한 앱에서만 된다. 유니버설 구매는 **같은 번들 ID의 앱을 한 App Store 앱 레코드에 묶어야** 한다. 그래서 Mac App Store용 Mac 앱은 번들 ID가 `com.mungyubin.daylog.ios`가 된다. iCloud 저장소는 이미 같아서 기록은 iCloud로 이어진다.

## 3. 먼저 정할 것

| # | 결정 | 제안 |
|---|---|---|
| D1 | Mac App Store 앱의 버전 번호 | **1.0.0** (사용자 결정 2026-10-26. iPhone·iPad는 1.0.1) |
| D2 | DMG 앱은 언제까지 유지하나 | Mac App Store 출시 뒤 **3개월**은 DMG도 받을 수 있게 둔다. 마지막 DMG 업데이트(1.5.12)에서 옮기기 안내 |
| D3 | iCloud를 끈 사용자의 기록 | 1.5.12 DMG에 **"전체 백업 파일로 내보내기"**, Mac App Store 앱에 **"백업 파일 가져오기"** 추가 |
| D4 | Mac 최소 OS | 지금 Mac 앱과 같게 유지(바꾸지 않음) |
| D5 | Mac App Store 앱에서 DMG 기능 중 빠지는 것 | Sparkle(업데이트 확인 메뉴·설정 줄)만 뺀다. 메뉴 막대·창 구성은 그대로 |

## 4. 작업 단계

### 단계 0 — Apple 쪽 준비 (사용자, 약 30분)
1. App Store Connect → 앱 6821788787 → **플랫폼 추가: macOS**.
2. Developer 사이트 → Identifiers → `com.mungyubin.daylog.ios`
   - macOS 사용 가능 여부
   - iCloud(`iCloud.com.mungyubin.daylog`) 연결
   - In-App Purchase 켜짐
3. 계약·세금·은행이 "활성"인지 확인한다(읽기만).
- 인증서·프로필은 Xcode 자동 서명이 만든다. 제가 `-allowProvisioningUpdates`로 처리한다.

### 단계 1 — Mac App Store용 빌드 분리 (Claude, 1일)
- **새 대상 `DaylogMacAppStore`**를 만든다. 지금 Mac 대상과 소스를 함께 쓰고, DMG 대상은 그대로 둔다(전환 기간 동안 둘 다 빌드).
  - 번들 ID `com.mungyubin.daylog.ios`, 플랫폼 macOS
  - 권한: 샌드박스, CloudKit `iCloud.com.mungyubin.daylog`(직접 적음), 푸시 production. **Sparkle 임시 예외는 없음**
  - Info.plist: `SUFeedURL`·`SUPublicEDKey` 없음, `PioStoreKitEnvironment=appStore`, `PioStoreKitCatalogConfirmed=true`, `LSApplicationCategoryType`(생산성)
  - 컴파일 조건 `MAC_APP_STORE`: Sparkle 코드(`DaylogUpdater`, [업데이트 확인] 메뉴, 설정의 업데이트 줄)를 빼고, Sparkle 패키지를 연결하지 않는다
- 테스트: 두 Mac 대상의 Info.plist·권한·연결 프레임워크를 고정하는 단위 테스트(DMG에는 Sparkle이 있고 App Store판에는 없다).

### 단계 2 — Mac에서 구매 켜기 (Claude, 1일)
- `PioPurchaseAvailability`: macOS에서도 `MAC_APP_STORE`이면 Info.plist 설정을 따른다. DMG판은 지금처럼 꺼짐.
- `StoreKitPioClient`: Mac 결제 창은 이미 창에 붙여 띄운다(`purchase(confirmIn:)`). 복원·환불 알림·재실행은 iOS와 같은 경로라 그대로 쓴다.
- 옷장(Mac): 구매 단추·복원 단추를 켠다. "앱 아이콘" 탭은 Mac에서 숨긴다(**지금 1.5.11에 보이는 문제도 이때 고침**).
- DMG판의 문구는 "의상은 iPhone·iPad·Mac App Store 버전에서 구매할 수 있어요"로 바꾼다.

### 단계 3 — 기록 옮기기 (Claude, 1~2일)
- **iCloud 사용자:** 새 앱이 처음 열리면 iCloud에서 기록을 받는다(첫 동기화 안내 화면이 이미 있다). 기기 설정(화면 배치·알림 등 이 기기에만 있는 값)은 새로 잡힌다. 이 값들을 백업 파일에 함께 넣어 옮길지는 단계 3-2에서 처리한다.
- **3-2 백업 파일:** DMG 1.5.12에 [전체 백업 내보내기]를 넣는다. 저장소 파일과 기기 설정을 사용자가 고른 곳에 한 파일로 저장한다(기존 `StoreBackup` 활용). Mac App Store 앱에는 [백업 파일 가져오기]를 넣는다. 저장소가 비어 있을 때만 받고, 개수 대조로 확인한다.
- 같은 Mac에 두 앱이 함께 있어도 iCloud에서는 기기 두 대처럼 동작한다(저장소 폴더가 달라 서로 잠그지 않음). 시험으로 확인한다.

### 단계 4 — DMG 사용자 전환 (Claude, 0.5일)
- DMG 1.5.12(Sparkle 업데이트)를 낸다.
  - Mac App Store 버전 안내 배너와 링크
  - 전체 백업 내보내기
  - 앱 아이콘 탭 숨김
  - 구매 안내 문구 수정
- Mac App Store 승인 **뒤에** 게시한다(링크가 열려야 하므로). 이후 DMG는 버그 수정만 한다.

### 단계 5 — 시험 (Claude + 사용자, 1일)
| 시험 | 방법 | 통과 기준 |
|---|---|---|
| Mac Sandbox 결제 | 이 Mac에서 개발 서명 Mac App Store 빌드 + Sandbox 계정 | 결제 창 `[Environment: Sandbox]`, 구매 후 바로 입기, 재실행 유지 |
| **유니버설 구매** | iPhone TestFlight에서 산 의상 → Mac TestFlight 빌드에서 [구매 복원] | Mac에서도 입을 수 있음(같은 Apple 계정) |
| 환불·회수 | Sandbox 구매 내역 지우기 | Mac·iPhone 모두 기본 피오로 복귀 |
| iCloud 이어짐 | 실제 계정의 이 Mac에 새 앱 설치 | 루틴·기록 개수가 DMG 앱과 같음 |
| 백업 옮기기 | 검증용 번들로 내보내기 → 가져오기 | 개수 대조 일치 |
| 심사 준비 | 권한에 임시 예외 없음, 개인정보 매니페스트, 수출 규정 | 업로드 검증 통과 |
- Mac TestFlight는 App Store Connect에서 macOS 빌드를 올리면 바로 쓸 수 있다.

### 단계 6 — 제출 (사용자)
1. Mac 스크린샷을 올린다(1280×800 이상). 제가 만들어 드린다.
2. Mac 버전 1.6.0을 제출한다. 의상 13종은 iOS 1.0.1과 함께 처음 심사받으면 Mac은 그 상품을 그대로 쓴다.
3. 승인 → 출시 → DMG 1.5.12를 게시한다(단계 4).

## 5. 누가 무엇을

| 일 | 사용자 | Claude |
|---|---|---|
| App Store Connect 플랫폼 추가, 계약 확인 | ✅ | |
| App ID 설정 확인 | ✅ (화면 확인) | 자동 서명으로 프로필 생성 |
| 새 Mac 대상, 구매 켜기, 기록 옮기기, DMG 1.5.12 | | ✅ |
| Sandbox·TestFlight 결제 승인 | ✅ (암호·Face ID/Touch ID) | 화면 확인·기록 |
| 스크린샷 | | ✅ 제작 |
| 심사 제출, 출시 | ✅ | |
| GitHub DMG 게시 | | ✅ (승인 후) |

## 6. 위험과 대응

| 위험 | 대응 |
|---|---|
| iCloud를 끈 사용자의 기록 유실 | 백업 파일 옮기기(단계 3-2). 새 앱은 저장소가 비어 있을 때만 가져온다 |
| 두 앱이 함께 있어 사용자가 헷갈림 | DMG 앱에 "Mac App Store 버전으로 옮겼어요" 배너. 옮긴 뒤 DMG 앱을 지워도 기록은 iCloud·새 앱에 있음을 안내 |
| 심사에서 권한 문제 | App Store판에서 Sparkle과 임시 예외를 제거한다. 업로드 전에 `codesign -d --entitlements`로 확인 |
| 번들 ID가 같은 iOS 앱(Mac에서 iPad 앱으로 실행)과 충돌 | Mac 플랫폼이 생기면 App Store는 Mac에 Mac 빌드를 준다. iPad 앱의 Mac 제공은 App Store Connect에서 끈다 |
| 이미 산 사용자에게 Mac 판매 화면이 다시 뜸 | 시작 시 `Transaction.currentEntitlements`로 소유를 읽는다(iOS와 같은 경로) |
| DMG 1.5.11에서 무료 착용이 사라진 데 대한 불만 | 1.5.12 안내 문구로 "Mac App Store 버전에서 구매·복원 가능"을 알림 |

## 7. 일정 (추정)
- 단계 0: 사용자 30분
- 단계 1~4: Claude 3~4일 분량(세션 기준 2~3번)
- 단계 5: 1일
- 단계 6: 심사 1~3일
- **총 약 1~2주**(심사 포함)

## 8. 승인되면 바로 하는 일
1. 단계 1의 새 Mac 대상을 만들고, 이 Mac에서 개발 서명으로 실행 확인(구매는 아직 꺼진 채)
2. 단계 2 구매 켜기 → Mac Sandbox 결제 시험
3. 그동안 사용자는 단계 0(App Store Connect 플랫폼 추가)
