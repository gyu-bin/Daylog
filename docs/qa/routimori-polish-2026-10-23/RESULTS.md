# RoutiMori 브랜드·홈·장면 통합 결과

최종 판정: **PARTIAL**. 사용자 표시 브랜드, 홈 헤더와 기존 모션을 재사용하는 반응을 구현하고 빌드·네이티브 캡처·검증된 로컬 거래 기반 연결을 확인했다. 분리 원화 부족, 일부 실행 환경 검사 실패, 모든 의상의 실제 UI 흐름 미검증을 완료로 처리하지 않는다.

## 변경한 기능과 파일

- 브랜드: iPhone/iPad `DaylogiOS`, macOS `Daylog`, 위젯 `DaylogWidgets`의 표시 이름을 정확히 **RoutiMori**로 통일했다. 홈/온보딩/스플래시/설정/사이드바/Mac 창·메뉴/위젯/알림/접근성·안내 문구를 수정했다. `DaylogShared/AppBrand.swift`, `DaylogShared/ko.lproj/InfoPlist.strings`, Config 표시용 plist, 프로젝트의 표시 이름 설정과 관련 뷰를 변경했다. 전체 목록은 `brand-changed-files.json`, 근거는 [BRAND.md](BRAND.md).
- Xcode의 생성 Info.plist가 기술적인 PRODUCT_NAME으로 CFBundleName을 다시 만드는 것을 실제 실패로 확인했다. 기술 제품명·실행 파일명을 바꾸지 않고 Apple의 표시 이름 현지화 리소스로 해결했다. 실제 Bundle API 검사 4개가 통과했다. 기존 raw CFBundleName의 Daylog는 기술 값이고 사용자 표시 값은 RoutiMori다.
- 홈: `TodayCompactView.swift`에서 브랜드·피오·기존 버튼을 정돈하고 날짜/인사말/이동 버튼을 다음 행으로 배치했다. 피오 버튼64pt, 좁은 화면52pt 대안, 날짜 버튼44pt를 확보했다. 큰 글자는 별도 행을 사용한다. `DashboardView.swift`의 넓은 레이아웃은 기존 높이를 유지하며 같은 피오 래퍼를 쓴다.
- 모션: 신규 `PioHeaderCompanion.swift`, `PioHeaderNativeCharacter.swift`는 기존 리그를 재사용한다. 작은 대기 자세·눈 깜빡임, 단발 인사/점프/응원, 루틴 완료/건너뜀 반응, 중복 터치 차단, 취소·대기 복귀를 연결했다. 원래 14×10 모션 파일은 변경하지 않았다. Release의 합쳐진 유료 원화는 지원되는 통통 반응을 사용하며 독립 날개 인사로 부르지 않는다. 상세는 [HEADER.md](HEADER.md).
- Mac 생명주기: `PioCloudSceneHost.swift`, `RoutimoriVacationScene.swift`에 현재 창의 가림/최소화 상태 관찰과 실제 표시 조건을 추가했다. 홈 래퍼도 같은 호스트를 재사용한다. 이번 환경에서 표시 상태의 양성 검사는 실패했으며 아래에 구분한다.
- 테스트: AppBrandTests, PioHeaderInteractionTests, PioHeaderCompletionTests, PioPolishLifecycleTests, PioHomePolishReviewTests 및 PioVerifiedSceneAssertions. 기존 LedgerFixture/ProcessRelaunch 검사에는 실제 검증된 소유 상태에서 6개 장면 및 미리보기 비변경 조건을 추가했다. 앱 구매 관리자는 변경하지 않았다.

## 홈 화면 전후와 모션

비교 기준은 같은 iPhone 17 UIKit 테스트 호스트·같은 피오 활성화 조건·같은 임시 데이터다. 초기 새싹이 캡처는 피오 비교에 사용하지 않는다.

- [변경 전 피오 홈](before-green/iphone-home-header.png)
- [최종 변경 후 홈](after-final/iphone-home-header.png)
- [큰 글자 AX5](after-final/iphone-home-AX5.png)
- [320pt 폭](after-final/home-layout-320pt-iphone-host.png)
- [768pt 폭](after-final/home-layout-768pt-iphone-host.png)

중간 after 캡처에서 첫 콘텐츠 카드의 위쪽 경계가 y770px→692px(@3x), **26pt 위로 이동**했다. 측정 원본과 해시는 `header-before-after-observation.json`에 있다. 최종 캡처도 별도로 저장했다. 루트와 구현 담당자가 실제 이미지를 확인했으며 보통 크기/320pt/AX5 헤더에서 글자·피오·버튼의 겹침이나 피오 발 잘림은 보이지 않았다. 320/768pt는 같은 iPhone 호스트의 제약 폭이며 실제 작은 iPhone/iPad 기기 검증을 대신하지 않는다.

`after-final/header-motion-frame-1.png`부터 연속 프레임은 네이티브 Core Animation 재생에서 캡처했다. 검토용 분리 원화 경로와 Release 렌더러의 능력은 다르다. **독립 눈·날개 대기 모션은 DEBUG 검토 경로에서 검증했고 Release 전체 완성이라고 주장하지 않는다.**

## 클라우드·휴가와 14종 호환

- 기존 클라우드 유료13종의 독립 눈/표정과 완료14종 축하 모션을 보존했다. 기본의 앉은 자세 눈, 유료의 손/태블릿 분리 원화가 없으므로 `BLOCKED_ASSET`이다. 신규 분리 렌더러는 기존 DEBUG `-PioOverhaulTrial` 범위를 유지한다.
- 휴가26장 원본과 낮/밤 배경, 기존 colorScheme 정책, 해먹 흔들림을 보존했다. 캐릭터·해먹·손·소품이 합쳐진 원화로 독립 눈/손/마시기를 완성했다고 주장하지 않는다. 회전하는 하나의 이미지로 두 고정 매듭을 동시에 유지할 수 없으므로 정확한 양쪽 매듭도 `BLOCKED_ASSET`이다.
- 권한 확인 중 캐릭터 숨김, 현재 착용의 coordinator, 기존 구매 제한을 유지했다. DEBUG 미리보기가 소유권/착용 상태를 바꾸지 않는 조건을 추가 검사했다.
- 기존 14종 장면 렌더링 증거는 이전 [장면 보고서](../pio-scenes-integration-2026-10-23/RESULTS.md)와 `native-cloud-final/`, `native-extremes/`, `native-ios-final/`을 재사용한다. 이번 실행에서 14종 전체 화면을 다시 찍었다고 주장하지 않는다.
- 이번 실제 Xcode 검증 거래 기반 6개 컨텍스트 검사: **기본+유료10종**(벚꽃/여름/가을/겨울/할로윈/크리스마스/한복/카페/학생/운동)까지 확인했다. 11번째 유료 비 오는 날 거래는 테스트 드라이버 반환 ID가 currentEntitlements에서 확인되지 않아 전체 테스트 **FAIL**. 잠옷/우주복의 해당 순차 검사는 도달하지 않았다. 미검증 거래를 소유권으로 대체하지 않았다.
- 카페는 실제 로컬 검증 거래와 선택 파일을 사용해 서로 다른 OS 프로세스의 seed/verify **2단계 PASS**. 재실행 후 같은 거래 ID·착용 상태·홈/클라우드3/휴가2 컨텍스트 및 미리보기 비변경을 확인했다. `verified-relaunch/run.json`과 로그가 근거다. 이는 프로그램 통합 검사이며 실제 옷장 버튼→모든 화면 탐색 E2E나 실제 Apple Sandbox 구매가 아니다.

## 검증 결과와 한계

| 검사 | 결과 |
|---|---|
| macOS Release 빌드 | PASS, `mac-release.log` |
| iOS Release 빌드 | PASS, `ios-release.log` |
| Mac 브랜드 검사 | 4 PASS, 실제 표시 이름 API 포함 |
| 홈 상태/관절/Release 대체 모션 검사 | 5 PASS, `mac-final-checks.log` |
| 홈 동작 자동 종료 | PASS, 실제 Task·Observation으로 대기 복귀 확인; 최종 홈 검사 6/6 PASS (`mac-header-completion.log`) |
| iPhone 최종 헤더/실제 모션 검사 | 2 PASS, 1 SKIP(ledger opt-in 미지정; 이후 별도 실행 FAIL); `ios-final-summary.json` |
| 로컬 검증 카페 의상 즉시 재실행 | seed/verify PASS, 별도 프로세스·동일 거래 확인 |
| 전체13종 소유 의상→장면 검사 | FAIL, 기본+10종까지 확인 후 비 오는 날 거래 조회 실패 |
| Mac 창 자동 가시성 전환 검사 | FAIL, 실제 visible 상태를 얻지 못함; 양성 복귀 NOT_VERIFIED |
| 보호 파일 | PASS 761개 SHA-256 동일; 원화/동작723개 및 휴가원본 포함 |
| diff 공백 오류 | PASS |
| 실제 VoiceOver 읽기/OS Reduce Motion 토글 | NOT_TESTED |
| 실제 작은 iPhone/iPad 기기·Mac 전체 화면 신규 캡처 | NOT_TESTED; 제약 폭/기존 네이티브 장면 증거와 구분 |
| 장시간 배터리/GPU·모든 장면 반복/백그라운드 | NOT_TESTED |

Mac 창 진단에서 host.window와 검사 window는 같고 isVisible=true였으나, SDK의 `.visible` 값2에 대해 occlusion 값8192로 visible 비트가 없었다. 현재 가시성 조건이 false를 반환하는 것은 기록된 상태와 일치한다. 테스트 실패를 숨기거나 강제로 visible로 바꾸지 않았다. 실제 데스크톱 표시가 가능한 상태에서 최소화/가림/orderOut/복귀 재검증이 필요하다. 해당 Apple API의 의미는 [공식 문서](https://developer.apple.com/documentation/appkit/nswindow/didchangeocclusionstatenotification)를 참고했다.

전체 Mac 실행은 창 검사 실패 때문에 FAILED다. 추가 Swift Testing 회귀 묶음은 시작 후 완료되지 않아 통과로 집계하지 않았다. 다른 통과한 개별 검사만 별도로 표시한다. 초기 테스트 호스트 환경 주입 누락과 이름 메타데이터 실패 로그도 보존했다. 기존 StoreKit 잔여4건 및 실제 Sandbox 미검증은 별도 알려진 문제이며 이번 변경으로 해결된 것으로 표시하지 않는다.

## 성능 관찰

120초 네이티브 클라우드 레이어 관찰에서 프로세스 CPU는 약1.02%, RSS는191,545,344→467,173,376바이트로 증가했다. 정지 후 트랙0개 조건은 통과했다. 그러나 실제 창의 표시 상태가 확인되지 않았고, 여러 의상을 처음 로드하는 조건이며 메모리 증가를 캐시와 누수로 분리하지 않았다. **보이는 화면의 장기 성능/메모리 안정성 PASS가 아니다.** 홈·휴가·배터리·GPU 측정도 아니다. 원본은 `mac-performance/`, 환경과 계산은 통합 QA 문서에 기록한다.

## 남은 작업

1. [BLOCKED_ASSETS.md](BLOCKED_ASSETS.md)의 clean face/눈꺼풀/손·어깨 뿌리/태블릿/실제 소품/해먹 전후·고정 줄을 제작하고 동일 좌표·빛·질감으로 검수한다. 임의 도형이나 저해상도 crop으로 대체하지 않았다.
2. 독립 모션의 production 통합은 검토용 원화 승인과 Release 자산 정책 확인 후 별도 진행한다.
3. Mac 실제 표시 환경, 실제 작은 iPhone/iPad, VoiceOver 읽기 순서, OS Reduce Motion, 모든 소유 의상의 실제 화면 탐색·즉시 재실행을 확인한다.
4. 안정적인 StoreKit 로컬/Sandbox 환경에서 나머지 소유 의상 검사를 수행한다. 이번 범위에서 구매 로직을 바꾸거나 실제 결제를 실행하지 않았다.
5. 메모리의 워밍업 후 반복 구간과 정지 후 회수, 보이는 화면의 CPU/GPU/배터리 비용을 추가 측정한다.
6. App Store Connect의 표시 이름은 외부 후속 작업이다. 이번에 변경/배포하지 않았다.

커밋·push·배포·운영 앱 교체·사용자 기록/SwiftData/CloudKit·제품 ID 변경을 하지 않았다. 기존 uncommitted 작업을 유지했다. 상세 구현은 BRAND.md/HEADER.md, 원화 요구는 BLOCKED_ASSETS.md, 실행별 결과는 QA.md를 함께 본다.
