# Pio 성장 날개 부착 개선 결과

2026년 10월 15일. Stage 2와 Stage 3의 승인 원화를 그대로 사용하면서, 날개를 작고 둥글게 정돈하고 몸 뒤의 낮은 어깨에 붙였다. 얼굴과 분홍 볼을 드러내고 통통한 몸의 실루엣을 보존하는 데 우선순위를 뒀다. 두 단계의 정적·실제 앱 검증을 통과했으며 커밋과 푸시는 하지 않았다.

![2단계와 3단계 전후 비교](before-after-overview.png)

## 단계별 결과

| 단계 | 변경 및 결과 |
|---|---|
| Stage 1 Lv.1–9 | 변경 없음. 밝고 어두운 배경, 48/64/76/220pt, 1×/3×의 전후 렌더 16쌍이 바이트 단위로 동일 |
| Stage 2 Lv.10–24 | 승인된 주황 끝 날개 유지. 원화 뿌리를 낮은 몸통 어깨로 옮기고 0.78배로 렌더. 뿌리를 몸 뒤로 숨기고 이전 앞쪽 접촉 그림자 제거 |
| Stage 3 Lv.25–49 | 승인 날개를 0.72배로 렌더하고 같은 어깨 구조 적용. 기존 볏·좌우 꼬리·몸·얼굴·발은 그대로 유지 |
| Stage 4 Lv.50+ | 공통 부착 설정 준비 완료. 최종 분리 날개 원화가 없어 실제 통합은 하지 않음. 기존대로 Stage 3를 표시하고 그림 준비 중 안내 유지 |

Stage 3 원화가 더 크므로 0.72배에서도 Stage 2보다 풍성하다. 낮게 내려간 후보는 발 주변에 깃털이 몰리는 인상 때문에 제외했다. 최종 배치는 최대 성장 차이보다 귀여움과 균형을 우선했다.

- [Stage 2 밝은 전후 비교](stage2-before-after-light-1x.png) · [어두운 전후 비교](stage2-before-after-dark-1x.png)
- [Stage 3 밝은 전후 비교](stage3-before-after-light-1x.png) · [어두운 전후 비교](stage3-before-after-dark-1x.png)
- 각 비교에는 48/64/76/220pt가 포함된다. 같은 이름의 `3x.png`는 iPhone 배율 비교다. `final/native/`와 `final/joints/`에는 자세별 원본 해상도와 연결부 확대가 있다.

## 공통 부착 구조

`PioTrial.wingAttachment(stage:)`가 2단계 이후의 공통 어깨·크기·뒤쪽 배치·그림자·휴식 각도·동작 범위를 설정한다. 좌표는 1536 원본 기준 왼쪽 `(480,995)`, 오른쪽 `(1056,995)`다. 기존 원화 뿌리 `(481.95,940.05)`, `(1054.05,940.05)`를 이 위치로 매핑한다. 앱 내부에서는 1024 기준으로 변환한다.

새 정적 부착 레이어 안에 기존 살랑임과 행동 레이어를 둔다. 정적 크기/위치와 동작을 분리했으므로 인사·퍼덕임·동작 정지 때 부착 설정이 덮어써지지 않는다. 원근 변화도 원화 중심이 아닌 뿌리를 기준으로 적용해 날개를 들어도 뿌리가 미끄러지지 않는다.

그리기 순서는 뒤쪽 볏 → 꼬리 → 뒤쪽 날개 → 몸 → 얼굴이다. Stage 2의 앞쪽 날개용 그림자는 뒤쪽 배치에 맞지 않아 사용을 끄되 원본 파일은 보존했다. 새 그림자를 그리거나 원화를 수정하지 않았다. 휴식 각도는 0°, 기존 안쪽 제한 −3° 및 48°/62° 동작을 유지했다. 60°는 기존 원근 변화의 포화 기준이며 회전 상한이 아니다.

Stage 1과 Saessagi에는 새 부착 설정을 적용하지 않는다. 기존 Core Animation 동작을 재사용하며 프레임마다 SwiftUI 레이아웃을 다시 만들지 않는다.

## 시각 및 동작 검증

정적 검사에서 두 단계의 중립 0°, 양 날개 48°, 오른쪽 인사 62°, 볏 ±12°, 점프·착지를 확인했다. 밝고 어두운 배경의 48/64/76/220pt, Mac 1×와 iPhone 3× 렌더를 비교했다. 뺨 가림, 뿌리 틈, 떠 있는 날개, 잘린 끝, 새로운 경계 결함은 발견되지 않았다. 220pt 실제 앱 확대 검사는 Mac에서 수행했고 iPhone 220pt는 동일 리그의 3× 정적 렌더로 확인했다.

Mac 및 iPhone 시뮬레이터의 실제 화면과 동작도 확인했다. 독립 시각 검토는 전후 화면, 날갯짓/인사 영상의 표본, 양 단계 점프, 걷기·달리기·숨바꼭질·볏 흔들기 24개 추가 표본을 통과했다. 숨바꼭질에서 헤더 경계로 들어가는 가림은 기존 의도된 동작이다.

| 실제 앱 검사 | Stage 2 | Stage 3 |
|---|---|---|
| 밝은 화면/어두운 화면 | PASS Mac·iPhone | PASS Mac·iPhone |
| 호흡·눈깜박임·평소 날개 움직임 | PASS | PASS |
| 인사·퍼덕임 | PASS iPhone 원본 영상 | PASS iPhone 원본 영상 |
| 걷기·달리기 | PASS Mac | PASS Mac |
| 점프·착지 | PASS Mac | PASS Mac |
| 숨바꼭질·볏 흔들기 | PASS Mac | PASS Mac |
| 동작 줄이기·복귀 | PASS iPhone | PASS iPhone |

대표 파일:

- [Mac Stage 2 밝은 화면](runtime/mac-after-stage2-light.jpg) · [어두운 화면](runtime/mac-after-stage2-dark.jpg)
- [Mac Stage 3 밝은 화면](runtime/mac-after-stage3-light.jpg) · [어두운 화면](runtime/mac-after-stage3-dark.jpg)
- [iPhone Stage 2 원본 3×](runtime/iphone-after-stage2-light-3x.png) · [Stage 3 원본 3×](runtime/iphone-after-stage3-dark-3x.png)
- [Stage 2 인사](runtime/iphone-stage2-wave.mp4) · [Stage 3 인사](runtime/iphone-stage3-wave.mp4)
- [Stage 2 퍼덕임](runtime/iphone-stage2-flap.mp4) · [Stage 3 퍼덕임](runtime/iphone-stage3-flap.mp4)
- [Stage 2 점프](runtime/mac-stage2-jump.mp4) · [Stage 3 점프](runtime/mac-stage3-jump.mp4)
- 나머지는 `runtime/mac-stage{2,3}-{idle,walk,dash,peek,crest-sway}.mp4`에 있다.

iPhone의 네 동작 영상은 Device Hub가 저장한 **1320×2868, 약 60fps** 원본 녹화다. Mac 영상은 실제 창의 연속 캡처를 시간 간격에 맞춰 묶은 시각 증거이며 고속 프레임 시간 측정은 아니다. [영상 메타데이터](runtime/recording-metadata.json)에 구분했다. 실물 iPhone 검사는 수행하지 않았다.

동작 줄이기에서는 Stage 2 약 29.8초, Stage 3 약 36.2초 간격의 **기기 원본 전체 화면 픽셀이 각각 동일**했다. 초기 창 JPEG 비교에는 헤더에 겹친 조작 포인터 표시가 변하므로 원본 PNG로 재확인했다. 이후 원래 꺼짐 설정으로 복원하고 같은 프로세스에서 움직임 재개를 확인했다. [원본 비교](runtime/reduce-motion-native-result.json), [복원 상태](runtime/reduce-motion-restored.txt), [재개 결과](runtime/resume-result.json). 정적 부착 레이어가 애니메이션 시작/정지 후 유지되는 것은 실제 CALayer 테스트로도 확인했다.

## 빌드와 테스트

다음 빌드 모두 PASS:

- macOS Debug
- iOS Simulator Debug 및 전용 검증 앱 설치/실행
- macOS 최적화 성능 검증 빌드
- macOS 순수 Release. 컴파일된 에셋에 Pio 항목 0개 확인

관련 **36개 테스트, 4개 모음, 0.631초 PASS**. `SaessagiTests`, `SaessagiGrowthTests`, `SaessagiHeaderActionTests`, `SaessagiGrowthArtTests`를 선택했고, 새 `developedWingRootsStayOnTorsoThroughRotationAndStopping` 검사도 실제 실행에 포함했다. 마지막 검사는 CALayer 좌표 변환으로 0°/48°/62° 및 시작·정지 후 뿌리 고정을 검증한다.

코드 검토에서 차단 결함은 없었고 `git diff --check`도 통과했다. 빌드/테스트 실행 로그는 `build-logs/`에 보존했다. 결과 번들은 `/tmp/DaylogWingAttachment.noindex/verify/Logs/Test/Test-Daylog-2026.10.15_18-04-31-+0900.xcresult`다.

## CPU와 메모리

같은 최적화 Mac 검증 앱, 같은 테스트 저장소, 헤더·성장 카드·220pt 확대, 반복 점프 조건에서 약 30초씩 측정했다. 측정 중 Mac 화면 캡처는 수행하지 않았다. CPU는 누적 프로세스 CPU 시간 차이를 실제 경과 시간으로 나눈 1코어 기준 값이다.

| 단계 | 변경 전 CPU | 변경 후 CPU | 변경 전 RSS | 변경 후 RSS |
|---|---:|---:|---:|---:|
| Stage 2 | 0.164% | 0.198% | 56.02–124.03 MiB | 120.69–120.75 MiB |
| Stage 3 | 0.231% | 0.165% | 125.39–128.44 MiB | 122.78–123.19 MiB |

변경 후 두 단계 모두 낮은 CPU 사용량과 안정적인 RSS를 보였다. 이 짧은 표본에서 성능 회귀는 관찰되지 않았다. 캐시·메모리 회수 시점이 달라 메모리 개선이나 미세한 CPU 차이의 유의성을 주장하지 않는다. 첫 Stage 2 측정은 앱 시작 비용이 포함되어 별도 `performance-before-stage2-startup.json`으로 남기고 위 비교에서 제외했다. 원자료는 `runtime/performance-{before,after}-stage{2,3}.json`에 있다. 장시간 누수·실물 iPhone 성능·GPU 프레임 시간 검사는 수행하지 않았다.

## Stage 4 준비 범위

공통 어깨와 뒤쪽 부착 시스템은 Stage 4에서도 재사용할 수 있다. `pio_growth_04`는 다른 얼굴/자세와 장식이 포함된 과거 1024px 통합 그림이며 승인된 분리 날개가 아니므로 통합하지 않았다. `implementedStages`는 3으로 유지했다.

최종 Stage 4에는 현재 마스터에 맞는 좌우 독립 RGBA 날개와 완전한 숨은 뿌리가 필요하다. 현재 어깨를 유지하고, 원화별 크기만 시각 검증 후 조정한다. 기존 얼굴·몸을 바꾸거나 장식/크기를 과도하게 늘리지 않으며, 동일한 0°/48°/62°·작은 화면·밝고 어두운 배경 검사를 다시 통과해야 한다. 현재 Stage 4의 0.72 배율은 승인된 최종 원화 값이 아니라 Stage 3를 재사용하는 기본 설정이다.

## 보존 및 남은 사항

기존 Pio PNG 42개와 승인 Stage 3 파츠 5개의 해시가 유지됐다. [보존 검사](PRESERVATION-CHECKS.txt), [해시 목록](asset-manifest.json). 기존 미커밋 Stage 3 코드와 변경 내역은 `before/`에 보존했고 이번 변경을 그 위에 적용했다.

XP 계산, SwiftData, CloudKit, 사용자 기록, 휴가/동기화 화면, 아이콘/스플래시와 카드 설정은 수정하지 않았다. 원래 제품 Mac 앱도 교체하지 않았다. 검증 앱은 CloudKit이 비활성화된 기존 별도 저장소 `pio-stage3-20261015`를 사용했다.

Device Hub에서 모델과 UDID를 재확인한 전용 iPhone 17 Pro Max / iOS 27 시뮬레이터 `CF19DDA2-20F5-440C-9133-7A4594341DAE`만 사용했다. 다른 프로젝트의 iPhone 17 시뮬레이터는 조작하지 않았다. [기기 확인](runtime/device-identity.txt). 전용 iOS 검증 빌드의 위젯 번들 ID만 생성 산출물에서 교정해 설치했으며 프로젝트 설정은 변경하지 않았다.

검증 범위 안에서 남은 시각 결함은 없다. Stage 4 최종 원화와 실물 기기/장시간 성능 확인은 미완료다. Stage 2·3의 변경은 최종 승인 가능한 상태이며 커밋·푸시·TestFlight·Release 배포는 하지 않았다.
