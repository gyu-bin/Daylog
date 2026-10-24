# 피오 의상 — 확인된 App Store Connect 카탈로그

2026-10-23 18:34:46 KST, 로그인된 Aside의 읽기 전용 App Store Connect 조회로 확인했습니다. 앱은 **Routimori**, Apple ID `6821788787`, iOS 번들 ID `com.mungyubin.daylog.ios`입니다. 앱·상품·가격·메타데이터를 수정하거나 구매하지 않았습니다.

**카탈로그 정합 PASS. 전체 출시 준비는 PARTIAL.** 실제 Sandbox 구매·복원은 아직 검증하지 않았으며 13개 상품 모두 `MISSING_METADATA`입니다.

## 단일 코드 매핑

권위 있는 런타임 매핑은 `Daylog/Services/PioProductRegistry.swift`입니다. 상품 ID를 번들 ID나 의상 raw value로 생성하지 않습니다. 원화 이름과 기기 내 착용 선호 키는 기존 값을 그대로 사용합니다. 기본 피오는 항상 무료이며 상품이 없습니다.

| 의상 키 | ASC 표시 이름 | 실제 Product ID | ASC ID | 한국 가격 |
|---|---|---|---|---:|
| `cherryBlossom` | 벚꽃 피오 | `outfit.cherryblossom` | `6823655655` | ₩2,500 |
| `summerVacation` | 여름휴가 피오 | `outfit.summer` | `6823655944` | ₩2,500 |
| `autumn` | 가을 피오 | `outfit.autumn` | `6823656729` | ₩2,500 |
| `winter` | 겨울 피오 | `outfit.winter` | `6823657805` | ₩2,500 |
| `halloween` | 할로윈 피오 | `outfit.halloween` | `6823658427` | ₩2,500 |
| `christmas` | 크리스마스 피오 | `outfit.christmas` | `6823658798` | ₩2,500 |
| `hanbok` | 한복 피오 | `outfit.hanbok` | `6823659160` | ₩2,500 |
| `cafe` | 카페 피오 | `outfit.cafe` | `6826170409` | ₩2,500 |
| `student` | 학생 피오 | `outfit.student` | `6826170542` | ₩2,500 |
| `fitness` | 운동 피오 | `outfit.workout` | `6826170417` | ₩2,500 |
| `rainyDay` | 비 오는 날 피오 | `outfit.rainy` | `6826170753` | ₩2,500 |
| `pajamas` | 잠옷 피오 | `outfit.pajamas` | `6826170450` | ₩2,500 |
| `astronaut` | 우주복 피오 | `outfit.space` | `6826170811` | ₩2,500 |

모두 비소모성, 가족 공유 꺼짐, 한국 기준 수동 가격, 175개 지역 판매 설정입니다. 기존 7종도 실제 등록 가격이 2,500원으로 확인됐습니다. `Routimori.storekit`은 이 ID·한국 표시 이름·가격을 미러링하는 **로컬 구성**입니다. 앱 UI는 구성 숫자나 목표 가격 대신 Apple `Product.displayPrice` / `displayName`을 표시합니다. 상품 조회 실패 시 추정 가격으로 결제하지 않습니다.

## 실행 환경과 판매 정책

- **로컬 Xcode:** Debug 전용 `-pio-storekit-testing`; 검증된 `AppTransaction.environment == .xcode`와 Xcode 거래만 허용합니다. 단, 앱 영수증 검사만으로 SDK의 결제 UI 경로가 보장되지는 않습니다. 실제 CLI 시험에서 Xcode 영수증이 있어도 Apple 로그인 화면으로 넘어가는 현상이 있었고 입력 없이 중단했습니다. 전용 시뮬레이터에서 Xcode의 연결된 `Routimori.storekit`으로 먼저 Run한 후 테스트했을 때 `XcodeTest` 거래가 확인됐습니다. 일반 테스트/운영 앱과 착용 선호 저장소가 분리됩니다.
- **Apple Sandbox:** iOS에서 `PioStoreKitEnvironment=sandbox` 및 `PioStoreKitCatalogConfirmed=true`를 번들 설정에 명시한 별도 검증 빌드가 필요합니다. 확인된 카탈로그 외에 실제 앱/거래 번들 ID·환경·서명도 검사합니다. 이 작업에서는 실제 Sandbox 계정/구매를 사용하지 않습니다.
- **App Store / TestFlight:** iOS의 명시적 `appStore` 설정에서 production 또는 sandbox 서명 거래를 허용하고 Xcode 거래를 거부하도록 구현했습니다. **현재 번들 설정은 추가·활성화하지 않았으므로 기본 판매 경로는 닫혀 있습니다.** Sandbox·실기기 QA 후 별도 출시 단계에서 설정해야 합니다.
- **Mac:** 현재 직접 배포 타깃은 `com.mungyubin.daylog`로, 확인한 iOS 앱과 다릅니다. 일반 Mac 구매는 비활성화하며 Debug Xcode 로컬 검증만 지원합니다. iOS 상품 확인만으로 Mac App Store 판매 준비를 주장하지 않습니다.

UserDefaults의 착용 선호·과거 mock 소유 기록은 구매 권한이 아닙니다. 실제 권한은 검증된 StoreKit 거래, `Transaction.currentEntitlements`, `Transaction.updates`에서만 얻습니다. 일반 실행에서 미구매 의상은 미리보기만 가능하고, 상점 비활성화가 유료 착용을 허용하지 않습니다. 별도 Debug `-pio-wardrobe-testing` 화면만 격리된 의상 테스트 권한을 가집니다.

## 출시 전 외부 확인 사항

1. **필수:** 13개 상품의 심사용 스크린샷 누락을 해소하고 상품 제출·검토 상태를 확인해야 합니다. 심사 메모·홍보 이미지는 현재 없지만 선택 항목이므로 필수라고 잘못 안내하지 않습니다.
2. 기존 7종 ASC 설명에는 전용 앱 아이콘이 포함된다고 되어 있지만 앱의 `registeredThemes`는 비어 있습니다. 판매 전 실제 아이콘을 구현하거나 설명을 실제 제공 범위에 맞추는 결정이 필요합니다. 이 작업은 아이콘 원화를 만들거나 ASC 설명을 변경하지 않습니다.
3. 실제 Sandbox에서 상품 13개 조회·지역별 가격·구매 승인/취소/대기·복원·프로세스 재실행·환불·오프라인을 실기기에서 검증해야 합니다.
4. 유료 앱 계약·세금·은행 상태 및 다른 지역 가격은 이번 읽기 전용 확인 범위가 아니었습니다.
5. 로컬 자동 테스트의 원본 로그와 실패 기록은 보존합니다. 단독 테스트 통과가 전체 실행 실패를 대체하지 않습니다. 최신 결과는 아래 보고서를 기준으로 합니다.

## 증거와 검증 결과

- [ASC 읽기 전용 확인 원본](docs/qa/pio-storekit-integration-2026-10-23/asc-products-confirmed.json)
- [코드/구성/ASC 13종 정합 검사](docs/qa/pio-storekit-integration-2026-10-23/catalog-verification.json)
- [최신 구매·착용·복원 검증 결과](docs/qa/pio-storekit-integration-2026-10-23/RESULTS.md)
- 이전 2026-10-16 안내 원본과 해당 날짜 QA는 보존돼 있으며, 예전 ID·2,000원 목표·통과/실패 기록은 현재 카탈로그의 기준이 아닙니다.

커밋·푸시·배포·운영 앱 교체·실제 결제를 수행하지 않습니다. SwiftData/CloudKit/사용자 기록 및 기존 원화·애니메이션 타이밍은 변경하지 않습니다.
