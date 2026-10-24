# 분리 원화 준비 목록 — BLOCKED_ASSET

기존 cloud 등록 PNG/registration.json과 vacation manifest를 다시 확인했다. 기존 723개 파일 및 휴가 26장 원본은 수정하지 않는다. 아래 항목은 도형·복제·확대 crop으로 완성 처리하지 않는다.

| 장면·대상 | 부족한 실제 레이어 | 권장 캔버스 | 연결 위치 |
|---|---|---|---|
| 클라우드 기본 피오 대기/실패 | 눈이 제거된 clean seated body, 좌우 open/half/closed eyes, worried brows, 기존 태블릿 자세 보존 | 기존 유료 cloud와 같은 1254×1254 RGBA | PioCloudSceneResources / PioCloudCharacterRig |
| 클라우드 유료 13종 | 손 뒤 복원된 torso/소매, 좌우 손과 어깨 hidden roots, 독립 tablet, tablet 앞/뒤 손 가림 레이어 | 현재 cloud 원본과 같은1254×1254 RGBA | PioCloudCharacterRig body/hand/tablet attachment subtree |
| 휴가 기본+유료13종 낮/밤 | clean face/torso, 좌우 eyes/eyelids, 분리 손+팔 hidden roots, 각 의상에 실제 있는 소품, 앞/뒤 해먹·줄 | 원본과 같은1024×1536 RGBA, 낮/밤 대응정렬 | RoutimoriVacationRig의 foreground를 전후 occlusion/character subtree로 연결 |
| 휴가 해먹 고정 | 양쪽 매듭 및 고정된 줄, 움직이는 천, 뒤쪽 복원영역 | 1024×1536 RGBA | PioVacationSceneResources registration + RoutimoriVacationRig |

유료13종: cherryBlossom, summerVacation, autumn, winter, halloween, christmas, hanbok, cafe, student, fitness, rainyDay, pajamas, astronaut. 기본은 basic이다. 모든 의상에 음료를 추가하지 않는다. 특히 astronaut v2의 닫힌 바이저와 음료 없음은 유지한다.

## 좌표와 레이어 제작 기준

- 원점은 원본 좌상단, x는 오른쪽, y는 아래쪽. 부품별 tight crop을 하지 않고 같은 전체 캔버스를 유지한다. 파일마다 sourceSize, part ID, parent ID, pivot(x,y), z-order, visible bounds를 JSON으로 함께 제공한다.
- 눈 pivot은 승인 원본의 실제 눈 중심, 손 pivot은 복원된 실제 어깨 관절, 소품 pivot은 손의 실제 접촉점이다. 소품은 손과 같은 부모 관절에 묶고 별도 몸통 회전을 중복 적용하지 않는다. 숫자는 그림별 측정 후 확정하며 임의의 공통 값으로 제작 승인을 대체하지 않는다.
- 낮/밤은 동일한 관절·가림 순서를 유지하되 기존 빛과 그림자에 맞는 원화를 제공한다. 잘린 경계를 확대해서 hidden roots라고 부르지 않는다.
- 투명 RGBA, 원본 질감/털 경계/그림자 유지. 최소 회전 양끝에서 드러나는 몸통·손·천 뒤를 실제로 복원해야 한다.
- 기존 휴가 후보의 임시 pivot은 day(968,500), night(58,225), focus day(512,820)/night(512,870)이다. 이는 제작 확정값이 아니다. 원래 Basic day pivot(968,484), night(68,465)도 별도 승인 원본 기준이다.
- 양쪽 고정된 줄을 포함하는 하나의 이미지를 회전하면 두 매듭을 동시에 고정할 수 없다. 각 줄/천 분리 또는 검증된 변형 리그가 있어야 완전한 결합을 보장할 수 있다. 기존 ±0.55° 후보 흔들림을 유지한 상태는 정확한 양쪽 매듭 고정 PASS가 아니다.

## 확인 후 승인 조건

14종 각각 낮/밤의 중립·양끝·전환 중간 프레임, 눈 open/closed, 팔 이동 및 소품 접촉을 확인한다. 클라우드는 대기/실패 seated와 완료 standing을 구분한다. 64/220pt, light/dark, 화면 경계·매듭·손 가림을 실제 네이티브 렌더러에서 확인한 뒤에만 BLOCKED_ASSET을 해제한다.

현재 독립 눈·손·음료 및 정확한 양쪽 매듭 고정의 미지원 범위는 BLOCKED_ASSET이다. 기존 원화만으로 가능한 전체 foreground 흔들림과 이미 분리된 유료 cloud 눈 동작은 계속 사용한다.
