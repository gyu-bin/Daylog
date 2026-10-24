# Mac 가시성·메모리 진단

판정: **PARTIAL**. 제한된 Mac native 창 전환과 반복 메모리 검사는 PASS이며, 첫 로드 최대 RSS와 전체 앱 장기/GPU/배터리 검증은 남아 있다. 기존 실패를 보존하고 아래 실제 실행 결과를 추가한다. StoreKit, 원화, 기존 14×10 모션은 수정하지 않았다.

## 기존 증거

- 이전 `routimori-polish-2026-10-23/mac-final-checks.log`의 창 값: isVisible=true, isMiniaturized=false, raw occlusion=8192. SDK `NSWindow.h`의 public `.visible`는 `1UL << 1`(2)이므로 8192에는 visible 비트가 없다. 이를 true로 바꾸는 구현 수정은 근거가 없다.
- 이전 120초 프로세스 CPU 약1.02%, RSS191,545,344→467,173,376바이트. 처음 여러 의상을 로드하는 조건이며, 캐시·누수와 실제 표시 여부가 분리되지 않았다. 기존 전체 실행 FAIL과 장기 성능 미승인 상태를 보존한다.

## 이번 진단 설계

신규 `PioMacStabilityReviewTests` 및 opt-in `DaylogPioMacStabilityReview` 스킴만 추가했다. 테스트 호스트는 in-memory RuntimeEnvironment이며 production 앱을 교체하지 않는다. 기본 스킴에서는 명시적 플래그가 없으면 실행되지 않는다.

1. public raw 상태와 실제 callback을 기록하며 창 표시→orderOut→복귀→최소화→복귀를 검사한다. 중앙 배치·native activation을 사용하고, 창을 강제로 visible로 간주하지 않는다. public visible 비트를 실제 얻지 못하면 양성 검사는 FAIL로 남긴다.
2. 별도 새 프로세스에서 동일14종×3클라우드 상태를500ms씩 관찰한다. 첫 pass와 warm3pass를 동일 조건으로 수행하고, 매 pass 정지/레이어 분리/scene 인스턴스 해제를 검사한다. 마지막10초는 scene 없는 cooldown을 측정한다. 테스트 구간은 iOS 검증 담당과 조율해 다른 빌드/런타임을 멈춘 상태다.
3. Basic receiving/failure light/dark 4장은 실제 앱과 같은 hasSeatedLayers 분기를 사용한다. 합쳐진 기존 원화가 실제 CGImage로 로드되고1024개보다 많은 비투명 픽셀이 있는지 검사한다. 기존 fixture가 Basic에서도 무조건 분리 리그를 켰던 것은 TEST_BUG이며 앱의 빈 캐릭터 결함이라고 보고하지 않는다. 기존 `PioSceneNativeEvidenceTests`도 동일 분기로 수정했다.

## 메모리 가설과 범위

`PioOverhaulResources`는96MiB soft cost limit의 NSCache를 사용하며 NSImage(named:)의 플랫폼 캐시도 별도 존재한다. 클라우드120장 모두1254×1254 캔버스로 RGBA8 전개 총량은 약719.84MiB다. 기존 cropped standing213장은 약112.43MiB다. `source-image-dimensions.json`은 PNG IHDR에서 계산한 크기 추정이고 실제 cache retained bytes가 아니다.

워밍업과 동일 자산 반복 구간을 나누기 전에는 RSS 증가를 누수로 단정하거나 캐시 때문이라 확정하지 않는다. 이 작업에서는 원본 crop/재생성, 캐시 강제 purge, 이미지 다운샘플링을 하지 않았다. 프로세스 CPU/RSS만 측정하며 WindowServer/GPU/배터리와 전체 앱 장기 사용은 측정 범위 밖이다.

## 원본 실행 기록

- `mac-build.log`: 최초 harness 빌드.
- `mac-build-final.log`, `mac-build-v3.log`: 강한 픽셀 assertion 추가 중 Swift CoreFoundation cast/typeID 컴파일 오류, 보존.
- `mac-build-v4.log`: SDK에 맞춘 CGImage.typeID 적용 후 TEST BUILD SUCCEEDED.
- `mac-memory.log`: 별도 프로세스 cold/warm 실행 1/1 PASS(104.47초).
- `mac-visibility-basic.log`: 실제 callback 및 Basic 픽셀/네이티브 이미지 검사 2/2 PASS.
- `mac-original-window.log`: 이전 실패 testWindowVisibilityLifecycle 그대로 재실행 1/1 PASS.
- 세 xcresult는 `/tmp/PioMacStability-{memory,visibility-basic,original-window}-20261024.xcresult`이며 attachment 원본을 해당 폴더의 두 `*-attachments/`에 내보냈다. 최종 실행 이후 app source 수정은 없다.


## 실제 결과

### 창 가시성

`mac-window-native-transitions.json`은 native NSWindow/호스트 callback의 실제 순서를 기록한다. 표시 직전8192→표시8194(8192|2), orderOut8192, 복귀8194를 관측했다. 최소화 시 `.isMiniaturized` true로 callback false, 복귀 후 public visible 비트가 들어온 뒤 callback true를 확인했다. 이벤트 구간 사이에 수동 refresh를 호출하지 않았고 전체0.575초에 통과했다. public visible 상태를 강제로 대체하지 않았다.

이어서 **기존 실패 테스트를 수정하지 않고** 별도 새 OS 프로세스에서 실행해0.059초 PASS와8194를 확인했다. 이전8192 상태를 잘못 true로 처리한 앱 결함이 아니었으며, 지금 표시 가능한 환경에서는 기존 관찰 경로가 작동했다. 이전 환경이 왜 가려졌는지(잠금/Space/외부 창 등)는 증명되지 않았으므로 특정 원인으로 단정하지 않는다.

이 검사는 cloud/header가 공유하는 PioCloudSceneHost의 실제 native 전환이다. 휴가의 별도 private host, 전체 앱 창/모든 Space, 장기 반복 전환을 모두 검증한 것으로 확대하지 않는다. 앱 가시성 코드는 변경하지 않았다.

### 메모리·CPU

실제 native cloud 창에서 **168/168 상태 관측 시점에 public visible=true**였다. 각 회차는14종×3상태를 같은 순서·500ms dwell로 반복했고, 정지 후 전체 CA 트랙0개와 weak stage4/4 해제를 확인했다. CPU는 getrusage의 process user+system seconds를 해당 회차 wall seconds로 나눈 값이다.

| 구간 | 관측 시간 | 프로세스 CPU | 종료 RSS |
|---|---:|---:|---:|
| 초기 baseline | — | — |172.14MiB|
| 첫 cold pass |24.354초|5.13%|667.67MiB|
| 같은 자산 warm1 |23.309초|1.11%|196.75MiB|
| 같은 자산 warm2 |23.292초|1.13%|192.20MiB|
| 같은 자산 warm3 |23.335초|1.00%|149.20MiB|
| scene 없는 cooldown |10.139초|0.34%|146.44MiB|

전체104.429초, 관측 최대 RSS **667.67MiB**, 최종146.44MiB. 원본은 `mac-cloud-cold-warm-memory.json`; 계산 요약은 `memory-summary.json`이다. 같은 자산 반복 중 단조 증가를 재현하지 못했고 이미지/플랫폼 캐시와 일시적 디코드/렌더 자원 회수라는 설명과 일치한다. 어떤 개별 캐시가 몇 바이트를 보유했는지는 측정하지 않았으므로 캐시 원인 확정/모든 누수 없음/성능 완료로 판정하지 않는다.

이전120초 결과와 의상 전환 간격·상태 조합·가시성 조건이 다르므로 CPU before/after 개선 수치로 비교하지 않는다. **첫 로드 약668MiB 최대 사용량은 남은 위험**이다. 추후 실제 저메모리 기기 측정과 별도 승인된 렌더 파생물/cost 관리 검토가 필요하다. 이번에 원화나 캐시 정책을 바꾸지 않았다.

### Basic 클라우드 캡처 정정

`basic-receiving-{light,dark}-app-parity.png`, `basic-trouble-{light,dark}-app-parity.png` 네 장을 실제 native rig에서 다시 캡처하고 직접 열어 확인했다. Basic 캐릭터·태블릿·발이 모두 존재하며, 기존 fixture의 빈 캐릭터와 구분된다. 원래 합쳐진 승인 원화를 그대로 사용하므로 **Basic 독립 blink/손/태블릿은 여전히 BLOCKED_ASSET**이다. 이 재촬영은 원화 제작 또는 앱 결함 수정이 아니다.

## 변경 파일과 남은 범위

- 신규 `DaylogTests/PioMacStabilityReviewTests.swift`: opt-in3개 검사, 실제 callback/메모리 JSON/4PNG.
- 신규 `DaylogPioMacStabilityReview.xcscheme`: 테스트 전용 인자, 정상 실행/배포 기능 없음.
- `DaylogTests/PioSceneNativeEvidenceTests.swift`: cloud capture에서 앱과 같은 hasSeatedLayers guard 적용.
- 기존 원화·모션, StoreKit 관리자·registry·데이터는 수정하지 않았다. production 앱 설치/교체·커밋·push·배포 없음.

짧은 반복 관찰과 객체 정리는 PASS지만, 모든 장면을 오가는 전체 사용자 흐름/휴가 host 자동 이벤트/장기 메모리·GPU·배터리/실제 VoiceOver는 이 검사 범위 밖이다. 루트 보고서의 다른 검증과 별도로 합산해야 한다.

## 재현 명령

아래 명령은 production 실행/설치가 아니라 테스트 호스트 빌드와 선택한 테스트만 실행한다. 동일 결과 경로를 덮지 않도록 새 실행에서는 별도 `-resultBundlePath`를 사용한다.

```sh
xcodebuild -project Daylog.xcodeproj -scheme DaylogPioMacStabilityReview \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath /tmp/PioStoreKit-20261023-mac \
  -clonedSourcePackagesDirPath /tmp/PioOverhaul-v2-build/SourcePackages \
  -only-testing:DaylogTests/PioMacStabilityReviewTests build-for-testing \
  CODE_SIGNING_ALLOWED=NO PRODUCT_BUNDLE_IDENTIFIER=com.daylog.verify
```

실행은 생성된 `DaylogPioMacStabilityReview_macosx27.0-arm64.xctestrun`으로 `test-without-building`, `-parallel-testing-enabled NO`를 사용했다. cold/warm은 해당 메서드만 별도 새 프로세스로 실행했고, 창/Basic2개는 다음 별도 실행으로 분리했다. 마지막으로 기존 `PioPolishLifecycleTests/testWindowVisibilityLifecycle`만 다시 실행했다. 실제 전체 명령은 각 로그 첫 줄에 보존되어 있다.
