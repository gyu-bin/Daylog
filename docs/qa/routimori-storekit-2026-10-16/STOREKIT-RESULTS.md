# StoreKit 검증 결과 — 2026-10-16

**전체 통과 또는 출시 준비 완료가 아닙니다.** 현재 증거는 Xcode 로컬 StoreKit 테스트입니다. 실제 계정 정보 입력, 실결제, App Store Connect 상품 등록, Sandbox, TestFlight, 운영 배포는 하지 않았습니다.

이 보고서는 최신 전체 실행 `ios-storekit-clean-fixture.log`와 후속 단독 실행 `ios-finish-observation.log`, Mac 최종 단위 테스트·결제창 재검증까지 확인한 결과입니다. 단독 실행 통과가 전체 실행 실패를 대체하지 않으며, 자동화 호스트의 PASS가 사람이 Apple 결제창을 확인했다는 뜻도 아닙니다.

## 실행별 결과

| 검증 | 결과 | 증거와 범위 |
| --- | --- | --- |
| iOS 전체 통합 테스트, 명시적 오류 정리 후 | **11개 중 7 PASS / 4 FAIL** | [로그](ios-storekit-clean-fixture.log). 테스트 본문 21.700초, 실패한 검증문 8개. |
| iOS 3개 테스트를 각각 새 프로세스로 실행 | **2 PASS / 1 FAIL** | [실행 요약](isolated-ios-v2/summary.json). 검증 오류 거부·환불 업데이트 통과, 중단 구매 실패. |
| iOS 유료 13개 구매·장착·이미지 로드 단독 실행 | **PASS** | [로그](ios-storekit-isolated.log). 실제 StoreKit API 호출, 표시창은 테스트 설정으로 숨김. 테스트 약 8.9초. |
| iOS 거래 종료 처리 보완 후, 즉시 확인 단독 실행 | **FAIL** | [로그](ios-finish-fix.log). 마지막 astronaut 거래 `id=73`이 즉시 조회에서 미완료로 남음. |
| iOS 13개 구매·장착·이미지·검증·거래 종료, 관찰 방식 단독 실행 | **PASS** | [로그](ios-finish-observation.log). 최대 3초 관찰 조건에서 **첫 조회부터 미완료 거래 0개**, 약 0.008345625초. 전체 테스트 0.748초. |
| Mac 전체 통합 테스트, 이전 fixture | **11개 중 8 PASS / 3 FAIL** | [로그](mac-storekit-final.log). 취소 오류 주입·Ask to Buy 승인 업데이트·환불 업데이트 실패. 테스트 본문 21.282초. |
| Mac Swift Testing 단위 테스트 | **44/44 PASS, 4 suites** | [최종 로그](mac-final-unit-allowed.log). 동시 거래 종료 요청 통합 검증 포함. 이전 [43개 통과 로그](mac-global-unit-v2.log)도 보존. Apple 결제창 증거가 아님. |
| Mac Release 빌드 | **BUILD SUCCEEDED** | [로그](mac-release-build.log). 빌드 성공이며 서명·공증·출시·실결제 승인 아님. |
| iPhone Apple Xcode 결제창 | **구매·취소·장착·명시적 복원·프로세스 재실행 PASS** | [수동 검증 기록](NATIVE-REVIEW.md). 벚꽃 상품 1개로 확인. |
| Mac Apple 결제창 | **최종 재시도 후에도 미검증** | [최종 표시 대기 화면](mac-native-final-purchase-waiting.png), [최종 호스트 로그](mac-native-final-review.log). 호스트 자체는 PASS지만 실제 결제 확인창이 나타나지 않았으며 성공·취소 완료 증거가 없음. 추가 재시도는 하지 않음. |

## iOS 최신 전체 실행의 11개 항목

| 항목 | 결과 | 관찰 |
| --- | --- | --- |
| 13개 상품·비소모성·한국 표시 가격 | PASS | `₩2,000`, `KRW`, 구성 Decimal 2000. 숫자 가격 속성 문제는 별도 PARTIAL. |
| 13개 구매·장착·승인 이미지·거래 종료 | **FAIL** | 구매·장착·이미지 검증은 진행됐지만 마지막 astronaut 거래 `id=53`이 `Transaction.unfinished`에 남음. 단독 실행은 통과했음. |
| 외부 구매 후 명시적 복원 | PASS | 실제 로컬 StoreKit 거래에서 복원. |
| 구매 성공·중복 방지·관리자 재생성·반복 장착 | PASS | 이 자동화의 재생성은 OS 프로세스 재실행과 다름. |
| Ask to Buy 보류 후 승인 업데이트 | PASS | 승인 전 잠금과 승인 후 권한 확인. |
| 상품 조회 실패 후 재시도 | PASS | 실제 StoreKitTest 오류 주입과 해제. |
| 구매 실패 후 재시도 | PASS | 실제 StoreKitTest 오류 주입과 해제. |
| 검증 실패 시 권한 거부 | PASS | 오류 해제 fixture를 적용한 전체 실행 및 별도 프로세스 실행 모두 통과. |
| 취소 오류 주입 | **FAIL** | SDK가 `ASDServerErrorDomain 907`을 public 취소로 변환하지 않아 `.failed` 반환. 실제 iPhone 결제창 취소는 별도 통과. private 코드 예외처리 없음. |
| 중단 구매 후 해결 | **FAIL** | 해결 전 `.updates`에 verified `.xcode` rainyDay 거래가 도착해 권한이 생김. `Product.purchase()`는 `ASDErrorDomain 825` 실패, 로컬 거래는 `hasPurchaseIssue == true`. 해결 후 기대한 새 업데이트가 오지 않음. 별도 프로세스에서도 재현. |
| 환불 업데이트·장착 기본값 복구 | **FAIL** | 전체 실행에서 업데이트 대기 시간 초과와 권한/장착 유지. 별도 프로세스에서는 실시간 환불 업데이트 및 기본값 복구 통과. |

## 직접 확인한 iPhone 화면

- [Apple 결제창](ios-apple-xcode-purchase-sheet.png)은 **Xcode**와 실제 청구가 없다는 문구를 표시했습니다.
- [직접 취소 후](ios-cancelled-purchase-still-locked.png) 잠금이 유지되고 구매 버튼이 돌아왔습니다.
- [Apple 구매 성공](ios-apple-purchase-success.png) 후 [보유 상태](ios-owned-outfit.png)와 [장착 상태](ios-equipped-outfit.png)를 확인했습니다.
- 사용자가 누른 복원에서 [Xcode 확인창](ios-restore-xcode-confirmation.png)을 확인했고, [의상 1개 복원 결과](ios-restore-success.png)를 확인했습니다. 계정 자격 증명 입력은 없었습니다.
- 기존 테스트 호스트 종료 후 새 프로세스에서 [벚꽃 의상과 장착 유지](ios-home-cherry-relaunch-closeup.png)를 확인했습니다. 재실행 시 수동 장착이나 권한 주입은 하지 않았습니다. [재실행 로그](ios-relaunch.log)

Mac의 [전체 표시용 테스트 호스트](mac-global-review-v2.log)는 로컬 구매로 네 의상의 권한과 장착을 준비해 화면을 확인했습니다. 이것은 실제 Apple 확인창에서 구매·취소를 마쳤다는 증거가 아닙니다.

## 거래 종료 후속 관찰의 해석

동시 거래 종료 요청을 합치는 처리를 추가한 후에도 [즉시 조회 테스트](ios-finish-fix.log)는 astronaut `id=73`이 미완료로 남아 실패했습니다. 따라서 해당 변경으로 기존 실패가 해결됐다고 말할 수 없습니다.

후속 테스트는 처음 조회한 상태를 첨부 자료에 보존하고, 최대 3초 동안 `Transaction.unfinished`가 비었는지만 관찰하도록 검사 시점을 변경했습니다. 이 관찰 구간은 거래를 finish·sync·clear하지 않습니다. [통과 실행](ios-finish-observation.log)에서는 **첫 스냅샷부터 비어 있었고 약 0.008345625초**였습니다. 실제로 지연 후 비워지는 현상은 관찰되지 않았으므로 SDK 확인 지연이 원인이라고 결론 내리지 않습니다. 검사의 시간 조건이 즉시 확인에서 제한 시간 내 관찰로 달라졌다는 점과 이전 실패를 모두 보존합니다. 최신 전체 11개 테스트를 이 변경으로 다시 통과한 증거는 없습니다.

## 환경 진단과 보존한 실패

첫 iOS 실행에서 의도하지 않은 계정 로그인 폼이 나타나 자격 증명을 입력하지 않고 취소했습니다. [화면](ios-local-test-unexpected-auth.png), [로그](ios-storekit-full.log). 같은 시뮬레이터의 이전 테스트 프로세스를 종료한 후 단독 13개 구매가 계정창 없이 통과했습니다. 이것만으로 원인이 확정되지는 않습니다.

이전 iOS 전체 실행은 [6 PASS / 5 FAIL](ios-storekit-final.log)이었습니다. 이후 fixture는 `.verification`, `.purchase`, `.loadProducts` 오류를 시작·종료 시 명시적으로 해제하고 getter가 nil인지 확인합니다. Ask to Buy와 중단 설정도 명시적으로 초기화합니다. 최신 전체 실행은 7 PASS / 4 FAIL이므로 개선 후에도 남은 실패가 있습니다. Mac 표시용 호스트의 [최초 검증 오류](mac-global-review.log)와 [후속 성공](mac-global-review-v2.log) 사이에는 오류 해제·거래 초기화·구매 호출 방식의 여러 변경이 있어 단일 원인으로 결론짓지 않습니다.

격리 실행 스크립트의 [첫 시도](isolated-ios/summary.json)는 잘못된 `-test-iterations 1` 옵션으로 테스트 시작 전에 실패했습니다. 옵션을 제거한 [두 번째 시도](isolated-ios-v2/summary.json)부터 실제 테스트를 실행했습니다. 첫 실패는 앱 테스트 결과에 합산하지 않으며 증거는 보존합니다.

[Mac 최초 최종 단위 실행](mac-final-unit.log)은 sandbox의 캐시 접근 거부로 exit 74, 테스트 0개 실행이었습니다. 이것은 소스 코드의 테스트 실패가 아닙니다. 허용된 환경에서 [44개 실제 단위 테스트](mac-final-unit-allowed.log)를 실행해 통과했습니다.

격리 실행의 로컬 거래 ID는 검증 오류 테스트 34 → 환불 35 → 중단 36으로 증가했습니다. 따라서 `clearTransactions()`가 ID를 1로 재사용했다는 가설은 이 실행으로 입증되지 않습니다. SDK 캐시나 이벤트 전달 문제도 아직 조사 가설입니다. 중단 테스트의 조기 업데이트에는 거래 ID·구매 시각 로그가 없어 오래된 거래의 전달과 새 중단 거래의 잘못된 전달을 구분하지 못했습니다.

## 가격과 남은 검증

13개 상품 모두 구성 `2000.00`, 표시 가격 `₩2,000`, 통화 `KRW`, JSON `priceString == "2,000"`을 반환하지만, 확인한 Mac 로컬 런타임의 `Product.price`는 `2`였습니다. 숫자 API 일관성은 **PARTIAL**입니다. 앱은 Apple `displayPrice`를 사용하며 가격 보정이나 구성 가격 증액으로 현상을 숨기지 않았습니다. [상품 설정과 가격 진단](../../../APP_STORE_CONNECT_PRODUCTS.md)

남은 핵심 항목은 Mac 네이티브 결제창, 전체 실행에서의 거래 종료·환불 전달, iOS 중단 구매, SDK 취소 오류 주입입니다. 반복 10회 안정성, Sandbox/실기기 결제, App Store 상품 등록은 이 자료로 확인되지 않습니다. 기존 실패 증거를 보존하고 거래 종료 관찰 조건 변경을 위에 명시했습니다. 테스트 skip이나 private 오류 코드를 성공으로 바꾸는 예외처리는 추가하지 않았습니다.
