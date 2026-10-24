# RESULTS — RoutiMori 브랜드·아이콘 최종 정리와 남은 UI 결함 (2026-10-24)

**최종 판정: PARTIAL**

필수 변경은 모두 했고, 최신 소스로 다시 빌드한 앱에서 실제로 확인했다.
- Mac 사이드바의 Daylog 나뭇잎 아이콘 제거, 공식 피오 아이콘 적용
- Finder 이름 RoutiMori
- 다크 Dock 아이콘 정리
- iPad 사이드바 큰 글자 대응
- 피오 타이밍 테스트 안정화

PASS가 아닌 이유:
- Dock·메뉴 막대·위젯 갤러리는 화면 캡처로 확인하지 못했다(시스템 API로만 확인).
- VoiceOver 실제 탐색, iPad 좁은 창, 큰 iPhone, Mac 키보드 탐색은 NOT_TESTED.
- 공식 슬로건이 셋으로 갈려 있어 결정이 필요하다.
- 꺾쇠 접근성 크래시의 근본 원인은 SwiftUI 내부까지만 좁혔다(UNRESOLVED).

이번 작업의 완료와 App Store 출시 준비 완료는 별개다. 운영 Mac 앱·TestFlight에는 아직 반영되지 않았다(배포하지 않음).

## 1. 먼저 확인한 것: 결함이 최신 소스에도 있었는가

| 항목 | 설치된 운영 앱(1.5.10) | 최신 소스 빌드(작업 전) | 결론 |
|---|---|---|---|
| 사이드바 아이콘 | 나뭇잎 | 나뭇잎(`BrandIcon` 에셋이 옛 그림) | 최신에도 결함 → 수정 |
| Finder 이름 | Daylog | Daylog(현지화 이름이 Finder에 안 쓰임) | 최신에도 결함 → 수정 |
| 다크 외관의 Dock 아이콘 | 나뭇잎(다크) | 나뭇잎(다크) | 최신에도 결함 → 수정 |
| 사이드바 글자 "RoutiMori" | RoutiMori | RoutiMori | 이미 정상 |

## 2. 수정 내용

| 영역 | 내용 | 파일 |
|---|---|---|
| 브랜드 아이콘 | `BrandIcon`을 공식 앱 아이콘(`icon_ios_1024.png`와 같은 파일)으로 교체하고 둥근 사각형으로 잘라 그림. 옛 나뭇잎 라이트·다크 그림 삭제 | `Assets.xcassets/BrandIcon.imageset`, `SidebarView.swift` |
| 다크 Dock 아이콘 | 다크일 때 옛 나뭇잎을 걸던 동작 중지(공식 아이콘에 다크 변형 없음), 옛 에셋 삭제 | `AppearanceMode.swift`, `DockIconDark.imageset`(삭제) |
| Finder·Dock 이름 | `LSHasLocalizedDisplayName` 추가, Mac 기본 표시 이름을 파일 이름(`$(PRODUCT_NAME)`)과 맞춤 → 현지화 이름 RoutiMori가 쓰임. 번들 ID·파일 이름은 그대로 | `Config/Daylog-Info.plist`, `project.pbxproj`(Mac 2줄) |
| iPad 사이드바 큰 글자 (P1, 이전 R2) | 메뉴 글자·아이콘·줄 높이·머리말을 `@ScaledMetric`으로(기본 크기 그대로). 큰 글자에서 메뉴 이름 2줄 허용. 열 폭은 216pt에서 최대 288pt까지만 | `SidebarView.swift`, `RootView.swift` |
| iPad 시트 키보드 (새로 발견) | 시트에서 키보드를 열면 [완료]가 시트 안과 뒤 화면에 두 개 → 시트가 떠 있으면 뒤 화면 막대를 띄우지 않음 | `SheetChrome.swift`, `RootView.swift` |
| 정보 화면 큰 글자 (새로 발견) | AX5에서 44pt 아이콘이 커진 글자 사이에 끼어 작게 보임 → 큰 글자에서 아이콘을 위로, 64pt | `SettingsView.swift` |
| 온보딩 SE AX5 (P2, 이전 R6) | 단계 표시를 큰 글자에서 스크롤 안으로 옮겨 내용 자리 확보 | `OnboardingView.swift` |
| 피오 홈 타이밍 테스트 | 완료 예약을 주입할 수 있게 함(앱 기본값은 실제 시간 그대로). 테스트 2개는 예약된 길이(인사 2.8초·축하 2.6초)와 완료 시 상태 전이를 결정적으로 확인. 동작 길이·연출 변경 없음 | `PioHomeProductionCharacter.swift`, `PioHomeProductionTests.swift` |
| 테스트 갱신 | 브랜드 아이콘·Dock 아이콘 테스트를 새 사양으로(이전 테스트는 다크에서 어두운 나뭇잎을 기대) | `AppearanceModeTests.swift` |
| 새 회귀 검사 | 브랜드 문자열·Finder 이름·아이콘 구성 3개, iPad 사이드바 폭 1개 | `BrandConsistencyTests.swift`, `UIDynamicTypeLayoutTests.swift` |
| 옛 생성기 | 실행하면 공식 아이콘을 덮어쓴다는 경고 주석 | `Tools/GenerateIcons.swift` |

삭제한 옛 나뭇잎 아이콘 4개 파일은 Git(HEAD)과 백업 브랜치에 그대로 있다.

## 3. 접근성 크래시 조사 (홈 루틴 카드 그룹 머리말의 꺾쇠)

- **재현:** iOS와 macOS 모두 재현됐다. 꺾쇠에 `.accessibilityHidden(true)`를 다시 붙이면 홈을 여는 순간 `EXC_BAD_ACCESS`가 났다.
- **스택:** `RoutineCard.body`(RoutineCard.swift:81, `ForEach` 안의 `sectionView`) → `ViewBuilder.buildBlock` → SwiftUI `initializeWithCopy for Button` → `objc_retain`. SwiftUI가 단추 값을 복사하는 도중 잘못된 주소를 참조했다.
- **변형 시험:** 같은 꺾쇠를 별도 View 구조체로 빼서 그 안에서 숨기면 Mac에서는 죽지 않았다.
- **결론:** 앱 코드의 논리 오류가 아니라, 이 단추 라벨의 타입 구성에서 SwiftUI 내부 복사가 깨지는 문제로 보인다(OS·SDK 27).
  - 독립된 최소 재현 파일은 만들지 못해서 **원인은 UNRESOLVED**로 둔다.
  - 이 단추는 이미 `accessibilityLabel`("○○ 그룹, n개 중 m개 완료")을 갖고 있다. 그래서 꺾쇠가 VoiceOver에서 따로 읽히지 않으므로 숨김 처리 자체가 필요 없다. 안정적인 기존 구현을 그대로 두었다(HEAD와 같음).
- **다른 화면의 같은 처리(6곳):** 각 화면을 실제로 열어 크래시가 없는 것을 이전 작업에서 확인했다. 이번 실행 중 새 크래시 보고서도 없었다(재현 시험 2건 제외).

## 4. 피오 홈 타이밍 테스트 원인

- 앱은 동작이 끝나는 시각에 `Task.sleep(동작 길이)` 뒤 idle로 돌아간다. 테스트는 그 완료를 10ms 간격으로 실제 시간으로 기다렸다.
- 전체 테스트 실행에서는 메인 액터가 붐벼, 실제 완료가 기다리는 시간을 넘겨 늦게 일어났다. 동작 길이와는 무관하다.
  - 실패 내용: "displayedAction → .greet", "translation.x 애니메이션 nil"
  - 단독 실행에서는 통과했다.
- **애니메이션 결함이 아니라 테스트의 실제 시계 의존 문제**였다. 대기 시간을 늘리는 대신 완료 예약을 테스트가 직접 넘기도록 바꿨다. 덕분에 "어떤 길이로 예약되는지"와 "완료되면 무엇이 되는지"를 따로 검증한다.
- 같은 파일의 실시간 테스트 1개(`outfitSwitchCancelsOldDeadline…`)는 실제 시계 그대로 두었다. 이번 두 번의 전체 실행에서 통과했다.

## 5. 테스트 결과 (이번에 실제로 실행한 것만)

| 항목 | 결과 |
|---|---|
| macOS 빌드 | PASS |
| iOS 시뮬레이터 빌드 | PASS |
| Mac 전체 단위 테스트 1회차 | 847개: 통과 759 / 실패 0 / 건너뜀 88 |
| Mac 전체 단위 테스트 2회차(iOS 테스트와 동시 실행해 부하를 줌) | 847개: 통과 759 / 실패 0 / 건너뜀 88 |
| └ 피오 홈 타이밍 테스트 | 두 번 모두 PASS(이전에는 전체 실행에서 2건 실패) |
| 브랜드 문자열·Finder 이름·아이콘 구성 검사(새로 추가) | PASS. 옛 이름을 일부러 넣으면 실패하는 것도 확인 |
| iOS 전체 테스트(iPhone 17) | 91개: 통과 24 / 실패 3 / 건너뜀 64 |
| └ 실패 3건 | 기존 StoreKit 로컬 실패(구매 취소, 중단 구매, 환불). 관리 중인 4건 중 "전체 의상 구매"는 이번에 통과했지만, 간헐적이므로 해결됐다고 보지 않는다 |
| 큰 글자 폭 검사(iOS, SE) | 3개 PASS: iPhone 조각 25종, 넓은 홈 2종, iPad 사이드바 2종 × 글자 크기 5단계 |
| `PioStoreKitIsolationTests` 환경 변수 크래시 수정 | 보존됨. 전체 실행에서 크래시 없음 |
| 실제 화면 확인 | DEVICE-QA.md 참조 |

건너뜀(SKIP)은 통과 수에 넣지 않았다.

**교훈:** Swift Testing은 `-only-testing`에 함수 이름만 쓰면(괄호 없이) 테스트를 0개 돌리고 "TEST SUCCEEDED"를 낸다. 변형 시험에서 처음에 이 때문에 검사가 통과로 보였고, 스위트 단위로 다시 돌려 실제로 잡는 것을 확인했다.

## 6. 이전 남은 결함(UI-AUDIT R1~R8) 판정

| 항목 | 판정 | 처리 |
|---|---|---|
| R1 편집 이름 칸 한 줄 잘림 | 시스템 기본 동작 | 유지(여러 줄로 바꾸면 Return 동작이 바뀜) |
| R2 iPad 사이드바 글자 고정 (P1) | 실제 결함 | **수정** |
| R3 그룹 머리말 꺾쇠 읽힘 | 변경할 필요 없음 | 단추 이름이 따로 있어 꺾쇠가 읽히지 않음. 크래시 원인은 UNRESOLVED(3절) |
| R4 시트 유리 단추 뒤로 내용 지나감 | 시스템 기본 동작 | 유지 |
| R5 휴가 휴식 화면 AX5 겹침 | 미적 개선 후보 | 유지(조작 가능, 원화 배치 보존) |
| R6 온보딩 SE AX5 스크롤 영역 작음 | 실제 결함(경미) | **개선**(단계 표시를 스크롤 안으로) |
| R7 첫 동기화 로고 고정 크기 | 변경할 필요 없음 | 브랜드 로고 |
| R8 설정 목록 가로에서 왼쪽 정렬 | 미적 개선 후보 | 유지 |
| 새로 발견: iPad 시트 [완료] 중복 | 실제 결함 | **수정** |
| 새로 발견: 정보 화면 AX5 아이콘 | 실제 결함(경미) | **수정** |

## 7. 미해결·후속

1. 공식 슬로건 결정: "하루를 기록하다." / "Small habits, Lasting growth." / "조금씩, 더 나은 나로"
2. 꺾쇠 접근성 크래시의 근본 원인(SwiftUI 내부). 지금은 숨김이 필요 없어 영향은 없다
3. 화면 캡처로 확인하지 못한 것: Dock·메뉴 막대, 위젯 갤러리
4. NOT_TESTED: VoiceOver 실제 탐색, iPad 좁은 창, 큰 iPhone, Mac 키보드 탐색·팝오버·최소화
5. 배포 후 반영: 운영 Mac 앱(Finder "Daylog", 나뭇잎 사이드바), TestFlight. App Store Connect 앱 이름·설명은 이번에 바꾸지 않았다
6. 기존 StoreKit 로컬 실패 4건(이번 실행에서는 3건 실패)

## 산출물

- [BRAND-AUDIT.md](BRAND-AUDIT.md), [DEVICE-QA.md](DEVICE-QA.md), [REVIEW.html](REVIEW.html)
- `evidence/` 대표 캡처 40장(7.4MB)
- 중간 캡처는 프로젝트 밖(`~/Library/Caches/DaylogQA.noindex/`)에서 만들고 검증 뒤 지웠다

보호 항목(번들 ID, 앱 그룹, 상품 ID 13종, 구매·복원 코드, 사용자 데이터, 저장 경로, 피오 원화, 휴가 원본, 의상 14종, 애니메이션 리그)은 바꾸지 않았다. 커밋·푸시·배포·App Store Connect 변경은 하지 않았다.
