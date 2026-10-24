# 피오 최종 제작 패스 — 실제 원화와 적용 범위

최종 원화 판정: **PARTIAL**. 기존 클라우드 분리 원화를 운영 경로로 연결했고, 이번에는 휴가 기본 낮의 눈 주변 털을 실제로 복원하여 독립 표정을 연결했다. 휴가 전 의상·낮/밤의 눈·손·소품·해먹 고정점이 완성된 것은 아니다. 아래 기술 검수와 사용자 최종 미적 승인을 구분한다.

## 1. 원화 수량과 출처

| 구분 | 수량 | 실제 내용 |
|---|---:|---|
| 이전 클라우드 제작 원화 재사용 |34장|기본8장, 유료13종의 복원 몸통/팔쌍26장. 이번에 다시 생성하지 않음. 기존 소스의 생성·QA 이력은 `../pio-independent-2026-10-24/RESULTS.md` 참조.|
| 이번 실제 이미지 생성·편집 결과 |3장|휴가 기본 낮 clean-eye 후보1장, 독립 음료 후보2장. 모두1024×1536 RGBA.|
| 이번 생성 결과 중 제한 채택 |1장 중2영역|clean-eye 후보의 얼굴 두 영역만 사용. 전체 그림 교체 금지.|
| 이번 생성 결과 거절 |2장|음료 halo·좌표·비율 불일치. 앱에 포함하지 않음.|
| 클라우드 production 리소스 복사 |141 PNG +14등록|기존 최종 텍스처의 바이트 동일 복사. 34장 새 원화와 기존 눈/광학 donor에서 구성된 런타임 리소스이며 신규 제작141장으로 세지 않음.|
| 휴가 production 리소스 복사 |3 PNG|신규 clean 후보1장 + 기존 고해상도 눈 donor2장. 신규 생성3장과 중복 합산하지 않음.|

보호 원본과 유료 휴가26장, 기본 낮/밤2장은 덮어쓰지 않았다. 원본28장의 파일별 치수·alpha·SHA는 `../../../output/pio-production-final-2026-10-24/vacation/source-inventory.json`에 기록했다. 클라우드 복사본 정합성은 `cloud-promotion-provenance.json`, `cloud-production-static-validation.json`이 근거다.

## 2. 기존 BLOCKED_ASSET 6개 — 엄격한 범위 판정

원래 계약은 `../pio-artwork-final-2026-10-24/artwork/ARTWORK-SPEC.md`다. 아래 제한 기능의 구현과 전체 계약의 완전 해제를 동일시하지 않는다.

| 항목 | 현재 판정 | 확인된 진척과 남은 범위 |
|---|---|---|
|CLOUD_BASIC_EYES|PARTIAL — 핵심 blink 원화/리그 연결|기존 clean face와 open/closed/brow 재사용, 정상 production 경로. 별도 half-state 등 전체 표현 계약·사용자 최종 승인은 완료라고 하지 않음.|
|CLOUD_PAID_HANDS|PARTIAL —13종 잡는 손 원화/리그 연결|최종 복원 torso/armPair를 Release 소스 경로로 승격. 의상별 sleeve/cuff/glove와 접촉 유지. 자유로운 손 놓기·각 손가락·개별 shoulder 표현은 별도 미완성.|
|CLOUD_TABLET|PARTIAL —14종 공통 hold 구현|기존 완전한 태블릿과 손을 같은 hold joint에 연결하여 몸통과 독립된 작은 움직임. 전체 손 분리/잡기 해제 완료는 아님. 초기 iOS 캡처 시점 assertion 실패는 실제 상태 관측으로 수정 후14종 배치 PASS. 원화 전체 계약과는 별도 판정.|
|VACATION_EYES|PARTIAL — **기본 낮 한 경우**|새 clean-eye 두 영역과 기존 genuine donor를 연결. Mac4/4 및 iPhone17 집중2/2 PASS,64/220pt open/closed/stopped/night fallback 검수. 기본 밤 및 유료13종 낮/밤 복원은 남음.|
|VACATION_HANDS_PROPS|BLOCKED_ASSET|음료2후보 품질FAIL. 누운 팔·손 roots, 가려진 몸통, 손 접촉 매트, 의상별 실제 소품 세트 없음.|
|VACATION_ROPES|BLOCKED_ASSET|양쪽 나무 매듭과 움직이는 천 접점의 독립 원화·숨은 배경 미완성. 기존 sway 보존은 두 고정점 해결이 아님.|

**엄격한 전체 계약 완전 해제:0/6. 실제 원화·리그 진척:4/6(기존 클라우드3 + 이번 휴가 눈1). 미해결 원화 블로커:2/6, 나머지4개도 위 범위 제한이 있는 PARTIAL.** 클라우드의 운영 경로 승격과 휴가 기본 낮 눈은 실사용 가능한 좁은 결과지만,6/6완료 또는14종 휴가 독립 눈 완성으로 보고하지 않는다.

## 3. 이번 생성 원화와 좌표

실제 PNG 폴더: `../../../output/pio-production-final-2026-10-24/vacation/`

| 파일 | 규격·alpha | 판정 |
|---|---|---|
|basic-day-eye-free-candidate-v1.png|1024×1536 RGBA, alpha0–254|두 clean-fur 영역만 채택. 전체 replacement는 미승인.|
|basic-day-complete-drink-v1.png|1024×1536 RGBA, alpha0–254|FAIL: 색 halo, 원본 좌표/크기/기울기 불일치.|
|basic-day-complete-drink-v2.png|1024×1536 RGBA, alpha0–254|FAIL: 수정 시도에도 커진 소품/halo.|

원본은 `Daylog/RoutimoriTrial.xcassets/routimori_vacation_hammock.imageset/routimori_vacation_hammock.png`다. 이미지 생성·편집으로 가려진 털을 새로 그렸으며, crop으로 원본에 없는 픽셀을 복구했다고 주장하지 않는다. 프롬프트 전문과 SHA/alpha/치수는 같은 폴더 `prompts.md`/`manifest.json`에 있다.

1024×1536 top-left 좌표:

| 레이어 | source rect 또는 배치 | pivot |
|---|---|---|
|왼쪽 복원 털/원본 닫힌눈|(422,688,58,44)|(451,710)|
|오른쪽 복원 털/원본 닫힌눈|(531,647,54,43)|(558,668.5)|
|기존 왼쪽 열린눈 donor|(431,687,37.8,43.8)|해당 slot 중앙|
|기존 오른쪽 열린눈 donor|(540,647,35.2,40.8)|해당 slot 중앙|

실제 vacation root가 geometry flipped이므로 source Y를 그대로 사용한다. 생성된 털 패치는 얼굴에 고정하고 회전하지 않는다. 표정 opacity와 기존 해먹 sway만 조합하며, 손·음료·줄의 독립화로 오인하지 않는다. 추가 hidden shoulder/grip/rope 좌표는 측정되지 않았으므로 null로 유지한다.

## 4. 기존 엔진 연결과 Release 범위

- `PioVacationIndependentEyes.swift`: 기존 CALayer 안의6레이어(복원2/open2/original-closed2),9.2초 expression. 별도 엔진 없음.
- `RoutimoriVacationScene.swift`: 기본 낮 원본만 선택적으로 helper 연결. 기본 밤·유료13종은 정상 기존 원화 유지. 로드 실패 시 기존 원화 fallback.
- `PioVacationProduction.xcassets`: production 리소스3개. 코드가 DEBUG에 한정되지 않으며 승인 범위를 넘어 다른 조명/의상에 적용하지 않는다.
- 기존7.6초 해먹 sway 타이밍 보존. Reduce Motion/정지/이탈/밤 전환에서 눈 트랙을 정리하고 원본 웃는눈으로 복귀.
- 클라우드14종은 `PioCloudProduction.xcassets`와 기존 리그/48MiB soft cache 경로로 연결. 자세한 코드·권한 보호 근거는 `cloud-implementation.md` 참조. 구매 관리자와 product ID는 변경하지 않음.
- 클라우드 완료 장면의 유료 의상은 기존 완성형 원화+bounce다. 새로운 독립 팔/눈 완료 모션이라고 주장하지 않는다.

Source가 Release 경로에 들어간 것과 signed Release 실기기 확인은 다르다. 빌드/전체 검증 결과는 최종 `RESULTS.md`를 따른다. 실제 운영 앱 교체·구매·배포는 하지 않았다.

## 5. 실제 렌더링 근거

휴가 신규 고유 테스트: Mac4/4 PASS(`mac-art-final-tests.log`), iPhone17 Simulator2/2 PASS(`iphone17-tests.log`). iOS 같은 번들의 다른 클라우드 검사 실패는 휴가 PASS로 덮지 않는다.

- Mac `vacation-native/`: source변형12장, diagnostic44장(3고유프레임), 실제 production96장(96고유프레임)+정지1장. 실제 open/closed가 보이고, 배경/부리/손/음료는 유지된다.
- iOS `iphone17-attachments/manifest.json`:64/220pt 각 closed/open/stopped/night fallback,8장 모두 직접 검토. 사각 패치, 이중 눈, 입·빨대 잔여물, 방향 오류 없음. 밤 조명은 원본 그대로.
- 동작은 실제 host의 presentation opacity와 transforms를 관측해 정적 snapshot에 명시적으로 복제한 네이티브 component 검토 프레임이다. 물리 iPhone 촬영이나 정확한10fps실시간 영상이라고 하지 않는다.
- 잘못된 Mac Y sampler, nested presentation 복제, 빈 CALayer copy로 나온 이전 실패 캡처는 `vacation-native/before-*/`에 보존했다. 현재 assertion은 blank와 동일 프레임을 거부한다.

상세 파일명/원인/로그: [휴가 세부 원화 결과](artwork/ARTWORK-RESULTS.md). 사용자 최종 미적 승인은 남아 있다.

## 6. 다음 실제 제작 요구

1. 기본 밤 및13종 낮/밤: 조명·안경·visor를 보존한 clean-face와 눈 상태. Basic 낮 donor를 무조건 공유하지 않는다.
2. 누운 팔/손/torso: 원래 어깨 roots와 손 전후 매트 복원. 기존 서 있는/태블릿 자세의 손을 대신 붙이지 않는다.
3. 의상별 실제 소품: Café커피, pajamas베개, astronaut밀폐visor/no-drink, 학생책, fitness덤벨, rainy우산, Christmas선물 등 현재 디자인 그대로. halo 없는 complete prop과 실제 grip 필요.
4. 해먹: 고정 양쪽줄/매듭, 움직이는cloth 앞뒤, 노출되는 배경복원, 양쪽 접점 좌표. 기존 단일회전은 근본 해결이 아니다.

PNG master 원본 해상도·lossless alpha 보존. UI source mipmap 미사용. 신규 휴가 runtime3PNG는1,148,536바이트이며 clean1024×1536 RGBA 한장 약6MiB는 이론 디코드량이다. 이것을 실제 메모리 사용량이나 성능 PASS로 보고하지 않는다. 비교 가능한 실측은 `PERFORMANCE.md`를 따른다.
