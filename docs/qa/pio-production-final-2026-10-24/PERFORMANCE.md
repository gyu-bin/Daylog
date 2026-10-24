# 피오 네이티브 성능·수명 검증 — 2026-10-24

## 판정

**PARTIAL.** 실제로 표시되는 Mac 네이티브 리그 성능 검사7개를 동일 조건의 변경 전·후 새 프로세스에서 모두 PASS했다. 모든 측정 대상 리그의 정지·분리·객체 해제를 확인했다. 클라우드14종의 중복 이미지 이름을 동일 원화로 공유해 관측 RSS peak를 **967.23→388.28MiB (59.86% 감소)**로 줄였다. 이는 단회 quiet 전후 비교의 실제 프로세스 관측치다. 실제 기기·장기 메모리 품질 전체를 PASS로 판정하지 않는다.

앞부분 표는 삭제하지 않은 첫 quiet baseline이고, 마지막 절에 같은7검사의 최적화 후 실제 측정을 추가했다. 기계 판독용 수치와 원본 JSON 경로는 `performance-comparison.json`에 있다.

## 장비·측정 범위

- macOS27.0.1 (26A434), 프로세서10개로 보고된 Mac. 하드웨어 모델/메모리 sysctl 조회는 환경 권한상 실패해 추정하지 않았다.
- Xcode27.1 (27A9275), Mac Debug XCTest 앱 호스트, 실제 NSWindow/NSView + Core Animation presentation layer.
- `candidateHandsFlag=false`, `candidateEyesFlag=false`, 선택 원화 `basic-production-hands-v2`. 새 production 이름/캐시 경로이며 시험용 의상 소유권을 부여하지 않는다.
- 부모 작업이 다른 빌드·렌더 작업을 멈춘 quiet 구간에7개 검사를 직렬 실행했다.
- 실행 증거: `/tmp/PioProductionFinal-Mac-performance-20261024.xcresult`, `mac-performance-attachments/manifest.json`.
- 각 리그150ms 실제 재생. CPU 비교는 별도5초 표본 구간6개. 전체 관측은 약73초다. 장시간 endurance 또는 앱 cold launch 측정이 아니다.
- RSS: `mach_task_basic_info`, byte/1,048,576=MiB. CPU: `getrusage(RUSAGE_SELF)` user+system 시간 / 실제 단조시계 구간. CPU100%는1코어다. XCTest 비용 포함, WindowServer/GPU/배터리 제외.

## 반복 진입·이탈

| 검사 | 시작 RSS | 최대 관측 RSS | 종료 RSS | 구간 | 해제/분리 |
|---|---:|---:|---:|---:|---|
|50회 기본 클라우드|174.31MiB|229.66MiB|229.59MiB|8.07초|50/50 host·stage 해제,50/50 즉시0 tracks|
|10회 기본 클라우드|729.97MiB|730.17MiB|730.17MiB|1.63초|10/10 해제,10/10 즉시0 tracks|
|20회 기본 클라우드|730.23MiB|730.28MiB|730.23MiB|3.25초|20/20 해제,20/20 즉시0 tracks|

실제 XCTest 순서는50회→14종 클라우드→14종 홈→CPU비교→10회→20회→휴가였다. 각 행은 별도 cold process가 아니다. 따라서10/20회의 시작 RSS가50회보다 높은 것을 반복 횟수에 따른 누수라고 해석하면 안 된다.

50회 검사의 첫 해제 직후229.28MiB, 마지막229.59MiB로 첫 원화/렌더 로딩 이후 큰 선형 증가가 관측되지 않았다. 이는 짧은 범위의 실제 객체 해제 근거이며, 전 앱의 누수 없음이나 메모리 budget 충족을 보증하지 않는다.

증거:
- 50회: `mac-performance-attachments/EA3C04E3-C3F2-42EE-A1BA-4273B2F91F81.json`
- 10회: `mac-performance-attachments/5A1A8C79-8F06-43C5-98B8-CDC1E0DB8523.json`
- 20회: `mac-performance-attachments/47141ADB-ABD8-4401-8EB8-B46AC46F8A50.json`

## 14종 의상 순차 렌더링

| 장면/회전 | 시작 | 최대 관측 | 종료 |
|---|---:|---:|---:|
|클라우드1회전|229.88MiB|967.22MiB|967.22MiB|
|클라우드2회전|967.22MiB|967.23MiB|952.28MiB|
|클라우드3회전|952.28MiB|952.28MiB|743.56MiB|
|일반 홈 reference1회전|743.72MiB|835.69MiB|835.69MiB|
|일반 홈 reference2회전|835.69MiB|835.69MiB|835.69MiB|
|휴가 낮·밤1회전|730.27MiB|891.63MiB|497.69MiB|
|휴가 낮·밤2회전|497.69MiB|497.69MiB|477.13MiB|

- 클라우드42/42 scene host·stage 해제.14종의 실제 production registration을 각각 기록했으며 Basic으로 대신 그리지 않았다.
- 홈28/28 rig 해제. 이는 일반 Release fallback인 `PioOutfitMotionRig`의 idle 검사다. DEBUG 독립10동작 전체나 실제 홈 버튼 사용자 흐름을 대신하지 않는다.
- 휴가28/28 rig 해제, 각 리그 낮·밤 총56상태. 기존 foreground/sway의 검사이며 새 독립 눈·손·음료 또는 고정 줄 품질 PASS가 아니다.
- 종료 RSS 감소는 객체·캐시·할당기의 지연 회수 가능성을 보여준다. 모든 차이를 특정 캐시 하나의 영향으로 단정하지 않는다. OS memory pressure와 allocation stack은 측정하지 않았다.

증거:
- 클라우드: `mac-performance-attachments/6C23BFF2-8471-4D04-A3B5-FE3494B37999.json`
- 홈: `mac-performance-attachments/64F5AD28-B59E-4571-95CB-BAB9BEB2E5E2.json`
- 휴가: `mac-performance-attachments/B7240451-E208-42DA-9AA9-086DA4A4EE52.json`

### 높은 첫 클라우드 메모리의 조사 근거

현재 production catalog의 PNG146개는 모두1254×1254다. RGBA4bytes/pixel로 계산한 전체 논리 픽셀 용량은875.81MiB다. **파일 SHA256 기준 실제 고유 이미지44개, 동일 바이트의 추가 사본102개**가 확인됐다. 예를 들어 공통 눈 이미지가 의상별13개 이름, 눈썹이15개 이름으로 들어 있다. 이 수치는 실제 heap allocation 측정치가 아니라 디스크 원화의 논리량이다.

`PioCloudImageResources`는48MiB 비용 한도의 NSCache를 사용하지만, 최초 로딩은 별도 asset 이름별 `NSImage(named:)`이다. AppKit의 이름 기반 이미지 보유와 렌더링 리소스는 자체 NSCache 한도만으로 상한을 보장할 수 없다. 첫14종 RSS 증가와 중복 이미지 이름은 확인된 사실이다. 각 바이트가 어떤 객체에 귀속되는지는 Instruments/heap 증거 없이 확정하지 않았다.

품질을 바꾸지 않는 후보는 byte-identical 이미지들을 동일 canonical asset/cache key로 공유하는 것이다. 원본 PNG·등록 좌표·의상별 앵커는 유지해야 한다. 변경 시 같은 quiet7검사 또는 최소14종3회전의 전후 비교가 필요하다. 이 baseline을 새 결과로 덮어쓰면 안 된다.

홈의14개 원화는 논리83.98MiB이며 첫 회전 RSS 약91.97MiB 증가와 비슷한 규모다. `PioOutfitMotionImageCache`는14종의 디코딩 결과를 의도적으로 보관한다. 휴가의 `ambient()`는 각 rig마다 낮·밤 backdrop을 CIContext로 생성한다. 두 항목 모두 사실이지만, 현재 측정만으로 버그나 누수로 판정하지 않았다.

## CPU 활성·정지 비교

같은 기본 피오/같은 native window에서 순서를 번갈아 실행했다. 각 상태는 실제 가시성5표본을 확인했다. 활성 track9개, 정지 track0개였다.

| 쌍 | 활성 CPU | 정지 CPU | 실행 순서 |
|---|---:|---:|---|
|1|0.2772%|0.9671%|활성→정지|
|2|0.2782%|0.2593%|정지→활성|
|3|0.3099%|0.2634%|활성→정지|
|산술 평균|0.2885%|0.4966%|각3개 구간|

빈 host2초1.5570%, 이미 앞선 검사에서 원화가 로딩된 이 메서드의 준비2초0.2493%, 최종 scene 해제 후2초0.2763%다. 빈 host와 준비를 새 프로세스의 cold start로 부르지 않는다.

n=3 paired 활성−정지 평균은−0.2082%p. Student-t(df2) 형식의 명목95%구간은[−1.2451,+0.8288]%p로0을 포함한다. 활성 평균의 명목95%구간은[0.2422,0.3347]%, 정지 평균은[−0.5157,1.5089]%다. 음수 하한은 저수준 CPU·작은 표본·변동성에 대해 대칭구간이 갖는 한계이며 실제 음수 CPU가 아니다. 같은 프로세스의 짧고 상관된 구간이라 독립 표본 모집단에 대한 엄격한95% 보증으로 해석할 수 없다.

**활성 애니메이션이 정지보다 CPU를 낮췄다는 주장이나 최적화 효과를 주장하지 않는다.** 이전16.08% Debug 점프 측정과 장면·작업·조건이 달라 전후 개선율을 계산하지 않는다.

증거: `mac-performance-attachments/FADFFAA9-D1C6-48F1-B307-D9FC39AB1FD0.json`.

## 실제 수정한 수명 결함

Mac clip ancestor의 strong 배열 때문에 document와 clip 사이 소유권 순환이 발생했다. 첫 실제 검사에서 stage/scroll은 해제됐지만 host/clip은 남았다. 기존20회 검사는 document 자체를 먼저 분리해 이 경로가 감춰졌다.

`PioCloudSceneHost.swift`, `RoutimoriVacationScene.swift`에서 사용하지 않는 `[NSClipView]` 보유만 제거했다. NotificationCenter selector 등록·정리는 유지했다. 같은 cloud intact subtree 검사 수정 후PASS, 실제 휴가 SwiftUI subtree 검사도PASS했다.

휴가 검사 첫 실패는 clip/scroll은 이미 해제되고 SwiftUI host가 남은 다른 서명이었다. fixture의 생성·레이아웃·subviews 검사 autorelease 범위를 명시한 후 추가 앱 수정 없이PASS했다. 일반 Text 대조군은 해제 assertion이 아닌 최초 window visibility 즉시 assertion에서 실패해 조건 기반 첫 보임 gate를 추가했다. 마지막 일반 Text 대조군도 `mac-art-final-tests.log`에서 PASS했다. 실패 로그는 보존했다.

- 첫 결함: `mac-first-tests.log`, `mac-first-attachments/9873DCFB-533A-4ABA-90FD-DBBC755DA170.json`.
- cloud 수정PASS: `mac-corrected-tests.log`.
- cloud/vacation 수정PASS: `mac-art-lifetime-tests.log`.
- 검사 설계/정확한 selector: `performance-review.md`.
- 최적화 후 실제 Mac 창 회귀 증거: `mac-alias-regression-attachments/EEE56C12-0C1F-42E0-9987-914EAD7AF32A.json`. orderFront / orderOut / restore / miniaturize / deminiaturize에서 기대 가시성 true / false / true / false / true 및 모든 host callback 일치를 확인했다. 실제 OS background CPU 검증과는 구분한다.

## 미검증·다음 단계

1. 초기 클라우드 peak 967.23MiB는 공유 최적화 후 388.28MiB로 줄었지만, 작은 iPhone의 전체 앱 메모리 예산·pressure 및 allocations/VM Tracker 검증은 여전히 필요하다.
2. 실제 앱 cold launch/홈→옷장→클라우드→휴가→background→재실행과 권한 복원은 이 리그 검사의 범위 밖이다.
3. 실제 OS background CPU, Swift concurrency 전체 Task 수, 전체 앱 리스너 수, FPS/drop, GPU, 배터리,120초 이상의 장기 실행은 이 실행에서 NOT_TESTED다.
4. weak rig/host 해제와 zero tracks는 PASS지만 모든 하위 프레임워크 리소스의 즉시 반납 또는 장기 leak-free 판정을 뜻하지 않는다.
5. 실제 VoiceOver/OS Reduce Motion 설정 조작, 전체14종 DEBUG10모션과 Release의 동등성은 별도 QA다. 구매/Sandbox 검사는 이 작업과 무관하다.

## 전후 비교를 위한 최소 최적화

첫 baseline 이후 부모 작업 승인으로 byte-identical texture canonicalization을 구현했다. `PioCloudImageResources`가 기존 registration의 asset 이름을 그대로 입력받되, NSCache key와 NSImage/UIImage named lookup 직전에만 canonical 이름으로 바꾼다.146원본 asset/PNG와 모든 registration/앵커/sampler는 그대로 보존했다. 새 alias dataset은 SHA256 및 실제 파일 바이트 equality로 생성했고 현재146파일의 해시 재검증을 통과했다.

- 생성 코드: `texture-aliases/generate.py`
- 원본 경로·PNG SHA256·크기·모든 alias: `texture-aliases/provenance.json`
- 앱 데이터: `Daylog/PioCloudProduction.xcassets/pio_cloud_production_texture_aliases.dataset/aliases.json`
- 실제 고유 원화44개의 논리RGBA 용량:263.94MiB. 기존875.81MiB와의 차이는 같은 픽셀에 붙은 이름만 공유하는 이론상 중복 용량이다. 아래 실제 RSS 전후 관측치와 동일한 지표가 아니다.

`PioCloudTextureAliasesTests`2개를 추가해 모든 등록 원화 alias 누락/순환/소실과146원본 이름 각각의 실제 native decoded RGBA SHA256 동등성을 검사한다. 이 검사는 의도적으로 모든 원래 이름을 로딩하므로 quiet 성능7검사와 별도 프로세스에서 실행해야 한다. 후속 성능 비교는 원래 7메서드·같은 순서·같은 조건의 새 프로세스로 수행했고 앞선 JSON도 보존했다. metadata가 없거나 잘못된 경우 alias 적용 없이 기존 로딩 경로를 유지한다. 실제 Mac native pixel/alias 검사 2/2 PASS: `mac-alias-regression-tests.log`, `/tmp/PioProductionFinal-Mac-alias-regression-20261024.xcresult`. 같은 별도 실행에서 실제 window visibility와 production 등록/전환/정지 검사까지 6/6 PASS했다.

## 최적화 후 동일 조건 실제 재검증

다른 빌드·렌더 작업을 중지한 quiet 구간에 **동일7메서드, 동일실행순서, 새 앱 프로세스**로 재실행해7/7 PASS했다. 원래 asset 이름을 모두 로딩하는 pixel 검사는 이 측정과 별도 프로세스로 분리했다. 별도의 source downscale, 원화 재생성, 좌표 변경, 캐시 전체 무제한화는 하지 않았다.

| 검사 | 전 시작/최대/종료 MiB | 후 시작/최대/종료 MiB | 후 구간 |
|---|---|---|---:|
|50회 기본 클라우드|174.31 /229.66 /229.59|169.16 /207.06 /156.11|8.06초|
|14종 클라우드3회전|229.88 /967.23 /743.56|156.52 /388.28 /305.64|7.03초|
|14종 홈 reference2회전|743.72 /835.69 /835.69|305.77 /365.53 /353.17|4.56초|
|기본 활성/정지 비교|835.78 /835.78 /729.88|353.23 /353.23 /135.72|36.32초|
|10회 기본 클라우드|729.97 /730.17 /730.17|143.91 /151.20 /151.19|1.63초|
|20회 기본 클라우드|730.23 /730.28 /730.23|151.28 /151.58 /151.05|3.23초|
|휴가14종 낮·밤2회전|730.27 /891.63 /477.13|151.20 /297.17 /183.61|11.22초|

50/10/20회 모두 actualVisible=true, stage/host 해제80/80, explicit cleanup 전 detached tracks0/80을 유지했다. 클라우드42/42, 홈28/28, 휴가28/28의 rig해제도 통과했다. 각 테스트 시작 RSS는 이전 메서드의 캐시/할당 상태를 이어받으므로 행별로 독립 cold-launch 절감율을 계산하지 않는다.

클라우드14종 후속 회전 상세:

| 회전 | 시작 | 최대 | 종료 |
|---|---:|---:|---:|
|1|156.53MiB|388.28MiB|388.28MiB|
|2|388.28MiB|388.28MiB|331.98MiB|
|3|331.98MiB|331.98MiB|305.64MiB|

같은 cloud scope에서 peak **578.95MiB 감소 (59.86%)**를 관측했다.102개 이름의 byte-identical 중복을 공유하는 로딩 변경과 시간적으로 일치한다. 이 결과는 불필요한 이름별 리소스 중복이 실질적인 메모리 비용을 만들었다는 강한 근거이지만, NSImage 내부 캐시와 Core Animation/할당기 각각의 기여 바이트를 heap trace로 분리한 것은 아니다. 기존 confirmed clip 순환 참조 수정과 이 이미지 공유 최적화는 서로 다른 문제다.

홈/휴가 후속값도 낮아졌지만 앞선 cloud 메모리 상태를 이어받는다. 따라서 홈 또는 휴가 자체의 새 로직이 그 비율만큼 개선됐다고 주장하지 않는다. 높은 첫 로딩을 줄였다는 결론과 실물 iPhone 전체 앱 메모리 예산 검증은 구분한다.

### CPU 후속 관측

| 쌍 | 후 활성 | 후 정지 |
|---|---:|---:|
|1|0.2154%|0.6641%|
|2|0.2066%|0.2092%|
|3|0.2502%|0.2128%|
|평균|0.2241%|0.3620%|

전 평균0.2885/0.4966%, 후 평균0.2241/0.3620%이다. 두 실행 모두 활성track9, 정지track0. 후 활성−정지 paired 평균−0.1380%p, 명목95%t 구간[−0.8082,+0.5322]%p. 후 활성평균 구간[0.1668,0.2813]%, 정지평균 구간[−0.2878,1.0118]%. 앞서 설명한 n=3·같은 프로세스 상관·대칭구간 한계가 적용된다. 전/후 활성평균 구간도 겹친다. **CPU 개선율 또는 통계적으로 입증된 CPU 향상을 선언하지 않는다.**

후속 증거:

- 실행 `/tmp/PioProductionFinal-Mac-performance-after-20261024.xcresult` (실행 로그의 resultBundlePath와 일치)
- `mac-performance-after-tests.log`, `mac-performance-after-attachments/manifest.json`
- 50회: `mac-performance-after-attachments/ED918D7B-30F1-494D-9F74-A6EFE0683012.json`
- 클라우드14종: `mac-performance-after-attachments/5CE2F6F5-943C-4B92-AF4F-85EBEBD1F1D5.json`
- 홈: `mac-performance-after-attachments/BF87CE7A-1245-4C64-960B-3BA6C19F4179.json`
- CPU: `mac-performance-after-attachments/F41B0CDA-AC99-49B8-B9A6-CB11E4CEDA28.json`
- 10회: `mac-performance-after-attachments/024A10B3-8A97-49BD-8F5D-4E39B0AC8390.json`
- 20회: `mac-performance-after-attachments/B535612A-8FC2-4E26-A8AD-8D0626E2E6C6.json`
- 휴가: `mac-performance-after-attachments/59893BFF-2D63-4795-8129-DA0224AAC00E.json`
