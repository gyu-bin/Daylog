# 피오 최종 시각 검수

판정: **PARTIAL**. 실제 렌더링에서 캐릭터의 비율·원화·소품 접합은 아래 범위에서 유지된다. 홈의 10가지 독립동작, 휴가 14종 전체의 독립 손·음료와 두 로프 고정점은 완성 판정하지 않는다. 사람의 최종 미적 승인은 별도다.

## 직접 본 증거 범위

- `mac-visual-attachments/manifest.json`: 14종 클라우드 각 3장(220pt light open / light hold-negative / dark closed) 42장, 홈 각 idle/jump/returned-reduce-motion 42장, 휴가 각 낮·밤 시작/중간/끝 84장. 총 **168개 실제 PNG를 개별로 직접 열어 검사**했다.
- `before-native/`: 변경 전 기본 cloud production V1의 실제 Mac component presentation. 손·태블릿은 baked 상태였다.
- `vacation-native/vacation-basic-day-production-025.png`, `...-060.png`: 새 기본 낮 눈의 실제 production 리그 열린/닫힌 눈을 직접 확인했다. 눈 주변 사각 잔여물, 이중 눈, 부리·볼·빨대 겹침이 보이지 않는다.
- `iphone17-attachments/`: 실제 앱 뷰 native host 캡처가 존재한다. 홈·cloud receiving/ready/trouble·휴가 낮/밤의 normal/AX5 12장을 직접 검수했다. 이 중 초기 ready/trouble4장은 잘못된 중간 상태를 포착해 최종 상태 자료로 부적합하다. 별도 테스트 하네스가 in-memory 데이터로 실제 SwiftUI 뷰를 호스팅한 자료이며 운영 데이터 화면이나 구매 검증은 아니다.
- `iphone17-final-attachments/`, `smallphone-attachments/`, `ipad-attachments/`: 수정된 캡처 하네스의 홈·cloud receiving/ready/trouble·휴가 낮/밤 × normal/AX5를 **각 12장, 총 36장 직접 검수**했다. 세 기기의 클라우드 glyph·문구·캐릭터가 요청 상태와 일치한다. 초기 결함 4장은 보존하되 최종 근거에서 제외한다.
- component CALayer presentation에서 만든 PNG는 실제 네이티브 애니메이션 상태의 검토 자료다. 실물 iPhone 영상이나 전체앱 종단 흐름과 구분한다. 녹화 프레임 간 실제 저장 시간이 추가되어 프레임 번호를 정확한 실시간 초수로 간주하지 않는다.
- `REVIEW.html`은 실제 존재하는 원본 이미지와 영상에 연결한다. crop·리터치·합성으로 결함을 가리지 않았다. 이 환경의 브라우저 file URL 정책 때문에 HTML 브라우저 실행 검사는 NOT_TESTED이며, 원본 PNG 검수는 별도로 수행했다.

## 14종 × 4장면 매트릭스

아래 **표시 PASS**는 위에서 관측한 샘플의 방향·실루엣·원화·소품 및 잘림 검수다. 전체 모션 완성을 뜻하지 않는다. **모션 PARTIAL**은 아래 별도 제한을 따른다.

| 의상 | 홈 | 클라우드 receiving | 휴가 낮 | 휴가 밤 |
|---|---|---|---|---|
| 기본 | 표시 PASS / 모션 PARTIAL | 눈·hold 표시 PASS | 표시 PASS / 독립 눈 scoped PASS / 나머지 PARTIAL | 표시 PASS / 모션 PARTIAL |
| 벚꽃 | 표시 PASS / 모션 PARTIAL | 눈·hold 표시 PASS | 표시 PASS / 모션 PARTIAL | 표시 PASS / 모션 PARTIAL |
| 여름휴가 | 표시 PASS / 모션 PARTIAL | hold 표시 PASS / 선글라스 속 눈 가시성 N/A | 표시 PASS / 모션 PARTIAL | 표시 PASS / 모션 PARTIAL |
| 가을 | 표시 PASS / 모션 PARTIAL | 눈·hold 표시 PASS | 표시 PASS / 모션 PARTIAL | 표시 PASS / 모션 PARTIAL |
| 겨울 | 표시 PASS / 모션 PARTIAL | 눈·hold 표시 PASS | 표시 PASS / 모션 PARTIAL | 표시 PASS / 모션 PARTIAL |
| 할로윈 | 표시 PASS / 모션 PARTIAL | 눈·hold 표시 PASS | 표시 PASS / 모션 PARTIAL | 표시 PASS / 모션 PARTIAL |
| 크리스마스 | 표시 PASS / 모션 PARTIAL | 눈·hold 표시 PASS | 표시 PASS / 모션 PARTIAL | 표시 PASS / 모션 PARTIAL |
| 한복 | 표시 PASS / 모션 PARTIAL | 눈·hold 표시 PASS | 표시 PASS / 모션 PARTIAL | 표시 PASS / 모션 PARTIAL |
| 카페 | 표시 PASS / 모션 PARTIAL | 눈·hold 표시 PASS | 표시 PASS / 모션 PARTIAL | 표시 PASS / 모션 PARTIAL |
| 학생 | 표시 PASS / 모션 PARTIAL | 눈·hold·안경 표시 PASS | 표시 PASS / 모션 PARTIAL | 표시 PASS / 모션 PARTIAL |
| 운동 | 표시 PASS / 모션 PARTIAL | 눈·hold 표시 PASS | 표시 PASS / 모션 PARTIAL | 표시 PASS / 모션 PARTIAL |
| 비 오는 날 | 표시 PASS / 모션 PARTIAL | 눈·hold 표시 PASS | 표시 PASS / 모션 PARTIAL | 표시 PASS / 모션 PARTIAL |
| 잠옷 | 표시 PASS / 모션 PARTIAL | 눈·hold 표시 PASS | 표시 PASS / 모션 PARTIAL | 표시 PASS / 모션 PARTIAL |
| 우주복 | 표시 PASS / 모션 PARTIAL | 눈·hold·visor 표시 PASS | 표시 PASS / 모션 PARTIAL | 표시 PASS / 모션 PARTIAL |

클라우드 14종은 위아래 방향이 정상이며 몸통에 팔 뿌리가 이어지고 태블릿이 손 사이에 남는다. 학생 안경과 우주복 visor는 얼굴 앞의 광학층을 유지한다. 여름휴가의 불투명 선글라스 때문에 눈 깜빡임을 사용자에게 보인다고 주장할 수 없다.

홈 42장에서는 모자·우산·베개 등 외곽이 잘리지 않고 캐릭터의 얼굴과 몸통 비율이 유지된다. 세 샘플 간 자세 변화는 작다. 이 자료는 14종 × 10가지 독립동작 전체가 일반 Release에서 재생된다는 증거가 아니다.

휴가 84장에서는 낮의 밝은 해변과 밤의 달·등불 배경이 각각 유지된다. 어두운 필터로 낮 원화를 대신하지 않는다. 의상별 소품은 원래 모습과 접촉을 유지한다. 잠옷은 베개, 카페는 커피, 우주복은 밀폐 visor를 보존하며 일반 주스를 억지로 공유하지 않았다. 밤/낮 원본 구도와 선물 위치 등이 다른 것은 기존 개별 원화 구성이다. 관측한 작은 sway는 캐릭터와 해먹 전경 전체의 움직임이다.

## 독립 모션의 정확한 적용 범위

- 홈: 일반 production `PioOutfitMotionRig`의 완성형 PNG 모션. DEBUG Overhaul의 모든 독립동작을 production에 승격했다는 판정은 하지 않는다.
- 클라우드 receiving/trouble: 눈/lid 트랙과 팔2개·태블릿 공통 hold joint. 손과 소품은 같은 joint로 접촉을 유지한다. 각 손이 소품과 별개로 자유롭게 움직이는 기능은 아니다. ready는 기존 의상 PNG와 제한된 bounce이므로 독립 눈·손 celebration은 PARTIAL.
- 휴가 기본 낮: 새로 복원한 눈 주변2영역과 기존 고해상도 눈 donor를 일반 리그에 연결한 좁은 범위의 독립 눈. 전체 원화를 교체하지 않는다. 원래 웃는눈과 열린눈 사이 변화가 보이며 해먹 이동을 따라간다.
- 휴가 기본 밤·유료13종: 원본 전경 sway 유지. independent hands/drink, 양쪽 고정 로프/매듭 완료는 미지원이다.

## 원화·진단 실패를 숨기지 않음

[원화 제작 결과](artwork/ARTWORK-RESULTS.md)에 생성된 음료2후보의 halo·좌표·크기 불일치 FAIL과 미적용 이유를 기록했다. 새 눈의 full-scene candidate도 전체교체하지 않고 검수한2영역만 사용한다. 실패한 sampler/presentation/blank snapshot 증거는 vacation-native 하위 before-* 폴더에 보존했다.

`clips/iphone17-cloud-native-screen.mov` 및 `iphone17-live-cloud.png`가 있다면 이는 초기에 투명한 component host 아래 Dashboard가 비친 진단 녹화다. 실제 클라우드 전체 화면으로 평가하지 않는다. 최종 실제 앱 뷰는 `iphone17-final-attachments`, `smallphone-attachments`, `ipad-attachments`의 `screen-*` 캡처다.

## iPhone 관측 및 테스트 시간 가정 수정

iPhone17 normal 홈·cloud receiving·휴가 낮은 검수한 viewport에서 캐릭터와 주요 텍스트가 겹치지 않는다. AX5 홈·cloud는 내용이 첫 viewport 아래로 이어진다. 휴가 AX5는 큰 문구와 버튼이 화면 높이의 상당 부분을 차지한다. 스크롤·버튼 도달·VoiceOver 읽기 순서까지 실행한 증거가 없으므로 접근성 전체 PASS는 아니다.

첫 iPhone14종 cloud 배치에서 우주복 `reopened`는 목표2.30s 대신 관측기록2.628/2.683s에 eye0/lid1이었고4.86s에는 eye1이었다. 실제 blink keys .88×3.6=3.168s이므로 이를 단순히 '2.6s의두번째blink'로 단정하지 않는다. 테스트가 벽시계만으로 화면상 열린눈을 가정한 결함을 제거했다. open/reopened도 closed와 같은0.5s 범위에서 실제 presentation opacity 조건을 관찰하며, 원래 assertion은 유지한다. 기록 elapsed는 PNG 저장 이후가 아닌 opacity 관측시점에 남긴다. 앱 타이밍은 바꾸지 않았다. 수정 후 iPhone 17 최종 배치는 14종 cloud 검사를 포함해 9/9 PASS다. 작은 iPhone과 iPad 화면 fixture도 각각 1/1 PASS다. 이는 해당 검사 범위의 결과이며 실물기기 검증은 아니다.

### 실제 앱 뷰 캡처 결함

초기 `screen-cloud-ready-normal/AX5`에는 아직 receiving 화살표·태블릿·안내문이 남고, `screen-cloud-trouble-normal/AX5`에는 이전 화면과 fade가 섞인다. AX5 ready의 문구는 왼쪽으로도 잘렸다. 전체12개 중 이4개를 최종상태 화면 PASS로 사용하지 않는다. 한 UIHostingController의 AnyView root를 연속 교체하면서 SwiftUI identity·transition 상태가 유지된 테스트 하네스 문제를 격리했다. 각 fixture에 새 host를 만들고 실제 CALayer glyph 픽셀을 요청된 receiving/check/xmark의 동일렌더러 출력과 비교하는 readiness 조건을 추가했다. 임의 sleep을 늘리지 않았고 앱 화면이나 전환 타이밍은 바꾸지 않았다. 수정 후 세 기기의 최종 36장을 직접 다시 확인했다. ready에는 check와 웃는 피오·완료 문구, trouble에는 x와 걱정 표정·재시도 문구가 올바르게 보이며 초기 receiving 잔상은 없다.

## 최종 기기별 화면 검수

| 기기 / 자료 폴더 | 직접 검수 | 관측 결과 | 제한 |
|---|---:|---|---|
| iPhone 17 / iphone17-final-attachments | 12장 | normal 클라우드 3상태와 휴가 낮·밤의 원화/문구 일치, 캐릭터 잘림 없음 | AX5에서는 홈·클라우드의 아래 내용과 일부 버튼이 첫 viewport 밖 |
| 작은 iPhone / smallphone-attachments | 12장 | normal 장면의 캐릭터·태블릿·해먹 유지, cloud 상태 정확 | normal trouble의 보조 동작과 AX5 CTA가 아래로 이어짐 |
| iPad / ipad-attachments | 12장 | normal 홈 카드와 장면이 넓은 화면에 맞게 배치, 낮·밤 배경 정상 | AX5 trouble 본문/버튼과 홈의 아래 내용은 viewport 밖; ready 확인·휴가 버튼은 캡처 안에 보임 |

세 기기 모두 검수한 프레임에서 텍스트의 수평 잘림이나 캐릭터와 글자의 직접 충돌은 보이지 않는다. AX5 휴가는 장면을 작게 줄여 텍스트 공간을 확보한다. 작은 화면에서 아래쪽 버튼에 스크롤로 도달할 수 있는지와 VoiceOver 읽기/실행 순서는 이 정지 캡처 검사에서 실행하지 않았으므로 **NOT_TESTED**다. 접근성 전체 판정은 PARTIAL을 유지한다.

## 남은 시각 승인과 검증

실물 기기 재생, 구매→착용→동기화→재실행 종단 흐름, 모든 장면의 VoiceOver 조작은 이 검수만으로 PASS 처리하지 않는다. 최신 CPU·메모리/최종 빌드 판정은 RESULTS 및 performance-review를 기준으로 한다. 갤러리에 자료가 있다는 사실과 그 자료를 직접 검수했다는 사실을 구분한다.
