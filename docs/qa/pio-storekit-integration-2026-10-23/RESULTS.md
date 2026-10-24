# 피오 의상 13종 StoreKit 2 통합 결과 — 2026-10-23

**전체 판정: PARTIAL. 출시 준비 완료가 아닙니다.** 실제 App Store Connect 상품 정합성과 구매 권한 처리 개선은 완료했지만, 로컬 연속 구매 검사의 실패와 프로세스 재실행 검증 문제가 남았습니다. 실제 Apple Sandbox·실기기 구매는 **NOT_TESTED**입니다.

## 1. 실제 카탈로그 확인 — PASS

로그인된 Aside에서 2026-10-23 18:34:46 KST에 **읽기 전용**으로 확인했습니다. Routimori의 Apple ID는 `6821788787`, iOS 번들은 `com.mungyubin.daylog.ios`입니다. ASC 상품·가격·메타데이터를 수정하지 않았습니다.

| 의상 | 실제 Product ID | ASC 상품 ID | 확인한 한국 가격 |
|---|---|---|---:|
| 벚꽃 | `outfit.cherryblossom` | `6823655655` | ₩2,500 |
| 여름휴가 | `outfit.summer` | `6823655944` | ₩2,500 |
| 가을 | `outfit.autumn` | `6823656729` | ₩2,500 |
| 겨울 | `outfit.winter` | `6823657805` | ₩2,500 |
| 할로윈 | `outfit.halloween` | `6823658427` | ₩2,500 |
| 크리스마스 | `outfit.christmas` | `6823658798` | ₩2,500 |
| 한복 | `outfit.hanbok` | `6823659160` | ₩2,500 |
| 카페 | `outfit.cafe` | `6826170409` | ₩2,500 |
| 학생 | `outfit.student` | `6826170542` | ₩2,500 |
| 운동 | `outfit.workout` | `6826170417` | ₩2,500 |
| 비 오는 날 | `outfit.rainy` | `6826170753` | ₩2,500 |
| 잠옷 | `outfit.pajamas` | `6826170450` | ₩2,500 |
| 우주복 | `outfit.space` | `6826170811` | ₩2,500 |

기본 피오는 무료이고 상품 ID가 없습니다. 13종 모두 비소모성이며 **기존 7종도 한국 가격이 2,500원**입니다. 코드·로컬 구성·실제 ASC ID 집합, 중복·누락, 한국 표시 이름과 구성 가격을 별도 검사해 일치했습니다.

증거: [ASC 확인 기록](asc-products-confirmed.json), [카탈로그 정합 검사](catalog-verification.json), [상품 안내](../../../APP_STORE_CONNECT_PRODUCTS.md).

## 2. 주요 변경 파일

| 파일 | 변경 사항 |
|---|---|
| `Daylog/Services/PioProductRegistry.swift` | 실제 13종 ID를 유일한 런타임 매핑으로 관리. 원화·선호 저장 키와 상품 ID 분리. 확인한 앱/번들 식별자 명시 |
| `Daylog/Services/PioPurchaseManager.swift` | 로컬 Xcode/Sandbox/App Store 환경 정책 분리, 검증된 앱·거래의 환경/번들/상품 확인. 복원 전 스냅샷 재사용 경합과 환불 뒤 잘못된 구매 성공 반환 수정. 기존 구매·복원·거래 감시 구조 재사용 |
| `Daylog/Services/PioWardrobe.swift` | 상점 비활성화가 유료 무료 착용을 허용하던 경로 제거. 명시적 DEBUG 의상 체험 유지. Sandbox 선호 저장소 분리. 목표 가격 하드코딩 제거 |
| `Daylog/Services/PioAppearanceCoordinator.swift` | 명시적 DEBUG 착용을 무료 소유로 잘못 분류하지 않도록 수정. 기존 전역 착용·단계·원화 연결 유지 |
| `Daylog/Views/Wardrobe/PioWardrobeView.swift` | Apple의 현지화된 상품 이름/가격 사용, 결제 중 입력 차단, 의상 선택이 바뀌어도 원래 구매한 상품에 결과를 연결, 실제 실행 환경 안내 |
| `Routimori.storekit` | 실제 ID·한국 이름·2,500원 로컬 테스트 구성 반영. ASC 가격을 변경한 것이 아님 |
| `DaylogTests/PioProductRegistryTests.swift` | 기본 무료, 유료 13종 일대일 대응, 원화 키와 다른 상품 이름 회귀 검사 |
| `DaylogTests/PioPurchaseTests.swift` | 환경 정책, 복원 경합, 환불·늦은 성공 경합 등 의미 있는 회귀 검사 추가. listener 종료 검사를 실제 종료 신호 기반으로 안정화 |
| `DaylogTests/PioWardrobeTests.swift` | 상점 비활성화 시 잠금과 기존 선호 보존 검사 |
| `DaylogStoreKitTests/PioStoreKitIntegrationTests.swift` | 실제 가격/ID 검사, 구매·착용 후 기존 10개 동작의 rig 구성 검사, bounded DEBUG 거래 진단 첨부 |
| `DaylogStoreKitTests/PioStoreKitProcessRelaunchTests.swift`, `Tools/pio-storekit/process-relaunch.py` | 새 OS 프로세스에서 동일한 검증 거래·착용 선호를 확인하는 명시적 opt-in 도구와 실패 진단. 즉시 자동 검사 실패·지연 분리 검사 통과로 PARTIAL |
| `DaylogStoreKitTests/PioStoreKitLedgerFixtureTests.swift`, `DaylogPioLedgerReview.xcscheme` | 테스트 드라이버 거래 생성과 앱의 `Product.purchase()`를 구분한 선택적 진단 경로. 이번 실행에서는 사용하지 않아 NOT_TESTED |
| `APP_STORE_CONNECT_PRODUCTS.md`, 현재 QA 폴더 | 확인된 매핑, 정책, 실패 원본, 독립 코드 검토와 남은 외부 요구사항 |

작업 전에 있던 native motion/원화/리뷰 도구 변경은 보존했습니다. `project.pbxproj`의 기존 Release trial 에셋 제외 설정도 유지했습니다. Xcode가 프로젝트를 열며 발생시킨 불필요한 자동 직렬화는 원본을 QA에 백업한 뒤 의미 변화 없이 정리했습니다. 기존 공유 스킴의 기능 변경은 남기지 않았습니다.

## 3. 구현 및 검증 상태

| 기능 | 상태 | 근거와 제한 |
|---|---|---|
| 기본 무료, 미구매 잠금, 13종 매핑 | PASS | 단위 검사·카탈로그 검사 |
| 로컬 상품 13개 조회·현지화 이름·KRW 표시 가격 | PASS | 실제 `Product.products`에서 13개 비소모성, `displayPrice == ₩2,500` 확인 |
| 구매 → 검증 → 잠금 해제 → 착용 | PASS / 로컬 범위 | 실제 Xcode 거래로 확인. 테스트 드라이버 소유권 주입 아님 |
| 이미 구매한 상품 재구매 방지 | PASS / 로컬 범위 | 추가 거래를 만들지 않는 실제 로컬 검사 |
| 대기 → 승인 업데이트 → 잠금 해제 | PASS / 로컬 범위 | Ask to Buy 실제 로컬 검사 |
| 상품 조회 실패·구매 실패·재시도 | PASS / 로컬 범위 | StoreKitTest 오류 주입과 재시도 |
| 서명 검증 실패 거부 | PASS / 로컬 범위 | 잘못된 서명은 권한을 주지 않음 |
| 구매 복원 | PASS / 로컬 범위 | 외부에서 만든 로컬 거래를 명시적 sync + currentEntitlements로 복원 |
| 새 manager에서 권한·착용 복구 | PASS / 같은 프로세스 | OS 프로세스 재시작 성공을 의미하지 않음 |
| 환불 → 잠금·기본 복귀 | PARTIAL | 전체 연속 검사 FAIL, 새 프로세스의 집중 검사 PASS. 두 결과 모두 보존 |
| 구매 취소 | PARTIAL | 단위 검사 PASS. 로컬 실제 API의 취소 오류 주입은 private server 오류 907로 반환돼 취소 UX 검사 FAIL. private 오류 코드를 취소로 임의 매핑하지 않음 |
| 중단 거래 해결 | FAIL / 로컬 검사 | 해결 전 verified 업데이트가 도착해 조기 소유 관측, 이후 기대 업데이트 timeout. 정확한 SDK/fixture 원인은 미확정 |
| 모든 거래의 처리 완료 관측 | FAIL / 로컬 검사 | 13개 모두 finish 호출·반환했으나 마지막 우주복 거래가 3초 동안 `Transaction.unfinished`에 남음 |
| 실제 OS 프로세스 재실행 후 유지 | PARTIAL | 즉시 실행한 자동 2단계 검사는 FAIL. 몇 분 뒤 별도 새 프로세스에서는 동일 검증 거래·소유·착용 복구 PASS. 즉시 유지와 전체 runner 통과를 주장하지 않음 |
| 실제 오프라인 cold launch | NOT_TESTED | 단위 오류 경로가 실기기 오프라인 동작을 증명하지 않음 |
| Apple Sandbox·실기기 구매·복원·환불 | NOT_TESTED | 계정 입력·실제 Apple 결제 없음 |
| 출시 활성화 | PARTIAL | iOS 환경 정책은 구현했으나 판매 설정은 닫혀 있음. Mac 일반 구매는 미지원 |

권한은 검증된 거래와 `Transaction.currentEntitlements`/`Transaction.updates`에서만 얻습니다. UserDefaults에는 착용 선호를 저장하고 소유 권한은 저장·신뢰하지 않습니다. 복원은 사용자가 명시적으로 요청할 때만 `AppStore.sync()`를 호출합니다.

## 4. 테스트·빌드 결과와 실패 증거

환경: **Xcode 27.1 (27A9275), macOS 27.0.1, iOS Simulator 27.0**. 새 전용 시뮬레이터 `Pio StoreKit Local 2026-10-23`, UUID `0426CD78-3807-4650-9776-B649780E2884`만 사용했습니다.

- **PASS:** Mac focused unit/회귀 **69개 / 7개 suite**. [최종 단위 로그](mac-unit-v4.log). 최초 컴파일·회귀·종료 fixture 실패 로그 v1–v3도 보존했습니다.
- **PASS:** Mac Release [빌드](mac-release-build.log), iOS Release [빌드](ios-release-build.log), iOS Debug [테스트 빌드](ios-diagnostics-build.log). Release는 컴파일 검증이며 판매/실기기 결제 검증이 아닙니다.
- **FAIL:** 최신 전체 실제 iOS StoreKit 검사 **7 PASS / 4 FAIL**. 별도 opt-in 리뷰/fixture 8개는 skipped. 19개를 전부 성공으로 세지 않습니다. [원본 xcresult](ios-ide-local-v1.xcresult), [요약](ios-ide-local-v1-summary.json), [검사별 상태](ios-ide-local-v1-tests.json).
- **FAIL:** 13종 집중 검사도 마지막 우주복 거래의 unfinished 관측 실패 재현. 단, 앞선 13종 실제 구매·착용·원화 조회와 **13×10개 기존 동작 rig 구성/활성/정지** assertion은 모두 통과했습니다. 테스트 전체는 FAIL입니다. 마지막 거래 ID 32의 cache 존재, inFlight 0, finish 시작·약 1ms 뒤 반환이 기록됐습니다. 호출 누락은 관측되지 않았지만 SDK 원인이 확정된 것은 아닙니다. [집중 로그](ios-focused-diagnostics/01-01-testEveryPremiumOutfitPurchasesEquipsAndLoadsApprovedArtwork.log). 실패 후 도구의 대용량 진단 수집이 100초 제한에 걸려 runner가 중단됐고 다음 환불 항목은 그 실행에서 시작하지 않았습니다. [runner 상태](ios-focused-diagnostics/summary.json).
- **PASS / 단독 실행 한정:** 새 테스트 프로세스의 환불 검사 **1/1**, 실제 revoked `.xcode` 업데이트 후 기본 복귀. [로그](ios-refund-diagnostics.log), [요약](ios-refund-diagnostics-summary.json). 이 통과가 전체 suite의 환불 실패를 지우지 않습니다.
- **PARTIAL / 초기 환경 오류:** 최초 Mac local 검사 3 PASS / 8 FAIL은 구매 요청이 Sandbox 3504로 향했습니다. 최초 iOS CLI 실행도 Apple 로그인 UI가 나와 입력 없이 중단했습니다. [Mac 로그](mac-local-v1.log), [초기 iOS 로그](ios-local-v1.log), [로그인 화면 증거](ios-local-v1-waiting.png).

### 로컬 환경 라우팅

전용 iOS 스킴에서 Xcode로 **Run해 연결된 `Routimori.storekit`을 활성화한 뒤 Test**했을 때 거래가 `XcodeTest`로 도착했고, 이후 CLI에서도 실제 로컬 구매가 동작했습니다. 검증된 `.xcode` AppTransaction만으로 SDK 결제 UI 경로까지 보장할 수 없다는 사실을 주석과 안내에 반영했습니다. 이 IDE 절차를 수행했다는 것이 모든 테스트 환경에서 문제가 해결됐다는 뜻은 아닙니다. 예상하지 않은 계정/결제 UI에는 입력하지 않아야 합니다.

### 프로세스 재실행

`ios-process-relaunch/`는 실제 Cafe `Product.purchase()`로 검증된 Xcode 거래 ID 34를 만들고 착용한 첫 OS 프로세스 **71326**은 PASS였습니다. 두 번째 프로세스 **71355**는 UUID 설정 저장소의 metadata가 없어 FAIL했습니다. 같은 manager를 재생성하는 검사를 OS 재시작 성공으로 표시하지 않았습니다.

`ios-process-relaunch-v2/`와 `ios-process-relaunch-v3/`는 새 UUID와 실제 로컬 거래로 저장소 문제를 분리했습니다. UserDefaults·새 인스턴스·CFPreferences 조회에는 착용·PID·거래 키가 있지만, 실제 plist에는 첫 `seedMethod`만 남았습니다. 공개 동기화 API가 true를 반환하고 최대 5초 대기해도 동일해서 v3 seed 단계는 FAIL, 자동 runner의 verify는 실행하지 않았습니다. 원인을 확정하지 않았고 설정 파일 강제 쓰기나 소유권 재주입은 하지 않았습니다. 이 결과를 표준 production 저장소의 결함으로 확대 해석할 수는 없습니다.

v3 seed 후 약 5분 뒤 **별도의 diagnostic-verify는 PASS**했습니다. 새 OS 프로세스 **76629**가 seed 프로세스 **73700**와 다름을 확인했고, `Transaction.currentEntitlements`에서 동일한 검증된 Xcode Cafe 거래 **ID 36**을 찾았습니다. 새 manager는 기본 무료 상태에서 시작해 실제 영수증으로 Cafe 권한을 얻고, 디스크에 뒤늦게 반영된 기존 선호에서 Cafe 착용을 복구했습니다. 재구매·복원·설정 재주입은 하지 않았습니다. 이후 해당 UUID 설정·진단 파일과 로컬 거래 ledger를 정리했습니다. [진단 로그](ios-process-relaunch-v3/diagnostic-verify.log), [요약](ios-process-relaunch-v3/diagnostic-verify-summary.json).

이는 지연 후 실제 프로세스 간 복구의 증거입니다. 저장 직후 자동 runner 실패를 성공으로 바꾸거나 즉시 재실행/재부팅·오프라인 안정성을 증명하지는 않습니다. 따라서 재실행 항목은 **PARTIAL**입니다.

추가 전체 반복, 실제 Sandbox 구매, 새 원화 생성, 성능 벤치마크는 수행하지 않았습니다. DEBUG 진단은 정확한 로컬 플래그에서만 최대 256개 이벤트를 보관하고 서명 payload를 기록하지 않습니다.

## 5. 출시 전 남은 문제

1. 위 로컬 취소·중단·finish 관측·연속 환불·즉시 자동 재실행 검사 실패를 해소하고 정리된 전체 실행을 통과시켜야 합니다. 지연된 프로세스 복구 PASS는 별도로 보존합니다. 통과시키기 위한 추가 승인, private 오류 재해석, 파일 강제 저장은 하지 않았습니다.
2. 실제 Sandbox 실기기에서 13개 상품의 지역별 표시 가격, 구매 승인/취소/대기, 재구매 방지, 종료·재시작, 복원, 환불/권한 취소, cold/warm 오프라인을 검증해야 합니다.
3. ASC 13종 모두 **MISSING_METADATA**이고 필수 심사용 스크린샷이 없습니다. 심사 메모와 홍보 이미지는 선택 항목이므로 필수라고 주장하지 않습니다. [실제 확인 기록](asc-products-confirmed.json).
4. 기존 7종 ASC 설명은 전용 앱 아이콘도 약속하지만 `PioAppIconService.registeredThemes`가 비어 있습니다. 실제 아이콘 제공 또는 정확한 설명으로 수정하는 결정이 필요합니다. 기존 아이콘 원화 생성이나 ASC 설명 수정은 하지 않았습니다.
5. iOS의 `PioStoreKitEnvironment`/`PioStoreKitCatalogConfirmed`는 별도 검증 빌드·출시 단계에서 명시해야 합니다. **이번 작업은 번들 설정을 활성화하지 않아 일반 판매는 닫혀 있습니다.** 실제 iOS 번들·서명 거래를 확인하는 구조를 로컬 테스트 플래그로 우회하지 않습니다.
6. 확인한 카탈로그는 iOS 번들용입니다. 별도 Mac 번들 `com.mungyubin.daylog`의 일반 구매는 비활성화돼 있습니다. iOS 상품 확인을 Mac App Store 준비 완료로 취급하지 않습니다.
7. 유료 앱 계약·세금·은행 상태, 다른 지역 가격은 이번에 확인하지 않았습니다.

## 6. 애니메이션·다음 장면 연결 준비

**보존 PASS:** 작업 전 보호 목록의 원화·rig/motion 소스 **723개**가 모두 동일합니다. [해시 결과](preservation-after.json). 14종 의상, 기존 independent rig, 소품 부착, 10개 동작, 단계 임계값, 휴가 낮/밤 26장과 클라우드 원화를 삭제·재생성하지 않았습니다. DEBUG native rig와 Release trial 에셋 제외 정책도 유지했습니다.

기존 홈/성장 카드/스플래시의 공통 appearance 경로와 StoreKit 권한·착용 상태는 같은 wardrobe를 읽습니다. 이번 구매 후 rig 구성 검사는 이 연결에 대한 코드·실행 증거이며, 모든 화면·크기·테마의 새 시각 QA를 완료했다는 뜻은 아닙니다. 기존 native 시각 증거는 [motion 결과](../pio-motion-v2-2026-10-23/RESULTS.md)에 보존돼 있습니다. 움직임 타이밍이나 Reduce Motion 로직은 변경하지 않았습니다.

휴가·클라우드는 공통 착용 상태와 장면별 리소스 요구사항을 이미 분리해 두었으므로 후속 연결을 시작할 구조는 있습니다. 하지만 의상별 장면 원화/rig가 등록·검증되지 않은 경우 기존 기본 피오 장면을 유지합니다. 보관된 휴가·클라우드 후보를 실제 장면 애니메이션에 연결한 것으로 보고하지 않습니다. 이번 범위에서는 신규 장면 구현을 하지 않았습니다.

## 7. 보호 범위

- 기존 uncommitted 변경·실패 로그·원화 실험 보존
- production 데이터, 사용자 기록, SwiftData 스키마, CloudKit 구성, bundle identifier 변경 없음
- 새 테스트 시뮬레이터 외의 기존 설치 앱 교체 없음
- 실제 Apple 계정 입력·결제·상품 제출 없음
- 커밋·푸시·배포 없음

최종 인수 기준은 아직 충족되지 않았습니다. 확인된 카탈로그를 기반으로 한 구현·검사와, 별도로 해결해야 할 로컬/실기기/ASC 문제를 분리해 남겼습니다.
