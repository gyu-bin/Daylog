# REVIEW — 시나리오별 관측과 원인 분류 (2026-10-24)

분류: APP_BUG(앱 결함 확인), LOCAL_TEST_BUG(로컬 테스트 가정의 문제), SDK_DEPENDENT(직접 SDK 경로에서도 관측, 결함 주체 미확정), UNRESOLVED(근거 부족), NOT_TESTED(환경 제약).

## 1. 실제 Apple 연결

| 관측 | 근거 | 판정 |
|---|---|---|
| Apple 서버가 13종을 반환: 비소모품, 한국어 이름, 미국 스토어프론트 $1.99 | `evidence/probe-apple-server-ipad-noaccount.txt`. 로컬 파일에는 KOR·KRW만 있다 | PASS(조회만) |
| 같은 조회가 로컬 설정이 남은 시뮬레이터에서는 Xcode 환경·₩2,500 | `evidence/probe-local-config-iphone17.txt` | 로컬 결과. Sandbox로 세지 않음 |
| Sandbox 빌드 + 계정 없음: 앱 영수증을 못 받아 조회·구매를 거절, 유료 권한 없음, 기본 피오 유지 | `evidence/ipad-sandbox-noaccount-*.png`, `probe-sandbox-build-ipad-noaccount.txt` | PASS(정책대로 거절) |
| 같은 조건의 안내 문구가 원인과 다르고 두 번 표시 | 위 캡처(수정 전) | **APP_BUG(UX) → 수정**(계정 안내, 구매 단추 옆 한 번, 다시 불러오기). 단위 테스트 `missingAppStoreAccountExplainsSignInAndGrantsNothing` PASS |

## 2. Sandbox 구매 시나리오

| 시나리오 | 결과 |
|---|---|
| A 정상 구매 | NOT_TESTED(Sandbox 계정 필요) |
| B 취소 | NOT_TESTED |
| C 대기·중단 | NOT_TESTED |
| D 복원 | NOT_TESTED |
| E 환불 | NOT_TESTED |
| F 즉시 재실행 | NOT_TESTED(Sandbox). 로컬 재실행은 10/23 3/3 PASS 기록이 있으나 이번에 다시 돌리지 않음 |

## 3. 로컬 StoreKit 통합 실패 (이번 실행)

`PioStoreKitIntegrationTests`(11개)를 iPhone 17 시뮬레이터에서 **3회 연속** 단독 실행: 매번 7 PASS / 4 FAIL / 0 SKIP. 실패 4건은 매번 같다.
전체 iOS 실행(91개)에서는 3건만 실패했다. "전체 의상 구매·unfinished 잔존"이 순서·부하에 따라 가끔 통과했기 때문이다(이전 보고의 3건 대 4건 차이의 원인).

| 실패 | 이번 관측 | 분류 | 앱 영향 판단 |
|---|---|---|---|
| 취소 오류 주입 | `setSimulatedError(.generic(.userCancelled))` 후 결과가 "연결 실패" | SDK_DEPENDENT | 10/23 직접 SDK 경로에서도 `StoreKitError.unknown`이 나왔다. 앱은 공개 취소 오류(중첩 포함)를 이미 취소로 처리한다. 실제 시트 취소는 로컬 UI에서 PASS 기록. 실제 Sandbox 취소는 NOT_TESTED |
| 중단 거래 | 해결 전 소유로 보임 | SDK_DEPENDENT | 로컬 드라이버는 issue 상태인데 SDK가 이미 검증된 거래를 준다. 앱은 검증된 거래만 반영하는 정책대로 동작. 실제 Sandbox 중단은 NOT_TESTED |
| 환불 알림 | 10초 안에 회수 알림 없음 | UNRESOLVED | 단독·직접 진단은 통과하고 연속 실행에서만 실패. 알림을 놓치면 다음 권한 재조회까지 소유가 남을 위험. 실제 Sandbox 환불로 확인 필요 |
| 마지막 거래 unfinished 잔존 | 3초 안에 unfinished 비지 않음 | SDK_DEPENDENT | 직접 경로에서 finish를 기다린 거래도 새 프로세스에서 남았다(10/23). 우주복만의 문제 아님 |

이번에 구매 관리자의 검증·권한 정책은 바꾸지 않았다. 바꾼 것은 오류 문구 분류(계정 없음)뿐이다. 테스트를 통과시키려는 우회는 넣지 않았다.

## 4. 이번 수정

| 파일 | 내용 | 정책 영향 |
|---|---|---|
| `Daylog/Services/PioPurchaseManager.swift` | `AppTransaction`이 계정 없음(`noAccount`)으로 실패하면 `accountUnavailable`을 던지고 로그인 안내 문구를 쓴다 | 없음. 어느 경우든 요청을 거절한다 |
| `Daylog/Views/Wardrobe/PioWardrobeView.swift` | 구매할 수 없는 까닭과 [상품 정보 다시 불러오기]를 구매 단추 바로 아래에 표시. 같은 실패 문구 중복 제거 | 없음 |
| `Daylog/App/DebugScript.swift` | Debug 전용 `storeProbe`(읽기 전용 조회 진단) | Release에 컴파일되지 않음 |
| `DaylogTests/PioPurchaseTests.swift` | 계정 없음 안내·무권한 단위 테스트 1개 | — |
| `Tools/pio-storekit/run-sandbox-sim.sh` | Sandbox 전용 시뮬레이터 빌드·실행 스크립트 | 일반 설정 불변 |

## 5. 미해결 원인

- 환불 알림 연속 실행 실패의 인과관계(UNRESOLVED)
- 로컬 오류 주입·중단·unfinished가 SDK 동작인지 Apple 결함인지(SDK_DEPENDENT, 확정 불가)
- 실제 Sandbox 동작 전부(계정 필요)
