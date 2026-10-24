# 접근성 검사 — 2026-10-24

판정 PARTIAL. 코드 검사와 실제 VoiceOver 조작을 구분한다.

## 확인·수정

- PioHeaderCompanion: 하나의 버튼 접근성 요소, 현재 의상 레이블, 동작 상태 value, Reduce Motion 안내 hint. 장식적인 내부 리그는 accessibilityHidden. 권한 조회 중 버튼 비활성화 및 조회 안내. 환경 Reduce Motion/scenePhase/화면 가시성에 따라 interaction Task와 native 동작 정지.
- RoutimoriSyncScene: 장식 장면 전체 hidden. FirstSyncView의 본문 상태와 버튼을 유지. Activity는 숫자 진행률을 꾸며내지 않고 'iCloud 기록 확인 중' 레이블.
- RoutimoriVacationScene: 장식 배경 hidden. VacationRestView의 slot이 하나의 이미지 의미를 제공하고 제목은 header trait, 설명은 세로 확장, ScrollView로 큰 글자 대응.
- **수정한 실제 불일치**: VacationRestView는 권한 확인 중 원화를 숨기지만 slot 레이블은 '해먹에서 쉬는 기본 피오'라고 읽을 수 있었다. isAwaitingVerification 조건에서 '피오 의상을 확인하는 중'으로 안내하도록 변경했다. 구매/착용 상태나 그림은 변경하지 않았다.

## 한계

이 문서의 검사는 소스 기반이다. VoiceOver의 실제 포커스 순서, 음성 출력, 스크롤 탐색 및 OS Reduce Motion 토글은 NOT_TESTED. 네이티브 XCTest에 Reduce Motion을 주입한 기존 증거는 OS 설정 조작과 다르다. 화면별 캡처는 validation 보고서의 실제 기기/호스트 조건을 따른다.

## 실제 작은 기기/태블릿 이미지 관찰

이번 전용 iPhone SE 3 및 iPad mini A17 Pro 시뮬레이터의 DashboardView 네이티브 호스트 normal/AX5 PNG를 직접 확인했다. 기본 크기에서 피오 발과 헤더 버튼 겹침은 보이지 않는다. SE AX5는 날짜가 3행, 인사가 2행으로 줄바꿈되어 요소가 분리된다. iPad AX5는 헤더 버튼이 다음 행으로 이동한다. 큰 글자에서 콘텐츠가 화면 아래로 이어지므로 스크롤 탐색 검증은 별도 필요하다. 전체 앱의 탐색바/탭/모든 장면/VoiceOver 읽기 순서를 검증한 결과가 아니다. 파일은 validation/small-device 및 validation/ipad-device에 있다.
