# SANDBOX — 실제 Apple Sandbox 구매 검증 환경과 절차 (2026-10-24)

## 1. 이번에 확인한 환경

| 항목 | 상태 |
|---|---|
| Xcode / SDK | Xcode 27.1, iOS Simulator SDK 27.1, macOS 27.0.1 |
| 번들 ID | `com.mungyubin.daylog.ios` (App Store Connect 앱 6821788787) |
| 일반 빌드(Debug·Release·TestFlight)의 구매 | **꺼짐.** Info.plist에 `PioStoreKitEnvironment`·`PioStoreKitCatalogConfirmed`가 없어 "구매 준비 중"이다. 현재 소스는 이때 유료 의상을 잠근다(무료 착용 없음) |
| Sandbox 전용 빌드 | `Tools/pio-storekit/run-sandbox-sim.sh`가 임시 Info.plist에만 `sandbox` 키를 넣어 만든다. 일반 Info.plist·프로젝트 파일 해시 변화 없음(확인함) |
| 로컬 StoreKit 설정 | `Routimori.storekit`은 그대로. 일반 `DaylogiOS` 스킴에는 붙어 있지 않다(StoreKit 전용 스킴만) |
| 시뮬레이터의 Sandbox 계정 메뉴 | 있음: 설정 → 개발자 → **샌드박스 Apple 계정 → 로그인**(evidence/ipad-settings-sandbox-account.png) |
| Apple 상품 조회 | 성공: 계정 없는 시뮬레이터에서 13종(PRODUCT-MATRIX) |
| 연결된 실제 iPhone | iPhone 14 Pro 페어링됨(오프라인). **사용하지 않음**: 같은 번들 ID의 개발 빌드를 설치하면 설치된 RoutiMori와 그 데이터를 덮어쓰고, 개발 빌드는 CloudKit Development 환경을 쓴다 |
| TestFlight 1.0.1(13) | Sandbox 거래를 쓰지만, 구매 환경 키가 없는 빌드라 구매 시험에 쓸 수 없다 |
| Paid Apps 계약·은행·세금 | 직접 확인하지 못함. 다만 Sandbox에서 상품 13종이 조회되었으므로 상품 공급에 필요한 계약은 유효한 것으로 보인다(Apple TN3186: 계약이 없으면 상품이 반환되지 않음) |

## 2. 주의: 로컬 설정이 남은 시뮬레이터

`Routimori.storekit`을 붙인 스킴으로 한 번이라도 실행한 시뮬레이터는, 나중에 `simctl`로 일반 빌드를 띄워도 로컬 설정을 계속 쓴다.
iPhone 17 QA 시뮬레이터가 그랬다. 이 경우 진단의 `appTransaction` 환경이 **Xcode**로 나오고, 가격도 로컬 파일 값(₩2,500)이다.
**Sandbox 시험 전에 진단의 첫 줄에서 환경을 꼭 확인하세요.** 이번에는 그런 적이 없는 iPad mini 시뮬레이터(`18A1DFA8…`)를 썼다.

## 3. 사용자가 할 일 (계정 정보는 저장소·로그에 남기지 않는다)

1. **Sandbox 테스터 만들기(없다면).** App Store Connect → 사용자 및 액세스 → Sandbox → 테스터 추가.
   - 지역은 **대한민국**으로 한다(₩2,500 확인용).
   - 일반 Apple 계정으로 쓴 적 없는 이메일을 쓴다.
2. **시뮬레이터에 로그인.** iPad mini 시뮬레이터 → 설정 → 개발자 → 샌드박스 Apple 계정 → 로그인. 일반 Apple 계정(iCloud)에는 로그인하지 않는다.
3. **Sandbox 빌드 실행.**
   ```
   Tools/pio-storekit/run-sandbox-sim.sh 18A1DFA8-796C-4403-9CC0-C02FD790F40A
   ```
   출력 첫 줄이 `appTransaction=verified environment=Sandbox`인지, 상품 13종의 가격이 `₩2,500`인지 확인한다.
4. **알려 주세요.** 그다음 단계(아래 4절)는 Claude가 화면을 보며 진행할 수 있다. 다만 구매 확인 시트의 승인이나 비밀번호 입력은 사람이 한다.

## 4. 검증 절차 (로그인 후)

| 시나리오 | 할 일 | 통과 기준 |
|---|---|---|
| A 정상 구매 | 옷장 → 벚꽃 → "₩2,500에 구매하기" → 시트에 `[Environment: Sandbox]` 확인 → 승인 | 승인 전에는 잠김. 승인 후 즉시 "입히기" 가능, 홈·클라우드·휴가에 같은 의상 |
| B 취소 | 다른 의상(예: 학생)으로 시트를 띄우고 취소 | 잠금 유지, "구매 진행 중" 해제, 다시 시도 가능, 기존 소유 영향 없음 |
| C 중단·대기 | 설정 → 개발자 → Sandbox 계정 → 관리에서 구매 허용 끄기 → 구매 시도 → 다시 켜기 | 완료 전 권한 없음, 완료된 검증 거래만 반영. 재현되지 않으면 NOT_TESTED로 둔다 |
| D 복원 | 앱 삭제 후 재설치(같은 시험 저장소) → "구매 복원" | 검증된 소유 재조회, 마지막 착용 복원, 산 의상의 구매 단추 없음 |
| E 환불 | Sandbox 계정 관리의 구매 내역 지우기, 또는 Xcode의 Transaction Manager(Sandbox 거래에는 적용 안 될 수 있음) | 소유 회수, 착용 중이면 기본 피오로 복귀. 요청 수락과 실제 회수는 따로 기록한다 |
| F 즉시 재실행 | 구매·착용 직후 앱 종료 → 재실행 | 권한·착용 유지, 기본 피오 순간 노출 없음 |

기록할 것: 시뮬레이터 종류·OS, 빌드 커밋, 진단의 영수증 환경, 거래 ID(숫자만).
기록하지 말 것: 계정 이메일·비밀번호, 서명된 영수증 본문.

## 5. 재현 가능한 오류

| 조건 | 관측 | 처리 |
|---|---|---|
| Sandbox 빌드 + 계정 없음 | 상품은 Apple에서 오지만, 앱 영수증(`AppTransaction`)을 못 받아 앱이 조회·구매를 거절한다(검증 정책대로). 화면은 "현재 구매 불가" | 정상(권한 안 줌) |
| 같은 조건의 안내 문구 | 원인과 다른 "네트워크를 확인하세요"가 목록 맨 아래에 두 번 나왔다 | **수정:** "App Store 계정을 확인할 수 없어요. … 로그인한 뒤 다시 시도" 문구를 구매 단추 바로 아래에 한 번, [상품 정보 다시 불러오기]와 함께 |

## 6. 추가 (2026-10-25) — 시뮬레이터 로그인 불가, TestFlight 시험 빌드로 전환

- **시뮬레이터 Sandbox 로그인 실패 (환경 제약).** 대한민국 Sandbox 테스터로 설정 앱과 앱 안 로그인 창 모두 시도했다. 로그상 계정·암호 단계는 통과했다(계정 식별자 발급). 그다음 기기 인증 단계에서 실패했다.
  - 실패 순서: `secureDeviceId not available on simulator` → IDMS 401 → anisette 발급 실패(code 5) → `AMSErrorDomain "unrecognized authentication failure"`
  - 이 Mac에는 iOS 27 런타임만 있어 다른 버전 시뮬레이터로 대조하지 못했다.
  - 그사이 앱은 계정이 없다는 안내와 [상품 정보 다시 불러오기]를 정상 표시했다.
- **TestFlight 1.0.1 (14) 업로드 (사용자 승인).** 구매 환경을 `sandbox`로 켠 시험 전용 빌드다.
  - 임시 Info.plist로만 켰고, 저장소의 `Config/DaylogiOS-Info.plist`는 그대로다.
  - 배포 IPA를 직접 확인했다: 푸시 production, iCloud Production, `get-task-allow=false`, 빌드 14, 위젯 14.
  - **이 빌드는 심사 제출용이 아니다.** App Store에서는 영수증 환경이 달라 구매가 꺼진다.
  - 내부 그룹 "Test"(2명)에 자동 배포된다. 이 빌드에서는 무료로 입던 유료 의상이 잠기고, Sandbox 구매(청구 없음)로만 열린다.
- **실기기 검증 절차:** TestFlight로 설치 → 옷장 → 벚꽃 → 구매. 결제 시트에 `[Environment: Sandbox]`가 보여야 한다. 이후 4절 A~F 순서로 진행한다.
- **TestFlight 1.0.1 (14), Mac mini에서 시작 직후 종료 (APP_BUG → 수정).** Mac(Apple 실리콘)에 "iPad 앱"으로 설치하면 시작 약 3초 뒤 알림 안내 시트가 뜨면서 `Fatal error: No Observable object of type AppStore found`로 종료됐다(충돌 기록 5건 + 재현 1건).
  - 같은 Release 코드는 iPad 시뮬레이터에서 정상이었다. 새로 설치한 경우와 시작 안내를 마친 상태 모두 확인했다.
  - 수정: `RootView`의 시작 안내·알림 안내 시트에 공용 객체(AppStore·DevicePreferences·CloudSyncMonitor·RoutineNotifications 등)를 직접 넘긴다(`launchSheetEnvironment`).
- **TestFlight 1.0.1 (15) 업로드 (출시 후보).** 저장소 설정 그대로 구매 환경 `appStore`, Mac 튕김 수정 포함.
  - 배포 IPA 확인: 빌드 15, 위젯 15, 푸시 production, iCloud Production, 디버그 명령 없음.
  - `appStore`는 TestFlight에서 Sandbox 결제를 받으므로, 이 빌드로 Mac 튕김 확인과 iPhone 결제 확인을 함께 할 수 있다.
