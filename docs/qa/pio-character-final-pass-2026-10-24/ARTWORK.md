# Vacation artwork — final pass (2026-10-24)

상태: **PARTIAL / 기본 낮·밤, Christmas 낮·밤, winter 밤 총 5개 맥락의 독립 눈 적용**. 신규 4개 맥락은 iPhone 실제 presentation 검증과 최종 Mac C8 회귀 검증을 통과했다. 실제 신규 PNG 13장을 built-in image generation/edit tool로 제작했다. 원본 761개, 휴가 26장과 앞선 Basic/day 적용 원화는 덮어쓰지 않았다. 이 문서는 휴가 담당 범위이며 클라우드 전체 완료를 의미하지 않는다.

## 새로 제작한 파일

모두 `output/pio-character-final-pass-2026-10-24/vacation/`에 실제 저장되어 있다. SHA-256, 크기, alpha extrema와 투명 픽셀 수는 `candidate-manifest.json`에 기록했다. 스크린샷 crop을 업스케일한 것이 아니라 원본을 참조한 신규 raster reconstruction이다.

| 파일 | 규격 | 현재 판정 | 용도 |
|---|---|---|---|
| basic-night-clean-eyes-v1.png | 1024×1536 RGBA | PASS (narrow patch) | 기본 밤 눈 아래 털 복원 |
| basic-night-open-eyes-v1.png | 1024×1536 RGBA | PASS (narrow patch) | 기본 밤 열린 눈 |
| basic-night-half-eyes-v1.png | 1024×1536 RGBA | NOT_ACCEPTED | 밝은 눈꺼풀 조각이 보여 폐기 후보로 보존 |
| basic-night-half-eyes-v2.png | 1024×1536 RGBA | PASS (narrow patch) | 주변 털과 색을 연결한 수정 중간 눈꺼풀 |
| christmas-night-clean-eyes-v1.png | 1024×1536 RGBA | PASS (narrow patch) | 산타 밤 눈 아래 털 복원 |
| christmas-night-open-eyes-v1.png | 1024×1536 RGBA | PASS (narrow patch) | 산타 밤 열린 눈, 별도 위치 보정 필요 |
| basic-day-hand-drink-assembly-v1.png | 1254×1254 RGBA | **NOT_ACCEPTED** | 손·음료가 함께 있는 독립 투명 assembly 후보 |
| basic-day-hand-drink-assembly-v2.png | 1254×1254 RGBA | **NOT_ACCEPTED** | 왼팔 비율 보정했으나 빨대와 부리 정합 실패 |
| basic-day-clean-torso-v1.png | 1024×1536 RGBA | **NOT_ACCEPTED** | 가려졌던 몸통 복원 후보 |

투명도는 구분해야 한다. 손·음료 assembly는 alpha 0..255, 완전 투명 픽셀 1,026,438개다. 나머지 full-canvas 후보는 alpha 0 픽셀이 없고 낮은 alpha 잔여물이 있으므로 **완전 투명한 standalone 전체 캐릭터로 승인하지 않았다**. 얼굴 내부의 작은 영역만 기존 리그에서 샘플링한다. 전체 후보로 기존 승인 원화를 교체하지 않는다.

## 원본과 좌표

- Basic/day 참조: `Daylog/RoutimoriTrial.xcassets/routimori_vacation_hammock.imageset/routimori_vacation_hammock.png`
- Basic/night 참조: `Daylog/RoutimoriTrial.xcassets/routimori_vacation_hammock_night.imageset/routimori_vacation_hammock_night.png`
- Christmas/night 참조: `Daylog/PioVacationScenes.xcassets/routimori_vacation_night_christmas.imageset/routimori_vacation_night_christmas.png`
- 모두 기존 1024×1536, 좌측 상단 원점. macOS vacation root는 geometry-flipped이므로 cloud root의 Y 반전을 복사하지 않는다.

Basic/night 눈 영역:

| 부분 | source/target rect | pivot |
|---|---|---|
| 왼눈 | (419,781,65,57) | (451.5,809.5) |
| 오른눈 | (547,732,63,54) | (578.5,759) |

clean/open/half는 같은 영역이다. closed는 원본 영역 그대로 사용하여 정지·Reduce Motion에서 원래 웃는 눈이 복원된다. 새 중간 눈꺼풀은 약 138ms 전환에만 사용한다. 기존 7.6초 해먹 주기와 독립적인 9.2초 눈 표정 주기다. `independentlyAnimatesBasicNightEyes` 기본값은 native 검토 후 true다. Basic 밤과 Christmas 밤 모두 정상 Release 경로에서 사용한다.

Christmas/night은 생성 눈이 원래 눈 중심에서 약 6–13px 벗어나므로 그대로 쓰지 않는다. 원본 어두운 눈 픽셀 bbox를 측정한 중심은 (473,781.5), (608,737.5)다. Mac 진단에서는 새 열린 눈의 sample rect와 placement rect를 구분해 중심을 복원한다. 이것은 전 의상 공통 보정값이 아니다.

| 부분 | sample rect | target rect |
|---|---|---|
| 왼눈 열린 상태 | (452,749,45,53) | (450.5,755,45,53) |
| 오른눈 열린 상태 | (576,708,40,51) | (588,712,40,51) |
| 왼눈 clean | (435,743,78,72) | 동일 |
| 오른눈 clean | (574,704,71,62) | 동일 |

## 손·음료 후보를 적용하지 않은 이유

이번에는 앞선 2번의 full-canvas 소품 분리 실패를 반복하지 않고, 확대된 독립 assembly를 제작했다. 실제 투명 외곽과 손 뿌리는 얻었으나 원래 손/유리잔의 상대 비율을 지키지 못했다. 원본 유리잔 약 72×86에 맞추면 새 왼팔 길이는 약 121px로 원래 약 185px보다 짧다. 한 affine 배치로 양손과 잔을 동시에 맞출 수 없다. 임의 비등방 변형으로 봉합하거나 전체 캐릭터를 교체하지 않는다.

clean torso 후보도 제작했지만 표정·몸통·해먹 경계와 paired assembly의 native 정합을 아직 검증하지 않았으므로 적용하지 않는다. 손 assembly 자체도 두 손과 잔 사이 독립 관절을 갖지 않는다. 이를 손 각각의 독립 애니메이션 완료로 세지 않는다.

## 검증 경로

- 기존 낮 eyes와 기존 의상 원화 경로는 보존.
- `PioVacationNightArtworkTests`: resource/lifecycle, 64/220 실제 presentation 상태, 1024 original/clean/open/half/closed 비교. 중복 실행·낮/밤 전환·offscreen/stop 상태를 검사한다.
- `PioVacationComponentArtworkTests`: Mac 전용 Christmas/night 원본/clean/open 64/220/1024 합성 진단. 최초 샘플 진단 후 앱 등록과 Release 경로를 연결했다. 별도 lifecycle/presentation 테스트로 실제 앱 리그를 검증했다.
- 새 원화 생성 및 메타데이터 확인 완료. Basic 밤 v2 / Christmas 밤 및 두 고정점 해먹 native 결과는 아래와 같다. Christmas 낮 / winter 밤은 Mac 정적 진단과 C7 iPhone production lifecycle/presentation 검증을 통과했다.

## 아직 남은 항목

- 유료 13종 각각의 낮·밤 눈: Christmas/night 적용 완료. Christmas/day 및 winter/night도 등록 및 C7 iPhone native 검증 완료. 나머지 의상은 기존 정상 정지 표정 유지.
- 휴가 손/팔/음료: assembly 2장과 clean torso 1장을 제작했지만 사용할 수 있는 matched pair 미확보.
- 해먹 줄·매듭: 신규 승인 원화 없음. 기존 실패 후보를 재사용하지 않는다. 이전 3D 고정점 후보는 실제 SwiftUI 합성 결함으로 거부했다. 최종 C7의 Basic 전용 2D planar 움직임은 실제 앱 합성 및 framebuffer 검증 후 적용했다. 새 root 원화로 세지 않으며 다른 의상에 공유하지 않는다.
- 기존 6 BLOCKED_ASSET 분류 전체를 해결했다는 주장은 하지 않는다. 현재 눈 부문 중 기본 낮 기존 적용 + 기본 밤, Christmas 낮·밤, winter 밤 적용까지가 구체적 진척이다. 나머지 눈과 독립 손·음료 원화는 미완성이다.

## 1차 native 결과

Mac 3/3, iPhone17 Simulator 3/3 test PASS. 두 플랫폼 64/220/1024 총26장 직접 시각 검토: open/closed/원본복귀는 위치와 조명 양호. half v1은 윗눈꺼풀이 밝은 판처럼 보여 시각 품질에서 거부하고 v2를 생성했다. 테스트 PASS와 원화 승인 PASS를 구분한다. `mac-first-attachments/manifest.json` 및 `iphone-first-attachments/manifest.json`이 실제PNG명과 testcase를 연결한다. v2 적용 후 검증이 별도로 필요하다.

Assembly v2는 한 번의 비율 수정을 수행했다. 유리잔 중심과 높이에 uniform scale로 맞추면 빨대 끝이 부리보다 약15px 위로 떨어진다. 그림 안에서 빨대/잔/손이 여전히 합쳐져 있어 독립 보정할 수 없다. 동일 방식은 2회로 중단했으며 이 실패를 실제 애니메이션 완료로 보고하지 않는다.

## 앞선 기본/Christmas 밤 검증 이력

- Basic 밤 v1 half는 시각적으로 거부했다. v2로 교체 후 Mac/iPhone 64/220/1024 직접 검토에서 밝은 눈꺼풀 판이 사라졌다. 짧은 중간 표정에만 사용한다.
- Christmas 밤은 원본 eye center에 개별 등록하고, clean/open 경계에 3 source px feather를 적용했다. 64/220 실제 presentation closed/open/stopped 각3장 × Mac/iPhone 총12장을 직접 검토했다. 눈이 독립적으로 달라지고 의상/잔/손은 원래 자리에 유지된다. 정지하면 원래 웃는 표정으로 복귀한다.
- 현재 결과 매핑: `mac-regression-attachments/manifest.json`, `iphone-final-attachments/manifest.json`. 부모 실행 결과 Mac7 XCTest+94 Swift tests PASS, iPhone 전체 해당 실행 PASS. 최종 전체 수치는 메인 RESULTS에서 집계한다.
- Basic 해먹 두 고정점 **과거 3D 후보 (거부됨; 최종은 아래 C7 2D)**: 기존 장면의 두 rope pixel 위치를 통과하는 3D축으로 전체 해먹 foreground를 움직인다. day (968,484)→(0,684), night (68,465)→(1024,820). 원래 7.6초 주기 유지. Mac/iPhone64/220 3시점씩 총24장과 수학투영 검증에서 두 점 오차0. iPhone12장은 담당자가 직접 검토했다. 숨은 매듭 원화를 복원했다는 뜻이 아니며 손·음료 독립 움직임도 아니다.

## 추가 4개 원화 — Mac 샘플링 및 C7 iPhone 재생 검증 완료

| 파일 | 규격 | 상태 |
|---|---|---|
| christmas-day-clean-eyes-v1.png | 1024×1536 RGBA | PASS (narrow patch; C7 iPhone) |
| christmas-day-open-eyes-v1.png | 1024×1536 RGBA | PASS (narrow patch; C7 iPhone) |
| winter-night-clean-eyes-v1.png | 1024×1536 RGBA | PASS (narrow patch; C7 iPhone) |
| winter-night-open-eyes-v1.png | 1024×1536 RGBA | PASS (narrow patch; C7 iPhone) |

두 맥락 모두 원래 얼굴의 개별 눈 중심을 측정하여 등록했다. 일반화된 공통 eye offset을 적용하지 않았다. 후보는 전체alpha0이 없는 fullcanvas master이므로 눈 내부만 샘플링하며 승인 원본을 바꾸지 않는다. `PioVacationComponentArtworkTests`의 두 별도 정적 테스트 후 기존 앱 리그에 연결했다. C7의 두 production lifecycle/presentation 테스트를 실제 실행했다.

Christmas 낮 원본 중심(473.5,751)/(583.5,708.5): clean rect(441,720,65,57)/(553,682,61,50), open source(450,723,48,48)/(557,686,43,46) → target(450,727.5,48,48)/(562.5,686,43,46).
Winter 밤 원본 중심(484,836)/(622,783.5): clean rect(446,802,77,65)/(588,756,69,57), open source(458,803,58,60)/(592,761,47,51) → target(455.5,806.5,58,60)/(599,758.5,47,51).

## 의상별 휴가 눈 적용 범위

| 의상 | 낮 눈 | 밤 눈 | 손·음료 독립 관절 |
|---|---|---|---|
| 기본 | 기존 적용 유지 | 신규 적용 PASS | BLOCKED_ASSET |
| 벚꽃 | 기존 정지 표정 | 기존 정지 표정 | BLOCKED_ASSET |
| 여름휴가 | 선글라스 뒤라 눈 표현 N/A | 선글라스 뒤라 눈 표현 N/A | BLOCKED_ASSET |
| 가을 | 기존 정지 표정 | 기존 정지 표정 | BLOCKED_ASSET |
| 겨울 | 기존 정지 표정 | 신규 적용 / iPhone PASS | BLOCKED_ASSET |
| 할로윈 | 기존 정지 표정 | 기존 정지 표정 | BLOCKED_ASSET |
| 크리스마스 | 신규 적용 / iPhone PASS | 신규 적용 PASS | BLOCKED_ASSET |
| 한복 | 기존 정지 표정 | 기존 정지 표정 | BLOCKED_ASSET |
| 카페 | 기존 정지 표정 | 기존 정지 표정 | BLOCKED_ASSET |
| 학생 | 기존 정지 표정 | 기존 정지 표정 | BLOCKED_ASSET |
| 운동 | 기존 정지 표정 | 기존 정지 표정 | BLOCKED_ASSET |
| 비 오는 날 | 기존 정지 표정 | 기존 정지 표정 | BLOCKED_ASSET |
| 잠옷 | 기존 정지 표정 | 기존 정지 표정 | BLOCKED_ASSET |
| 우주복 | 기존 정지 표정 | 기존 정지 표정 | BLOCKED_ASSET |

기존 정지 표정도 의상별 원래 해먹 흔들림은 유지된다. 이 표는 장면의 표시 가능 여부가 아니라 눈/손 독립 원화 적용 범위다. 여름 낮·밤 원본은 직접 확인했으며 눈 전체가 불투명 선글라스에 가려져 있다. 안경을 임의로 지우거나 눈을 위에 그리지 않는다.

## 리소스 예산 및 사용법

- 고정 원본 좌표1024×1536 유지, source-resolution import, UI texture mipmap생성 없음.
- 눈 root당 clean2 + open2 + closed2 = 6 CALayer, Basic 밤만 half2를 추가하여8. CAopacity animation4개, Basic밤6개. per-frame SwiftUI state/layout 업데이트 없음.
- RGBA 1024×1536 decoded master1장 약6MiB. 새2상태 profile은 clean/open2장 약12MiB가 상한 기준이며 동일 master의 좌/우 CALayer는 같은 CGImage를 공유한다. Basic밤은3장18MiB 기준. 원본 foreground는 기존 리소스다.
- 새 고해상도 masters 전체를 장면에 겹쳐 그리지 않는다. 얼굴 안쪽 소형 sample rect만 draw한다. backgroundalpha잔여물이 화면에 노출되지 않는다.
- 화면 이탈/캐릭터 숨김/Reduce Motion 정지 시 모든 눈 CA animation을 제거하고 원래 closed 상태로 복귀한다. 신규 프로필별 별도 장시간 memory measurement는 아직 수행하지 않았으며 전체 성능 수치는 부모 RESULTS를 따른다.

## 추가 후보 native 샘플링 결과 및 연결

`mac-extra-candidates-attachments/manifest.json`의 Christmas 낮 / winter 밤 각각9장(64/220/1024, original/clean/open), 총18장을 직접 검토했다. 원래 얼굴 안에 새 눈과 복원 털이 맞고 손·소품 위치를 바꾸지 않았다. 두 프로필을 기존 리그에 등록했으며 신규4개 assets는 원본 후보와 byte-identical copy다. `PioVacationNightArtworkTests`의 두 추가 production lifecycle/presentation 테스트는 C7 iPhone에서 PASS다. 64/220 closed/open/stopped 총12장을 직접 검토했으며 눈 위치·털 경계·원래 표정 복귀가 정상이다. Mac C8 최종 회귀 실행에서 Night6 및 hinge4를 포함한107/107 PASS를 부모 에이전트가 확인했다. 담당자의 Mac 추가2맥락 직접 시각 검토는 정적18장이고 실제 production 프레임 직접 검토는 C7 iPhone12장이다.

현재 원화 제작 수13장 중 적용 대상으로 선택한9장: Basic밤3 + Christmas밤2 + Christmas낮2 + winter밤2. 거부/보류4장: Basic밤halfv1, 손·음료assembly v1/v2, clean torso. 앞선 Basic낮3장은 신규 제작 수에 포함하지 않는다.

## 고정점 실패와 최종 C7 수정 — 범위 구분

C4의 3D축 후보는 직접 CALayer 렌더/투영검사는 통과했지만, iPhone 전체 SwiftUI `drawHierarchy`에서 낮 몸통/해먹이 사라지고 밤 화면이 대각선으로 잘렸다. 특정 GPU 결함으로 단정하지 않는다. 즉시 기본 적용을 취소했고 당시 소스는 `hinge-3d-rejected-source.swift`로 보존했다. 위의 3D 결과는 역사적 진단이며 최종 구현이 아니다.

최종 C7은 `A = I + k u vᵀ`인 **2D 면적 보존 planar shear**를 사용한다. u는 두 고정점을 잇는 축, v는 그 수직 방향이며 |k|≤0.025, det(A)=1, 최대 늘어남 약1.3%다. 기존 7.6초 주기를 유지한다. Basic 낮 (968,484)→(0,684), 밤 (68,465)→(1024,820) 두 visible rope 위치만 등록했다. 두 번째 위치는 캔버스 가장자리 줄 진입점이며 숨겨진 매듭을 복원했다는 뜻이 아니다.

C7 iPhone 실제 presentation의 64/220 낮·밤 12프레임에서 중심은 움직이고 두 점 최대 오차는 **0.0002782 source px**였다. 이 숫자는 수학적 이상값0과 구별되는 실제 presentation 행렬 측정이다. 해당 JSON은 `iphone-vacation-c7-attachments/A9F0D6A8-D754-46D8-85C4-28EB829C3673.json`이다. 대표220 낮·밤 프레임과 전체 SwiftUI 화면, 실제 simulator framebuffer를 직접 확인했으며 기존 몸통 누락/대각선 잘림은 나타나지 않았다. 두 convenience init의 Basic 고정점 기본 적용은 true다. 유료 의상에는 이 좌표를 공유하지 않는다.

이는 **기존 전체 foreground의 작은 움직임 개선**이다. 독립 손, 음료, 해먹 줄·매듭 원화를 새로 완성한 것으로 세지 않는다.

## 최종 C7 iPhone 및 작은 화면 검증

| 검증 | 실제 결과 | 근거 |
|---|---|---|
| Mac C8 최종 회귀 (부모 실행) | 107/107 PASS, Night6 + hinge4 포함 | 최종 메인 RESULTS 및 C8 실행 로그 |
| iPhone17: Night artwork6 + Hinge1 + 전체화면1 | 8/8 PASS, 38.781초 | `iphone-vacation-c7-tests.log`, `iphone-vacation-c7-attachments/manifest.json` |
| 작은 iPhone: 전체화면 + AX5 스크롤 끝 | 2/2 PASS, 3.878초 | `smallphone-c7-tests.log`, `smallphone-c7-attachments/manifest.json` |
| Christmas 낮 / winter 밤 production64/220 | 각 closed/open/stopped 실제12프레임 직접 검토 PASS | C7 manifest의 production 이름 |
| Basic 낮·밤 실제 전체화면 및 작은 화면 | 몸통·해먹·줄 정상, AX5 하단 버튼 도달 확인 | 두 manifest의 screen-vacation / content-end |
| 실제 simulator framebuffer 낮·밤 | 1206×2622 PNG2장 직접 검토 PASS | `native-framebuffer/vacation-day-actual-simulator-framebuffer.png`, night 동명 파일 |
| 실제 화면 녹화 파일 | H264, 1206×2622, 29.151667초, 64,919,894bytes | `native-framebuffer/vacation-day-night-actual-simulator.mov`, `video-metadata.json` |

영상은 실제 존재와 codec/길이/크기를 ffprobe로 확인했다. 담당자는 전체 영상을 재생 시청했다고 주장하지 않는다. 실제 animation presentation의 상태 변화와 비동일 프레임은 XCTest에서 검사했다. full-screen 검증은 in-memory 데이터와 기존 앱 뷰의 렌더링이며 실제 구매·CloudKit 동기화 또는 OS VoiceOver 조작 검증이 아니다. 작은 화면 테스트에서 UIKit appearance transition 경고가 남았으나 두 테스트의 assertion은 통과했다. 최종 전체 빌드·성능·보호 파일 검증은 메인 RESULTS를 따른다.

## 최종 남은 원화 요구사항

- 휴가 독립 눈은 28개 의상×조명 맥락 중5개 적용이다. 여름2개는 선글라스로 가려져 N/A, 나머지는 기존 정지 표정을 유지한다. 미제작 맥락을 기술적으로 불가능하다고 단정하지 않는다.
- 손·팔·음료: 독립 assembly2회가 원본 비율과 빨대 연결 조건을 충족하지 못했다. 각 손과 잔/빨대를 분리하고 원본 몸통/부리 좌표에 맞춘 재제작이 필요하다.
- 해먹: Basic 두 점 고정 움직임은 개선했으나 신규 투명 줄·매듭 및 가려진 배경 원화는 없다. 유료26장 고정점별 등록도 완료하지 않았다.
- 전체 독립 원화 요구는 여전히 PARTIAL이다. 승인된 기존 전체 원화/의상 실루엣을 후보 전체이미지로 교체하지 않았다.
