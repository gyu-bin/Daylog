# 휴가 원화 최종 제작 패스

작성 범위: 이번 휴가 원화 3회 실물 제작 및 좁은 눈 영역 네이티브 검토. 기존 원본·구매 상태 변경 없음. 클라우드 작업 결과는 이 문서의 범위가 아니다.

## 실제 제작

내장 `image_gen.imagegen` 편집을 사용해 실제 1024×1536 RGBA PNG3장을 제작했다. 원본이나 저해상도 시트를 확대하거나 도형으로 대신하지 않았다. 숨겨진 픽셀은 생성한 새 원화이며 원본에서 복구했다고 주장하지 않는다. 생성 결과는 원본 바이트 그대로 프로젝트에 복사했다.

저장 폴더: `output/pio-production-final-2026-10-24/vacation/`

| 파일 | 육안·정합 결과 | 적용 |
|---|---|---|
| `basic-day-complete-drink-v1.png` | 실제 유리·주스·빨대·레몬은 그려졌지만 큰 녹색/노란 halo가 남고 크기·위치가 원본과 다름 | FAIL, 미적용 |
| `basic-day-complete-drink-v2.png` | halo 제거/좌표 교정 요청에도 더 커진 소품과 halo. 원본 컵 기울기·질감도 달라짐 | FAIL, 미적용 |
| `basic-day-eye-free-candidate-v1.png` | 원본 눈2개 위치에서 연속된 털 복원. 이전 솜패드와 달리 부풀어 오른 형상은 없음. 전체이미지에는 천 등의 미세 차이가 있어 전체교체 불가 | 눈 주변2개 영역만 기존 리그 연결, Mac/iPhone 17 scoped PASS |

각 출력 alpha 범위는0–254다. PNG 형식/alpha 존재는 이미지 품질 통과를 뜻하지 않는다. 특히 음료 후보는 alpha>0 영역이 넓어 떨어진 색 halo를 포함한다. 음료의 alpha>200 bounds는 v1 `[478,755,700,1000]`, v2 `[149,389,881,1186]`; 원본 소품 설계 범위 약 `[530,694,635,812]`와 다르다. 고정된 손·빨대 접촉을 보장하지 못하므로 강제 축소·이동해 완료 처리하지 않았다.

## 원본 기준과 재구성 영역

26개 유료 낮/밤 원본 + 기본2개를 실제 파일에서 읽어 크기·alpha·SHA를 `source-inventory.json`에 기록했다. 모든 원본은1024×1536이며, 기본 낮 원본이 이번 제작의 입력이다. 기존 낮/밤 렌더러 앵커는 미검증 독립관절을 뜻하지 않는다.

- 기본 낮 눈A source rect `(422,688,58,44)`, pivot `(451,710)`.
- 눈B source rect `(531,647,54,43)`, pivot `(558,668.5)`.
- 정규화 contentsRect는 `basic-day-eye-region-registration.json`에 기록했다. 현재 휴가 트리는 `root.isGeometryFlipped=true`이므로 top-left Y를 그대로 사용한다. unflipped 클라우드 트리의 Mac Y 변환을 여기에 다시 적용하면 잘못된 영역을 읽는다.
- 같은 좌표의 원본/신규 후보 경계 RGB 절대차 평균2.46/1.64(0–255), 최대12/18. 이는 경계가 정확히 동일하다는 뜻이 아니며 실제 렌더링 이음새 검사가 필요하다.
- 기존 눈 상태 복귀는 원본의 바로 그2개 영역을 복원하는 방식이다. 열린 눈 donor는 기존 고해상도 `pio_overhaul_basic_eyeLeft/Right`를 이용한다. 원화편집으로 만든 눈이라고 주장하지 않는다.
- 샘플링은 생성된 정밀 복원 영역을 선택하는 런타임 처리다. 원본 단순 crop으로 가려진 털을 복구한 것이 아니다.

새 후보는 해먹 움직임을 그대로 따라야 한다. 눈 주변 복원 패치는 회전시키지 않고 원본 얼굴 좌표에 고정한다. 열린 눈과 닫힌 눈의 opacity만 변화시킨다. 해먹 줄·매듭·손·음료는 여전히 기존 이미지에 구워져 있으며 이번 눈 후보가 이들을 독립 레이어로 만들지 않는다.

## 네이티브 검토

신규 opt-in `DaylogTests/PioVacationFinalArtworkTests.swift`:

- `testNativePreciselyReconstructedEyeRegions`: 기존 `RoutimoriVacationRig`, 원본/복원영역/원본닫힌눈/열린눈4모드 ×64/220/1024pt 실제 AppKit 캡처12장.
- `testNativeEyeCandidateActualPresentationSequence`: 기존 리그 내부 독립 눈 opacity2초 변화의 실제 CALayer presentation44프레임. 50ms는 영상 취득 cadence이며 검증 timeout 확대가 아니다.
- `-PioVacationFinalArtworkReview` 명시 opt-in, production renderer·구매·착용 상태 변경 없음.
- 첫 실행2/2 XCTest는 통과했으나 실제캡처에서 눈 아래에 사각형 입·빨대 픽셀이 나타났다. 코드 전용 PASS와 시각 품질을 분리한다. 휴가 `root.isGeometryFlipped=true`에 클라우드의 unflipped Mac Y 샘플변환을 복사한 진단 코드 결함이다. sampler를 top-left Y로 수정했으며 처음56캡처는 `vacation-native/before-sampler-fix/`에 보존했다. 재검증 전 원화 PASS로 판정하지 않는다.

## 남은 원화와 적용 제한

### 수정 후 정적 검수 및 실제 리그 연결

수정된 실제 AppKit1024pt clean/open/closed,220pt open,64pt open을 직접 열어 검사했다. 눈 주변 사각형 잔여물과 이중 눈이 제거됐으며, 눈이 부리·볼·음료와 겹치지 않는다. 기본 낮2개 복원영역의 정적 육안 검수는 좁은 범위에서 PASS 후보로 판단했다. 최종 사람의 미적 승인을 대신하지 않는다.

한편 실제 sequence44장이 모두 닫힌눈의 동일 픽셀이고 이미지가 상하 뒤집혀 있음을 발견했다. opacity 관측 assertion 통과만으로 영상 PASS를 처리하지 않았다. `render(in:)`가 중첩 presentation 변화를 그대로 캡처하지 못하는 진단 결함을 고쳐, 계층별 실제 presentation 값을 별도의 정적 snapshot으로 복제하고 출력 CTM을 교정했다. 프레임이 실제로 달라지는 assertion도 추가했다. 이전44장은 `vacation-native/before-presentation-capture-fix/`에 보존했다. 이 snapshot은 실제 렌더러의 측정값을 재현한 component capture이며 물리 iPhone 화면 녹화가 아니다.

현재 소스 연결:

- `Daylog/Views/Dashboard/PioVacationIndependentEyes.swift`: 기존 해먹 CALayer의 자식, 복원영역2개+열린눈2개+원본닫힌눈2개. fullscene 교체 없음.
- `Daylog/Views/Dashboard/RoutimoriVacationScene.swift`: 기본 낮 foreground 이름일 때만 연결. 밤·13유료는 기존 원화 유지. 이미지 로드 실패 시 새eyes 미생성으로 안정적 기존화면 유지.
- `Daylog/PioVacationProduction.xcassets`: 새clean PNG1개+기존open donor2개 byte-identical복사. 보호원본 변경 없음.
- 눈9.2초 expression과 기존7.6초 해먹 sway는 서로 다른주기. stop/ReduceMotion/offscreen은 기존rig.setAnimating 경로로 눈도중지하고 원본 웃는눈으로 복귀. 낮/밤전환도눈트랙 제거/재개.
- 신규 실제rig lifecycle 및96프레임 native playback 테스트를 추가했다. 코드연결 완료가 실행PASS는 아니며 재빌드/실행결과는 별도기록한다.

### 최종 Mac 실행 결과

`mac-art-final-tests.log` / `/tmp/PioProductionFinal-Mac-art-final-20261024.xcresult`:

- `testBasicDayProductionEyesNativePlayback` PASS15.896s.
- `testBasicDayProductionEyesPreserveNightPaidAndLifecycle` PASS0.712s.
- `testNativeEyeCandidateActualPresentationSequence` PASS4.719s.
- `testNativePreciselyReconstructedEyeRegions` PASS1.150s.

휴가 신규4개 고유메서드 PASS. 같은번들에 다른7개도 실행됐지만 이원화검토의4개와 중복합산하지 않는다. 테스트중 production/diagnosticsnapshot이전의 `CALayer(layer:)` 복제는 이미지내용 없는 투명출력141장을 만들었다. 실제내용과 presentation값을 명시적으로 새CALayer에 복사하도록교정하고 blank거부assertion을추가했다. 이실패출력은 `before-explicit-layer-copy-fix/`에보존했다. 실제앱 production리그동작이사라진문제는아니고 검토영상캡처코드결함이었다.

최종 `vacation-native/`에는 정적12장, diagnostic44장(3개서로다른프레임), production96장(96개서로다른프레임)+정지1장이 있다. production000/025/040/070/stopped와1024/220/64정적이미지를직접열어검토했다. 원래웃는눈→열린눈→닫힘→복귀가보이고, 얼굴패치의사각형이음새/이중눈/소품분리/전신교체가없다. 현재좁은Basic낮눈동작의Mac품질은PASS후보. 사람의최종미적승인과별개다.

실제명령의100ms/50ms는최소샘플간격이며 렌더링·PNG저장시간이추가된다. 96프레임영상은정확한10fps실시간화면녹화라고보고하면안된다. 실제host에붙은CALayer의presentation을관측한순차검토프레임이다. 자세한증거범위는 `vacation-native/capture-validity.json`에기록했다. iOS8프레임집중검사도 아래와 같이 실행·육안 검수했다.

음료2회의 같은 실패를 무한 반복하지 않았다. 눈 지역 후보가 통과하더라도 기본 낮만 해당한다. 밤 조명이나13종 의상에 임의 공유하면 색·표정·광학 레이어가 달라진다. 여름 선글라스, 학생 안경, 우주복 visor를 보존해야 한다.

- 휴가 밤/유료13종: 해당 조명과 의상을 보존하는 clean-face/eye 복원.
- 독립 팔·손: 누운 자세 원래 shoulder roots, 앞/뒤 손 매트, 가려진 torso 복원.
- 음료: 원본 좌표·기울기·투명유리 유지, halo 없는 complete prop, 손과의 앞/뒤 접촉 매트.
- café커피, pajamas베개, astronaut밀폐visor/no-drink 예외를 유지. 일반 주스를 모든 의상에 넣지 않는다.
- 해먹: 양쪽 고정나무 매듭·로프와 움직이는 cloth 접점을 각각 분리하고 접점별 숨은 픽셀 복원. 이전 실패2후보는 재사용하지 않았다.

원본28장에는 새 shoulder/grip/고정rope anchor가 없으며, 미측정 값은 `null`을 유지했다. 승인되지 않은 값으로14종에 동일 보정값을 적용하지 않았다. 현 단계 신규 source texture budget는 한장6MiB(1024×1536×4)이며 실제 디코드 메모리 측정값이 아니다. 원본 master lossless PNG 유지, UI source mipmap 없음. full-frame 후보 전체를 모든 의상에 중복 로드하지 않는다.

프롬프트 전문은 `output/pio-production-final-2026-10-24/vacation/prompts.md`, 생성파일 치수·alpha·SHA는 `manifest.json`, 원본28장 매핑은 `source-inventory.json`에 있다.


## iPhone 17 Simulator 최종 집중 검증

`../iphone17-tests.log`와 `/tmp/PioProductionFinal-iPhone17-20261024.xcresult`의 `PioVacationProductionTests` 두 메서드를 확인했다.

- `testBasicDayEyeResourcesAndLifecycle`: PASS, 0.389초. 리소스, 기본 낮 범위, 밤·유료 원본 fallback 및 중지/재개 조건 확인.
- `testBasicDayEyesActualUIKitPresentationAt64And220`: PASS, 4.212초. UIKit window에 실제 리그를 붙여 64/220pt의 닫힘·실제 presentation 열린 눈·정지·밤 fallback을 캡처. 열린 상태 관측, 비어 있지 않은 캡처, 서로 다른 이미지 assertion 유지.
- 같은 실행의 전체 테스트 번들에는 별도 클라우드 assertion 실패가 있다. **휴가 신규 2/2 PASS를 전체 iOS PASS로 확대하지 않는다.**

`../iphone17-attachments/manifest.json`의 아래 8개 PNG를 모두 직접 열어 검사했다. 220pt는660×990px,64pt는192×288px이다. 얼굴 복원 영역의 사각 경계, 이중 눈, 입·빨대 잔여물, 잘못된 방향이 보이지 않는다. 눈 열림이 구분되며 정지 시 원래 웃는 눈으로 돌아간다. 밤은 원본 표정·조명을 그대로 유지한다. 이 증거는 네이티브 component 실제 presentation 캡처이며 물리 iPhone 영상은 아니다.

| 크기/상태 | 실제 PNG 파일 (`../iphone17-attachments/`) |
|---|---|
|220pt 낮 open|F62F2D00-5AA2-4C80-A609-54D63540294F.png|
|220pt 낮 closed|F9F1C776-9C8E-4CB9-B494-4509F6AE6138.png|
|220pt 낮 stopped|E4D83DCF-0A79-4AEF-B8F5-25127B2A4DA0.png|
|220pt 밤 fallback|02968D0E-159C-43F2-8199-11B994BA2B9F.png|
|64pt 낮 open|B4326142-2AF8-43F9-9532-CBDFFA1D08BD.png|
|64pt 낮 closed|60C6F9BF-E39E-4674-A375-6D58237739EC.png|
|64pt 낮 stopped|E8188AE4-4B56-45F9-8CB6-5C9A46F210E6.png|
|64pt 밤 fallback|37BA7F73-13C3-4604-BDC2-935EA85B94E3.png|

Basic 낮 눈의 네이티브 기술·시각 범위만 PASS 후보다. `VACATION_EYES` 전체는 여전히 PARTIAL이며 기본 밤 + 유료13종 낮/밤, 독립 half-eye 상태 및 광학 레이어 복원은 미완성이다. 사용자 최종 미적 승인은 남아 있다. 이번 확인 이후 앱 소스·원본 PNG는 변경하지 않았다.
