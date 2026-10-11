# Phase 3 상세 명세

## 공통 계약

기존 SwiftData v4 엔티티·CloudKit 동기화·과거 통계를 유지한다. 새 사용자 환경설정은 UserDefaults에만 저장하고 동기화하지 않는다. 뷰는 AppStore/서비스를 통해 데이터를 변경한다. 파일을 읽거나 미리보는 동안 저장하지 않는다.

## 구현 순서

1. 가져오기/내보내기 형식과 순수 검증·직렬화 서비스, 관련 테스트.
2. 명시적 확인을 받는 가져오기 화면·파일 내보내기 화면, 일괄 저장과 보존 테스트.
3. 기기별 식사 표시·대시보드 설정 및 모든 탐색 경로 반영.
4. 체크 접근성·Reduce Motion·통계 기간 비교.
5. 최초 실행 온보딩.
6. macOS Sparkle 2 기반과 운영 문서. 실제 게시·서명 변경은 보류.
7. 통합 검토, 플랫폼별 빌드·UI, 최종 전체 회귀, 진행 문서와 커밋.

독립된 서비스와 화면 작업은 병행할 수 있지만 공통 파일 소유권을 나누고 통합 검증한다.

## A CSV와 JSON 루틴 가져오기

- 파일 선택 → 전체 검증 → 생성/재사용/중복/오류 미리보기 → 사용자 저장 확인 → 원자적 저장.
- 그룹명·루틴명·요일·시간·메모 지원. CSV 템플릿과 내보낸 루틴 JSON을 사용한다.
- 동일 그룹명은 재사용한다. 이름이 같은 그룹이 여러 개여서 모호하면 오류로 표시한다.
- 같은 그룹의 동일 루틴은 중복으로 미리보기에 표시하고 생성에서 제외한다. 다른 설정의 같은 이름은 충돌로 표시하며 덮어쓰지 않는다.
- 빈 이름·초과 길이·잘못된 요일/형식 등은 자동 보정하거나 잘라내지 않는다. 오류가 있으면 저장할 수 없다.
- 저장 직전 최신 데이터로 재검증한다. 동기화로 미리보기와 달라지면 다시 확인받는다.
- 신규 루틴은 오늘부터 유효한 이력을 생성한다. 기존 루틴·체크·이전 날짜 스냅샷은 수정하지 않는다.
- 테스트: CSV 따옴표/쉼표/개행/UTF-8, JSON 버전·타입 오류, 중복·충돌, 일괄 저장 실패, 과거 통계 불변.

## B 내보내기

- 활성 루틴 CSV 및 버전 있는 루틴 JSON은 A에서 다시 가져올 수 있어야 한다.
- 전체 JSON은 모든 그룹·루틴(보관·삭제 포함)·revision·일별 기록·체크·FieldEdit·AppSettings와 휴가 정보를 포함한다. ID·날짜·관계·동기화 충돌 이력을 손실 없이 남긴다.
- 파일 목적과 포함 범위를 UI에서 구별한다. 전체 백업은 이번 버전에서 복원할 수 없다.
- 읽기 전용: 모델 저장·삭제·정리·동기화 mutation을 호출하지 않는다. 현재 로컬에 도착한 데이터만 담으며 아직 내려오지 않은 iCloud 데이터까지 보장하지 않는다.
- 테스트: roundtrip, 한국어·특수문자, 전체 엔티티 필드 포함, 내보내기 전후 데이터 불변.

## C 식사 기록 표시

- 기본 ON. 기기별 선택, 식사 메뉴·대시보드·통계·날짜 상세의 식사 UI를 숨긴다.
- OFF 전 입력 중 변경은 기존 저장 흐름으로 보존한다. ON으로 되돌리면 이전 기록을 다시 표시한다.
- 테스트: 설정 지속·기기 독립·기록 불변·선택한 메뉴에서 안전하게 이동.

## D 대시보드

- 카드 순서 변경, 카드 표시/숨김, 기본 배치 복원. 오늘 루틴은 항상 표시.
- 식사 OFF는 식사 카드의 저장된 개인 선택을 지우지 않고 표시만 억제한다.
- 좁은 화면과 넓은 화면 모두 설정 반영. 카드 크기 조절·자유 좌표 배치 제외.
- 테스트: 잘못된 저장값 복구, 필수 카드, 순서와 숨김 지속, 기본 복원, 식사 연동.

## E macOS 업데이트

- macOS 앱에만 Sparkle 2를 연결한다. Daylog 메뉴에서 업데이트 확인.
- 기존 Developer ID·공증 DMG 흐름을 유지하며 GitHub Releases 자산과 HTTPS appcast를 사용한다.
- EdDSA 공개 키와 유효한 feed 설정이 없으면 updater를 시작하지 않는다. 개인 키는 키체인/보안 CI에만 두고 저장소에 포함하지 않는다.
- 실제 키 생성·서명 변경·appcast 게시·릴리스 업로드·설치 검증은 별도 승인 이후 수행한다. 비활성 기반 구현과 실제 배포 완료를 구분한다.
- 테스트: 누락/잘못된 설정의 안전한 비활성화, macOS 빌드 및 iOS에 의존성이 유입되지 않음.

## F 체크와 통계

- 체크 버튼에 루틴명·상태·행동 설명, 성공 피드백. Reduce Motion에서는 장식적 이동/확대 애니메이션 억제.
- 7/30/90일은 바로 앞 동일 길이 기간과 비교한다. 전체 기간은 비교 없음. 비교 대상이 없으면 0으로 채우지 않는다.
- 휴가·휴식·시작 전·미래는 집계에서 제외. 기존 미기록 예정일의 분모 규칙은 유지하되 화면에서 실제 기록된 0%와 구별해 표시한다.
- 테스트: 기간 경계·휴가·빈 기간·미기록 상태, 기존 통계 회귀, VoiceOver 속성과 Reduce Motion UI 확인.

## G 최초 실행 온보딩

- 소개 → 그룹·루틴 만들기 → 오늘 시작하기. 언제든 건너뛰기 가능.
- 완료 여부는 기기별 저장. 데이터가 늦게 동기화되어도 자동 seed·초기화·덮어쓰기를 하지 않는다.
- 사용자가 입력하고 확인한 신규 그룹·루틴만 기존 서비스로 생성한다. 이미 데이터가 있으면 기존 루틴으로 진행 가능.
- 테스트: 첫 실행/완료 후/건너뛰기, 기존 데이터 및 늦은 iCloud 도착 보존, 빈 입력 방지.

## 최종 검증

관련 테스트 → 코드 검토 → macOS Debug/Release·iOS Simulator Debug/Release → 가능한 Mac/iPhone/iPad UI → 전체 회귀 1회. 실기기·Production CloudKit·공증·실제 업데이트 설치는 수행하지 않으면 미검증으로 기록한다.

## 구현된 파일 계약과 검증 재개

CSV/JSON의 정확한 필드·제한·시간 표현은 [ROUTINE_FILES.md](ROUTINE_FILES.md)를 따른다. 루틴 파일로 안전하게 표현할 수 없는 중복 ID/동일 이름 그룹/잘못된 기존 값은 내보내기를 중단하고 원본 전체 JSON 보관을 안내한다.

Mac 검증은 실제 앱과 분리된 bundle ID 및 `Config/Verify.entitlements`를 사용한다. 예시:

```sh
xcodebuild -project Daylog.xcodeproj -scheme Daylog -configuration Debug \
  -derivedDataPath /tmp/daylog-phase3-mac \
  PRODUCT_BUNDLE_IDENTIFIER=com.daylog.phase3.verify \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= \
  PROVISIONING_PROFILE_SPECIFIER= CODE_SIGN_ENTITLEMENTS=Config/Verify.entitlements \
  test -only-testing:DaylogTests/RoutineTransferTests -only-testing:DaylogTests/DataExportTests
```

다른 관련 suite: DevicePreferencesTests, OnboardingTests, StatsComparisonTests, UpdateConfigurationTests. 전체 회귀는 이번 변경에서 이미 최종 1회 실행했다. 후속 수정이 있다면 해당 suite부터 실행한다.

iOS 빌드는 scheme DaylogiOS, SDK iphonesimulator, Debug/Release를 사용한다. 대상 UUID는 세션마다 `xcrun simctl list devices available`로 다시 확인한다. Mac UI는 검증 bundle에 `-DaylogStoreName phase3ui`를 주어 별도 저장소를 사용한다. 검증 저장소는 코드에서 CloudKit 연결을 차단한다.
