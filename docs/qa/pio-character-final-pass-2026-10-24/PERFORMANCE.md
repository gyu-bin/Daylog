# 성능·리소스 검증

## 현재 판정: PARTIAL — bounded lifecycle 검사는 PASS, 전체 성능·장기 누수 승인은 아님

이 문서는 이전 측정 증거와 이번 작업 후 검증을 구분한다. 이전 PASS를 새 홈 10동작·휴가 원화 변경 후 PASS로 승계하지 않는다. StoreKit seed·상품 조회·native pixel 전수 검사는 메모리 측정 프로세스와 분리한다.

## 재사용 가능한 기준선

기준: `../pio-production-final-2026-10-24/PERFORMANCE.md`, `performance-comparison.json`, `mac-performance-after-attachments/manifest.json`.

- macOS 27.0.1 (26A434), Xcode 27.1 (27A9275), 10 logical processors.
- Debug XCTest 호스트의 실제 네이티브 창. 신규 앱 cold launch 측정이나 실기기 결과가 아니다.
- 다른 빌드·렌더를 멈춘 새 프로세스에서 7개 메서드를 순차 실행했다.
- 146개 PNG 이름을 byte-identical 44개 canonical texture로 공유한 후의 값이다. 원본/좌표/등록을 보존한 최적화는 이번에도 유지한다.

| 기준선 순서·범위 | 시작 MiB | 최대 MiB | 종료 MiB |
|---|---:|---:|---:|
|50회 기본 cloud 진입·이탈|169.16|207.06|156.11|
|14종 cloud 3회전|156.52|388.28|305.64|
|14종 home reference 2회전|305.77|365.53|353.17|
|기본 active/stopped 3쌍|353.23|353.23|135.72|
|10회 기본 cloud|143.91|151.20|151.19|
|20회 기본 cloud|151.28|151.58|151.05|
|14종 vacation 낮·밤 2회전|151.20|297.17|183.61|

각 행 시작 상태는 앞선 메서드의 캐시/할당을 이어받는다. 메서드별 독립 cold-process 값으로 해석하지 않는다. 홈 baseline은 기존 `PioOutfitMotionRig` reference 경로로, 새 production 10동작 리그를 변경 없이 그대로 비교하는 지표가 아니다. 새 production 경로의 별도 관측이 필요하다.

이전 cloud 최대 RSS는 공유 전 967.23 → 공유 후 388.28MiB(관측 59.86% 감소)였다. 단회 전후 관측이며 모든 기기 메모리 예산 또는 leak-free 보장이 아니다.

CPU 기준선은 5초 구간 3쌍, `getrusage` user+system / monotonic interval, 100%=1 CPU core다. 활성 평균 0.2241%, 정지 평균 0.3620%였으나 n=3과 큰 분산 때문에 CPU 개선은 판정하지 않았다. 역사적 16.08% jumping 수치와 직접 비교하지 않는다.

## 이번 실행 계획

1. 기존 `PioProductionFinalLifecycleTests`의 정확한 7메서드를 같은 순서의 새 프로세스에서 재실행해 canonical 이미지 최적화/10·20·50회 해제 회귀를 확인한다.
2. 홈 production 10동작 연결이 완료되면 해당 경로의 실제 노출·종료·해제·Reduce Motion을 별도 검사한다. baseline reference rig를 production rig라고 바꿔 보고하지 않는다.
3. macOS intact scroll subtree 및 실제 window hide/minimize/restore 관측을 재사용하거나 변경 영향에 따라 재검증한다. weak host/rig 해제와 track=0을 확인하되 임의 RSS 허용량으로 누수를 판정하지 않는다.
4. 실제 소유권 검증 56조합과 seed/verify 재실행은 별도 프로세스에서 실행한다. 해당 Apple local ledger 준비 비용을 quiet scene CPU에 혼합하지 않는다.

## 새 홈 production 측정 fixture

`PioCharacterHomePerformanceTests/testProductionHomeFourteenOutfitsTwiceAndPairedIdleStop`을 `-PioCharacterHomePerformance` 플래그의 별도 새 프로세스에서 실행한다. 기존 7개 메서드와 합쳐 실행하지 않는다.

- 실제 visible macOS 창에 `PioHomeProductionStage`와 실제 `PioCloudSceneHost`를 연결한다.
- 14종을 2회전하고 매번 노출된 presentation/애니메이션 존재, body texture, native detach 직후 track=0, host/stage weak 해제를 검증한다.
- 초기·각 의상 전/재생/종료·warm empty·prepared stopped·active/stopped 5초 3쌍·cleanup RSS와 프로세스 CPU를 기록한다. 두 번째 쌍은 정지→활성 순서다.
- 150ms는 동일한 재생 관측 구간이며 실패 조건 재시도나 StoreKit 지연 우회가 아니다. 노출 여부는 실제 조건 기반 expectation으로 검사한다.
- 직접 production renderer 측정이다. 구매 권한·실제 앱 navigation·전체 홈 데이터 로딩 비용은 별도의 shared verified integration 범위다.

## 이번 실행 결과

대기 중. root가 빌드·시뮬레이터·quiet 구간을 직렬 조정한다. 실제 실행 전에는 PASS를 부여하지 않는다.

## 남은 측정 한계

실제 App UI 전체 cold launch, OS background CPU, 장기 120초 이상 endurance, 실물 iPhone GPU/배터리, 전체 Swift Task 수, Instruments allocation stack은 아직 이번 작업에서 측정하지 않았다. 일반 native rig `setActive(false)`의 정지 검사는 OS background 전환 측정과 다르다.

## 첫 홈 측정: FAIL 유지, 해제 관측 시점 수정 후 재검증 대기

원본 `mac-home-performance-tests.log`, `/tmp/PioCharacterFinal-Mac-home-performance-20261024.xcresult`, `mac-home-performance-first-attachments/B7C00E00-29A2-40DE-8408-95FFC1A10492.json`.

28회 모두 native detach 후 track=0, stage weak 해제=true였다. host는 같은 동기 호출 안에서 즉시 nil을 기대한 assertion이 28회 실패했으며 로그 주소는 두 개가 교대로 재사용됐다. 실제 지속 cycle이 확정된 근거는 아니다. fixture를 기존 5초 조건 기반 expectation으로 weak host/stage의 실제 해제 시점을 관측하도록 수정했다. sleep 확대·assertion 삭제·앱 코드 변경 없음. 즉시 상태와 최종 상태를 모두 기록한다. 후속 결과 전까지 FAIL을 유지한다.

해당 실패 실행에서 관측한 RSS는 시작168.89 / 의상 반복 중 최대236.78 / 최종178.52MiB였다. CPU 활성3구간 0.22531/0.21528/0.20918%, 정지3구간 0.22304/0.21776/0.23834%다. 동작 관측값일 뿐 메모리 안정성 PASS 또는 최적화 전후 비교로 사용하지 않는다.

## 수정 fixture 실제 실행: 홈 production PASS

`mac-home-performance-final-tests.log` / `/tmp/PioCharacterFinal-Mac-home-performance-final-20261024.xcresult`, 1/1 PASS, 테스트 메서드 99.877초. 원본 측정: `mac-home-performance-final-attachments/F06F354A-0AD8-41CC-A55A-8B74A3AA86A8.json`.

| 항목 | 관측 |
|---|---:|
| 실제 native production 홈 의상 반복 | 14종 × 2회 = 28 |
| detach 직후 animation tracks | 28/28에서 0 |
| 즉시 stage 해제 | 28/28 |
| 즉시 host 해제 | 0/28 |
| 조건 기반 대기 후 stage/host 해제 | 각각 28/28 |
| 초기 RSS | 174.78MiB |
| 반복 중 관측 최대 RSS | 234.97MiB |
| 최종 RSS | 118.50MiB |
| 별도 CPU fixture 최종 stage/host 해제 | 둘 다 true |

즉시 host 해제 실패는 최종에도 그대로 기록됐다. 기존 5초 조건 기반 expectation에서 다음 관측 시점인 약1.003–1.010초 후 28/28 해제를 확인했다. 이것은 실제 객체가 정확히1초 뒤 해제됐다는 뜻이 아니다. XCTest predicate 관측 간격을 포함한다. 추가 sleep이나 제한시간 확대 없이 참조가 결국 해제된 사실을 확인했으므로, 첫 동기 assertion은 AppKit 수명 관측 시점이 잘못된 TEST_BUG로 분류한다. 앱 retain cycle 수정은 필요하지 않았다. 이전에 별도로 확인·수정한 scroll ancestor cycle과 혼동하지 않는다.

| 동일 warm 창 구간 | CPU (% of one core) | tracks |
|---|---:|---:|
| active1 | 0.26361 | 15 |
| stopped1 | 0.19381 | 0 |
| stopped2 | 0.54701 | 0 |
| active2 | 0.20550 | 15 |
| active3 | 0.23032 | 15 |
| stopped3 | 0.20610 | 0 |

활성 평균0.23314%, 정지 평균0.31564%. paired 활성−정지 차이 평균−0.08250 percentage points, 명목95% t 구간 약[−0.64260,+0.47760]pp. 3쌍은 독립 기기/실행 표본이 아니며 stopped2 변동도 커서 성능 개선을 주장하지 않는다. 새 production 홈 경로의 최초 baseline이며 기존 reference 홈 또는 역사적16.08% jumping과 전후 비교하지 않는다.

새 테스트의 PASS는 실제 노출, track 정지, bounded weak 해제의 assertion 통과를 의미한다. 사용자 전체 데이터 로딩·OS background CPU·장기 메모리 누수·FPS·GPU/배터리까지 PASS라는 의미가 아니다. 초기 실패 JSON과 최종 JSON 모두 보존했다.

## 최종 C8 quiet7: 7/7 PASS

2026-10-24 17:35–17:36, 이전과 같은 7메서드·순서·Mac Debug host·새 프로세스. 다른 빌드/UI/시뮬레이터 작업을 정지한 구간에서 실행했다. 메서드 총72.078초. `mac-performance-final-tests.log`, `/tmp/PioCharacterFinal-Mac-performance-final-20261024.xcresult`, `mac-performance-final-attachments/manifest.json`, 기계 판독 요약 `performance-final-summary.json`.

| 순서·범위 | 시작 MiB | 최대 MiB | 종료 MiB | JSON |
|---|---:|---:|---:|---|
|50회 cloud|174.36|227.34|212.17|E621F190-7FAB-4B7F-9455-F075DCA40971.json|
|14종 cloud ×3|212.38|422.53|187.91|62BC0EE1-FF05-424E-A04E-A51880342CFB.json|
|14종 reference home ×2|188.11|291.08|289.11|20BBE65F-C466-4F8D-A4EF-AB13DA88C5F2.json|
|cloud active/stopped3쌍|289.12|289.12|151.69|37F741E6-4A96-4487-B7C9-93E27992BE88.json|
|10회 cloud|156.77|159.91|159.91|0A0C3787-4ADC-4903-BCEC-8366D7E9A5D0.json|
|20회 cloud|160.06|160.14|160.08|CAFDF875-4CD3-43B6-83AE-4B456CE2120C.json|
|14종 vacation 낮·밤 ×2|160.16|448.30|204.25|F9232BDF-63FE-4C08-A243-C7F137A868C4.json|

80회 cloud 및 14종×3회 모두 native 가시성, 활성 tracks, detach0, weak host/stage 해제 검사 PASS. Reference home28회와 vacation28rig(각day/night)의 stop/release 검사 PASS. 이 홈 행은 여전히 PioOutfitMotionRig fallback이며 새 production 홈의 별도 결과를 대체하지 않는다.

CPU active [0.22696435701566206, 0.19959335027542874, 0.2046494567173636], stopped [0.21106770323241442, 0.2312043346999506, 0.20709935419460562] (% one core). 평균 활성 0.21040%, 정지 0.21646%; paired차이 -0.00605pp, 명목95% t 구간 [-0.06557,0.05346]pp. 활성9tracks/정지0, 모든 샘플 실제 visible. CPU 개선을 주장하지 않는다.

이전 canonical baseline 대비 cloud14 최대388.28→422.53MiB, vacation297.17→448.30MiB로 높아졌다. 완료된 아트 승격과 초기 캐시 상태가 다른 단회 측정이며 어느 요인의 비용인지 allocation stack 없이 확정하지 않는다. vacation 종료204.25MiB, 모든rig해제true인 것만으로 장기누수가 없다고 단정하지 않는다. 448.30MiB 최대값은 실물 작은기기에서 확인할 남은 메모리 위험이다. 초기/최대/종료를 모두 공개하며 낮아진 값만 선택하지 않는다.
