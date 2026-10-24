# Routimori — App Store Connect 상품 등록 안내

작성 기준: 2026-10-16. **등록 준비용 문서이며 실제 판매 활성화 승인이 아닙니다.** 이 작업은 App Store Connect에 접속하거나 상품을 등록하지 않습니다.

## 확정 카탈로그와 상품 ID

실제 `PioOutfitID`는 기본 1개 + 유료 13개 = **총 14개**입니다. 요청의 “총 13개/유료 12개”와 목록 사이의 불일치는 기존 승인 카탈로그를 보존하는 방식으로 처리했습니다. `basic`은 항상 무료이며 StoreKit 상품을 만들지 않습니다.

기존 iOS 번들 ID는 `com.mungyubin.daylog.ios`, Mac 번들 ID는 `com.mungyubin.daylog`입니다. 변경하지 않습니다. 상품 ID는 iOS 번들 ID와 기존 의상 raw value를 사용합니다. 대소문자까지 아래 표와 정확하게 일치해야 합니다. 권위 있는 코드 매핑은 `Daylog/Services/PioProductRegistry.swift`입니다.

모든 상품은 **Non-consumable / 비소모성**, 1회 구매 후 영구 이용, 구매 복원 가능, 구독 없음입니다. 관련 아이콘 테마 권한도 포함되며 아이콘을 별도 판매하지 않습니다. 실제 아이콘 변경은 번들에 등록된 지원 아이콘에 한해서만 가능하고, 현재 누락된 테마는 선택 불가로 표시됩니다.

| Related outfit ID | Exact Product ID | Reference name | 한국어 표시 이름 | 한국어 설명 | Type | 목표 한국 가격 |
|---|---|---|---|---|---|---|
| `cherryBlossom` | `com.mungyubin.daylog.ios.outfit.cherryBlossom` | Pio Outfit - Cherry Blossom | 벚꽃 피오 | 벚꽃 피오 의상을 영구 소장해요. | Non-consumable | KRW 2,000 |
| `summerVacation` | `com.mungyubin.daylog.ios.outfit.summerVacation` | Pio Outfit - Summer Vacation | 여름 휴가 피오 | 여름 휴가 피오 의상을 영구 소장해요. | Non-consumable | KRW 2,000 |
| `autumn` | `com.mungyubin.daylog.ios.outfit.autumn` | Pio Outfit - Autumn | 가을 피오 | 가을 피오 의상을 영구 소장해요. | Non-consumable | KRW 2,000 |
| `winter` | `com.mungyubin.daylog.ios.outfit.winter` | Pio Outfit - Winter | 겨울 피오 | 겨울 피오 의상을 영구 소장해요. | Non-consumable | KRW 2,000 |
| `halloween` | `com.mungyubin.daylog.ios.outfit.halloween` | Pio Outfit - Halloween | 할로윈 피오 | 할로윈 피오 의상을 영구 소장해요. | Non-consumable | KRW 2,000 |
| `christmas` | `com.mungyubin.daylog.ios.outfit.christmas` | Pio Outfit - Christmas | 크리스마스 피오 | 크리스마스 피오 의상을 영구 소장해요. | Non-consumable | KRW 2,000 |
| `hanbok` | `com.mungyubin.daylog.ios.outfit.hanbok` | Pio Outfit - Hanbok | 한복 피오 | 한복 피오 의상을 영구 소장해요. | Non-consumable | KRW 2,000 |
| `cafe` | `com.mungyubin.daylog.ios.outfit.cafe` | Pio Outfit - Cafe | 카페 피오 | 카페 피오 의상을 영구 소장해요. | Non-consumable | KRW 2,000 |
| `student` | `com.mungyubin.daylog.ios.outfit.student` | Pio Outfit - Student | 학생 피오 | 학생 피오 의상을 영구 소장해요. | Non-consumable | KRW 2,000 |
| `fitness` | `com.mungyubin.daylog.ios.outfit.fitness` | Pio Outfit - Fitness | 운동 피오 | 운동 피오 의상을 영구 소장해요. | Non-consumable | KRW 2,000 |
| `rainyDay` | `com.mungyubin.daylog.ios.outfit.rainyDay` | Pio Outfit - Rainy Day | 비 오는 날 피오 | 비 오는 날 피오 의상을 영구 소장해요. | Non-consumable | KRW 2,000 |
| `pajamas` | `com.mungyubin.daylog.ios.outfit.pajamas` | Pio Outfit - Pajamas | 잠옷 피오 | 잠옷 피오 의상을 영구 소장해요. | Non-consumable | KRW 2,000 |
| `astronaut` | `com.mungyubin.daylog.ios.outfit.astronaut` | Pio Outfit - Astronaut | 우주인 피오 | 우주인 피오 의상을 영구 소장해요. | Non-consumable | KRW 2,000 |

**KRW 2,000은 목표 가격입니다.** 앱의 실제 결제 가격은 `Product.displayPrice`로 표시합니다. 상품이 없거나 로드에 실패하면 구매를 비활성화합니다. 현지 통화, 세금, 다른 스토어 가격을 앱이 추정하지 않습니다.

## 사용자가 직접 등록하는 순서

1. App Store Connect에서 기존 iOS 앱을 선택합니다. Monetization → In-App Purchases → `+`로 이동합니다.
2. 각 행을 **Non-Consumable**로 생성하고 정확한 Product ID와 Reference name을 입력합니다. 기본 의상 상품은 만들지 않습니다. [Apple 상품 생성 안내](https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/create-consumable-or-non-consumable-in-app-purchases)
3. 한국어 현지화에 표의 이름과 설명을 입력하고, 판매 지역과 심사 정보·심사용 스크린샷을 준비합니다. [Apple 상품 정보 안내](https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/view-and-edit-in-app-purchase-information)
4. Price Schedule에서 대한민국을 기준 지역으로 선택해 **KRW 2,000** 가격을 확인합니다. 가격 목록에 보이지 않으면 추가 가격을 확인하세요. 계약·세금·은행 정보 및 유료 앱 계약도 계정 소유자가 확인해야 합니다. [Apple 가격 설정 안내](https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/set-a-price-for-an-in-app-purchase)
5. 상품 ID 13개를 코드/로컬 파일과 대조하고, 별도의 승인된 후속 작업에서 Sandbox 계정 및 실제 기기의 구매·복원·환불을 검증합니다. 등록 즉시 이 코드의 판매 잠금이 해제되지는 않습니다.
6. Sandbox 검증과 사용자 명시적 출시 승인 후에만 배포용 StoreKit 환경 지원 및 판매 허용 정책을 별도 변경합니다. 현재 작업에서는 심사 제출, TestFlight 업로드, 배포를 하지 않습니다.

## 로컬 StoreKit 테스트

**최신 실행 요약:** iOS 전체 통합 테스트는 명시적 오류 정리 fixture 적용 후 11개 중 **7개 통과/4개 실패**, 별도 프로세스 3개 검증은 **2개 통과/1개 실패**입니다. 후속 13개 구매 단독 테스트는 최대 3초 관찰 조건에서 첫 미완료 거래 조회부터 비어 있어 통과했지만, 직전 즉시 조회 실패와 전체 실행 실패를 대체하지 않습니다. Mac 단위 테스트 **44/44**와 Release 빌드는 통과했습니다. iPhone의 실제 Xcode 결제창 구매·취소·복원·프로세스 재실행은 확인했지만, Mac은 최종 재시도에서도 실제 확인창이 나타나지 않아 미검증입니다. 이 결과를 전체 통과나 출시 가능으로 해석하지 마세요. 항목별 로그·화면·검사 조건 차이는 [StoreKit 검증 결과](docs/qa/routimori-storekit-2026-10-16/STOREKIT-RESULTS.md)를 기준으로 확인하세요.

`Routimori.storekit`은 App Store Connect 동기화가 없는 로컬 구성입니다. 유료 상품 13개, 비소모성, 한국 스토어(`KOR`), 한국어(`ko_KR`), 각 `2000`을 설정합니다. 로컬 거래는 실제 결제나 App Store 서버 연결 없이 StoreKit API를 실행합니다. [Apple 로컬 테스트 설정](https://developer.apple.com/documentation/xcode/setting-up-storekit-testing-in-xcode)

전용 공유 scheme:

- `DaylogStoreKitTests`: Mac 앱 + 기존 Mac 단위 테스트 대상에서 피오 관련 단위 테스트와 StoreKit 통합 테스트를 선택.
- `DaylogiOSStoreKit`: iPhone/iPad 시뮬레이터 앱 + 새 iOS StoreKit 테스트 대상.

두 scheme은 Debug 전용으로 로컬 구성과 `-pio-storekit-testing` 인자를 사용합니다. 기존 `Daylog`, `DaylogiOS` scheme 및 Release 서명/번들 ID는 유지합니다. 테스트 scheme은 프로파일/아카이브 작업을 제공하지 않습니다. UI 실행은 `routimori-storekit-review` 전용 데이터 저장소와 옷장 화면 인자를 사용합니다. 테스트는 자체 UUID UserDefaults를 사용하며 테스트 세션마다 로컬 거래를 초기화합니다.

구매 어댑터는 구매·복원 전에 **검증된 `AppTransaction.environment == .xcode`**를 요구하며, 권한도 검증된 `.xcode` 거래만 인정합니다. Release와 일반 실행에서 판매는 잠겨 있습니다. 과거 mock UserDefaults는 실제 구매로 승격되지 않습니다. 이 검증이 SDK 내부 요청 경로까지 보장하는 것은 아닙니다. 아래와 같은 계정 로그인창이 나타나면 자격 증명을 입력하지 말고 취소 후 테스트 환경을 점검하세요.

Xcode에서 해당 scheme과 시뮬레이터/Mac을 선택해 Run 또는 Test를 실행하세요. 구성 파일은 루트 경로에 유지해야 합니다. 자동화 테스트는 테스트 번들의 구성(또는 `#filePath` 기준 루트 파일)을 `SKTestSession(contentsOf:)`로 엽니다. 제품 앱의 리소스에 테스트 구성을 포함하지 않습니다.

예시 명령(별도 DerivedData로 빌드하며 설치된 Mac 앱을 교체하지 않음):

```sh
xcodebuild -project Daylog.xcodeproj -scheme DaylogStoreKitTests \
  -destination 'platform=macOS' -derivedDataPath /tmp/routimori-storekit-mac \
  -parallel-testing-enabled NO -test-iterations 10 \
  -resultBundlePath /tmp/routimori-storekit-mac.xcresult test

xcodebuild -project Daylog.xcodeproj -scheme DaylogiOSStoreKit \
  -destination 'platform=iOS Simulator,id=<SIMULATOR-UUID>' \
  -derivedDataPath /tmp/routimori-storekit-ios \
  -parallel-testing-enabled NO -test-iterations 10 \
  -resultBundlePath /tmp/routimori-storekit-ios.xcresult test
```

설치된 Xcode/프로젝트에 맞는 개발 서명이 필요할 수 있습니다. 자동화 테스트는 [Apple StoreKitTest](https://developer.apple.com/documentation/storekittest)로 진짜 로컬 StoreKit 거래를 생성합니다. 실패 시 xcresult에 거래 ID/상품/상태/보류 여부가 첨부됩니다. 테스트는 세션 단위로 전역 StoreKit 상태를 바꾸므로 같은 앱의 StoreKit 테스트를 병렬 실행하지 마세요.

자동화 범위: 상품 13개/타입/구성 가격·현지화 표시 가격/통화, 유료 13개 각각의 실제 구매·장착·승인 이미지 로드·거래 finish, 구매 성공, 중복 구매 방지, 구매 관리자 재생성 후 권한 회복, 반복 장착, Ask to Buy 보류 및 승인 업데이트, 환불 업데이트, 명시적 복원, SDK 취소 오류, 실패 후 재시도, 상품 로드 실패 후 재시도, 검증 오류 거부, 중단된 구매의 문제 해결.

**관리자 재생성 테스트는 OS 프로세스 재실행과 구별됩니다.** Apple 결제창에서 직접 취소, 앱 강제 종료 후 재실행, 화면 상태/VoiceOver/라이트·다크, iPad 레이아웃은 아래 수동 QA로 확인해야 합니다. 테스트 코드 존재만으로 성공을 뜻하지 않으며 실제 실행 결과는 최종 QA 보고서에서 확인하세요. Xcode 로컬 결과는 Sandbox/실결제/서버 등록 검증을 의미하지 않습니다.

## 로컬 가격 숫자 속성 불일치 — PARTIAL

설치된 Xcode 27 / macOS 27의 로컬 StoreKit 런타임에서 구성 가격 `2000.00`에 대해 13개 상품 모두 `displayPrice == "₩2,000"`, 통화 `KRW`, 상품 JSON `priceString == "2,000"`을 반환했지만, `Product.price` 숫자 속성은 `2`를 반환했습니다. 정수 문자열 `2000`과 소수 문자열 `2000.00` 모두 같은 결과였습니다. 숫자 가격 API의 일관성 검증은 **PARTIAL**이며 통과로 처리하지 않습니다.

앱은 요청대로 Apple의 `displayPrice`를 그대로 표시합니다. 이 현상을 감추기 위한 앱 가격 보정이나 구성 가격 1,000배 증가는 적용하지 않았습니다. 자동화는 원본 구성의 Decimal 2000, 비소모성 타입, `KRW`, 실제 표시 가격 `₩2,000`을 검증합니다. `Product.price`와 원본 JSON도 xcresult 첨부 자료에 보존합니다. 향후 Sandbox/실기기 검증 시 숫자 속성과 실제 결제창 가격을 다시 대조해야 합니다. 이 결과는 등록할 실제 상품 가격을 변경할 근거가 아닙니다.

## iOS 자동화 환경 진단

2026-10-16의 첫 iOS 27 CLI 실행은 `.xcode` 앱 거래 검증과 13개 상품 조회에 성공했지만, 구매 시 `disableDialogs = true` 설정에도 Apple 계정 로그인창이 나타났습니다. 계정 정보는 입력하지 않았습니다. 계정창을 직접 취소한 뒤 통과한 취소 테스트는 자동 오류 주입 성공의 증거로 간주하지 않습니다. 같은 시뮬레이터에 남아 있던 이전 테스트 앱 프로세스를 종료한 뒤, 13개 전체 실제 구매·장착·승인 이미지 로드 테스트는 계정창 없이 단독 실행에서 통과했습니다(8.9초). 프로세스 종료가 유일한 원인을 증명하지는 않습니다.

설정 파일은 시뮬레이터 StoreKit의 해당 번들 ID 구성 경로에 존재했고 13개 상품을 포함했습니다. 테스트 설정 첨부 자료에는 `disableDialogs` 조회 값도 기록합니다. [Apple DTS의 유사 CLI/시뮬레이터 문제](https://developer.apple.com/forums/thread/826971)는 참고 자료이며, 현재 실행의 원인을 입증하지 않습니다. 실제 통과 여부는 QA 보고서의 최신 실행 결과를 기준으로 판단하세요.

이후 같은 프로세스에서 11개 전체 테스트를 실행했을 때는 6개 통과/5개 실패였습니다. 단독 통과한 전체 구매 테스트의 미완료 거래, 중단 구매의 조기 권한, 검증 오류 주입 결과 차이가 관찰되어 프로세스 간 비교가 필요합니다. 거래 ID 재사용 또는 SDK 캐시는 조사 가설입니다. [Apple 문서](https://developer.apple.com/documentation/storekittest/sktestsession)는 모든 세션이 하나의 환경을 공유한다고 명시하며, 공개 API에는 거래 ID 지정이나 StoreKit 프로세스 캐시 초기화 기능이 없습니다. 테스트는 기존 검증을 유지하고 초기 빈 거래 목록, 프로세스 ID, 미완료 거래 식별자를 기록합니다.

후속 거래 종료 관찰 테스트는 처음 스냅샷과 최대 3초의 관찰 결과를 모두 저장하며, 관찰 중 finish·sync·clear를 호출하지 않습니다. 통과 실행에서는 첫 조회 약 0.008345625초에 이미 비어 있었으므로 **SDK 지연이 입증된 것은 아닙니다**. 동시 종료 요청 처리 변경 후 즉시 확인 실패도 있었으므로, 해당 변경이 기존 실패의 원인을 해결했다고 주장하지 않습니다. 전체 실행 결과와 단독 관찰 결과를 함께 보존합니다.

재현 시 먼저 위 명령의 `test` 대신 `build-for-testing`을 한 번 실행한 후, 각 메서드를 아래처럼 별도의 `xcodebuild` 호출로 실행하세요. 각 호출마다 다른 결과 경로를 사용하고 실패한 테스트도 기록합니다. `-test-repetition-relaunch-enabled YES`는 반복 사이의 재실행 옵션이므로, 같은 회차의 여러 테스트 메서드를 각각 격리하는 대체 수단은 아닙니다.

```sh
xcodebuild -project Daylog.xcodeproj -scheme DaylogiOSStoreKit \
  -destination 'platform=iOS Simulator,id=<SIMULATOR-UUID>' \
  -derivedDataPath /tmp/routimori-storekit-ios -parallel-testing-enabled NO \
  -only-testing:DaylogStoreKitTests/PioStoreKitIntegrationTests/testEveryPremiumOutfitPurchasesEquipsAndLoadsApprovedArtwork \
  -resultBundlePath /tmp/routimori-storekit-ios-all-outfits.xcresult test-without-building
```

메서드 목록은 `DaylogStoreKitTests/PioStoreKitIntegrationTests.swift`의 `test…` 함수입니다. 단독 실행 통과로 전체 실행 실패를 삭제하거나 통과로 바꾸지 않으며, 두 실행 모드의 결과를 함께 보존합니다.

반복 실행은 `Tools/storekit/run-isolated-tests.py`로 자동화할 수 있습니다. 먼저 현재 소스로 `build-for-testing`을 완료해야 합니다. 스크립트는 기존 DerivedData의 `.xctestrun`을 확인하고, 선택한 메서드마다 별도 `test-without-building`을 순차 실행합니다. 실패해도 다음 메서드를 실행하며 각 로그·xcresult·`summary.json`을 새 출력 폴더에 남깁니다. 제한 시간 초과나 사용자 중단은 남은 실행도 중단합니다. 종료 코드가 0이어도 선택한 XCTest의 실제 통과 기록이 없으면 실패로 처리합니다.

```sh
python3 Tools/storekit/run-isolated-tests.py \
  --platform ios --simulator-id '<SIMULATOR-UUID>' \
  --derived-data /tmp/routimori-storekit-ios \
  --output /tmp/routimori-storekit-isolated-results \
  --test testVerificationFailureNeverGrantsFreshManagerOwnership \
  --test testRefundUpdateRevokesAccessAndRefreshResetsEquipment \
  --test testInterruptedPurchaseOnlyUnlocksAfterResolution \
  --dry-run
```

`--dry-run`은 명령만 출력합니다. 실제 실행 시 제거하세요. `--test` 생략 시 현재 파일의 11개 메서드를 모두 실행합니다. `--repeat 10`은 재시도 성공으로 실패를 덮는 대신, 모든 반복을 개별 결과로 보존합니다. Mac은 `--platform macos`와 Mac DerivedData를 지정하고 `--simulator-id`를 생략합니다. 빌드 때 별도 패키지 경로를 사용했다면 `--cloned-source-packages <기존 경로>`도 지정합니다. 스크립트는 빌드·실기기 실행·운영 앱 설치·프로세스 일괄 종료를 하지 않습니다. **테스트 자체는 로컬 거래를 초기화하므로 수동 구매/재실행 검증 중인 시뮬레이터에서 동시에 실행하지 마세요.**

별도의 iPhone 수동 검증에서는 Xcode 표시가 있는 Apple 결제창 취소, 벚꽃 상품 구매, 장착, 명시적 복원(1개), 기존 프로세스 종료 후 새 프로세스에서 보유·장착 유지를 확인했습니다. 이 화면 결과는 자동 오류 주입의 실패를 대체하지 않습니다. 환불은 별도 프로세스 자동화에서 통과했지만 전체 실행에서는 실패했습니다. 항목별 최신 증거는 위 QA 보고서를 확인하세요.

## 화면 QA 절차

1. 전용 scheme으로 실행 → 설정 → 피오 옷장 → 유료 의상 미리보기. 가격은 StoreKit 반환 값인지 확인합니다.
2. 구매 버튼 → Apple 테스트 결제창 → 취소. 잠김 유지, 오류 경고 없이 취소 안내, 재시도 가능 여부를 확인합니다.
3. 다시 구매 → 승인 → 보유 표시 → 장착. 기본과 구매 의상 사이를 반복 전환합니다.
4. 앱을 종료하고 같은 scheme으로 다시 실행합니다. 거래를 지우지 않은 상태에서 보유/장착 유지 여부를 확인합니다.
5. `구매 복원`을 눌러 복원 결과를 확인합니다. 거래가 없는 초기 상태에서도 빈 복원 안내를 확인합니다.
6. Xcode Debug → StoreKit → Manage Transactions에서 구매 거래를 환불합니다. 의상 권한이 사라지고 장착한 경우 기본 피오로 전환되는지 확인합니다.
7. `Routimori.storekit` 편집기의 Ask to Buy / Interrupted Purchases / StoreKit 오류 설정을 사용해 보류·실패·재시도를 확인하고, 완료 후 설정을 되돌립니다.
8. iPhone/iPad 및 Mac에서 구매 전·취소·보유·장착·복원·실패 화면을 각각 기록합니다. 자동화에서 결제창을 숨기는 것은 테스트에만 적용되며 수동 실행은 결제창을 표시합니다.

## Mac 배포 제약

현재 Mac 앱은 `docs/UPDATES.md`에 명시된 GitHub Releases DMG + Sparkle 직접 배포입니다. 이 작업은 Mac App Store 전환, Sparkle 설정, 기존 배포 채널을 변경하지 않습니다. 현재 iOS App Store 구매를 이 직접 배포 Mac 앱으로 공유한다고 주장하지 않으며, 일반 Mac 실행에서는 구매/복원이 비활성화됩니다. Mac의 전용 Debug scheme에서는 Xcode 로컬 테스트만 가능합니다.

실제 Mac 구매 또는 iOS와의 공유 권한이 필요하면 후속 작업에서 Mac App Store 배포/앱 구성 또는 별도로 검증된 계정·서버 권한 구조를 먼저 결정해야 합니다. UserDefaults, 로컬 JSON, iCloud 플래그만으로 결제 권한을 공유해서는 안 됩니다.

## 이 작업의 경계

App Store Connect 접근/상품 등록/심사 제출 없음, 실결제 없음, TestFlight 업로드 없음, 기존 설치 앱 교체 없음, GitHub Release/커밋/push/배포 없음. 기본 의상은 무료이며 의상·아이콘 설정은 루틴/XP/SwiftData/CloudKit 모델을 바꾸지 않습니다.
