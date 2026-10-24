# RoutiMori 피오 최종 캐릭터 통합 — 2026-10-24

## 최종 판정: PARTIAL

실제 코드·신규 원화·네이티브 렌더링을 추가했다. 홈 14종의 기존 10동작을 일반 앱 경로에 연결하고, 휴가 독립 눈을 총 5개 낮·밤 조합으로 확장했다. 기본 휴가 낮·밤은 두 줄 진입점을 유지하는 작은 평면 흔들림으로 보정했다. 그러나 휴가 손·음료 분리 원화, 나머지 눈 원화, 유료 권한을 통한 전체 화면·재실행 흐름, iPad 회전 및 실제 VoiceOver 검증이 남아 전체 완료가 아니다. 사람의 최종 미적 승인이나 실제 Sandbox 구매·출시 준비 완료를 의미하지 않는다.

## 구현한 사항

- 홈: `PioHomeProductionRig`가 승인된 기존 리그/10동작/앵커를 생성 과정으로 그대로 재사용한다. 14종 원본 등록 및 PNG는 byte-identical 복사·공유다. 새 애니메이션 엔진이나 새 의상 디자인을 만들지 않았다.
- 홈 일반 화면: 대기·터치 인사/점프/응원·기존 성장 이벤트 축하를 연결했다. 미사용 모션은 라이브러리에 유지한다. 의미 없는 이벤트를 신설하지 않았다. Reduce Motion·비노출 정지·마지막 요청 교체를 유지한다.
- 실제로 발견한 홈 결함 2개: 활성화 전에 받은 첫 동작이 버려지는 문제, 성장 말풍선의 기존 1.8초 종료가 2.6초 축하를 끊는 문제를 래퍼에서 수정했다. 원본 동작 시간과 성장/사용자 데이터 로직은 변경하지 않았다.
- 휴가 눈: 기존 기본 낮 + 신규 기본 밤/크리스마스 낮/크리스마스 밤/겨울 밤. 실제 원화 도구로 가려진 얼굴을 보완한 master texture를 사용한다. 눈별 standalone PNG라고 주장하지 않으며 좌표 영역을 별도 레이어로 렌더링한다.
- 휴가 줄: 기본 낮/밤의 정확히 등록된 두 원본에만 작은 면적 보존 평면 변형을 적용한다. 두 source-space 진입점을 고정하며 과도한 확대를 피한다. 가려진 매듭·줄을 새로 그렸거나 13종 유료 장면까지 해결했다고 주장하지 않는다.
- 클라우드: 기존 14종 일반 앱 경로와 이미지 공유·참조 순환 수정을 보존했다. 구매 관리자/상품 ID/권한 검증 정책은 수정하지 않았다.

## 원화 채택과 품질 게이트

실제 신규 출력 13장 중 9장 채택, 4장 불합격. 기본 밤의 첫 중간 눈 프레임과 손·음료 assembly 2안 및 그 단독 몸통 보완은 채택하지 않았다. 손과 잔 크기·접촉 위치가 기존 원본에 맞지 않아 기존 고품질 통합 원화를 유지한다. 상세 파일/해상도/앵커와 의상별 표는 [ARTWORK.md](ARTWORK.md)에 있다.

휴가 눈은 28개 의상·낮밤 조합 중 5개 독립 구현, 선글라스 여름 2개는 눈 표현 대상 아님, 나머지 21개는 신규 레이어 미제작이다. 손·음료 독립 모션과 유료 해먹 양쪽 고정점은 미완료다.

첫 3D 고정점 후보는 부품 검사에서는 통과했으나 실제 전체 화면에서 몸통이 사라지거나 잘렸다. 해당 캡처와 실패를 보존하고 기각했다. 평면 보정으로 바꾼 뒤 실제 iPhone Simulator framebuffer 낮·밤에서 몸통과 해먹이 온전히 보이는 것을 직접 확인했다. 서로 다른 시점의 결과를 혼합하지 않는다.

## 실제 촬영 증거

- [실제 iPhone Simulator 낮 화면](native-framebuffer/vacation-day-actual-simulator-framebuffer.png)
- [실제 iPhone Simulator 밤 화면](native-framebuffer/vacation-night-actual-simulator-framebuffer.png)
- [실제 시뮬레이터 낮·밤 재생 영상, 29.15초](native-framebuffer/vacation-day-night-actual-simulator.mov)
- [전체 검토 갤러리](REVIEW.html): 실제 네이티브 캡처, 원화 후보, 기각된 결과, 기존 증거 재사용을 구분한다. 실제 물리 iPhone 촬영은 아니다.

## 착용·구매 상태 통합

현재의 중앙 appearance state와 허가 검사를 재사용한다. DEBUG 미리보기로 유료 소유권 검증을 대체하지 않았다. 새 엄격한 local StoreKit integration 2개는 Mac에서 fixture 구매 `notEntitled`, iPhone에서는 만료된 StoreKit Testing 인증서 검증 오류로 실패했다. 무료 4조합만 실제 shared state로 관측했으며 유료 52조합의 verified 장면 전환은 미실행이다. 원인이 앱 또는 SDK라고 단정할 증거는 부족하다.

이 환경에서 동일 구매를 반복하거나 인증서/시계/보안 정책을 완화하지 않았다. 실제 OS 즉시 재실행 검사는 같은 선행 조건이 막혀 이번 패스에서는 NOT_TESTED다. 이전 재실행 PASS를 새 패스 PASS로 재사용하지 않는다. [VERIFIED-INTEGRATION.md](VERIFIED-INTEGRATION.md) 참조. 기존 StoreKit 알려진 4개 실패도 별도로 유지하며 이번 해결 사항이 아니다.

## 수정 파일

이번 시작 스냅샷과 비교한 정확한 목록은 [source-changes-this-pass.json](source-changes-this-pass.json)에 있다. 기존 미커밋 전체를 이번 변경이라고 보고하지 않는다.

앱 소스: `PioAppearanceView.swift`, `PioHeaderCompanion.swift`, 신규 `PioHomeProductionCharacter.swift`/`PioHomeProductionRig.swift`, `PioVacationIndependentEyes.swift`, `RoutimoriVacationScene.swift`, 신규 `PioVacationAnchorMotion.swift`.

리소스: 신규 `PioHomeProduction.xcassets`와 생성/검사 스크립트, `PioVacationProduction.xcassets`에 신규 승인 눈 texture만 추가. 원본은 덮어쓰지 않았다. 집중 테스트와 실제 렌더/성능/기기 검사 fixture는 별도 신규 테스트 파일이다.

## 검증 결과

| 검증 | 상태 | 실제 범위 |
|---|---|---|
| 최종 Mac 집중 회귀 | **PASS 107/107** | 98 Swift Testing(기존77+홈8+고정점4+장면9), XCTest9(휴가6+클라우드3). `mac-regression-final-tests.log` |
| 홈 실제 동작 | PASS | 14종×64/220×idle/greet/정지 =84 PNG, 대표3유한동작 실제 시간 재생·자동idle 복귀. 개별 모션 전체의 사람 시각 승인과는 별개 |
| 최종 Mac 전체 화면 | PASS | 실제 NSWindow 2크기×6화면=12 PNG, `mac-native-screens-C8-tests.log` 실행1검사 |
| 최종 iPhone17 휴가 | PASS 8/8 | Night6+두고정점 native1+전체화면1. 별도 실제 framebuffer 캡처 검사1 PASS,29.15초 영상 |
| 최종 작은 iPhone | PASS 2/2 | 전체 화면과 AX5 큰 글씨 스크롤. 모든 사용자 흐름 전수검사는 아님 |
| iPad | **PARTIAL** | 최종 평면 보정 후 실제 portrait 12캡처 검사1/1 PASS, AX5 스크롤 PASS. 실제 landscape orientation 요청 확인2회 FAIL. 회전 결과를 합성 화면으로 대체하지 않음 |
| 유료 verified 통합 | **FAIL / 환경 차단** | 새2메서드가 Mac·iPhone 각각 실패. 유료52조합 및 새OS재실행은 미검증 |
| macOS Release | **PASS** | 일반 `Daylog` 스킴, 미설치. `mac-release-final.log` |
| iOS Simulator Release | **PASS** | 일반 `DaylogiOS` 스킴, 미설치. `ios-release-final-correct-scheme.log` |
| 원본 보존 | **PASS** | 보호761/761, 기존장면387/387 SHA동일. `protected-final-verification.json` |
| Release 리소스 | PASS | 각 플랫폼 home160등록/cloud162등록/vacation12신규PNG, DEBUG overhaul/trial0. 원래 bundle ID유지. `release-resource-verification.json` |
| VoiceOver 수동·실물기기·실제OS background·장기120초 이상 | **NOT_TESTED** | 자동 접근성 구조·Reduce Motion·native 정지를 이 항목의 완료로 확대하지 않음 |

처음 iOS Release 호출은 Mac전용 스킴을 선택해 목적지 오류가 났고 iOS전용 스킴으로 수정해 성공했다. Mac 화면 재검사에서 iOS전용 테스트 클래스 필터를 사용한 한 번의 실행은 0개였으므로 PASS 수에 넣지 않고 올바른 Mac클래스의 실제 실행1개를 별도로 확인했다. 로그는 모두 유지한다.

C6 성장 축하 테스트의 비표시 CALayer 조회 실패는 실제 visible NSWindow에 같은 테스트를 연결해 재현 조건을 바로잡았다. 1.8초에도 movement5트랙과 presentation이 유지됐고 2.642초에 자동idle로 돌아와 8/8 PASS였다. assertion 삭제·대기시간 확대 없이 확인한 테스트 수명 관측 문제다. 초기실패와 최종PASS는 모두 남겼다.

전체 고유 테스트는 **134개: 최신 관측 PASS131 / FAIL3**이다(98 Swift Testing+36 XCTest). 실패3개는 iPad 실제회전1, verified integration2이며 후자는 Mac/iPhone 각각 실패했다. 기기별 상세·초기 실패·재검증은 `test-inventory.json`에 보존한다. 반복 실행 수를 고유 검사 수에 더하지 않는다. StoreKit 이전4실패는 이번 범위 밖이며 재실행·해결하지 않았다.

## 성능 결과: PARTIAL

최종 동일조건 quiet7 **7/7 PASS**,50·20·10회 cloud 진입/이탈과 14종 반복에서 정지 tracks0 및 bounded weak 해제를 확인했다. 새 홈 production 별도28회 검사도 PASS다.

- 새 홈 production: 초기174.78 / 최대234.97 / 종료118.50MiB. 첫 baseline이며 기존 정적 홈과의 개선 비교가 아니다.
- 최종 cloud14: 초기212.38 / 최대422.53 / 종료187.91MiB.
- 최종 vacation14 낮·밤: 초기160.16 / 최대448.30 / 종료204.25MiB.
- 이전 canonical 기준 cloud최대388.28, vacation최대297.17보다 높다. 캐시 출발 상태·추가 원화 비용 등의 원인은 allocation stack 없이 확정하지 않는다. 기존967.23MiB 이전 값보다 낮다는 이유로 이번 증가를 숨기거나 회귀없음으로 판정하지 않는다.
- cloud CPU 활성0.21040% / 정지0.21646%(one core),3쌍 명목95% 차이구간이0을 포함하여 CPU개선 판정하지 않는다.
- 모든검사rig가 해제됐다는 사실은 장기누수 없음·실물 작은기기 메모리예산 통과를 보장하지 않는다. **448.30MiB 최대치는 남은 검증 위험**이다.

원본JSON·동일조건비교·남은측정은 [PERFORMANCE.md](PERFORMANCE.md)에 있다.

## 남은 작업

1. 손·음료·가려진 몸통을 원본과 맞는 위치/비율로 다시 제작하고 품질 게이트를 통과시킬 것.
2. 휴가 나머지 21개 눈 조합과 유료 장면별 줄/매듭 앵커 원화·등록을 제작할 것.
3. 정상적인 Apple 로컬 테스트 인증서/서명 환경에서 verified 56조합과 OS 즉시 재실행 흐름을 다시 검증할 것. 이후 실제 Sandbox는 별도 작업이다.
4. iPad 실제 회전·창 변화, 작은 기기, VoiceOver 수동 순서, 실제 OS 백그라운드/장기 성능의 미검증 항목을 완료할 것.
5. 휴가 최대448.30MiB의 할당 원인을 추적하고 작은 실물 기기의 메모리 예산을 검증할 것.
6. 새 눈과 홈/해먹 재생을 사람의 최종 시각 승인으로 확정할 것.

운영 앱 교체·실제 결제·사용자 데이터 변경·App Store Connect 변경·커밋·푸시·배포는 수행하지 않았다.
