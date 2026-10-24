# 피오 독립 원화·클라우드·휴가 — 2026-10-24

최종 판정 **PARTIAL**. 실제 새 원화와 동작하는 클라우드 리그를 만들었다. 14종 클라우드 후보의 독립 눈과 몸통에서 분리된 손·태블릿 동작을 Mac/iPhone Simulator에서 검사했다. **Release 일반 경로에 반영한 범위는 기본 피오의 눈 깜빡임·걱정 표정이다. 14종 손·태블릿은 DEBUG 검토 후보이며, 휴가의 독립 눈/손/소품/양쪽 고정 매듭은 미완성이다.**

## 실제 제작한 파일

내장 이미지 편집 도구로 신규 투명 RGBA PNG **42장**을 만들었다. 기존 눈썹 donor2장을 포함한44소스의 경로·크기·alpha·SHA는 [artifact-inventory.json](artifact-inventory.json)에 있다. 앱 카탈로그 복사본을 별도 원화로 중복 집계하지 않았다.

- 현재 클라우드 제작 세트34장: 기본8장 + 유료13종×몸통/팔쌍2장=26장. 기본 세트는 clean face/body, open/closed/half eye pair, restored torso, arm pair, complete tablet, foreground foot pair다. Half pair는 소스만 있고 현재 리그에는 연결하지 않았다.
- 이전 불합격 클라우드 후보3장: 한복의 늘어진 소매 끝, 벚꽃의 불필요한 망토 형태, 우주복의 큰 소매 뿌리/작은 장갑. 교정본을 새 파일로 만들고 이전 파일을 보존했다.
- 휴가 불합격 후보5장: 얼굴 복원/눈 주변 패치3장, 고정 줄2장. 실제 생성·검토했지만 기준 미달로 적용하지 않았다.
- 현 클라우드 선정 원화는1254×1254, 휴가 후보는1024×1536. 이전 우주복 불합격 팔 아틀라스는1388×1133이며1254원본이라고 주장하지 않는다. 실제 크기 기준 sampler가 기록되어 있고 현재는1254교정본을 사용한다.
- 눈/팔/발 쌍은 한 PNG에 두 부품이 담긴 투명 아틀라스다. 각각 독립 CALayer가 별도 영역을 표시한다. 부품 하나당 파일 한 장이라고 주장하지 않는다.
- 가려진 몸통/손/태블릿 픽셀은 실제 이미지 도구가 새로 그린 것이다. 원본에서 손실 없이 복구한 픽셀이 아니다. Python은 메타데이터·알파·해시 분석 및 바이트 동일 복사에만 사용했다.

원화 경로: `output/pio-independent-2026-10-24/<outfit>-cloud/`. 각 폴더의 `registration-v2.json`에 실제 asset명,1254기준 목표rect/pivot/z, 원본 영역 sampler, 잡기 관절과 안전 회전 범위를 기록했다. `PROMPTS.md`/`prompts.md`, provenance 파일은 실제 생성 출처를 기록한다. 원본은 덮어쓰지 않았다.

## 기존 BLOCKED_ASSET 6개와 해결 범위

| 항목 | 현재 상태 | 실제 구현 / 남은 조건 |
|---|---|---|
| CLOUD_BASIC_EYES | PARTIAL, 기본 blink 기능 해결 | 새 clean face/open/closed/brows를 기존 리그에 연결. 일반 Release 경로 포함. Half source만 미통합, signed Release 실기기 실행 미검증. |
| CLOUD_PAID_HANDS | PARTIAL,13종 실제 분리 원화/후보 리그 완료 | 의상별 복원 torso와 실제 sleeves/cuffs/hands 제작.14종 전체 DEBUG native 검수. 자유로운 손 놓기/인사·개별 손가락 동작 및 Release 승격 미완료. |
| CLOUD_TABLET | PARTIAL,14종 잡기 관절 구현 | 완전한 태블릿 원화와 손을 같은 hold joint에 연결. 의상별 rect/pivot 보정. 부모 몸통과 독립적 ±1.5° 움직임. 전체 앱/구매 의상 전환/장기 메모리 검증 후 Release 검토 필요. |
| VACATION_EYES | BLOCKED_ASSET | 실제3후보 생성. 원본 형태 변형 또는 밝은 솜 패드 경계가 남아 네이티브 합성 품질FAIL. |
| VACATION_HANDS_PROPS | BLOCKED_ASSET | 승인 가능한 reclining torso/arm/prop 접촉 세트 없음. 기존 태블릿 손을 해먹 자세에 붙이지 않음. 의상별 실제 소품 분리·가려진 몸통 재작화 필요. |
| VACATION_ROPES | BLOCKED_ASSET | 실제2후보 생성. 매듭·막대 좌표 불일치와 넓은 halo로FAIL. 양쪽 고정 줄과 움직이는 천을 분리 연결하지 않음. |

**3/6항목에 실제 클라우드 원화·리그 진척, 휴가3항목은 BLOCKED_ASSET 유지. 전체 명세/Release까지 완전히 해제한 항목은0/6이다.** 이는 원화가 없다는 뜻이 아니라, 분리 원화·검토 후보와 모든 운영 장면 완료를 구분한 것이다. 기존 휴가26원화 및 기본 낮/밤 원화를 유지한다. 이미 깨끗한 낮 해변 배경은 재생성하지 않았다.

휴가의 정확한 실패 증거·다음 아트 요구사항: [눈 복원 검토](../../../output/pio-independent-2026-10-24/vacation/REVIEW.md), [고정 줄 검토](../../../output/pio-independent-2026-10-24/vacation-ropes/REVIEW.md). 전체 의상별 실제 소품/좌표 계약은 기존 [ARTWORK-SPEC.md](../pio-artwork-final-2026-10-24/artwork/ARTWORK-SPEC.md)를 따른다. 잠옷은 베개, 우주복은 닫힌 visor/음료 없음, 카페는 커피라는 설계를 보존한다.

## 리그·의상 호환과 Release 구분

새 애니메이션 엔진을 만들지 않고 기존 `PioCloudCharacterRig`에 원화 등록을 연결했다. 실제 open/closed 원화를 교체하며 몸통을 회전시켜 눈 움직임처럼 보이게 하지 않는다. 두 손은 접촉을 유지하도록 태블릿과 하나의 관절로 움직인다. 눈3.6초/걱정5.2초, 잡기6.4초로 동일 주기 기계적 반복을 피한다. 기존 홈14종×10동작의 타이밍과 원화는 수정하지 않았다.

14종: 기본, 벚꽃, 여름휴가, 가을, 겨울, 할로윈, 크리스마스, 한복, 카페, 학생, 운동, 비 오는 날, 잠옷, 우주복. 모두 새 torso/arm 후보와 실제 native 중립·회전 극점·눈 상태를 검사했다. 여름의 불투명 선글라스는 유지하므로 그 뒤의 눈 깜빡임이 보인다고 주장하지 않는다. 학생 안경·우주복 visor도 기존 레이어를 재사용한다. 의상별 상세 시각 판정은 [ARTWORK-STATUS.md](ARTWORK-STATUS.md)에 있다.

Release는 새 소형 `PioCloudProduction.xcassets`의5고유텍스처+등록파일만 사용한다. 기본 receiving/trouble의 눈만 독립적이며 완료 연출/유료 의상/휴가에는 기존 정책을 유지한다. 구매 권한 확인 전에는 캐릭터 표시를 억제하는 기존 처리를 유지했다. 강제 착용·구매 권한 해제는 추가하지 않았다. DEBUG 손 후보는 `-PioOverhaulTrial -PioCloudHandsV2`로 검토하며 이것은 소유권 부여가 아니다.

## 실제로 발견하고 수정한 문제

1. Mac texture sampler의 Y원점 차이로 눈이 안 보였다. 실제 픽셀 검사로 확인 후 Mac좌표 변환을 수정했고 iOS원점은 유지했다. opacity assertion만 통과한 첫 결과는 시각PASS로 사용하지 않는다.
2. 중첩 잡기 관절이 `CALayer.render(in:)`에서 몸통 뒤에 그려졌다. 실제 삽입 순서와z순서를 일치시켰다. 모든 화면 compositor의 동일 버그로 일반화하지 않는다.
3. 기본 태블릿이 앞발을 가렸다. 실제 새 발 쌍을 원래 앞쪽 위치로 등록하고 Mac/iOS앞발 및 양쪽 극점 검수.
4. 우주복 새 팔의 장갑이 작고 뿌리가 커서 중복 팔처럼 보였다. 원래 hip padding을 지우지 않고 새 짧은 소매/장갑 원화로 교정했다. 원본 visor가 태블릿 뒤에 오도록 기존 가림 순서를 유지했다.
5. 과거 fallback 테스트 및 새 fixture 일부에 이전 Basic capability/revision 기대값이 남아 있었다. 실제 production 경로로 수정하되 기존 alpha/CGImage assertion과 명시적 flattened fallback 검증을 보존했다.
6. 반복 수명주기 테스트가 native host의 동기 deallocation을 가정했다. 명시적 autoreleasepool로 정리 범위를 닫고 실제 detach 후 정지와 weak참조 해제를 모두 검사했다. assertion을 없애거나 sleep을 늘리지 않았다.

## 빌드·테스트·검토 결과

- **PASS** macOS/iOS Release 빌드. 각 Assets.car에서 production5텍스처+등록만 포함하고 trial 리소스가 제외됨을 확인. 빌드만 했으며 signed Release 앱을 실행/설치하지 않았다.
- **PASS** 최종 선택 검사 누적44 XCTest 실행. 마지막 확대 검사는4 XCTest 메서드 안에서10의상×2검사×2플랫폼=40개 의상별 검사 조합을 수행했다. 이것을40개 XCTest라고 부풀리지 않는다. 초기 실패 시도·이미지는 삭제하지 않았다.
- **PASS(한정)** Mac/iPhone Simulator64/220pt, light/dark, open/closed/reopened, 잡기 ±극점, Reduce Motion, 정지·가시성·resize/fallback, 실제 눈 픽셀 및 리소스 정합.
- **PASS(한정)** production Basic20회 생성/표시/분리:20/20실제가시성,20/20stage와host해제, detach후트랙0.
- **NOT_TESTED** signed Release 실행, 실물 iPhone, 실제 구매한 의상의 전체 앱 재실행·클라우드 계정 흐름, 신규 손 리그14종 장기 성능, OS VoiceOver 직접 조작, 새로운 모든 화면 회전/작은iPhone/iPad E2E.
- 홈 및 작은iPhone/iPad의 기존 검사 자료는 이전 [원화 최종 QA](../pio-artwork-final-2026-10-24/RESULTS.md)에서 재사용한다. 해당 코드·원화는 보존했고 이번에 다시 실행한 것으로 집계하지 않는다. 기존77단위/회귀 전체 및 StoreKit검사는 재실행하지 않았다. StoreKit 잔여 실패4건/통합 거래 불안정성과 Sandbox NOT_TESTED는 그대로다.

명령·환경·각 실행 로그·xcresult·정확한 검증 범위: [native/NATIVE-RESULTS.md](native/NATIVE-RESULTS.md).

## 성능·접근성

같은 Mac production Basic 호스트를 가시 상태에서 active10.13초/stopped10.16초 비교했다. CPU0.352%/0.979%, RSS200.19→197.81MiB /197.81→201.75MiB. 짧은 정지 표본의CPU가 더 높으므로 성능 개선을 주장하지 않는다. 예전16.08% jumping과 다른 조건이어서 직접 비교할 수 없다.

20회 생성/제거3.26초 검사에서 RSS173.11→203.00MiB, 첫정리208.70/최대209.06/마지막203.00MiB. weak참조는 모두 해제됐지만 프로세스 할당은 남는다. 캐시/프레임워크가 기여할 수 있으나 단일 원인이나 장기누수없음으로 확정하지 않는다. GPU/배터리/실제Release성능PASS가 아니다.

장면 이탈·Reduce Motion에서 트랙 정지, 재진입에서 재시작을 검사했다. 장식 캐릭터를 VoiceOver에서 숨기고 기존 상태 문구를 유지한다. 실제 OS설정/읽기 순서 전체 인증은 하지 않았다.

## 검토 산출물

- [전체 검토 갤러리](review.html): 원본·실제 새 투명 레이어·14종 최종iOS프레임·불합격 휴가 후보.
- [기본 눈 실제 재생](native/basic-cloud-eyes-native.mp4): 후보 옵션 없는 일반 리소스 경로, Mac Debug native호스트.
- [기본 손 최종iOS](native/basic-cloud-hands-final-ios.mp4), [크리스마스 손 최종iOS](native/christmas-cloud-hands-final-ios.mp4), [카페 손 최종iOS](native/cafe-cloud-hands-final-ios.mp4).
- 각 영상은 실제 wall-time Core Animation presentation104프레임,20fps,5.2초,660×660. 실제 시뮬레이터 재생 프레임을 묶은 영상이며 실물 iPhone 녹화/전체 앱 화면 녹화가 아니다.
- [실제 시뮬레이터 화면](native/production-basic-visible-simulator.png): dedicated review host의 실제 SwiftUI장면. 운영 클라우드 로그인 흐름 검증과 구분한다.

## 변경 파일과 보존

이번 앱 변경은 `Daylog/Views/Onboarding/PioCloudCharacterRig.swift`, `RoutimoriSyncScene.swift`, 신규 `PioCloudProduction.xcassets`, 신규 DEBUG후보카탈로그 항목이다. 테스트는 `PioCloudCandidateReviewTests.swift`, `PioCloudProductionTests.swift`, 기존 `PioMacStabilityReviewTests.swift`의 capability기대값, opt-in scheme들이다. 원화·등록·출처는 `output/pio-independent-2026-10-24/`, 증거는 본 QA폴더에 있다.

작업 시작 기준 보호761파일 SHA-256 비교 결과 모두 동일. `preservation-before.json`/`preservation-after.json` 참조. 기존 사용자 미커밋 변경은 별개로 유지했다. StoreKit/상품ID/번들ID/데이터/원본761/휴가26원화 변경 없음. 커밋·push·배포·운영 앱 교체 없음.

다음 단계는 DEBUG14종 전체 장면/착용전환/장기성능 검수 후 손 리그의 Release 승격, 휴가 clean face·reclining hand/실제props·양쪽rope/cloth의 정합 재작화다. 휴가 후보를 억지 합성하거나 전체 캐릭터 흔들림을 독립 애니메이션으로 표시하지 않는다.
