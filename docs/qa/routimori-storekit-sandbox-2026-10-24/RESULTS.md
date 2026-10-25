# RESULTS — GitHub 체크포인트와 StoreKit Sandbox 출시 준비 (2026-10-24)

| 영역 | 판정 |
|---|---|
| GitHub 백업 | **PASS** |
| StoreKit Sandbox | **PARTIAL** — 실제 Apple 서버의 상품 13종 조회 성공. 구매·취소·복원·환불·재실행은 Sandbox 계정이 없어 NOT_TESTED |
| 출시 준비 | **준비 안 됨** — P0 4건(RELEASE-BLOCKERS.md) |

## 1. GitHub 백업

| 항목 | 결과 |
|---|---|
| 브랜치 | `backup/routimori-release-prep-20261024` (새 이름. 이전 `backup/routimori-pio-20261024`는 그대로) |
| 커밋 | `727030b9b6c873364e1acf546288ec468fa72490`, 부모 `f48105a`(이전 백업에 이어 붙임). 이 문서와 이후 수정은 같은 브랜치의 다음 커밋으로 추가 |
| 방법 | 임시 Git 인덱스(`read-tree HEAD` → 추적 변경 69개 반영 → 선별한 미추적 4,450개 추가) → `commit-tree` → 브랜치만 push. 작업 폴더·main·다른 브랜치 불변, force push 없음 |
| 내용 | 이전 백업 대비 추가 128 / 수정 34 / 삭제 4(옛 나뭇잎 아이콘). 전체 5,481개 파일 |
| 대조 | 백업 트리 5,481개가 작업 트리와 바이트 단위로 같음(한글 파일 이름 1건은 표기 차이). 빌드에 필요한 미추적 파일 누락 0 |
| 원격 확인 | `git ls-remote`·GitHub API로 커밋과 트리 파일 수(5,481, 잘림 없음) 확인 |
| 독립 빌드 | 백업 커밋을 별도 작업 공간에 꺼내 macOS·iOS Simulator 빌드 모두 성공(작업 공간과 빌드 산출물은 삭제) |
| 민감정보 | 키·토큰·인증서·계정 이메일 없음. 새로 공개되는 파일에 로컬 사용자 경로 0. 빌드 로그 1건은 경로 문자열 오탐(이전 백업에도 있던 파일) |
| 제외(로컬에만) | QA 이미지 원본 2.2GB, 렌더 0.8GB, 영상·zip 0.2GB, 95MB 초과 1개, 캐시 |

## 2. StoreKit 조사와 수정

- **구현은 검증된 거래만 권한으로 인정한다.** 영수증 환경·번들 ID·비소모품·등록된 제품 ID를 확인하고, 환불·업그레이드된 거래는 회수한다. 이 정책은 그대로 두었다.
- **일반 빌드에서 구매가 꺼져 있다.** Info.plist에 구매 환경 키가 없다. 현재 소스는 이때 유료 의상을 잠근다. 이전 배포본은 모두 무료로 입혀 줬다 → P0.
- **실제 Apple 조회:** 로컬 설정을 쓴 적 없는 iPad mini 시뮬레이터에서 13종이 모두 돌아왔다.
  - 비소모품, 한국어 이름, 미국 스토어프론트 $1.99
  - 로컬 파일에는 KOR·₩2,500만 있으므로 Apple 서버 값이다
  - 한국 가격은 한국 Sandbox 계정으로 다시 확인해야 한다
- **함정 확인:** 예전에 로컬 StoreKit 설정으로 실행한 시뮬레이터는 일반 빌드도 로컬 값을 쓴다(영수증 환경 `Xcode`). 이 결과는 Sandbox로 세지 않았다.
- **수정(UX, 정책 불변):** Sandbox 빌드에서 계정이 없으면 원인과 다른 "네트워크 확인" 문구가 목록 맨 아래에 두 번 나왔다. 이를 바꿨다.
  - 계정 로그인 안내를 구매 단추 바로 아래에 한 번 보인다.
  - [상품 정보 다시 불러오기]를 같은 자리에 둔다.
  - 단위 테스트를 추가했다.
- **Sandbox 준비:**
  - `Tools/pio-storekit/run-sandbox-sim.sh`: 일반 설정을 바꾸지 않는 Sandbox 전용 시뮬레이터 빌드
  - Debug 전용 읽기 진단 `storeProbe`
  - 시뮬레이터의 "샌드박스 Apple 계정" 메뉴 확인
- **개인 iPhone 14 Pro는 쓰지 않았다.** 같은 번들 ID의 개발 빌드를 설치하면 설치된 RoutiMori와 데이터를 덮어쓴다.

## 3. 빌드·테스트 (이번에 실제로 실행한 것)

| 항목 | 결과 |
|---|---|
| macOS 빌드 / iOS Simulator 빌드 | PASS / PASS |
| 백업 스냅샷 단독 빌드(macOS·iOS) | PASS |
| Sandbox 전용 iOS Simulator 빌드 | PASS(일반 Info.plist·프로젝트 해시 불변) |
| Mac 전체 단위 테스트(StoreKit 문구 수정 후) | 848개: 통과 760 / 실패 0 / 건너뜀 88 |
| `PioPurchaseTests`(구매 관리자 단위, 새 테스트 포함) | 30개 PASS |
| 큰 글자 폭 검사(iOS) | 3개 PASS |
| `PioStoreKitIntegrationTests`(로컬 StoreKit, 단독 3회) | 매번 7 PASS / 4 FAIL / 0 SKIP |
| 실제 Sandbox 조회(Apple 서버) | 13/13 반환 |
| 실제 Sandbox 구매·취소·대기·복원·환불·재실행 | NOT_TESTED |
| 실기기 개발 빌드 | NOT_TESTED(개인 기기 보호) |

이전 기준선(Mac 759/0/88, 전체 iOS에서 StoreKit 3건 실패)과 이번 결과를 구분했다.
"3건 대 4건"의 차이는 전체 실행에서 "전체 의상 구매·unfinished" 테스트가 순서·부하에 따라 가끔 통과하기 때문이다. 단독 실행에서는 매번 4건이 실패한다.

## 4. 남은 위험

1. 배포 빌드의 구매가 꺼져 있다(P0). 켜는 순간 TestFlight에서도 Sandbox 구매가 열리고, 무료로 입던 사용자는 기본 피오로 돌아간다.
2. 실제 Sandbox 구매 흐름 전체가 미검증이다.
3. 환불 알림 누락(로컬, UNRESOLVED): 알림을 놓치면 다음 권한 재조회까지 소유가 남을 수 있다.
4. ASC 상품 13종 `MISSING_METADATA`, 그리고 "전용 앱 아이콘" 설명과 실제 제공 내용의 불일치.

## 5. 수정 파일

- `Daylog/Services/PioPurchaseManager.swift` — 계정 없음 오류 분류·문구(검증 정책 불변)
- `Daylog/Views/Wardrobe/PioWardrobeView.swift` — 구매 단추 옆 사유·다시 불러오기, 문구 중복 제거
- `Daylog/App/DebugScript.swift` — Debug 전용 `storeProbe`
- `DaylogTests/PioPurchaseTests.swift` — 단위 테스트 1개
- `Tools/pio-storekit/run-sandbox-sim.sh` — 새 스크립트

제품 ID, 구매·복원 로직, 사용자 데이터, 원화는 바꾸지 않았다. App Store Connect·TestFlight·배포·main 변경도 없다.

## 6. 산출물

- [PRODUCT-MATRIX.md](PRODUCT-MATRIX.md)
- [SANDBOX.md](SANDBOX.md) — 사용자가 할 일 포함
- [RELEASE-BLOCKERS.md](RELEASE-BLOCKERS.md) — Aside 작업 목록 포함
- [REVIEW.md](REVIEW.md)
- `evidence/`: 캡처 4장과 진단 출력 3개(계정 정보 없음)
