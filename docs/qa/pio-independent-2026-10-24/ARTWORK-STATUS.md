# 실제 분리 원화 제작 상태 — PARTIAL

이번에는 사양서만 작성한 것이 아니라, built-in imagegen으로 가려진 얼굴·몸통을 복원하고 눈·팔·태블릿·발의 실제 투명 원화를 만들었다. 생성기가 부품 크기/위치를 그대로 유지하지 않은 결과는 그대로 덮어쓰지 않고, 원본 캔버스 기준 runtime sampler와 목표 좌표를 명시했다. 모든 PNG는 생성본 또는 기존 genuine donor를 **픽셀 변경 없이 복사**했다. Python은 alpha/크기/SHA 분석과 JSON·catalog 복사에만 사용했다.

## 6개 기존 blocker

| 기존 blocker | 현재 상태 | 실제 진척 / 남은 조건 |
|---|---|---|
| Basic cloud clean face + eyes | PARTIAL | 눈 제거 후 얼굴 털이 복원된 1254² RGBA, 원본 스타일 open pair, 실제 새 closed pair, worried brows 등록. 교정된 Mac 64/220 light/dark open/closed/failure가 귀여운 인상과 재질을 유지하는 것 확인. Half pair도 새로 만들었으나 **source-only, 미등록/미통합**. 정상 catalog로 복사한 V1은 root의 Release/native QA 결과를 따름. |
| 유료 13종 cloud 손/숨은 어깨 | PARTIAL | 13종 모두 의상별 genuine torso + sleeve/cuff/hand pair 후보를 실제 제작·등록했다. Basic/Christmas 및 검토한 Hanbok/Café 프레임은 Mac/iOS pilot appearance 확인. Cherry/Autumn/Winter/수정 Astronaut도 실제28frame의 Mac/iOS gate 통과. 나머지6종도 담당자의 실제 Mac/iOS component appearance 검토에서 통과했다. 전체14 후보의 검토 범위는 아래에 기록한다. DEBUG 명시 선택 후보이며 Release 전체 의상/손 떼기 동작 완성은 아니다. |
| Cloud 독립 tablet/가림 | PARTIAL | Basic의 녹색 tablet 전체 외곽을 진짜 원화로 복원하고 14종 DEBUG 후보에서 원래 prop 크기로 등록해 공유했다. 팔/손/tablet의 shared hold joint가 몸통과 따로 움직이며, 초기 파일럿의 Mac/iOS 접촉은 확인했다. 최종 batch도 실제 native 부품 프레임과 원화 검토 범위이며 Release V2는 미승인이다. |
| Vacation 독립 eyes | BLOCKED_ASSET | 14종 낮/밤 모두 기존 flattened foreground. Root의 별도 복원 시도는 cotton-pad처럼 보여 시각 gate FAIL; 채택·확장하지 않음. 새 clean face/eyelids가 장면에 통합됐다고 주장하지 않음. |
| Vacation 독립 arms/drinks/실제 props | BLOCKED_ASSET | 새로 승인된 reclining arm/hand/prop root/occlusion 세트 없음. Café coffee, pajamas pillow, astronaut 닫힌 visor/no-drink 등 실제 소품 차이 유지. |
| Vacation 양쪽 고정 ropes/cloth | BLOCKED_ASSET | 두 fixed knot + moving cloth + 가려진 배경 복원 세트 없음. 기존 약한 전체 foreground 흔들림은 두 매듭 고정이나 cloth deformation 완료가 아님. |

이 표는 일부 실제 부품을 제작한 결과이며 14종 전체 독립 애니메이션 완료, 최종 사용자 시각 승인, 모든 성장 단계의 별도 외형 완성을 의미하지 않는다.

## 14종별 이번 제작/등록 범위

`기존`은 이전 genuine cloud eye rig 또는 원래 flattened fallback을 유지한다는 뜻이다. 이번에 해당 의상을 새로 제작/완성했다는 뜻이 아니다. 과거 14종 native evidence와 정확한 원본 목록은 [이전 원화 감사](../pio-artwork-final-2026-10-24/artwork/README.md)를 재사용한다. 여기서 14종 전체 홈/휴가 runtime를 새로 촬영하지 않았다.

| Outfit | 이번 새 cloud eye art | 이번 새 독립 hands/torso | 이번 새 tablet | Vacation 낮/밤 |
|---|---|---|---|---|
| basic | clean face + open/closed + brows; half source-only | V2 genuine torso + 의상별 sleeve/hand pair; Mac/iOS component appearance PASS | complete tablet 공유/재등록; shared hold 접촉 PASS | 기존 flattened |
| cherryBlossom | 기존 | V2 genuine torso + 의상별 sleeve/hand pair; Mac/iOS component appearance PASS | complete tablet 공유/재등록; shared hold 접촉 PASS | 기존 flattened |
| summerVacation | 기존; opaque sunglasses 제한 유지 | V2 genuine torso + 의상별 sleeve/hand pair; Mac/iOS component appearance PASS | complete tablet 공유/재등록; shared hold 접촉 PASS | 기존 flattened |
| autumn | 기존 | V2 genuine torso + 의상별 sleeve/hand pair; Mac/iOS component appearance PASS | complete tablet 공유/재등록; shared hold 접촉 PASS | 기존 flattened |
| winter | 기존 | V2 genuine torso + 의상별 sleeve/hand pair; Mac/iOS component appearance PASS | complete tablet 공유/재등록; shared hold 접촉 PASS | 기존 flattened |
| halloween | 기존 | V2 genuine torso + 의상별 sleeve/hand pair; Mac/iOS component appearance PASS | complete tablet 공유/재등록; shared hold 접촉 PASS | 기존 flattened |
| christmas | 기존 8개 genuine eye/lid/half/brow 그대로 재사용 | V2 genuine torso + 의상별 sleeve/hand pair; Mac/iOS component appearance PASS | complete tablet 공유/재등록; shared hold 접촉 PASS | 기존 flattened |
| hanbok | 기존 그대로 재사용 | V2 genuine torso + 의상별 sleeve/hand pair; Mac/iOS component appearance PASS | complete tablet 공유/재등록; shared hold 접촉 PASS | 기존 flattened |
| cafe | 기존 | V2 genuine torso + 의상별 sleeve/hand pair; Mac/iOS component appearance PASS | complete tablet 공유/재등록; shared hold 접촉 PASS | 기존 flattened; coffee |
| student | 기존 | V2 genuine torso + 의상별 sleeve/hand pair; Mac/iOS component appearance PASS | complete tablet 공유/재등록; shared hold 접촉 PASS | 기존 flattened; book+juice |
| fitness | 기존 | V2 genuine torso + 의상별 sleeve/hand pair; Mac/iOS component appearance PASS | complete tablet 공유/재등록; shared hold 접촉 PASS | 기존 flattened; weights+juice |
| rainyDay | 기존 | V2 genuine torso + 의상별 sleeve/hand pair; Mac/iOS component appearance PASS | complete tablet 공유/재등록; shared hold 접촉 PASS | 기존 flattened; closed umbrella+juice |
| pajamas | 기존 | V2 genuine torso + 의상별 sleeve/hand pair; Mac/iOS component appearance PASS | complete tablet 공유/재등록; shared hold 접촉 PASS | 기존 flattened; pillow/no drink |
| astronaut | 기존 eyes + visor 그대로 재사용 | V2 genuine torso + 의상별 sleeve/hand pair; Mac/iOS component appearance PASS | complete tablet 공유/재등록; shared hold 접촉 PASS | 기존 v2 flattened; closed visor/no drink |

## 파일·좌표·안전 동작

- [14종 최종 runtime 좌표](cloud-final-registrations.json)는 catalog에서 직접 읽은 canvas/asset/sampler/target rect/pivot/z/holdGroup을 그대로 기록한다. 모든 실제 제작자의 shoulder root 승인이 존재하는 것은 아니므로, 새 joint 좌표는 측정·provisional 등록값으로 구분했다. 큰 회전이나 손 떼기 동작의 안전 범위를 뜻하지 않는다.
- [Basic provenance](../../../output/pio-independent-2026-10-24/basic-cloud/provenance.json): 기존/생성 source, 실제 크기, alpha bbox, SHA, app copy 경로. [정확한 worker prompt](../../../output/pio-independent-2026-10-24/basic-cloud/PROMPTS.md), [root의 normalized 실제 prompt](ROOT-GENERATION.md).
- [Basic V1 registration](../../../output/pio-independent-2026-10-24/basic-cloud/registration-v1.json): canvas 1254×1254. 원래 눈 dark bbox Left(444,695)-(544,797), Right(755,695)-(854,797). 새 slot 중심 Left(494,746), Right(805,746). 눈/닫힌 lid는 고정 geometry에서 opacity만 one-hot으로 교체한다. 눈 자체를 찌그러뜨려 감긴 눈처럼 보이게 하지 않는다.
- [Basic V2 registration](../../../output/pio-independent-2026-10-24/basic-cloud/registration-v2.json): 진짜 팔·tablet hold pivot(650,1000), 설계 범위 ±1.5°. 팔/태블릿 세 부품만 hold group에 들어가며 몸통·눈·앞발은 독립. 앞발 pivot Left(443,1120), Right(836,1120), z20/21. 원래 visible toe bbox에 맞춰 등록했다. 추정 shoulder 좌표 Left(270,850), Right(1000,850)는 제작 승인된 anatomical root가 아니며 seam QA 대상이다.
- [Christmas V2 registration](../../../output/pio-independent-2026-10-24/christmas-cloud/registration-v2.json): pivot(676,935), 설계 범위 ±1.5°. Tablet의 목표 visible bbox는 원본 green 영역(498,808)-(854,1050). 추정 shoulder Left(350,865), Right(1000,865)는 승인 전 값이다. 기존 eye part source/좌표는 그대로 사용한다.
- 부모/가림: torso → eyes/lids/brows → held tablet → front hands/cuffs → 앞발. 실제 runtime group은 팔·손 접촉이 유지되도록 함께 움직인다. 손을 떼고 흔드는 동작이나 손가락/관절별 완성으로 표현하지 않는다.

Pair PNG는 두 개의 실제 눈/팔/발이 들어 있는 투명 atlas다. 두 독립 CALayer가 각각의 정규화 contentsRect를 샘플링한다. **개별 PNG 한 장에 부품 하나만 들어 있다고 허위 표시하지 않는다.** Sampler는 원본 좌상단 기준이며 Mac의 반대 Y 방향은 renderer가 변환한다. 원화 이미지를 재인코딩·확대 crop한 것이 아니다.

## 증거 및 실패 이력

1. 첫 Mac V1은 opacity assertion이 PASS였지만 눈 sampler의 Y 방향이 틀려 눈이 보이지 않았다. `native/mac-eyes-v1/` 실패 이미지는 보존했다.
2. `native/mac-eyes-v1-samplerfixed/`의 실제 open/closed/걱정 표정과 64/220 light/dark를 열어 확인했다. 부드러운 인상, 원본 glossy-eye material, 얼굴·손·태블릿·발 비율이 유지됐다. 이어서 `native/ios-eyes-v1-attachments/manifest.json`이 식별하는 실제 UIKit 220pt light open/closed, 64pt dark open/closed도 열어 같은 질감을 확인했다. 이 범위의 Mac/iOS V1 eye appearance gate는 PASS다. 이는 DEBUG candidate component 렌더이며 Release 전체 cloud 화면 E2E 검증과는 구분한다.
3. 첫 V2 sampler 교정본은 hold group이 torso보다 먼저 삽입되어 render(in:)에서 손/태블릿이 가려졌다. `native/mac-hands-v2-samplerfixed/`는 원화 품질 승인 증거로 사용하지 않는다. 삽입 순서 교정 후 `native/mac-hands-v2-painterfixed/`에서 실제 손과 tablet이 보이며 ±1.5° 동작을 확인했다. 실제 positive 관측 0.02617994rad, negative -0.02614332rad(약 ±1.5°). 단, 앞발 안쪽이 tablet에 가려져 새 foreground foot pair를 추가했다.
4. `native/mac-hands-v2-feet-final/`의 실제 220pt light open/±hold, 220pt dark closed, 64pt light open/dark closed를 확인했다. 앞발이 tablet 앞에 자연스럽게 보이며 이 크기에서 뚜렷한 double-toe나 붙여넣은 발 경계는 보이지 않았다. 어깨와 손·tablet 접촉이 ±1.5°에서 유지되고 귀여운 비율도 보존됐다. **Basic V2 Mac pilot appearance PASS**.
5. `native/mac-christmas-v2-final/`의 같은 6개 크기·동작 조합을 확인했다. 실제 red-coat torso/sleeves/tablet이 보이고 cuffs/어깨 root와 손·tablet 접촉이 유지됐다. 얼굴·모자·새싹·코트·발 비율에서 뚜렷한 seam/clipping/과도한 부피를 보지 못했다. **Christmas V2 Mac pilot appearance PASS**. Hat/sprout은 torso에 baked된 상태이므로 독립 headwear 완료로 표현하지 않는다.

6. 이어서 `native/ios-basic-v2-final/`에서 실제 UIKit 220pt light open/negative hold/dark closed, `native/ios-christmas-v2-final/`에서 220pt light open/positive hold 및 64pt dark closed도 열어 확인했다. Mac과 같은 원화·크기·가림 및 자연스러운 접촉을 보였고 sampler 방향/뚜렷한 seam/clipping 문제는 보지 못했다. **검토한 6개 iOS V2 component frame appearance PASS**.

Historical initial checkpoint: **Basic V1 eye material Mac/iOS PASS, Basic/Christmas V2 held-pose Mac/iOS pilot appearance PASS**. 최종14종 추가 checkpoint는 아래 절을 참조한다. 최종 사용자 시각 승인, Release V2, free-hand release/per-arm joint choreography를 의미하지 않는다. 전체 테스트/Release/iPhone/CPU·메모리 결과는 root의 RESULTS.md와 분리하여 보고한다. 이 원화 문서에서 실행하지 않은 검증을 PASS로 올리지 않는다.

Subsequent work: 14종 모두 generic V2 catalog 등록을 완료했다. Hanbok과 Cherry의 첫 sleeve에는 불필요한 collar/cape flaps가 있어 rejected 폴더에 보존하고 genuine artwork 편집으로 고쳤다. Astronaut 첫1388×1133 atlas는 front mitten이 작고 기존 hip padding과 겹쳐 팔이 중복돼 보이는 후보여서 미승격했고, 새1254² compact sleeve/mitten source로 수정했다. 원래 side/hip padding을 무조건 새 ghost arm으로 오인해 제거하지 않았다. 기존 visor 원화는 바꾸지 않고 z9로 눈 위/태블릿 아래에 배치했다. 최종 수정본 native gate는 별도 기록한다. 정확한 경로·SHA·prompt는 각 `output/pio-independent-2026-10-24/<outfit>-cloud/`의 provenance/registration/PROMPTS JSON에 있다.

## 소스 검증 및 실제 해상도 예산

[worker-art-validation.json](worker-art-validation.json)은 Hanbok/Astronaut/Cherry/Autumn/Winter의 새10개 PNG가 실제1254² RGBA이고 alpha0..255, source/catalog SHA동일, sampler bounds 유효, runtime dataset과 문서 manifest 일치함을 확인한다. 재인코딩/확대 crop은 하지 않았다. 새 torso+arm atlas의 비압축 RGBA 예산은 의상당12.0MiB(1254²×4×2)이며 native sampler는 두 팔용 한 atlas를 공유한다. 눈/태블릿은 기존 source를 재사용한다. 14종 동시 decode나 전체 GPU메모리 안정성을 이 소스 검증만으로 PASS 처리하지 않는다. UI sprite이므로 mipmap/3D LOD 체인은 해당하지 않는다. 실제 cache/CPU/memory는 runtime 보고서 범위로 따로 확인한다.

## 최종 추가 native appearance checkpoint

- CherryBlossom/Autumn/Winter/refined Astronaut: [worker-final-visual-review.json](worker-final-visual-review.json)에 실제로 열어본 28개 파일 경로를 기록했다. `native/mac-expansion-batch/`에서 각 220pt light open, 220pt dark negative hold, 64pt light positive hold, 64pt dark closed (16개), `native/ios-expansion-batch/`에서 각 220pt light positive hold, 220pt dark negative hold, 64pt dark closed (12개). 이 범위의 귀여운 원래 비율/의상 재질, cuff/shoulder 연결, 태블릿 접촉, 투명 경계에서 뚜렷한 결함을 보지 못했다. **4종 Mac/iOS component appearance PASS**.
- Astronaut actual observations JSON은 armLeft/right 모두 `pio_cloud_astronaut_v2_armPairCompact`와 의도한 target rect를 기록한다. 초기 long atlas의 작은 mitten 문제는 새 원화로 해결됐으며, 기존 hip padding은 원본에도 있는 승인 디자인이므로 유지했다. Visor는 눈 위/태블릿 뒤에 정상적으로 보인다.
- Hanbok: 이전 Mac220 open/closed/±hold에 이어 iOS220light positive hold와64darkclosed를 열어 soft floral sleeve/cuff와 태블릿 접촉을 확인했다. Café도 Mac220lightopen/iOS220darknegative에서 original brown beret/white sleeve/green apron 디자인과 접촉이 일치했다.
- Parent independent review: Student/Fitness/RainyDay 각 Mac220lightnegative,64darkclosed 및 iOS220darkpositive, 총9개 실제PNG에서 open-gap 없는 소매/손·tablet 접촉, 앞발, Student glasses, 귀여운 비율을 확인했다. 이 문서는 해당 담당자 관측을 출처로 삼으며 같은 파일을 이 작성자가 다시 모두 열었다고 주장하지 않는다.

이 checkpoint는 native component source/registration 검토다. 전체 화면 workflow, 구매/ownership, production data, Release V2 활성화, 사용자 최종 시각 승인은 검증 범위에 포함하지 않는다. 실제 관측된 held group 범위는 ±1.5°이며, 이를 큰 wing wave나 독립 손 떼기 동작으로 확대 해석하지 않는다.

- Scene review 담당자는 SummerVacation/Halloween/Pajamas의 최종 Mac+iOS `native/{mac,ios}-expansion-batch/` 실제24PNG(각220lightopen,220darkpositive/negativehold,64lightclosed)를 열어 확인했다. ±1.5° 범위에서 shoulder gap, hand/tablet 분리, feet/hat/sprout clipping을 보지 못했고 원래 의상 인상을 유지했다. **3종 scoped native appearance PASS**. SummerVacation의 opaque sunglasses는 원래 optics를 유지하며 눈깜빡임을 가리므로 visible blink는 **N/A/OCCLUDED**이며 PASS로 기재하지 않는다.

**최종 원화 checkpoint: 14종 모두 실제 새 torso/의상별 hand atlas와 shared complete tablet을 가진 DEBUG 후보가 등록됐고, 담당자별로 Mac/iOS64/220 light/dark actual component appearance를 검토했다.** 이 좁은 appearance gate는 PASS다. 6개 전체 작업 blocker는 상단과 같이 cloud3개 PARTIAL / vacation3개 BLOCKED_ASSET로 유지한다. 남은 cloud 조건은 Release V2 활성화·전체 화면 통합 승인, freehand release/per-arm choreography, Basic half source 통합이며, vacation은 실제 새 필수 부품이 없다. 승인 원화를 보존했다는 것은 원래 파일을 덮어쓰지 않았다는 뜻이고 새 숨은 torso의 픽셀이 과거 원본을 정확히 복구했다는 뜻은 아니다.
