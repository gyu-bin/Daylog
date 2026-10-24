from pathlib import Path
import json
q=Path(__file__).parent
rows=[]
for f in sorted(q.glob('performance-*.json')):
 r=json.loads(f.read_text());rows.append(r)
s='''# Phase2.2 CPU·메모리 결과

판정: 통제한 DEBUG 파일럿의 단기 측정 완료. 성능 종합 PASS, 장시간 무누수, 실기기 배터리/FPS 보증은 하지 않는다.

같은 진단 루트, 캐릭터 한 개220pt, light, 모든 파일럿55개 이미지를 미리 준비한 조건이다. Mac1040×900창, 전용iPhone17/iOS27시뮬레이터를 사용했다. 각 실행3초 대기 후1초 간격의 프로세스 누적CPU시간과RSS를 읽었다. 기본20초, 전환35초. 측정 중 우리 도구의 캡처·녹화는 없었다. 기기는 다른 작업과 공유되었으며 전체 시스템 부하/창의 가림 여부는 완전히 통제되지 않았다. 100%는CPU코어 하나다. GPU·WindowServer·렌더서버 비용은 포함하지 않는다.

| 플랫폼·조건 | 측정초 | 평균CPU | 최대1초구간CPU | RSS MiB |
|---|---:|---:|---:|---:|
'''
for r in rows:
 lo,hi=r['rssMiBRange'];s+=f"|{r['case']}|{r['seconds']:.1f}|{r['meanCPUPercent']:.3f}%|{r['maxIntervalCPUPercent']:.3f}%|{lo:.2f}–{hi:.2f}|\n"
s+='''
## 해석과 제한

- iOS flat-static은 처음3개 측정구간에서70.1/134.2/34.7%, 마지막구간23.8%를 기록했다. layered-static도 첫구간37.5%였다. 따라서3초 대기가 모든 실행의 초기 작업을 제거하지 못했으며, 이 두 행을 안정상태의 애니메이션 비용과 직접 비교해 성능 개선이라고 해석하지 않는다. 반복 디코딩이나 리그 자체가 이 스파이크의 원인이라는 증거는 없다. 원인 확정에는 재현 시CPU프로파일이 필요하다.
- iOS 동작 표본의 평균은0.000–0.098%, 전환은1.016%였다.0은 샘플 시간 해상도에서 증가가 없었다는 뜻이다. 정지 이미지의 큰 초기 비용이 오히려 더 높았으므로 동작 유무만으로 첫 실행 비용을 설명할 수 없다.
- Mac 의상·기본idle/jump/flap 표본 평균0.049–0.393%,30회 전환1.300%. 실제 전환 후31configurations,32hostUpdates,activeRigs1,liveRigs1,sourceLoads55/cache55를 확인했다. 눈만=6tracks/body0, 양날개=2/body0, 걷기=feet4/body0, 점프=body1, 착지=body2였다.
- 같은Mac PID80240에서30회 전환 후 뷰 제거시liveRigs0/activeTracks0. 제거 뒤20.5초 평균CPU0.049%,RSS43.94–74.48MiB. 실제스크롤화면밖은 별도표본에서liveRigs1/activeTracks0, 화면복귀시6눈tracks 재개했다.
- iOS30회 전환 후에도liveRigs1/cache55/sourceLoads55,configurations31을 확인했다. RSS첫/마지막414.91→379.25MiB,범위378.73–425.95MiB. Mac전환113.56→81.64MiB. 짧은 관찰에서 누적증가 증거는 없었으나 RSS는 압축/회수 영향이 있어 차이를 절감량으로 해석하지 않는다.
- 캐시의 decodedBytes56,144,964(약53.54MiB)는 리그가 보관한CGImage 버퍼 크기 합계이며 앱 전체메모리가 아니다. sourceLoads는 성공한소스조회계수로 물리적 PNG디코더 호출수는 아니다.55이미지 선로딩은 비교조건을 같게 만든진단화면 동작이다.
- iPhone 실제스크롤화면밖은 DeviceHub의 다른 시뮬레이터 전환과 겹쳐최종계측을 못했다. Mac스크롤및두플랫폼OS Reduce Motion 기존유효증거를 재사용했다. 이를iPhone스크롤PASS로 확대하지 않는다.

## 이전16.08%와 비교

Phase2.1/PERFORMANCE.md의 조사와 원시증거를 재사용했다. 당시16.08%는다른화면조건이며 재현조사에서확정병목이없었다. 이번도16.08%→0.05%최적화라고주장하지않는다. 이번변경은진짜레이어아트와공유CoreAnimation리그추가다. CPU전후개선율은미확정이다.

추가필요: 초기작업완료후동일조건반복측정, 실제기기/Release/GPU/열/장시간메모리프로파일. 원시수치는performance-*.json에 모두 보존했다.
'''
(q/'PERFORMANCE.md').write_text(s)
(q/'RESULTS.md').write_text('''# 피오 의상 Phase2.2 — 시각 검토용 결과

기본 피오와 크리스마스·한복·우주복의 독립 부품 리그를 DEBUG 검토 화면에 구현했다. 13종 원화는 보존했다. 전체 상점/대시보드 교체나 성장1–4단계 대응 완료가 아니다. 최종 시각 승인은 사용자 검토를 기다린다.

## 만들어진 것

- 투명1254×1254 공통좌표 부품51개: 기본12,크리스마스13,한복12,우주복14. 실제 native raster artwork를 재구성했다. 원화의 작은 시트 조각 확대나 단순도형 대체가 아니다. 실제 생성 원본 크기는1254²,1319×1192,1536×1024등이며1536²라고 과장하지 않는다.
- 깨끗한눈없는몸/얼굴,open·half·closed눈,좌우날개/손,새싹/모자,발과 숨은연결뿌리. 크리스마스선물,한복소매,우주복헬멧·실제투명바이저를 독립PNG로 보존했다.
- 눈깜빡임,한쪽날개인사,양날개펄럭임,제자리발걸음,작은점프,착지,기뻐하기,장식/소품동작,숨쉬기. 몸 전체 움직임은 점프/숨쉬기 등에만 쓰며 눈/날개독립모드의 몸통과상위레이어는고정된다.
- 크리스마스 왼손+선물은 실제공유부모로 함께움직인다. 한복소매와우주복장갑은각각다른회전축으로움직인다. 우주복눈은투명바이저뒤에있고헬멧은얼굴과함께고정된다.

## 실제 검증

| 항목 | 결과/증거 |
|---|---|
| Mac / iPhone Simulator Debug빌드 | mac-build-final.log / ios-build-final.log: BUILD SUCCEEDED |
| 집중테스트 | focused-tests-final.log: PioLayeredRigTests5개PASS; 독립축·3상태눈·정지/재개·공유그립·캐시/해제 |
| 독립코드/패킹검토 | code-review.md;51부품의해시/좌표/알파/패킹검증,수정필요코드문제없음 |
| 세의상64/220pt·light/dark | 실제앱runtime/final-*화면,정적원본/조립비교registered; Mac한복220light와iOS한복220light는after-30-switches화면 |
| 독립눈 | 새크리스마스8초실제영상및frame100/103/105/108: open→closed→half,몸/선물/모자고정; Mac눈6tracks/body0 |
| 독립날개 | 한복·우주복8초실제영상,0–3.5초8샘플접합검토. 몸과얼굴고정,팔각도만변함. 샘플에서노출된뿌리/틈없음 |
| 걷기·소품 | iOS실제presentation JSON두표본: 발의회전/높이만변함; attachment는모자회전과leftGrip위치만변하고선물/손로컬관계유지 |
| 점프·착지·기뻐하기 | 실제Mac/iOS선택화면및track계측; 모든프레임의전수검사나모든의상×모드전체조합을인증하지않음 |
| Reduce Motion | 같은공유lifecycle코드의기존Mac/iOS실제OS설정ON→tracks0/OFF원복증거재사용;최종집중테스트도정지/재개PASS |
| 반복전환·화면밖 | 두플랫폼30회전환후리그1/캐시55유지. Mac실제스크롤0tracks→복귀재개,뷰제거리그0 |
| CPU·메모리 | PERFORMANCE.md및전체원시JSON;초기iOS스파이크포함,종합PASS아님 |

iPhone추가스크롤검증중다른시뮬레이터화면전환이겹쳤으므로해당검증은미완료다. 다른앱이찍힌무효캡처는이패키지에포함하지않았다. 화면명/JSON조건은실제선택값으로검증했다.

## 남은 제한

1. 성장1–4단계:기존네단계녹색원화는각각다르지만정면청결몸체·네단계날개/새싹·의상부착좌표가없다. 현재네리그는각각한체형이며모든manifest는supportsGrowthStages=false다. 기존Lv1–9/10–24/25–49/50+계산은변경하지않았다. 상세누락은growth-stage-readiness.md.
2. 나머지10종:원본보존,독립부품미제작/미지원. 확장하지않았다.
3. 크리스마스모자+새싹+방울은하나의부품이다. 한복옷감/꽃/술,우주복버튼/호스/부츠소매는몸체에남아있다. 각각의재질변형이나물리시뮬레이션은없다.
4. 재구성은픽셀동일복원이아니다. 우주복팔은원본보다조금길고눈이조금둥글다. 기본피오새싹/발의시점에도작은차이가있다. 비교이미지로최종귀여움·정체성승인이필요하다. 헬멧과바이저는별도파일이지만얼굴위에서따로흔들지않는다.
5. 현재격리DEBUG검토경로다. 기존상점·대시보드의평면의상을자동교체하지않았다. 단계별부착검증이끝나기전전체성장호환을주장하지않는다.
6. 실기기/Release/FPS/GPU/배터리/장시간메모리와iPhone스크롤정지는추가검증대상이다.16.08%보고의정확한병목은미확정이다.

## 보존과 산출물

baseline554파일중의도된기존수정은RootView DEBUG분기와pbx Release에셋제외2파일뿐이다. 그외기존변경과원본의상14PNG(13종+기본)는동일해시. 새부품/리그/검토자료만추가했다. SwiftData·CloudKit·구매·배포앱을수정하지않았고커밋/푸시/배포하지않았다. HEAD는702e611aa1a95323bb1a78e27772d583972c383a그대로다.

- review.html:원본/조립비교및대표영상.
- selected-assets.json:51개선택부품/해시/출처.
- RIGGING.md:좌표/부모관계/제한.
- generation-prompts.json:built-in image_gen편집생성의전체프롬프트·실제출력출처. 원본을참조해재구성했고원본파일은보존했다.
- runtime/preview-*-8s.mp4:실제iPhone녹화의1–9초무속도변경발췌. 출력30fps는앱FPS측정치가아니다.
- runtime/preview-*-contact.png:실제영상추출프레임의비교,정적합성으로움직임을꾸민자료가아니다.
- Pio-Outfit-Phase2.2-Review.zip:선택부품·생성출처·비교·실제영상·검토/계측/빌드/테스트결과.
''')
html=(q/'review.html').read_text();html=html.replace('</html>',''.join(f'<article><h2>{title} 실제 움직임</h2><video controls loop muted playsinline src="runtime/preview-{key}-8s.mp4"></video></article>' for title,key in [('크리스마스 깜빡임','christmas-blink'),('한복 소매','hanbok-flap'),('우주복 장갑','astronaut-flap')])+'</html>');(q/'review.html').write_text(html)
print('Final reports written')
