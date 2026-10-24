# 피오 클라우드·휴가 통합 결과

최종 판정: **PARTIAL**. 현재 착용 상태와 기존 장면을 연결했고 실제 네이티브 렌더링을 검증했다. 원화가 합쳐져 있는 부분의 독립 동작, 모든 환경의 접근성 및 장시간 성능은 완료되지 않았다.

## 구현 결과

- 클라우드 대기/실패: 유료 13종의 기존 앉은 자세와 태블릿을 보존하고 분리된 눈·눈꺼풀·눈썹을 연결했다. 대기는 주기적 깜빡임과 주의 동작, 실패는 걱정 표정으로 정착하고 느리게 깜빡인다. 완료는 기본 포함 14종의 기존 독립 축하 모션을 한 번 재생한다. **신규 클라우드 렌더러는 DEBUG `-PioOverhaulTrial` 검토 범위**다.
- 기본 피오 대기/실패는 기존 원화를 유지한다. 기본의 독립 눈 원화와 유료 13종의 손·태블릿·어깨 뿌리 분리 원화가 없어 해당 독립 움직임은 미완료다.
- 휴가: 기본의 기존 낮/밤 장면과 유료 13종×2=26장 원본을 연결했다. 실제 야간 원화를 사용하며 기존 colorScheme 정책(라이트=낮, 다크=밤)을 유지했다. 새로운 시간 규칙을 만들지 않았다. 우주복은 승인 후보 v2를 사용한다.
- 휴가 원화는 캐릭터·소품·해먹이 합쳐져 있어 전체 해먹의 잔잔한 흔들림만 가능하다. 독립 눈·손·마시기 동작은 구현했다고 주장하지 않는다. 유료 후보 흔들림 ±0.55°, 기본 기존 ±1.5°를 사용하며 기존 10종 캐릭터 동작 타이밍은 바꾸지 않았다.
- 착용 상태는 기존 coordinator/wardrobe 권한을 재사용한다. 권한 확인 중에는 캐릭터를 숨기고 배경/진행 표시를 유지하여 기본 캐릭터 순간 노출과 미검증 유료 착용을 막는다. 새로운 소유권 저장이나 구매 우회는 없다.
- Reduce Motion, scenePhase, 화면 이탈 및 native viewport 조건에 따라 CA 트랙을 중지한다. 새 프레임별 SwiftUI 타이머는 없다. Mac 최소화/가려진 창의 모든 상태까지 실측한 것은 아니다.

## 검증

| 항목 | 결과와 범위 |
|---|---|
| Mac Debug 빌드 | PASS |
| 기존 장면 회귀 | 22/22 PASS |
| 휴가 통합 검사 | 4/4 PASS |
| 네이티브 장면 검사 | 3/3 PASS; 합계 고유 29개는 여러 기록된 실행의 결과이며 하나의 최종 전체 실행은 아님 |
| iPhone Simulator Debug 빌드 | PASS |
| 최종 Mac 클라우드 캡처 | 84장: 14종×3상태×라이트/다크, `native-cloud-final/` |
| 최종 휴가 캡처 | 85장: 28중립+56양끝 모델 자세+1실제 AppKit 창, `native-extremes/` |
| Reduce Motion | 명시적 네이티브 설정과 정지 검사 PASS; 실제 OS 설정 토글 NOT_TESTED |
| VoiceOver | 장식 레이어 숨김/기존 상태 문구 보존 정적 확인; 실제 읽기 순서·사용성 NOT_TESTED |
| 실제 소유 의상 선택→장면→즉시 재실행 | 이번 장면 통합의 E2E NOT_TESTED. 기존 StoreKit 재실행 3/3 증거와 동일하지 않음 |
| 장시간 사용/배터리/GPU/CPU 비교 | NOT_TESTED |

iPhone 17 / iOS 27 전용 시뮬레이터의 최종 네이티브 XCTest **1/1 PASS, 0 FAIL, 0 SKIP**. 42개 의상/클라우드 상태 매핑, Reduce Motion 42개 트랙 정지, 확인 대기 캐릭터 정지, native window 분리 및 휴가 숨김 정지를 검사했다. 최종 실제 네이티브 PNG 17장(클라우드 표본 9, 눈 깜빡임 2, 휴가 낮/밤 6)과 JSON을 `native-ios-final/`에 저장했다. 자세한 범위는 [IOS.md](IOS.md)에 기록했다. 네이티브 장면 캡처는 실제 렌더러의 결과이며, 전체 앱 화면·모든 방향·Dynamic Type·애니메이션 전체 시간축 검수가 아니다.

초기 Mac 휴가 캡처가 뒤집힌 것은 테스트 캡처 좌표 문제였다. 실제 AppKit 창을 캡처해 정상 방향임을 확인했고 원화나 기존 앱 좌표계를 바꾸지 않았다. 초기 클라우드의 발 잘림은 독립 캐릭터 표시 크기/위치를 조정해 수정하고 다시 캡처했다. 초기 실패/비최종 이미지는 보존하며 최종 증거와 구분한다. 휴가 테스트 NSNumber 브리징과 모델 자세 설정의 암묵적 CA 동작 문제도 assertion을 제거하지 않고 수정했다.

## 성능 관찰

Mac에서 60.00009초 동안 135,858회 레이어 구성/정지를 반복했다. RSS 시작 및 관측 최대 311.44MiB, 마지막 198.52MiB이며 정지 후 활성 트랙은 0이었다. 100회마다 샘플링했고 iOS 빌드가 동시에 실행됐다. 이는 표시 중 장시간 애니메이션이나 비교 CPU 측정이 아니며, 장기 누수 없음 또는 에너지 효율 PASS로 해석하지 않는다. 원본은 `native-mac/scene-lifecycle-60s.json`에 있다.

## 수정 파일

- `Daylog/Services/PioAppearanceCoordinator.swift`: 장면 원화 매핑과 누락/확인 대기 메타데이터.
- `Daylog/Views/Onboarding/RoutimoriSyncScene.swift`: 현재 의상·상태·독립 렌더러·생명주기 연결, 발 잘림 수정.
- 신규 `PioCloudCharacterRig.swift`, `PioCloudSceneHost.swift`: 기존 분리 원화를 재사용하는 공통 클라우드 리그/가시성 처리.
- `Daylog/Views/Dashboard/RoutimoriVacationScene.swift`: 낮/밤 의상·확인 대기·등록 좌표·생명주기 연결.
- 신규 `PioVacationSceneResources.swift`, `PioVacationScenes.xcassets`: 26장 원본 그대로 복사 및 출처/매핑.
- `PioOverhaulTrial.xcassets`에 기존 파일을 수정하지 않고 클라우드 120개 원본 동일 레이어 등록.
- 신규 테스트 `PioVacationSceneIntegrationTests.swift`, `PioSceneNativeEvidenceTests.swift`, `PioScenesIOSReviewTests.swift`.

원화·동작 기존 723개와 휴가 원본은 해시 보존 검사로 변경 없음. 시작점 761개 중 변경된 파일은 허용된 coordinator 한 개다. StoreKit 관리자·제품 ID·wardrobe 저장은 변경하지 않았다. 기존 uncommitted 작업, 사용자 데이터, 운영 앱을 보존했고 커밋·push·배포하지 않았다. 기존 StoreKit 7/11 및 잔여 실패 4건은 이번에 해결되거나 재검증된 것으로 표시하지 않는다.

## 남은 작업

1. 휴가의 실제 매듭 위치는 원화별로 달라 현재 공유 고정점은 잠정값이다. 표본 8개 양끝 자세에서 뚜렷한 캐릭터/소품 잘림은 없었으나 26장 전체의 시간축 고정점 승인 전이다.
2. 휴가 clean face/eyelid, 손·소품·어깨 뿌리, 앞뒤 해먹 가림 레이어가 있어야 독립 동작을 완성할 수 있다. 클라우드 기본 눈과 유료 손/태블릿도 같은 제약이 있다.
3. 실제 VoiceOver, OS Reduce Motion 토글, Mac 최소화·가림, 전체 앱 작은 화면/가로/큰 글자 및 장기 성능 검증이 남았다.
4. 실제 구매 권한 상태에서 의상 변경→클라우드/휴가→즉시 프로세스 재실행 E2E 검증과 최종 사용자 시각 승인이 필요하다.

상세 구현/근거는 CLOUD.md, VACATION.md, QA.md와 iPhone 보고서를 참조한다. 전체 독립 애니메이션 완성 또는 출시 승인으로 판정하지 않는다.
