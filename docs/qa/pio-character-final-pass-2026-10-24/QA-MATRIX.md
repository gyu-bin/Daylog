# 피오 14종 × 4장면 검증표

## 최종 C8 요약 (아래 초기 실패 기록을 대체하는 최신 판정)

- 홈 production 14종: 원본 140개 모션 구조 동등성 및 상태/권한/실제 완료를 포함한 **8/8 PASS**. 84개 홈 native 샘플 및 대표 15개 동작 프레임 직접 확인.
- Mac 일반 화면: C8 **1개 검사 PASS**, 두 실제 창 크기 560×600/900×650의 홈·클라우드 수신/완료/실패·휴가 낮/밤 **12장 전부 직접 확인**. 몸통/새싹/소품/해먹 소실이나 잘림 없음.
- 휴가 기본 전경: 이전 3D 고정축 캡처의 소실/잘림은 거부. 수정된 planar affine 경로의 C7 실제 iPhone framebuffer 2장 및 C8 Mac 4장에서는 온전한 전경 확인. 이 결과를 유료 모든 휴가 손·음료 독립 완성으로 확대하지 않음.
- 클라우드 수신/실패 리그 유지, 완료 장면의 기존 제한은 PARTIAL. 휴가 독립 눈은 기본 낮/밤, 크리스마스 낮/밤, 겨울 밤에 적용; 다른 프로필 및 손·음료는 ARTWORK의 구체적 제한을 따름.
- 최종 C8 회귀 **107/107 PASS**는 `mac-regression-final-tests.log` 기준. 기존77 + 홈8 + 고정점4 + 장면9 Swift98, 밤6 + 클라우드3 XCTest9. 일반 Mac/iOS Release 결과는 RESULTS 참조.
- 실제 verified 유료52장면·Apple Sandbox는 NOT_TESTED/환경 차단. 전체 결과는 **PARTIAL**이며 출시 완료가 아님.


## 판정 범위

실제 권한 검증, 리소스 존재, 모션 구조, 시각 품질은 별도로 판정한다. 아래 홈 PASS는 Mac 일반 production 리그의 64/220pt idle·greet·stopped 캡처 84장을 직접 확인한 범위이다. 140개 동작 전체의 프레임을 모두 육안 검토했다는 뜻이 아니다. 클라우드는 변경 없는 이전 native 증거를 재사용하며 새 홈 리그로 대체하지 않았다. 실제 로컬 StoreKit 공유 상태 56조합 검사는 `VERIFIED-INTEGRATION.md`의 실행 결과가 최종 근거이다.

| 의상 | 홈 | 클라우드 | 휴가 낮 | 휴가 밤 |
|---|---|---|---|---|
| 기본 | PASS · 6프레임 | PASS 수신/오류, PARTIAL 완료 | PARTIAL · 독립 눈 + 기존 장면 | PARTIAL · 독립 눈 일반 적용, 손/음료 미분리 |
| 벚꽃 | PASS · 6프레임 | PASS 수신/오류, PARTIAL 완료 | PARTIAL · 기존 전경 흔들림 | PARTIAL · 기존 전경 흔들림 |
| 여름휴가 | PASS · 6프레임 | PASS 수신/오류, PARTIAL 완료 | PARTIAL · 기존 전경 흔들림 | PARTIAL · 기존 전경 흔들림 |
| 가을 | PASS · 6프레임 | PASS 수신/오류, PARTIAL 완료 | PARTIAL · 기존 전경 흔들림 | PARTIAL · 기존 전경 흔들림 |
| 겨울 | PASS · 6프레임 | PASS 수신/오류, PARTIAL 완료 | PARTIAL · 기존 전경 흔들림 | PARTIAL · 독립 눈 일반 적용, 손/음료 미분리 |
| 할로윈 | PASS · 6프레임 | PASS 수신/오류, PARTIAL 완료 | PARTIAL · 기존 전경 흔들림 | PARTIAL · 기존 전경 흔들림 |
| 크리스마스 | PASS · 6프레임 + 인사 영상 프레임 | PASS 수신/오류, PARTIAL 완료 | PARTIAL · 독립 눈 일반 적용, 손/음료 미분리 | PARTIAL · 독립 눈 일반 적용, 손/음료 미분리 |
| 한복 | PASS · 6프레임 + 점프 영상 프레임 | PASS 수신/오류, PARTIAL 완료 | PARTIAL · 기존 전경 흔들림 | PARTIAL · 기존 전경 흔들림 |
| 카페 | PASS · 6프레임 | PASS 수신/오류, PARTIAL 완료 | PARTIAL · 기존 전경 흔들림 | PARTIAL · 기존 전경 흔들림 |
| 학생 | PASS · 6프레임 | PASS 수신/오류, PARTIAL 완료 | PARTIAL · 기존 전경 흔들림 | PARTIAL · 기존 전경 흔들림 |
| 운동 | PASS · 6프레임 | PASS 수신/오류, PARTIAL 완료 | PARTIAL · 기존 전경 흔들림 | PARTIAL · 기존 전경 흔들림 |
| 비 오는 날 | PASS · 6프레임 | PASS 수신/오류, PARTIAL 완료 | PARTIAL · 기존 전경 흔들림 | PARTIAL · 기존 전경 흔들림 |
| 잠옷 | PASS · 6프레임 | PASS 수신/오류, PARTIAL 완료 | PARTIAL · 기존 전경 흔들림 | PARTIAL · 기존 전경 흔들림 |
| 우주복 | PASS · 6프레임 + 응원 영상 프레임 | PASS 수신/오류, PARTIAL 완료 | PARTIAL · 기존 전경 흔들림 | PARTIAL · 기존 전경 흔들림 |

## 직접 확인한 이미지

- `mac-first-attachments`: 홈 14종 × 2크기 × 3상태 = 84개 원본 PNG 전부 직접 표시하여 확인했다. 잘림, 없어진 부품, 떨어진 소품, 새로 드러나는 어깨 구멍이 관측되지 않았다. 눈은 바이저·안경 뒤에 있고, 의상 질감과 비율을 유지한다.
- 같은 묶음의 실제 시간 캡처 131개 프레임 중 크리스마스 greet·한복 jump·우주복 encourage 각각 5개(시작/1⁄4/중간/3⁄4/끝), 총 15개를 직접 확인했다. 한복 점프 정점 여백과 착지 복귀, 선물 손 부착, 우주복 좌우 기울기·표정이 확인된다. 모든 131개를 직접 검토했다고 주장하지 않는다.
- `iphone-first-attachments`: iPhone 17 AX5 홈/클라우드 완료·실패/휴가 낮·밤 각각 스크롤 전후 10개를 직접 확인했다. 내용 끝으로 이동하면 확인·다시 시도하기·나중에 하기·평소 화면 보기 버튼이 보인다.
- AX5 홈 아래의 기존 휴가 행 제목은 `휴가…`로 생략된다. 캐릭터 회귀는 아니지만 전체 화면 텍스트의 접근성 완성도는 PARTIAL이다. VoiceOver 실제 낭독/스위치 제어/실기기 터치는 NOT_TESTED.

## 테스트 증거와 해석

- 홈 새 Swift Testing 5개 PASS. 그 중 원본과 production의 14×10 모션 트랙 동등성 검사 포함.
- 기존 헤더 interaction/completion 6개 PASS.
- 홈 native 84캡처 검사 PASS.
- 첫 대표 모션 검사: 3종 모두 idle 자동 복귀 관측. 우주복 encourage가 Y이동을 하지 않는 정상 타임라인인데 검사기가 Y축만 비교하여 초기 assertion FAIL. X·회전·날개 등 실제 변화를 확인하는 수정 후 재실행 결과를 별도로 기록해야 한다. 앱 모션 시간은 변경하지 않았다.
- iPhone 첫 검사 4개 PASS: 밤 눈 후보 3개 및 AX5 스크롤 검사. 후보 검증을 곧바로 Release 적용 PASS로 취급하지 않는다.
- 실제 Apple Sandbox, 실제 StoreKit 상품 가격/구매, signed Release 실기기 사용은 이 표의 PASS 대상이 아니다.

## 남은 시각 범위

유료 휴가 13종의 독립 눈·손·음료, 해먹 고정 줄·매듭과 가려진 배경 복구는 기존 전경 흔들림 성공과 별개다. 현재 파일만으로 모두 해결했다고 표시하지 않는다. 작은 iPhone/iPad, 엄격한 검증 권한의 전체 장면 전환, 반복 진입 메모리 결과는 해당 후속 증거에 따라 갱신한다.


## 엄격한 실제 권한 검증의 별도 결과

`VERIFIED-INTEGRATION.md`에 기록된 새 실행은 성공으로 대체하지 않는다.

- Mac: 실제 shared 상태의 무료 기본 의상 4장면은 렌더·scenePhase 중지/복귀를 검사했다. 유료 13종은 모두 로컬 SKTestSession fixture 구매의 `notEntitled`로 막혔다. **유료 52조합은 NOT_TESTED**, suite는 FAIL이다. 렌더 원화 검증을 verified 구매/착용 통합 PASS로 바꾸지 않는다.
- iPhone: StoreKit Testing 인증서 만료·체인 검증 실패로 setUp 두 건 FAIL. 미검증 거래를 허용하지 않았다.
- 새 OS 2-process 재실행 및 Apple Sandbox는 NOT_TESTED. 기존 패스의 재실행 결과를 이번 결과로 재계산하지 않는다.
- 원인 확정 전 앱 결제 로직 버그 또는 Apple SDK 결함으로 단정하지 않는다. 실제 구매 로직은 수정하지 않았다.

## 추가 코드 리뷰 및 최신 소스

독립 리뷰에서 최초 비활성 host 요청 유실과 1.8초 성장 버블 종료가 2.6초 축하 모션을 자르는 결함을 확인했다. wrapper만 수정했으며 세 개의 실제 시간 회귀 검사를 추가했다. 기존 84장 이미지의 외관/원화 동등성은 유효하지만 새 상태 전이의 최종 PASS는 build6 이후 결과를 별도로 확인한다. 보호된 키프레임이나 UI 버블 시간은 변경하지 않았다.

## 초기 C5/C6 기기 캡처 직접 검토 — 실패 기록 보존

`iphone-final-attachments` 12장과 `ipad-recheck-attachments` 14장, 총 26장을 원본으로 직접 표시했다. 캡처 테스트 PASS와 시각 품질 PASS는 같지 않다.

- 홈 및 클라우드 수신·완료·실패: 확인한 기본 피오의 신체/소품/얼굴은 온전하다. iPad AX5 완료·실패 버튼은 스크롤 후 접근 가능하다. iPhone AX5 최상단 프레임은 긴 화면의 일부이며 버튼 도달 검증은 별도 스크롤 증거를 사용한다.
- **FAIL — 휴가 낮:** iPhone normal/AX5와 iPad portrait/AX5에서 몸통·해먹이 사라지고 새싹 일부만 떠 있는 프레임이 관측됐다.
- **FAIL — 휴가 밤:** iPhone AX5는 몸통이 사라졌으며, iPhone normal과 iPad portrait/AX5에서는 몸통은 있으나 오른쪽 잎이 대각선으로 잘렸다.
- 이전 `iphone-first-attachments`에서는 온전한 전경이 관측됐다. 새 고정점/마스크 경로와 네이티브 캡처 방식의 영향을 원인 분석해야 한다. 아직 앱 렌더 결함과 캡처 결함을 단정하지 않는다. 두 묶음의 휴가 프레임은 승인 근거로 사용하지 않는다.
- 이 발견은 담당자에게 전달했다. 수정 후 새로운 파일/묶음의 직접 시각 검증이 있기 전까지 휴가 통합의 최종 시각 판정은 FAIL이다. 실패 증거는 삭제하지 않는다.

### C7 실제 시뮬레이터 화면으로 재확인

`native-framebuffer/vacation-day-actual-simulator-framebuffer.png`와 `vacation-night-actual-simulator-framebuffer.png` 두 장을 직접 확인했다. planar affine 고정점 보정 후 기본 피오의 몸통·해먹·줄·음료·양쪽 잎이 모두 온전하다. 이전 3D/masked-subtree 실패 캡처는 역사적 실패 증거로 보존한다. 이 두 새 캡처는 실제 simctl framebuffer이며 `CALayer.render` 프레임과 구분한다. 실제 재생 MOV도 같은 폴더에 있다. 이 범위에서 정상 iPhone 휴가 전경 잘림은 재현되지 않았으며, 후속 `ipad-portrait-final-attachments` 12장에서도 normal/AX5의 온전한 전경을 확인했다. 실제 iPad 가로 회전은 별도로 미검증 상태를 유지한다.

### C8 홈 회귀 최종 결과

`PioHomeProductionTests` **8/8 PASS** (`mac-home-hosted-C8-tests.log`). 앞선 7/8 실행에서 누락된 CA 트랙은 비표시 layer fixture 문제였다. 실제 네이티브 창에 부착하면 1.8초에도 5개 이동/회전/크기 트랙과 presentation이 유지되고 축하가 원래 2.6초 뒤 idle로 끝난다. 이전 assertion 삭제나 임의 지연 확대 없이 검사를 수정했다. Mac C8 test build PASS이며 Release 빌드는 별도 결과를 따른다.


## C8 Mac 네이티브 화면 및 전체 직접 검토 범위

`mac-native-screens-C8-attachments` 12장 전부 직접 검토했다. C8 home8/실제 화면1개 실행과 원본 export 명령은 해당 logs에 있다. 처음 iOS-only class를 Mac에 지정한 `mac-screens-C8-tests.log`는 0개 실행이므로 PASS 집계에서 제외하고, 올바른 `PioCharacterMacScreenTests`를 실행한 `mac-native-screens-C8-tests.log`만 1개 PASS로 집계한다.

후속 iPad/MOV 추가 전 이 담당자가 직접 표시한 원본 총149장: 홈84 + 모션 대표15 + 첫 iPhone AX5 10 + 초기 최종 iPhone12 + 초기 iPad14 + 실제 iPhone framebuffer2 + C8 Mac12. 실패를 포함한 검토 수이며 전체149장 승인이라는 뜻이 아니다. 추가 C7 iPhone/작은 iPhone 자료의 직접 검토는 ARTWORK 담당 결과와 구분한다. C8 Mac은 실제 SwiftUI 장면을 in-memory 테스트 host로 표시한 캡처이며 실제 사용자 기록/동기화/유료 구매 E2E가 아니다.


## 최종 iPad 세로 화면 및 실제 동영상 프레임

`ipad-portrait-final-attachments/manifest.json`의 12장(홈, 클라우드 수신/완료/실패, 휴가 낮/밤 × normal/AX5)을 모두 직접 표시하여 검토했다. 현재 planar 보정에서 휴가 몸통·해먹·새싹·음료가 정상 표시되고 이전 3D 전경 소실/잎 잘림은 관측되지 않았다. 클라우드의 손/태블릿 및 완료 표정, 홈 캐릭터 비율도 보존된다. AX5 최상단 캡처는 긴 스크롤 내용의 일부이므로 화면 아래가 안 보이는 것을 버튼 부재로 해석하지 않는다. 이 실행은 세로 화면 1/1 PASS이며, 가로 회전 검증을 대체하지 않는다. `IPAD-ROTATION.md`의 회전 미검증 판정은 유지한다.

`native-framebuffer/video-day-at-2.2s.png`, `video-night-at-18s.png`는 실제 시뮬레이터 MOV에서 추출한 원본 프레임이며 두 장을 직접 확인했다. 낮의 열린 눈, 밤의 반쯤 닫힌 눈과 온전한 몸통·해먹·소품을 확인했다. 밤 프레임의 반쯤 감긴 눈은 단일 전환 프레임이며 별도 지속 표정 완성으로 판단하지 않는다.

직접 표시한 총 원본 수는 **163장**(이전149 + 최신 iPad12 + 실제 MOV 프레임2)이다. 실패 기록도 포함한 검토 수이며 163장 전체 승인 또는 모든 의상의 실구매 검증을 뜻하지 않는다. 최종 전체 고유 검사 결과 및 메모리 수치는 RESULTS/PERFORMANCE가 기준이며 이 표는 시각 범위를 한정한다.
