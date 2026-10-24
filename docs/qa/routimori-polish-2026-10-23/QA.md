# RoutiMori 브랜드·홈 헤더 통합 QA

최종 판정: **PARTIAL**. 실제 캡처·검증된 범위와 미검증 범위를 분리한다. 기존 StoreKit 잔여 실패 4건은 해결된 것으로 간주하지 않는다.

## 환경과 격리

- macOS 27.0.1, Xcode 프로젝트의 현재 SDK. Mac 테스트 번들 식별자는 빌드 시에만 `com.daylog.verify`로 격리했다.
- iOS 27.0 / build 24A434, iPhone 17 Simulator `0426CD78-3807-4650-9776-B649780E2884` 전용 테스트 환경.
- 사용자 데이터 대신 in-memory 모델 컨테이너, UUID UserDefaults, 로컬 StoreKit Configuration을 사용했다. 운영 앱 교체·실제 결제·Sandbox 구매·커밋·푸시 없음.
- 원본 761개 비교는 `preservation-after.json` 참조: 기존 723개 원화·동작 및 휴가 26장 포함 변경 없음.

## 홈 시각 검증

| 항목 | 결과 | 근거 |
|---|---|---|
| 동일 green Pio 조건의 변경 전후 | PASS (네이티브 구성요소 캡처) | `before-green/iphone-home-header.png` → `after-final/iphone-home-header.png` |
| 기본 경로 기존 캐릭터 참고 | 기록 | `before/iphone-home-header.png`는 Saessagi 경로이므로 green Pio 비교 기준과 구분 |
| AX5 글자 크기 | PASS (샘플 시각 검사) | `after-final/iphone-home-AX5.png`, 헤더 겹침 및 Today 텍스트 잘림 없음 |
| 좁은 320pt / 넓은 768pt | PARTIAL | `after-final/home-layout-320pt-iphone-host.png`, `home-layout-768pt-iphone-host.png`; 같은 iPhone 호스트 폭 제약이며 별도 iPad/소형 iPhone 실행 아님 |
| 실제 Core Animation 인사 변화 | PASS | `after-final/header-motion-frame-1.png`부터 `20.png`, 실제 타이머·presentation 값 변화 확인, 중단 후 animationCount=0 |
| 인사 종료 후 idle 자동 복귀 | PASS | `PioHeaderCompletionTests`, 실제 completion Task를 Observation으로 기다려 2.839초 후 nil, 다음 jump 수락; sleep·수동 complete 없음 |
| Mac 실제 홈 UI / 별도 iPad / 별도 소형 iPhone | NOT_TESTED | Mac 윈도 가시성 검증 환경 제한; 폭 제약 이미지로 기기 실행을 대체 판정하지 않음 |
| VoiceOver 실제 탐색 / OS Reduce Motion 토글 | NOT_TESTED | 소스·단위 검증과 실제 접근성 조작을 구분 |

20프레임은 약 2초의 실제 네이티브 모션 표본이며 전체 애니메이션 동영상 또는 10종 전체 동작 검증이 아니다. 독립 리그 캡처에는 DEBUG `-PioOverhaulTrial` 경로를 사용했다. Release fallback 지원 동작은 별도 단위 테스트로 검증했다.

## 테스트 결과

- `mac-final-checks.log`: HeaderInteraction 5 PASS, AppBrand 4 PASS, Mac window lifecycle 1 FAIL. `mac-final-summary.json`: 9 PASS / 1 FAIL / 0 SKIP.
- `mac-completion-final.log`: 자동 종료 1 PASS (2.839초), HeaderInteraction 5 PASS. 추가 Swift Testing 회귀 세그먼트(NotificationPlan/TemplateFile/MobileUIConfig)는 시작 메시지 이후 완료되지 않아 작업의 xcodebuild PID만 SIGINT로 중단했다(exit 75). 이 추가 집합은 NOT_TESTED/실행 미완료이며 전체 PASS가 아니다. 해당 로그를 보존하고 헤더 XCTest만 별도 실행했다. 중복 실행을 새로운 테스트 개수로 합산하지 않는다.
- `ios-final.log` / `ios-final-summary.json`: 홈 네이티브 검증 2 PASS, ledger 1 SKIP. SKIP 이유는 첫 호출에서 명시적인 `-pio-storekit-ledger-fixture` opt-in이 빠졌기 때문이다. 이후 올바른 플래그로 실제 실행한 결과는 아래 FAIL이며 숨기지 않았다.
- `ios-ledger-final.log`: 13종 전체 로컬 verified fixture **FAIL**. `SKTestSession.buyProduct(identifier:)`가 `outfit.rainy` 거래 ID 10을 반환했으나 즉시 `currentEntitlements` 조회에는 ID 9 이하만 관측되어 receipt XCTUnwrap이 실패했다. 원인은 이번 범위에서 확정하지 않았다. assertion 제거·지연 확대·구매 관리자 변경 없음.
- 실제 verified 영수증 → 착용 → dashboard/cloudDownloading/cloudCompleted/cloudFailed/vacationDay/vacationNight 일치 및 preview 비변경까지 성공: 기본, 벚꽃, 여름휴가, 가을, 겨울, 할로윈, 크리스마스, 한복, 카페, 학생, 운동. 비오는날은 영수증 조회 단계 FAIL, 잠옷·우주는 미도달 NOT_TESTED.
- `verified-relaunch/run.json`: **2단계 PASS**, 카페 verified Xcode 거래를 seed한 뒤 별도 PID 프로세스에서 같은 거래·착용·6개 장면 상태 복구 확인. UUID 저장소와 테스트 ledger는 종료 후 정리했다. 이것은 프로그램 방식 통합 검증이며 옷장 탭 구매 UI E2E나 `Product.purchase()`/실제 Sandbox 검증이 아니다.
- 이전 StoreKit 4개 실패의 재실행·해결은 이번 범위 밖이며 여전히 알려진 문제이다.

초기 홈 테스트의 DashboardDecor/CloudSyncMonitor 환경 누락은 테스트 fixture 결함으로 고쳤다. 초기 브랜드 CFBundleName 실패는 최종 localized InfoPlist.strings 적용 후 기존 assertion 그대로 4/4 PASS. 원래 실패 로그는 보존했다.

- 최종 헤더 전용 완결 실행 `mac-header-completion.log` / `mac-header-completion-summary.json`: **6 PASS / 0 FAIL / 0 SKIP**, 실제 자동 종료 1 + 기존 헤더 5. 추가 회귀 집합의 중단과 별개이며 미완료 테스트를 삭제하지 않았다.

## 빌드

- `mac-release.log`: macOS Release **BUILD SUCCEEDED**.
- `ios-release.log`: iOS Simulator Release **BUILD SUCCEEDED**.
- 실제 iOS 기기 서명·배포·설치 및 Apple Sandbox는 NOT_TESTED.
- `brand-built-metadata.json` / `BRAND.md`: Mac/iOS/widget 사용자 표시 Bundle 문자열 RoutiMori 확인. 내부 PRODUCT_NAME/실행파일/식별자와 사용자 표시 브랜드를 구분.

## 성능·생명주기

`mac-performance/scene-120s.json` 및 `summary.json`, `mac-lifecycle-v2.log`:

- 120.0443초, getrusage 기반 프로세스 CPU 시간 / 경과 시간 = **1.0217%**.
- RSS 시작 **191,545,344 bytes (182.7 MiB)**, 최대/종료 **467,173,376 bytes (445.5 MiB)**.
- 1초 간격으로 측정하고, 의상/장면 전환 및 중단을 반복했다. 종료 후 직접 리그 animationCount 0 확인.
- 다른 빌드 없이 측정했으나 **윈도를 앞으로 요청했을 뿐 OS에서 실제 visible 상태가 확인되지 않았다**. 따라서 화면에 표시 중인 GPU/CPU 비용 또는 오프스크린 최적화 성공으로 인증하지 않는다.
- 이미지 캐시를 포함하는 메모리 증가가 있었으므로 장기 누수 없음 PASS로 판정하지 않는다. 비교 가능한 정적/애니메이션 전후 대조 실험도 아니다.

Mac window lifecycle FAIL의 정확한 관측 (`mac-window-diagnostic.log`): host.window === window, isVisible=true, isMiniaturized=false, bounds/visibleRect 유효. 하지만 occlusionState.rawValue=8192이고 `.visible.rawValue=2`여서 visible bit가 없었다. 수동 refresh도 false였으며 기대한 실제 visible callback을 관측하지 못했다. 이 환경에서는 최소화·orderOut·복귀 자동 처리가 끝까지 검증되지 않았다. 앱 결함 또는 SDK 결함으로 단정하지 않는다. 실패 assertion은 유지한다.

## 원화와 남은 승인

- 휴가 26장 자체의 눈·팔·음료 독립 레이어는 존재하지 않으며 별도 원화가 필요하다. `BLOCKED_ASSETS.md` 참조.
- 휴가 전체 전경의 제한된 움직임과 독립 관절 움직임을 동일하게 보고하지 않는다.
- 장면 네이티브 캡처·모델 극값 검증은 이전 `../pio-scenes-integration-2026-10-23/QA.md`의 명시된 범위만 재사용한다. 이번 홈 검증이 14종 전체 장면 UI E2E를 새로 통과했다는 뜻이 아니다.
- 전체 PASS 조건: 실제 가시 Mac 창의 생명주기, 별도 기기 크기, 실제 VoiceOver/Reduce Motion, 전체 13종 verified flow 및 장기 메모리 관찰 보완 필요.

## 원본 결과 위치

실행 로그, JSON, PNG는 이 QA 폴더에 저장했다. 최종 헤더 6개 XCTest와 iOS 홈 캡처 결과 원본 번들은 `xcresults/PioPolish-header-completion.xcresult`, `xcresults/PioPolish-ios-final.xcresult`에 복사 보관했다. 원본 xcresult는 `/tmp/PioPolish-ios-final.xcresult`, `/tmp/PioPolish-ledger-final.xcresult`, `/tmp/PioPolish-final-checks.xcresult`, `/tmp/PioWindow-diagnostic.xcresult`, `/tmp/PioPolish-completion-final.xcresult`이며 재실행 2단계 번들은 `verified-relaunch/`에 있다. `/tmp` 결과는 임시 경로이므로 영구 보관으로 간주하지 않는다.
