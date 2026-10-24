# RoutiMori 사용자 노출 브랜드 통일

판정: **PARTIAL**. 앱·위젯 소스와 표시용 메타데이터 변경 및 식별자 보존 검사는 완료했다. 최종 앱 빌드/실제 화면 결과는 이번 작업의 통합 검증 결과와 구분한다. 운영 앱은 교체하지 않았다.

## 확인한 범위

작업 전 motion v2 RESULTS, scene integration RESULTS/IOS, StoreKit isolation RESULTS 네 보고서를 읽었다. 기존 모션·장면 성과는 재작성하지 않고, StoreKit 7/11 및 잔여 실패 4건·실제 Sandbox 미검증 상태를 유지했다.

실제 앱 타깃은 macOS `Daylog`, iPhone/iPad 공용 `DaylogiOS`, iOS 위젯 확장 `DaylogWidgets`다. 별도 watchOS/tvOS/visionOS 타깃은 없다. 작업 전 현지화 문자열 카탈로그/별도 InfoPlist.strings는 없었다. 사용자 문구는 주로 Swift/표시용 plist/모바일 UI 설정에 있으며, 이번에 기존 개발 언어 ko의 공유 InfoPlist.strings를 추가했다.

| 영역 | 변경 |
| --- | --- |
| iPhone/iPad 아이콘 아래 이름 | 두 구성(Debug/Release)의 CFBundleDisplayName을 RoutiMori로 변경 |
| macOS 앱·표준 메뉴 이름 | 표시용 CFBundleDisplayName 및 현지화 CFBundleName RoutiMori, 주 창 제목/메뉴 막대 문구/접근성 레이블 통일 |
| 위젯 확장 | 표시 이름과 위젯 브랜드/앱 열기/저장 대기/접근성 문구 통일 |
| 시작·온보딩·클라우드 | Routimori/Daylog/루티모리 브랜드 표기를 RoutiMori로 통일 |
| 설정·정보·사이드바 | 제목, 알림 설정 안내, 위젯 안내, 기기 안내 등 사용자 문구 통일 |
| 알림 | 새 루틴 알림 제목 RoutiMori, 동일 요청 ID로 기존 예약 제목을 갱신할 수 있게 내용 signature에 제목 포함 |
| 템플릿 | 안내/오류/새 내보내기 제안 이름과 문서 유형 설명 통일; 확장자/UTType/기존 파일 경로 보존 |
| 홈 헤더 | 별도 헤더 담당자가 TodayCompactView에서 Text(verbatim: AppBrand.name)을 적용; 최종 소스 감사에서 확인 |

기존에 이미 전달된 알림 기록을 소급해 바꾼 것으로 주장하지 않는다. 예약된 알림은 다음 정상 예약 조정 시 같은 요청 ID로 갱신된다. 실제 OS 알림 표시/기존 예약 교체는 아직 실행하지 않았다.

## 오래된 원격 문구 처리

공유 `DaylogShared/AppBrand.swift`는 사용자 표시 이름 `RoutiMori`를 정의한다. `MobileUISettings.string`에서 **앱이 관리하는 UI 문구만** 표시 시 보정한다. 이전 캐시에 Daylog/Routimori/루티모리가 있어도 새 브랜드를 표시한다. 원격 캐시 JSON, 사용자 작성 기록, URL, 설정 키를 변경하지 않는다.

`RemoteConfig/mobile-ui.json` 및 개발 예제의 알림 안내 문구도 변경했다. 서버에 업로드·게시하지 않았다. URL과 config/schema version은 그대로다.

스플래시의 기존 새싹 장식과 모션을 유지하고 텍스트 조각을 `Rout` + `i` + `Mori`로 맞췄다. 별도 피오 원화나 모션을 생성/수정하지 않았다.

## 식별자·데이터 경계

브랜드 작업 시작 시점의 보호 파일 **15/15 SHA-256 동일**:

- StoreKit 구매 관리자, 제품 registry, `.storekit` 구성.
- wardrobe 선택/소유 정책 및 선택 파일 저장 코드.
- DaylogStore와 동결된 스키마 파일.
- 앱 그룹 WidgetBridge, 세 타깃 entitlements.
- 업데이트 및 원격 설정 URL/캐시 저장 코드.

`project.pbxproj`의 제품 번들 ID, 모듈/제품 이름, team, signing entitlement 경로 목록도 이전과 동일하다. 프로젝트에서는 세 타깃×Debug/Release의 CFBundleDisplayName 6개만 변경했다. 사용자 표시용 CFBundleName은 공유 ko.lproj/InfoPlist.strings로 재정의한다. Xcode가 생성하는 원시 CFBundleName은 기술 PRODUCT_NAME(Daylog/DaylogWidgets)을 유지한다. 세 Info.plist는 허용한 CFBundleName/사람이 읽는 문서 유형 설명 이외 값이 동일하다. 정상 구매 opt-in 키도 추가하지 않았다.

보존된 식별자의 예:

```text
com.mungyubin.daylog
com.mungyubin.daylog.ios
com.mungyubin.daylog.ios.widgets
group.com.mungyubin.daylog
com.mungyubin.daylog.template
DaylogToday
daylog://today
.daylogtemplate
Application Support/Daylog
```

13개 `outfit.*` 제품 ID는 그대로다. 앱 실행 파일/프로젝트/Swift 모듈/기술 파일명에 Daylog가 남는 것은 의도적이다. 기존 파일을 새 브랜드 이름으로 이동하거나 저장소 마이그레이션하지 않았다.

## 검사·증거

| 검사 | 결과 |
| --- | --- |
| 변경 전후 문자열 감사 | PASS — 홈 헤더 반영 후 구 표기 직접 UI literal 0개, 기술·입력 보정 문자열은 유지 |
| 보호 파일 SHA-256 | PASS 15/15 |
| 프로젝트 기술 설정 목록 | PASS 동일 |
| plist 허용 표시 항목 이외 값 비교 | PASS 동일 |
| 일반 빌드 구매 opt-in 미추가 | PASS |
| Swift frontend parse | PASS |
| plist/project `plutil -lint` | PASS |
| AppBrandTests 4개 | PASS 4/4 — mac-final-checks.log 실제 실행, metadata assertion 유지 |
| 기존 알림·템플릿·모바일 UI 회귀 | 변경 문구 기대값 2개 갱신, 실제 실행은 통합 검증 담당 |
| 실제 iPhone/iPad/Mac/위젯 표시 | 통합 빌드/화면 검증 결과 참조; 소스 검사만으로 PASS 처리하지 않음 |

새 테스트는 번들 표시 이름, 오래된 원격 문구의 비파괴 표시 보정, 알림 요청 ID 보존/내용 갱신, 제품·앱 그룹·UTType 프로토콜 불변을 검사한다.

근거:

- `brand-strings-before.json`, `brand-strings-after.json`: 범위 내 문자열 감사 원본. 기술 키·URL·파일명 및 입력 보정용 이전 이름은 분류해 유지한다.
- `brand-protected-before.json`, `brand-protected-after.json`: 이전 시점 해시와 허용 변경 검사.
- `brand-changed-files.json`: 이 담당자가 편집한 경로 목록(홈 헤더 별도).
- `brand-parse.log`: 구문 검사 기록.
- `brand-built-metadata.json`: Mac/iOS/위젯 실제 빌드 plist·현지화 리소스. 원시 기술 이름과 사용자 표시 이름을 구분한다.
- `mac-final-checks.log`: 기존 assertion을 유지한 AppBrandTests 4/4 PASS. 별도 lifecycle 실패로 전체 실행은 FAILED.

## 후속 작업과 한계

- App Store Connect에 등록된 앱 이름 등 외부 메타데이터의 대소문자는 별도 변경이 필요할 수 있다. 이번에 ASC를 수정하지 않았다.
- 원격 설정 저장소 예제만 바꿨고 배포하지 않았다. 앱의 표시 보정으로 기존 캐시 문구를 처리한다.
- 홈 헤더·장면 최종 화면, 작은 화면/Dynamic Type/실제 VoiceOver, 위젯 갤러리 및 OS 메뉴 표시는 통합 검증 결과를 확인해야 한다.
- 기존 구매 실패 4건과 실제 Sandbox 미검증은 이 브랜드 변경으로 해결되지 않았다.

커밋·push·배포·운영 앱 교체·실제 결제·사용자 데이터 변경을 하지 않았다.

## 독립 소스 리뷰

부모 작업의 Mac 창 가시성 변경(클라우드·휴가)과 헤더 담당자의 새 상호작용/네이티브 래퍼도 읽기 전용으로 검토했다. 창 observer 교체·해제, visible/miniaturized/occlusion·clip 조건, 완료 Task의 weak self·token, 중복 탭 차단과 기존 모션 길이 일치에서 수정할 구체적 소스 결함은 발견하지 못했다. 실제 창 숨김/최소화 재생 정지와 작은 화면·VoiceOver 검증은 별도 실행 증거가 필요하며, 이 리뷰만으로 PASS 처리하지 않는다.

## 실제 빌드에서 발견한 메타데이터 결함

첫 Mac 실행에서 CFBundleDisplayName은 RoutiMori지만 사용자 표시 CFBundleName은 Daylog여서 AppBrandTests가 실패했다. 원본 Info.plist의 CFBundleName만으로는 `GENERATE_INFOPLIST_FILE=YES`의 생성 값을 덮지 못했다. 실제 `/tmp/PioStoreKit-20261023-mac/Build/Products/Debug/Daylog.app/Contents/Info.plist`를 읽어 확인했다.

추가한 `INFOPLIST_KEY_CFBundleName` 사용자 정의 설정도 실제 출력에는 효과가 없었으며, `mac-focused-final.log`의 재실패를 보존했다. 이 설정은 제거했다. Apple 문서에 따라 생성 CFBundleName은 PRODUCT_NAME에서 오므로 기술 제품 이름을 바꾸지 않고 **지원되는 현지화 표시 리소스** `DaylogShared/ko.lproj/InfoPlist.strings`에 CFBundleName/CFBundleDisplayName=RoutiMori를 지정했다. 기존 프로젝트 개발 언어는 ko이고, 공유 디렉터리는 세 타깃이 모두 포함한다.

원시 생성 plist의 CFBundleName은 기술 이름을 유지하며, 사용자 표시는 Bundle의 현지화 조회를 사용한다. 기존 `Bundle.main.object(forInfoDictionaryKey:)`의 정확한 RoutiMori assertion은 그대로다. 최종 수정 후 `mac-final-checks.log`에서 AppBrandTests **4/4 PASS**를 확인했다. 이 실행 전체는 별도 창 가시성 테스트 실패로 **FAILED**이며 전체 PASS로 바꾸지 않는다. Mac·iOS 앱·위젯 세 산출물의 ko.lproj/InfoPlist.strings도 읽어 두 표시 키가 RoutiMori인지 확인했다(`brand-built-metadata.json`). iOS/위젯 리소스 포함 검사는 실제 OS 화면/위젯 표시 검증과 구분한다.

근거: [Apple build settings reference](https://developer.apple.com/documentation/Xcode/build-settings-reference), [정보 plist 값 관리 및 이름 현지화](https://developer.apple.com/documentation/bundleresources/managing-your-app-s-information-property-list). PRODUCT_NAME, 실행 파일, 모듈, Bundle ID와 기존 데이터 경로를 보존했다.
