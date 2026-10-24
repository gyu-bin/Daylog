# BRAND-AUDIT — RoutiMori 브랜드·아이콘 정합성 (2026-10-24)

공식 표기: **RoutiMori** (`DaylogShared/AppBrand.swift`의 `AppBrand.name`).
내부 식별자(번들 ID, 앱 그룹, 저장소 이름·경로, 파일 이름 `Daylog.app`, URL 스킴·템플릿 확장자, StoreKit 상품 ID)는 바꾸지 않았다.

## 1. 사용자가 본 "Daylog·나뭇잎 아이콘"의 원인

| 본 곳 | 원인 | 최신 소스에서 |
|---|---|---|
| Mac 사이드바 머리말의 초록 나뭇잎 아이콘 | `BrandIcon` 에셋이 v1.3.3(2026-10-10)의 Daylog 나뭇잎 그림(라이트·다크) 그대로였다. 앱 아이콘(`AppIcon`)만 10/17에 피오로 바뀌었다 | 고침: `BrandIcon`을 공식 앱 아이콘 그림으로 교체 |
| Mac을 다크로 쓸 때 Dock의 나뭇잎 아이콘 | 실행 중 다크 외관이면 `DockIcon`이 옛 다크 나뭇잎(`DockIconDark`)을 Dock에 걸었다 | 고침: 공식 아이콘에 다크 변형이 없어 번들 아이콘을 그대로 둔다. 옛 에셋 삭제 |
| Finder·Dock의 앱 이름 "Daylog" | 기본 `CFBundleDisplayName`이 Daylog였고, 현지화 이름(ko: RoutiMori)을 Finder가 쓰게 하는 `LSHasLocalizedDisplayName`이 없었다 | 고침: 키 추가 + 기본 표시 이름을 파일 이름과 맞춤 → Finder가 "RoutiMori"로 표시 |
| 이전 캡처 | 설치된 운영 앱 `/Applications/Daylog.app`(1.5.10)도 같은 결함을 가진 빌드다. 최신 소스로 다시 빌드한 검증 앱에서도 같은 결함을 재현한 뒤 고쳤다 | 운영 앱은 배포 전이라 아직 옛 표시(증거: `evidence/mac-finder-name-installed-vs-current.png`) |

## 2. 플랫폼별 표시 위치

| 위치 | 결과 | 근거 |
|---|---|---|
| **iPhone·iPad** 홈 화면 앱 이름·아이콘 | RoutiMori · 피오 | 시뮬레이터 홈 화면 캡처(SE, iPhone 17, iPad mini) |
| iPhone·iPad 앱 안 머리말·설정 앱 정보·온보딩·첫 동기화 | RoutiMori · 피오 아이콘 | 캡처 |
| 알림 제목 | "RoutiMori · 루틴 시간이에요" | `AppBrandTests` |
| 위젯 이름·설명 | "오늘의 루틴"(브랜드 표기 없음), 위젯 확장의 현지화 이름 RoutiMori | 코드·빌드 산출물 확인. 위젯 갤러리 화면은 NOT_TESTED |
| 템플릿 공유 파일 이름·문서 유형 이름 | "RoutiMori 템플릿 - …", "RoutiMori 루틴 템플릿" | 코드·Info.plist |
| **macOS** 사이드바 이름·아이콘 | RoutiMori · 피오 (라이트·다크·900/1100/1680 창) | 캡처 |
| Mac 창 제목 | RoutiMori | 캡처 |
| Mac 설정 → 정보 | RoutiMori · 피오 아이콘 | 캡처 |
| Finder 앱 이름·아이콘 | RoutiMori · 피오 | 실제 Finder 창 캡처(`evidence/mac-finder-window.png`) |
| Dock·앱 전환기·메뉴 막대 앱 이름 | RoutiMori | 실행 중 앱이 시스템에 알린 이름(`NSRunningApplication.localizedName`). Dock 자동 숨김이 켜진 다중 모니터라 Dock·메뉴 막대 화면 캡처는 하지 않았다(사용자 화면이 함께 찍혀서). 화면 캡처 기준 NOT_TESTED |
| Dock 아이콘(실행 중, 다크) | 번들 아이콘(피오) 유지 | `BrandIconTests.dockIconKeepsTheBundleIconInEveryAppearance` |
| 접근성 이름 | 사이드바 머리말 "RoutiMori, 하루를 기록하다." | 코드 |

자동 검사: `BrandConsistencyTests.userVisibleStringLiteralsUseTheExactBrand`가 `Daylog/`·`DaylogWidgets/`·`DaylogShared/`의 화면 글자(Text·Label·Button·접근성 이름·제목·위젯 이름 등)에서 Daylog·Routimori·ROUTIMORI·Routi Mori·루티모리를 찾는다.
일부러 옛 이름을 넣으면 실패하는 것을 확인했다.

## 3. 남아 있는 "Daylog"(의도적으로 유지)

- 내부 식별자: 번들 ID `com.mungyubin.daylog(.ios)`, 앱 그룹, 저장소 폴더 `Daylog`, 스키마 이름, 템플릿 확장자 `daylogtemplate`, 색 에셋 이름
- 파일 이름: `Daylog.app`(Sparkle 업데이트·설치 경로가 이 이름을 쓴다), 소스·타깃 이름
- 외부 주소: GitHub 저장소 `gyu-bin/Daylog`(Sparkle 피드, 개인정보 처리방침, 원격 UI 설정). 이미 설치된 앱이 계속 여는 주소라 옮기지 않았다
- 로그 문구(`NSLog("Daylog: …")`): 사용자에게 보이지 않음
- 원격 UI 설정의 옛 문구는 화면에 그릴 때 `AppBrand.displayCopy`가 RoutiMori로 바꾼다(저장된 내용은 그대로)

## 4. 브랜드 문구(슬로건)

| 문구 | 쓰는 곳 | 판단 |
|---|---|---|
| "하루를 기록하다." | Mac·iPad 사이드바 머리말 | 유지. Daylog 시절부터의 문구 |
| "Small habits, Lasting growth." | iPhone·iPad 스플래시 | 유지 |
| "조금씩, 더 나은 나로" | 첫 동기화 화면 | 유지 |

공식으로 확정된 RoutiMori 슬로건을 저장소에서 찾지 못했다. 서로 다른 문구 세 개가 있으므로, **하나로 정할지 결정이 필요하다**(후속). 새 문구를 만들지 않았다.

## 5. 앱 아이콘 매핑

| 에셋 | 그림 | 쓰는 곳 | 이번 변경 |
|---|---|---|---|
| `AppIcon.appiconset` (mac 16~512@2x 10장 + iOS 1024 1장) | 피오(10/17 사용자 승인, 커밋 d338608) | 홈 화면, Dock, Finder, App Store | 없음 |
| `BrandIcon.imageset` | 옛 나뭇잎(라이트·다크) → **피오(`icon_ios_1024.png`와 바이트 단위로 같은 파일)** | Mac·iPad 사이드바, 설정 정보, 온보딩, 알림 안내 | 교체. 둥근 사각형으로 잘라 그린다 |
| `DockIconDark.imageset` | 옛 다크 나뭇잎 | 실행 중 다크 Dock | 삭제(쓰는 곳 없음) |
| `MenuBarIcon.imageset` | 메뉴 막대 상태 아이콘(단색 기호) | Mac 메뉴 막대 | 없음 |
| `Tools/GenerateIcons.swift` | 옛 나뭇잎을 그리는 생성기 | — | 실행하지 말라는 경고만 추가(실행하면 공식 아이콘을 덮어쓴다) |

공식 아이콘 판단 근거: 사용자가 10/17 "앱 아이콘은 이걸로 바꾸자"며 준 그림이 `AppIcon`에 들어가 1.5.9·1.0.1(12)부터 배포되었다. 옛 아이콘은 `output/app-icon-2026-10-17/`에 백업되어 있다. 새 아이콘을 만들지 않았다.
공식 아이콘에는 다크 변형이 없다. 그래서 다크 모드에서도 같은 피오 아이콘을 쓴다.

## 6. 시즌·유료 의상 아이콘

`PioAppIconService`(iOS 대체 아이콘)는 Info.plist에 `CFBundleAlternateIcons`가 없어서 지금은 등록된 테마가 없다. 옷장의 "앱 아이콘" 화면은 테마 미리보기라고 밝히고 있다.
이번에 아이콘 교체 정책, 파일 이름, 매핑, 구매 권한을 바꾸지 않았다.

## 7. 이번에 바꿀 수 없는 외부 메타데이터 (후속)

- App Store Connect의 앱 이름·부제·설명·스크린샷
- GitHub 저장소 이름과 릴리스 페이지, 개인정보 처리방침 페이지의 표기
- 설치된 운영 Mac 앱(1.5.10)과 TestFlight 1.0.1(13): 다음 배포에서 이번 변경이 반영된다
