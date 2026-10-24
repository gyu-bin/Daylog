# Pio Growth Stage 3 — 최종 검증 결과

2026-10-15 · 기준 커밋 `6f722fe` · 커밋/푸시 없음

새 볏과 좌우 꼬리 3개를 완성하고 정적 검증 통과 후 DEBUG 전용 PioTrial에 연결했다. 최종 사용자 승인 대기 상태이며 Stage 4는 구현하지 않았다.

## 최종 상태

| 항목 | 결과 | 근거 |
|---|---|---|
| ARTWORK_QUALITY | PASS | 개별 생성한 완전한 파츠, 원본과 같은 재질·조명 방향, 밝고 어두운 배경 검사 |
| MASTER_IDENTITY | PASS | 원본 얼굴·몸·발 포함 기존 Pio PNG 42개가 기준 커밋과 해시 일치 |
| CREST_JOINT | PASS | 기존 피벗과 ±12° 유지, 머리 뒤 배치, 뿌리 틈·수평 절단면 없음 |
| TAIL_LEFT | PASS | 독립 파츠·완전한 뿌리, 몸 뒤 배치, 이동/점프 중 연결 유지 |
| TAIL_RIGHT | PASS | 독립 파츠·완전한 뿌리, 몸 뒤 배치, 이동/점프 중 연결 유지 |
| STAGE_3_DISTINCTION | PASS | 48/64/76/220pt에서 Stage 1·2와 비교, 볏과 날개 실루엣으로 구분 |
| ANIMATION | PASS | Mac 및 iPhone 시뮬레이터 실제 앱, 기존 동작·성장 전환·동작 줄이기 확인 |
| PERFORMANCE | PASS | 아래 Mac 비교 측정 범위에서 CPU 회귀와 지속 메모리 증가 관찰되지 않음 |
| READY_FOR_STAGE_4 | YES | 검증한 Stage 3를 다음 단계의 기준으로 사용할 수 있음. 사용자 최종 승인과 Stage 4 별도 요청은 아직 남음 |

## 전달물

- `assets/`: 1536×1536 RGBA 새 볏·좌우 꼬리, 그리고 변경 없이 재사용한 승인 날개 2개.
- `Pio-Stage3-Delivery.zip`: 위 5개 파츠, 원본 생성 이미지, 가이드, 보고서, 해시 목록, 최종 정적 검증 이미지, 런타임 영상/대표 화면/측정 결과 및 빌드 로그. 연속 캡처 원본 전체는 용량을 줄이기 위해 ZIP에서 제외하고 이 폴더에 보존했다.
- [연결 가이드](INTEGRATION.md), [제작 출처와 배치](ARTWORK.md).
- [밝은 배경 비교](validation-padded/comparison-light-2x.png), [어두운 배경 비교](validation-padded/comparison-dark-2x.png).
- [64pt](validation-padded/sizes/light-stage3-64pt-2x.png), [220pt](validation-padded/sizes/light-stage3-220pt-2x.png). 각 파일은 2× 화면 픽셀 기준이다. `sizes/`에는 1× 결과도 있다.
- `validation-padded/joints/`: 볏·양쪽 어깨·꼬리 연결 부위를 각 자세/배경별 원본 픽셀 크기로 저장했다.

## 정적 검증 및 수정

기존 CALayer 계층, 원본 몸/눈/발, 승인된 3단계 날개와 기존 좌표계를 재현했다. 중립, 양 날개 48°, 오른쪽 인사 62°, 볏 ±12°, 점프, 착지를 밝고 어두운 배경에서 검사했다. 기존 동작 각도는 줄이지 않았다.

기존 2pt 렌더 여백에서는 220pt 미리보기의 오른쪽 날개 끝이 잘렸다. Stage 3에만 `max(2, ceil(size × 27 / 1228.5))` 여백을 적용해 해결했다. 48/64/76pt는 2pt, 220pt는 5pt다. 몸 크기와 피벗은 유지했다. `validation/`은 수정 전 증거이고 **최종 판정은 `validation-padded/` 기준**이다.

별도 시각 검토에서 최종 정적 결과와 점프/날갯짓 화면을 통과했다. 추가로 인사·걷기·달리기·숨바꼭질·볏 흔들기에서 총 15개 실제 캡처 프레임을 검토했으며 새 연결 결함은 없었다.

## 실제 앱 동작

- Mac: [밝은 화면](runtime/mac-light.jpg), [어두운 화면](runtime/mac-dark.jpg), [점프/착지](runtime/mac-jump.mp4), [인사](runtime/mac-wave.mp4), [걷기](runtime/mac-walk.mp4), [달리기](runtime/mac-dash.mp4), [숨바꼭질](runtime/mac-peek.mp4), [볏 흔들기](runtime/mac-crest-sway.mp4). 기존 호흡과 눈깜박임도 실제 화면에서 확인했다.
- iPhone: [밝은 화면](runtime/iphone-light.jpg), [어두운 화면/동작 줄이기](runtime/iphone-dark-reduce-motion.jpg), [날갯짓](runtime/iphone-flap.mp4).
- 동작 줄이기: 초기 안정화 이후 연속 47장의 전체 캡처가 **33.044초 동안 바이트 단위로 동일**했다. 원래 꺼져 있던 설정을 검사 후 꺼짐으로 복원했다. [측정](runtime/reduce-motion-result.json), [복원 확인](runtime/reduce-motion-restored.txt).
- 성장 전환: 기존 루틴 완료로 Lv.24(90/100) → Lv.25(20/100), Stage 2 → 3 전환을 확인했다. 완료 취소 시 Lv.24와 Stage 2로 복귀했다. [전환 전](runtime/level24-before.jpg), [전환 후](runtime/level25-after-settled.jpg), [취소 후](runtime/level24-restored.jpg).

영상은 실제 앱 창의 연속 캡처를 시간 간격에 맞춰 MP4로 묶은 것이다. 대략 4–6fps의 시각 증거이며 60fps 프레임 시간이나 부드러움을 측정한 자료는 아니다. 원본 JPEG와 캡처 시각은 각 `*-frames/`에 있다. 정적 CALayer 렌더를 실제 앱 영상으로 대체하지 않았다.

기기 확인 후 전용 **Daylog Store iPhone 17 Pro Max / iOS 27.0 시뮬레이터** (`CF19DDA2-20F5-440C-9133-7A4594341DAE`)에서 검사했다. 다른 프로젝트의 실행 중 iPhone 17 (`66B81EA7-8132-4677-A443-2C5F96FB06ED`)은 조작하지 않았다. 실물 iPhone에서는 검사하지 않았다.

## 빌드와 테스트

- Mac Debug 빌드: PASS.
- iOS Simulator Debug 빌드 및 별도 앱 설치/실행: PASS.
- Mac 순수 Release 빌드: PASS. 컴파일된 에셋에서 Pio 이름 0개 확인, Saessagi 경로 유지.
- 관련 테스트 `SaessagiTests`, `SaessagiGrowthTests`: **26개 PASS**, 2개 모음, 0.407초.
- 최적화된 Mac 성능 검증 빌드: PASS. Release 최적화에 DEBUG 검사 옵션과 Pio 에셋을 이 검증 빌드에만 포함.
- 코드 검토: 차단 결함 없음. `git diff --check`: PASS.

명령과 경로는 [BUILD-VERIFICATION.txt](validation-padded/BUILD-VERIFICATION.txt), 실행 로그 사본은 `build-logs/`에 있다. iOS 별도 번들 ID를 빌드 인자로 전역 지정하면서 위젯 ID까지 같아진 설치 문제가 있었고, 생성된 앱 산출물의 위젯 ID만 수정하여 서명/설치했다. 프로젝트 설정이나 제품 앱은 변경하지 않았다.

## 성능 측정

같은 최적화 Mac 검증 앱에서 헤더·성장 카드·220pt 미리보기와 반복 점프를 실행했다. 캡처를 멈추고 약 30초간 누적 프로세스 CPU 시간 차이 및 RSS를 측정했다.

| 단계 | 구간 | CPU (1코어 기준) | RSS 범위 |
|---|---:|---:|---:|
| Stage 2 | 30.365초 | 0.198% | 126.48–130.33 MiB |
| Stage 3 | 30.334초 | 0.198% | 105.91–107.09 MiB |

[Stage 2 원자료](runtime/performance-stage2.json), [Stage 3 원자료](runtime/performance-stage3.json). 캐시/초기화 조건 차이가 있으므로 메모리가 개선됐다는 결론은 내리지 않는다. 짧은 Mac 측정에서 메모리는 안정적이었으며, 실물 기기 성능·GPU 프레임 시간·장시간 누수 검증은 수행하지 않았다.

## 보존 범위와 남은 사항

확인된 새 결함은 없다. 원본 Pio 몸의 이마 음영과 기존 눈꺼풀 외곽선은 그대로다. +12°/착지에서는 작은 둥근 금색 후면 깃이 보일 수 있지만 뿌리가 연결되어 있고 틈이나 절단면은 없다. 새 파츠와 승인 날개 내부 알파는 주로 253/255로, 새 반투명 뿌리 띠를 더하지 않고 원본 알파를 보존했다. 밝고 어두운 최종 합성에서 연결부를 검토했다.

기존 Pio PNG 42개, Stage 1·2 및 승인 Stage 3 날개를 해시로 확인했다. SwiftData/CloudKit/XP 계산/저장 로직과 카드 설정은 수정하지 않았다. 런타임 검사는 CloudKit이 꺼진 별도 테스트 저장소와 별도 검증 앱으로 수행했다. 제품 Mac 앱 교체, TestFlight 업로드, GitHub Release, 커밋과 푸시는 하지 않았다. 검증용 Mac/iPhone 시뮬레이터 앱은 Stage 3 일반 동작 화면으로 남겨 두었다.
