# Daylog 진행 기록

최종 갱신: 2026-10-12. 다음 세션은 이 문서 → PHASE3.md → git status/diff 순서로 확인한다.

## 기준과 커밋

- 작업 브랜치 main. 시작 상태 clean, 기준 HEAD `64cb21023cd535b0e2c34ef9c52a3f332754e468` (`feat: persist widget checks immediately and add vacation mode`).
- 이전 커밋 `408947a`는 알림·위젯·메뉴 막대, `f0d74de`는 iOS 유니버설 앱·루틴 편집 개선.
- Phase 3 코드와 이 최종 검증 기록은 같은 main 커밋에 포함한다. 해당 구현 SHA는 `git log -1 --format=%H -- docs/PROGRESS.md`로 확인한다. 다음 세션은 `git status`와 `git log -1`로 이후 변경 및 원격 상태도 확인한다.
- SwiftData v4·CloudKit 모델/환경은 유지했다. 실제 사용자 저장소에 테스트 데이터를 쓰지 않았다.

## Phase 3 기능별 상태

| 기능 | 구현 상태 | 검증 및 남은 작업 |
|---|---|---|
| 개발 계획·명세 | 완료 | DEVELOPMENT_PLAN.md, PHASE3.md, 본 진행 기록. 형식/운영 문서 추가 |
| A CSV·JSON 가져오기 | 완료 | 5MB/1,000행, 검증·미리보기·확인·최신 상태 재검증·원자적 저장. Mac 파일선택→중복1/생성2 확인→저장 및 잘못된 시간 차단 UI 확인 |
| B 데이터 내보내기 | 완료 | 활성 CSV/루틴 JSON, 7개 엔티티 전체 JSON. 읽기전용/모든 모델 필드/관계/휴가·충돌 이력 테스트. Mac 파일저장 결과 확인 |
| C 식사 ON/OFF | 완료 | 기기별 UserDefaults, 모든 메뉴/식사 UI 숨김. Mac 입력→OFF→ON→재실행 내용 보존, iPhone 탭 숨김 확인 |
| D 대시보드 | 완료 | 순서·숨김·복원·오늘 루틴 필수. Mac 조작/배치 확인, iPhone·iPad 화면 확인 |
| E Sparkle 2 | 기반 완료·활성화 보류 | macOS만 Sparkle 2.10.0 고정 연결, 메뉴와 준비 중 안내 확인. 공개 키/설치 통신 권한/게시/실제 업데이트 승인 후 진행 |
| F 체크·통계 UX | 완료 | VoiceOver 속성·iOS 피드백·Reduce Motion 처리, 7/30/90일 직전 기간 비교, 미기록 구분. 계산 테스트와 Mac/iPad UI 확인 |
| G 온보딩 | 완료 | 3단계·skip·다시 보기·명시적 생성. Mac 생성 흐름, iPhone skip, iPad 기존 루틴 유지 흐름 확인 |

## 검증 결과

기능별 테스트를 먼저 실행했다. 최종 전체 회귀를 한 번 실행해 **310 tests / 49 suites**가 통과했다. fixture 생성용 2개 테스트는 원래 설정에 따라 건너뛰었다. 이전 Phase 2.1의 결과와 별개다.

| 검증 | 결과 | 증거 |
|---|---|---|
| 업데이트 구성·통계 비교·기간·휴가 | 28 tests / 4 suites 통과 | `/tmp/daylog-phase3-targeted.log` |
| 기기 설정·온보딩 | 10 tests / 2 suites 통과 | `/tmp/daylog-phase3-preferences.log` |
| 온보딩 보관 이름 충돌 수정 후 | 5 tests / 1 suite 통과 | `/tmp/daylog-phase3-onboarding-final.log` |
| 가져오기·내보내기 최종 | 18 tests / 2 suites 통과 | `/tmp/daylog-phase3-transfer.log` |
| 전체 회귀 1회 | 310 tests / 49 suites 통과 | `/tmp/daylog-phase3-regression.log` |
| macOS Debug | 최종 전체 회귀 빌드 통과 | 위 테스트 로그 |
| macOS Release | 최종 수정 포함 통과 | `/tmp/daylog-phase3-mac-release-final.log` |
| iOS Simulator Debug | 최종 수정 포함 통과 | `/tmp/daylog-phase3-ios-debug-final.log` |
| iOS Simulator Release | 최종 수정 포함 통과 | `/tmp/daylog-phase3-ios-release-final.log` |
| diff/프로젝트 설정 | 공백 오류 없음, plist 문법 정상 | `git diff --check`, `plutil -lint` |

테스트와 빌드는 검증용 Mac bundle `com.daylog.phase3.verify` 및 ad-hoc 서명으로 수행했다. 실제 Developer ID 공증 배포 빌드와 다르다. iOS는 시뮬레이터 빌드이며 실기기 Release 서명은 검증하지 않았다.

## 실제 UI 확인 범위

- Mac 별도 로컬 저장소 `phase3ui`: 온보딩 3단계로 그룹·루틴 생성, 체크 상태와 접근성 행동 설명, 식사 입력/표시 OFF/ON, 카드 숨김·이동·기본 복원, 앱 재실행 후 체크·식사 유지.
- Mac 파일 이동: CSV 선택→미리보기(중복1, 신규2, 기존 그룹1/새 그룹1)→명시적 확인→저장. `25:99` 오류 행 저장 비활성. 전체 JSON 파일 `/tmp/daylog-phase3-ui-backup.json`에서 루틴3·그룹2·체크2·식사 문자열과 기존 완료 체크·잘못된 행 미생성을 확인했다.
- Mac 메뉴 `Daylog → 업데이트 확인…`: 준비 중 안내, 실제 업데이트 시작 없음.
- iPhone Air / iOS 27.0 시뮬레이터: 첫 안내·건너뛰기·빈 대시보드·설정·식사 OFF 후 4개 탭 표시. Mac 설정과 독립.
- iPad Air 11-inch (M4) / iPadOS 26.5 시뮬레이터: 안내 도중 기존 루틴 1개 인식, 현재 루틴으로 계속→오늘 화면, 기존 체크100% 유지, 세로 대시보드와 통계의 빈 이전 기간 안내.
- 실제 VoiceOver 낭독·Reduce Motion 시스템 설정을 켠 런타임 동작·실기기 촉각은 미검증. 접근성 트리의 루틴명/상태/행동 설명은 확인했다.

## 검토에서 수정한 문제

1. 보관된 동일 이름 루틴을 온보딩 성공으로 잘못 안내하던 경로: 명확한 오류 안내와 회귀 테스트 추가.
2. 같은 그룹/이름의 서로 다른 루틴 ID가 내보내기 후 하나로 줄어들 수 있는 경로: 정의 일치 여부와 관계없이 루틴 파일 내보내기 차단, 전체 JSON 안내·두 ID 보존 테스트 추가.

## 다음 작업

1. 로컬 main 및 원격 상태를 확인하고 기존 변경을 보존한다. A/B/C/D/F/G의 중복 개발은 하지 않는다.
2. 배포 담당 승인 후 docs/UPDATES.md에 따라 키·샌드박스 설치 통신 권한·appcast/DMG 게시·실제 업데이트 설치 검증을 수행한다.
3. 실기기 iPhone/iPad, 최소 지원 OS, 실제 VoiceOver·Reduce Motion, iOS Files 가져오기/내보내기와 다기기 CloudKit를 추가 검증한다.

## 범위 밖 및 보류

- 전체 JSON 복원, 카드 크기 조절·자유 배치는 제외.
- CloudKit Production·실기기 동기화, 실제 Sparkle 서명/변조 거부/설치, Developer ID archive/export·공증·GitHub Releases 게시 미수행.
- Sparkle 개인 키는 생성하지 않았으며 저장소에 없다. `DaylogUpdatesEnabled=false`, 공개 키 비어 있음. 기존 서명 인증서/팀/CloudKit entitlements는 변경하지 않았다. 파일 가져오기·내보내기에 필요한 사용자 선택 파일 read/write 권한만 추가했다.
- 테스트 로그는 /tmp에 있으므로 영구 보존되지 않는다. 핵심 결과와 재개 조건은 본 문서에 기록한다.
