# 잔여 거래 진단 및 실제 기기 크기 검증

판정 **PARTIAL**. 구매 관리자·상품 ID·원화 변경 없이 테스트만 추가했다.

## 환경

Xcode 27.1 (27A9275), macOS 27.0.1 (26A434), iOS 27.0 Simulator. 로컬 Xcode StoreKit `.storekit` 환경만 사용. SDK 빌드 이름은 iphonesimulator27.1이며 실행 런타임은 27.0이다. 실제 Sandbox/결제 UI/Product.purchase 검증 아님.

## 거래 진단

| 테스트 | 결과 | 관측 |
|---|---|---|
| 비오는날 단독 verified 흐름 | PASS | buyProduct 반환 직후 currentEntitlements verified ID 일치, manager 조회 후 착용, 6장면 일치, 10동작 start/stop, finish 완료 |
| 잠옷 단독 verified 흐름 | PASS | 같은 검증 |
| 우주복 단독 verified 흐름 | PASS | 같은 검증 |
| SDK 최소 13종 순차 즉시 조회 | PASS | manager/wardrobe/리그 없이 모든 제품의 즉시 verified ID 일치 |
| 기존 통합 13종 순차 fixture | FAIL | 이번에는 두 번째 여름휴가 id=1 반환 후 currentEntitlements에서 벚꽃 id=0만 관측. 기존 10월23일 실패는 비오는날 id=10이었다 |

총 새 진단 **4 PASS / 0 FAIL / 0 SKIP**, 기존 비교 검사 **0 PASS / 1 FAIL / 0 SKIP**. `ledger-diagnostic-summary.json`, `full-ledger-summary.json` 및 각 log 참조. 각 테스트 setup/teardown에서 session reset/clear를 수행했고 개별 검증은 UUID preferences를 정리한다. 테스트 환경은 `AppTransaction.environment == .xcode` 및 ledger opt-in 플래그로 제한했다.

원인 판정: **UNRESOLVED**. 실패 위치가 바뀌었고 동일 상품 단독 및 SDK 최소 순차 하네스는 통과했다. 비오는날 상품/매핑 결함이나 Apple SDK 자체 결함으로 확정할 수 없다. 현재 증거는 기존 통합 fixture의 즉시 권한 조회 불안정성을 재현한다. 잠옷·우주복이 실제 verified 거래 이후 기존 장면·동작을 사용할 수 있는 것은 개별적으로 확인했다. 전체 통합13종 PASS로 대체하지 않는다.

추가 sleep, assertion 삭제, fake ownership, purchase manager 변경은 없다. 이전 알려진 StoreKit 4개 실패가 해결된 것으로 보고하지 않는다. Transaction.updates 알림 계약 및 실제 Apple Sandbox는 이번 테스트 범위 밖이다. 로그는 거래/제품 ID와 검증 상태만 기록하고 signed receipt 원문은 기록하지 않는다.

## 실제 소형 iPhone / iPad

새 전용 시뮬레이터를 만들고 동일한 네이티브 `DashboardView`를 실제 UIWindow에 올렸다. in-memory AppStore, UUID preferences, 비활성 CloudSyncMonitor 사용. 기기 크기·size class는 강제하지 않았다.

- iPhone SE (3rd generation), `87F27718-1575-4384-B7DB-1AF4601DBC86`: 375×667pt, compact. **1/1 PASS**, 정상/AX5 PNG 2장.
- iPad mini (A17 Pro), `18A1DFA8-796C-4403-9CC0-C02FD790F40A`: 744×1133pt, regular. **1/1 PASS**, 정상/AX5 PNG 2장.
- 두 기기의 실제 normal/AX5 PNG를 눈으로 확인했다. 일반 크기에서 헤더와 피오 발 잘림/겹침은 관측하지 않았다. AX5에서 날짜·인사·컨트롤이 분리되어 있고 문자 확대에 따라 아래 콘텐츠는 화면 밖으로 이어진다.
- 전체 스크롤 도달성, VoiceOver 읽기 순서, 키보드 탐색, 실제 앱 내비게이션 chrome, 회전/멀티태스킹은 NOT_TESTED. 화면에는 Dashboard fixture만 포함된다.
- DEBUG `-PioOverhaulTrial -DaylogDebugCharacter routimori` 경로이다. Release 전체 화면 검증을 대신하지 않는다.

캡처:

- `small-device/actual-phone-dashboard-normal.png`
- `small-device/actual-phone-dashboard-AX5.png`
- `ipad-device/actual-ipad-dashboard-normal.png`
- `ipad-device/actual-ipad-dashboard-AX5.png`

## 변경 파일 및 결과 보관

- `DaylogStoreKitTests/PioRemainingLedgerDiagnosticTests.swift`: 새 로컬 최소/개별 진단4개.
- `DaylogStoreKitTests/PioDeviceSizeReviewTests.swift`: 실제 기기 환경 Dashboard 캡처1개를 2기기에서 실행.
- 테스트 전용 xctestrun 복사만 `/tmp/PioStoreKit-20261023-ios/Build/Products/`에 구성. 기존 테스트·스킴·앱 코드는 수정하지 않았다.
- `ios-build.log`, `device-build.log`: build-for-testing PASS.
- 원본 번들은 `/tmp/PioRemainingDiagnostic-20261024.xcresult`, `/tmp/PioFullLedger-20261024.xcresult`, `/tmp/PioSmallDevice-20261024.xcresult`, `/tmp/PioPadDevice-20261024.xcresult`. 임시 경로로 명시한다. 로그·통계·PNG는 이 폴더에 보존한다.

실행 반복은 최소 하네스1회 + 기존 통합 비교1회로 제한했다. 운영 앱 설치/교체, 제품 설정 변경, 사용자 데이터 변경, 실제 결제, 커밋·푸시는 수행하지 않았다.
