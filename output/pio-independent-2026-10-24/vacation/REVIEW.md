# 휴가 독립 원화 제작 파일럿

최종 원화 판정: **FAIL / BLOCKED_ASSET**. 실제 PNG 3장을 제작했고 기존 리그의 네이티브 합성으로 검토했다. 품질 기준을 통과하지 못했으므로 앱에 활성화하지 않았다. 기존 휴가 원화와 동작은 그대로 유지한다.

## 제작 결과

모든 후보는 기본 제공 `image_gen.imagegen`으로 생성한 실제 1024×1536 RGBA PNG다. CLI·도형 대체·Python 이미지 편집을 사용하지 않았다. 상세 프롬프트는 `prompts.md`, 파일 해시는 `manifest.json`, 알파 분석은 `alpha-v*.txt`에 있다.

1. `basic-day-clean-base-candidate-v1.png`: 눈 없는 얼굴 복원 후보. 눈은 제거됐으나 부리·음료·발·해먹 위치와 털 질감까지 달라졌다. 승인된 원본과의 좌표/외형 유지 기준 FAIL.
2. `basic-day-eye-fur-patches-candidate-v2.png`: 원본을 유지하기 위한 투명 눈 주변 복원 후보. 요청한 위치보다 아래에 생성됐고 털이 연속된 얼굴 표면이 아니라 두꺼운 솜 조각처럼 보인다. 넓은 주변 알파도 발생했다.
3. `basic-day-eye-fur-patches-candidate-v3.png`: 위치·크기·알파 범위를 구체적으로 수정 요청한 후보. 거의 같은 문제가 유지돼 반복 생성은 중단했다.

## 실제 합성 검토

기존 `RoutimoriVacationRig`에 후보 v3를 독립 CALayer로 올리고 AppKit `cacheDisplay`로 캡처했다. 원본은 편집하지 않았다. 순수 원본, 원좌표 패치, 스케일0.77/이동(112,122) 패치 세 경우를 64pt·220pt·1024pt에서 비교했다.

검토한 증거:

- `native-review/vacation-day-1024pt-original-diagnostic.png`
- `native-review/vacation-day-1024pt-raw-patch-diagnostic.png`
- `native-review/vacation-day-1024pt-registered-patch-diagnostic.png`
- `native-review/vacation-day-220pt-registered-patch-diagnostic.png`
- `native-review/vacation-day-64pt-registered-patch-diagnostic.png`

관측 결과:

- 원좌표에서는 원래 눈이 그대로 보이고 후보 패치가 뺨·음료에 걸친다.
- 좌표 보정으로 눈을 가릴 수는 있지만 얼굴과 다른 두툼한 솜 패드 두 개가 명확히 보인다. 연속된 얼굴 털/자연스러운 음영으로 복원되지 않았다.
- 220pt에서도 눈 자리에 밝은 덩어리가 보인다. 64pt에서 결함이 작아 보이는 것으로 고해상도 품질 실패를 승인하지 않는다.
- 따라서 눈을 얹거나 깜빡임을 추가해도 그 아래의 원화 이음새 문제가 해결되지 않는다. 후보를 앱에 연결하지 않았으며 밤·13개 의상으로 확장하지 않았다.

## 테스트와 범위

`PioVacationCandidateArtworkTests.testNativeEyePatchRegistrationCandidates` 실행은 **1/1 PASS**: 파일 로딩, 실제 기존 리그 합성, 캡처 및 정지 상태 검사를 통과했다. 이는 원화 품질 PASS를 의미하지 않는다. 내보낸 결과는 **9 PNG = 3가지 합성×3크기**다. 현재 테스트 소스에는 승인된 기본 피오 open-eye 비트맵을 재사용한 네 번째 진단 모드도 추가되어 있으나 이 검토의 실행 바이너리는 그 이전이며 해당 모드 결과를 검증했다고 주장하지 않는다.

실행 로그: `docs/qa/pio-independent-2026-10-24/native/mac-hands-v2.log` 40~44행, 본 테스트 1.099초 PASS. 원본 번들: `/tmp/PioCloudHandsV2-native-20261024.xcresult`. 영상은 제작하지 않았다. 등록 실패 후보를 움직여 독립 애니메이션이 완성된 것처럼 보여주지 않는다.

필요한 다음 원화 작업: 승인된 얼굴의 실제 미세 털·음영을 연속적으로 복원한 eye-free face patch 또는 clean face, 정확한 기존 좌표, 주변 alpha 잔여물 없는 경계. 이후 기존 고해상도 눈을 등록하고 실제 깜빡임을 검증할 수 있다. 현재 후보3장의 실패는 외부 제작 불가능을 의미하지 않으며, 이번 자동 생성 결과가 기준 미달이라는 뜻이다.

원본 761개/휴가26장 수정 없음. 런타임 앱 코드 변경 없음. 신규 테스트와 후보/검토 자료만 남겼다. 커밋·푸시·배포 없음.
