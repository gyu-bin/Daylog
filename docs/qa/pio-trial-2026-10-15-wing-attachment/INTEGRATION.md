# Pio 공통 날개 부착 가이드

Stage 2·3은 기존 승인 PNG를 그대로 사용한다. 새 PNG 생성이나 에셋 교체가 필요하지 않다. Stage 4는 부착 구조만 준비되어 있으며 최종 원화는 없다.

## 코드

- `Daylog/Components/PioTrial.swift`: `wingAttachment(stage:)`에서 단계별 배율과 공통 어깨를 지정한다. 1536 기준 어깨는 `(480,995)`, `(1056,995)`, Stage 2 배율 0.78, Stage 3 배율 0.72다.
- `Daylog/Components/SaessagiIdleView.swift`: 선택적인 `SaessagiWingAttachment`를 받아 정적 부착 레이어를 배치한다. 그 아래 기존 sway/action/image 레이어를 유지한다. 뒤쪽 날개의 원근 변화 중심도 원화 뿌리다.
- `DaylogTests/SaessagiTests.swift`: 원화 보존 정책, 공통 어깨, 실제 CALayer 좌표 변환과 동작 정지 후 부착 유지 검사.

원화의 기존 피벗과 목표 어깨를 혼동하지 않는다. 원화 뿌리를 새 위치로 매핑하는 정적 변환이며, 이미지 전체를 임의로 내려 놓은 것이 아니다. Stage 1과 Saessagi의 부착 설정은 nil이다.

## 정적 비교 재현

저장소 루트에서 실행한다. 최종 기본값은 앱의 0.78/0.72/995와 일치하며 이 명령의 결과가 최종 비교 이미지와 바이트 단위로 일치하는 것을 확인했다.

```sh
swiftc -O -module-cache-path /tmp/pio-wing-module-cache Tools/pio-rig/validate-wing-attachment.swift -o /tmp/pio-wing-validator
/tmp/pio-wing-validator docs/qa/pio-trial-2026-10-15-stage3/assets /tmp/pio-wing-final . --stage3-padding --rear-wings
```

`--rear-wings`를 빼면 이 변경 전의 앞쪽 배치다. `WING_SCALE_2`, `WING_SCALE_3`, `SHOULDER_Y` 환경 변수는 과거 후보 재현용이다. 최종 재현에는 지정하지 않는다. 원본 Stage 3 검증 스크립트는 이전 작업 증거이므로 덮어쓰지 않았다.

`compare-wing-attachment.swift`는 이 폴더의 `before/rendered/`와 `final/` 결과로 전후 비교판을 만든다. 비교판은 별도의 증거 이미지이며 승인 에셋에는 포함되지 않는다.

## 검증 앱

새 빌드 경로는 `/tmp/DaylogWingAttachment.noindex/`이고 이전 `/tmp/DaylogStage3.noindex/` 산출물은 비교용으로 보존했다. 제품 앱을 교체하지 않는다.

공통 실행 인자:

```text
-DaylogStoreName pio-stage3-20261015
-DaylogDebugCharacter pio
-DaylogDebugGrowthBonus 900
-DaylogDebugAppearance dark
```

표시 전용 성장 보너스 900은 Stage 2, 2400은 Stage 3다. Mac 확대 검사는 `-DaylogDebugPioStage 220`을 더한다. 고정 동작은 기존 `-DaylogDebugSaessagiAction`의 `wave`, `flap`, `walk`, `dash`, `bigHop`, `peek`, `leafShake`를 사용했다. 자연 동작 검사에는 고정 동작 인자를 생략한다. 저장된 XP를 바꾸는 방식이 아니다.

Stage 4의 새 원화가 승인되기 전에는 `implementedStages`를 늘리지 않는다. 새 날개가 준비되면 공통 어깨와 완전한 뿌리를 유지하고 크기만 검증하여 조정한다. 상세 결과와 측정 한계는 [RESULTS.md](RESULTS.md)에 있다.
