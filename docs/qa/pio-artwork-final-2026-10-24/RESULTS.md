# 피오 원화·시각 품질 및 잔여 안정성 — 2026-10-24

최종 판정 **PARTIAL**. 새로 분리 원화를 제작하거나 기존 합성 PNG를 독립 레이어로 위장하지 않았다. 실제로 고친 항목은 접근성 안내와 잘못된 시각 검증 fixture다. 부족한 실제 픽셀은 제작 명세로 전달한다.

## 해결한 항목 / 해결하지 못한 항목

- VacationRestView: 권한 확인 중 캐릭터가 숨겨져 있는데도 '해먹에서 쉬는 기본 피오'라고 읽는 불일치 수정. 이제 '피오 의상을 확인하는 중'이라고 안내한다. 구매/착용 상태는 변경하지 않았다.
- 기존 Mac cloud native snapshot fixture가 모든 의상에 independent=true를 강제해 기본 피오 receiving/trouble light/dark 4장의 캐릭터가 비어 있었음을 발견했다. 앱은 hasSeatedLayers 검사로 기본 합성 원화를 사용하는 것이 맞다. fixture를 앱과 일치하도록 수정했다. 과거84장 전체를 유효한 캐릭터 렌더링 증거로 간주하면 안 된다.
- 새 독립 원화 BLOCKED_ASSET 해제는 **0건**. 기본 클라우드 clean face/눈, 유료 손/태블릿 뒤 숨은 몸통, 휴가 눈/손/소품/해먹 뒤와 고정 줄은 기존 합성 이미지에서 손실 없이 얻을 수 없다. 원본은 보존했다. 상세 사양·참조·좌표는 artwork/ 문서를 따른다.

## 제작 전달물과 시각 검수

[artwork/ARTWORK-SPEC.md](artwork/ARTWORK-SPEC.md)에 실제 제작용 레이어/숨은뿌리/가림/부모관절/투명도 계약을 작성했다. [PER-OUTFIT.md](artwork/PER-OUTFIT.md)와 inventory.json에14종의 현재실측등록좌표·출처·크기·SHA를 담았다. 아직 없는 어깨·그립·양쪽매듭 좌표는 null이며 임의값으로 승인하지 않는다. 클라우드1254×1254RGBA, 휴가1024×1536RGBA를 유지한다.

기존 standing213부품 원본rect픽셀일치, cloud120파일동일, vacation28원본대응을 확인했다. 참조PNG16장을 바이트동일복사하고 기존 실제렌더56개를 review.html로 연결했다. 중립 자세의 홈리그14종/유료cloud13종/휴가28장 정체성·비율·소품접촉을 검토했으며 전체앱14종동작시간축검증과 다르다. 크리스마스 선물이 낮에는 관찰자왼쪽, 밤에는 오른쪽인 것은 원래그림 차이이므로 아트승인이 필요하다. 잠옷/우주복은 음료없음, 카페는커피라는 실제설계를 보존한다.

## 의상과 실제 권한 검증

새 최소 진단4/4 PASS: 비오는날·잠옷·우주복을 각각 SKTestSession으로 시드한 직후 verified currentEntitlements를 확인했다. 검증 전 착용 거부→검증 후 착용→홈/클라우드3/휴가2 컨텍스트 일치→기존10개 동작 활성/정지까지 검사했다. SDK만 사용하는13종 순차 즉시 조회도 PASS.

기존 통합13종 검사는 한 번 비교 실행해 FAIL. 이전에는 비오는날에서 실패했으나 이번에는 두 번째 여름휴가에서 즉시 영수증이 빠졌다. 특정 outfit.rainy 매핑 결함이라는 근거는 없으며 최소 하네스에서 재현되지 않아 SDK 결함으로도 판정하지 않는다. 공통 통합 경로/세션 이벤트 시점 문제는 **UNRESOLVED**다. 구매 관리자/제품 ID/검증 보안을 바꾸거나 assertion을 없애지 않았다.

프로그램 방식 로컬 Xcode 거래 검증이며 실제 Product.purchase 사용자 흐름/Apple Sandbox 구매가 아니다. 기존 StoreKit 실패4건은 별도 알려진 문제로 유지한다. 모든14종 전체 사용자 흐름 최종PASS는 아니다.

## 작은 iPhone / iPad 및 접근성

전용 iPhone SE3(375×667pt compact)와 iPad mini A17 Pro(744×1133pt regular) 시뮬레이터에서 실제 DashboardView 분기를 각각 검사해1/1 PASS. normal/AX5 각각PNG 저장·직접 관찰. 피오 발 잘림이나 헤더 겹침은 보이지 않았다. AX5에서는 SE날짜3행/인사2행, iPad버튼다음행으로 이동했다.

이는 네이티브 DashboardView 호스트 캡처이며 실제 앱 탐색바·탭·스크롤 전체·회전·VoiceOver 조작 인증이 아니다. 실제 음성 읽기 순서/OSReduceMotion토글은 NOT_TESTED. 코드 기반 상태/장식숨김 검사는 ACCESSIBILITY.md 참조.

## Mac 창·메모리 실제 결과

- 실제 가시성 전환 PASS: raw occlusion8192(false)→8194(true), 표시→orderOut→복귀→최소화→복귀의 자동 콜백 확인. 이전8192기록은 정상적인 비표시 판정이며 앱조건을 우회하지 않았다. 이번 테스트 창 활성화 환경에서 문제가 재현되지 않았다.
- 기본 클라우드 fallback 검사 PASS: receiving/trouble × light/dark4장의 실제 비투명 원화 픽셀과 캡처 확인. 잘못된 기존 fixture는 TEST_BUG로 수정했으며 기본 눈 분리 원화가 생긴 것은 아니다.
- 104.43초 동일14종×3상태 cold1회/warm3회 검사 PASS(한정된 정지·해제 조건): RSS cold약172→667.67MiB, warm1종료196.75, warm2 192.20, warm3 149.20, cooldown146.44MiB. 모든4개 scene weak참조해제, 정지트랙0. 168개 구성 표본에서 publicVisible=true.
- 이번 결과는 초기 이미지 로딩과 캐시/OS회수 양상에 부합하며 반복누적을 재현하지 못했다. 캐시별 retained bytes를 직접분해하지 않았으므로 증가원인을 캐시 하나로 확정하지 않는다. 초기약668MiB peak는 주의사항이며 장기누수없음/GPU/배터리PASS가 아니다.
- 신규 Mac선택검사3개 PASS, 새 iOS진단4개+기기별2개 PASS, 기존통합검사1개 FAIL. 테스트용 Debug 빌드로 실제 실행했다. 이번 Release 재빌드는 하지 않았다.
- 보호761개 SHA-256 모두동일, git diff --check PASS.

## 변경 파일

- Daylog/Views/Dashboard/VacationRestView.swift: 조회 중 접근성 문구.
- DaylogTests/PioSceneNativeEvidenceTests.swift: 기본 클라우드 fixture의 리그 선택 조건.
- DaylogTests/PioMacStabilityReviewTests.swift 및 전용 opt-in 테스트 scheme: Mac 창·메모리·기본원화 진단.
- DaylogStoreKitTests/PioRemainingLedgerDiagnosticTests.swift: 실제 verified 로컬거래 격리 진단.
- DaylogStoreKitTests/PioDeviceSizeReviewTests.swift: 실제 기기 크기 Dashboard 호스트.
- 본 QA 폴더: 원화 명세·참조·실행로그·검사결과.

실행 세부와 실패 로그는 validation/RESULTS.md, Mac 결과는 stability/ 문서, 제작 전달물은 artwork/에 있다. 과거 Release 빌드PASS는 이전 증거이며 이번에 다시 실행했다고 주장하지 않는다.

## 남은 출시 차단/승인 조건

1. 독립 장면 동작을 완성하려면 새 clean-body/눈/손/소품/해먹 레이어 제작·앵커 승인 필요. Release와 DEBUG 독립 리그 범위는 동일하지 않다.
2. 실제 소유 전체 의상 통합 흐름과 StoreKit 잔여 실패 원인 격리, Apple Sandbox/실기기 검증 필요.
3. Mac 실제 가시성·장기 메모리 결과의 범위는 stability 보고서 참조. 보이지 않는 창의 낮은CPU를 실제 화면 성능PASS로 쓰지 않는다.
4. 실제 VoiceOver·스크롤 도달성·회전·모든 장면과 전체 앱 화면 검증 필요.
5. 원화별 낮/밤 소품 위치 차이와 양쪽 고정 매듭은 최종 아트 승인 및 분리 리그가 필요하다.

커밋·push·배포·운영 앱 교체·사용자 데이터·StoreKit 구매 로직 변경 없음.
