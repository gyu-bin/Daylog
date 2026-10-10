<p align="center">
  <img src="Daylog/Assets.xcassets/BrandIcon.imageset/DaylogIconLight.png" width="128" alt="Daylog 아이콘">
</p>

<h1 align="center">Daylog</h1>

<p align="center">
  <b>하루를 기록하다.</b><br>
  루틴과 식사를 매일 가볍게 적고, 쌓인 기록을 한눈에 보는 macOS 앱
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-43BFA6" alt="macOS 14+">
  <img src="https://img.shields.io/badge/SwiftUI-SwiftData-6395E8" alt="SwiftUI · SwiftData">
  <img src="https://img.shields.io/badge/iCloud-CloudKit-A78BFA" alt="iCloud · CloudKit">
  <img src="https://img.shields.io/badge/version-1.3.3-F59E63" alt="version 1.3.3">
</p>

<p align="center">
  <img src="docs/screenshots/dashboard-light.jpg" width="49%" alt="대시보드 (라이트)">
  <img src="docs/screenshots/dashboard-dark.jpg" width="40.8%" alt="대시보드 (다크)">
</p>

> 스크린샷의 내용은 화면 확인용으로 만든 예시 데이터입니다.

## 무엇을 하는 앱인가요

| | |
|---|---|
| ✅ **오늘의 루틴** | 그룹별로 묶은 루틴을 체크합니다. 요일을 정해 두면 해당하는 날에만 나옵니다. |
| 🍚 **식사 기록** | 아침·점심·저녁·간식과 메모를 자유롭게 적습니다. 입력하면 자동으로 저장됩니다. |
| 📈 **통계** | 오늘 달성률, 7일 평균, 연속 달성일, 기간별 추이, 활동 히트맵, 그룹·항목별 달성률. |
| 🗂 **루틴 관리** | 그룹과 항목을 추가·편집·순서 변경·보관·삭제합니다. 바꿔도 지난 날짜의 기록은 그대로입니다. |
| 🌗 **외관** | 시스템 설정 / 라이트 / 다크. Mac마다 따로 고를 수 있습니다. |
| ☁️ **iCloud 동기화** | 같은 Apple 계정의 Mac끼리 내 iCloud 개인 데이터베이스로 동기화합니다. 별도 계정이나 서버가 없습니다. |

<p align="center">
  <img src="docs/screenshots/statistics-light.jpg" width="49%" alt="통계">
  <img src="docs/screenshots/routines-light.jpg" width="49%" alt="루틴 관리">
</p>

## 설치

Xcode로 직접 빌드해서 설치합니다. 배포용 패키지는 없습니다.

### 필요한 것

- macOS 14 이상
- Xcode (Swift 5 이상을 지원하는 최신 버전)
- iCloud 동기화를 쓰려면 Apple 개발자 계정으로 Xcode에 로그인되어 있어야 합니다

### 한 번에 설치

```bash
git clone https://github.com/gyu-bin/Daylog.git
cd Daylog
Tools/install.sh
```

Release로 빌드해 `/Applications/Daylog.app`에 설치하고 실행합니다.
이미 Daylog가 실행 중이면 멈추므로, 앱을 종료(⌘Q)한 뒤 다시 실행하세요.

새 버전으로 올릴 때도 같습니다.

```bash
git pull
Tools/install.sh
```

기록은 앱이 아니라 `~/Library/Containers/com.mungyubin.daylog`에 저장되므로, 앱을 다시 설치하거나 지워도 남아 있습니다.
저장 형식이 바뀌는 버전으로 올릴 때는 앱이 열기 전에 자동으로 백업을 만들고, 실패하면 백업으로 되돌립니다.

### 다른 Apple 계정으로 빌드한다면

이 저장소의 서명 설정(팀, 번들 ID `com.mungyubin.daylog`, iCloud 컨테이너)은 만든 사람의 계정에 맞춰져 있습니다.
Xcode에서 **Signing & Capabilities**의 Team과 Bundle Identifier를 본인 것으로 바꾸면 됩니다.
iCloud 권한 없이 빌드하면 기록은 그 Mac에만 저장됩니다.

## 개발

```bash
# 빌드
xcodebuild -project Daylog.xcodeproj -scheme Daylog -configuration Debug -derivedDataPath build -allowProvisioningUpdates build

# 테스트 (메모리 저장소만 쓰므로 실제 기록을 건드리지 않습니다)
xcodebuild -project Daylog.xcodeproj -scheme Daylog -derivedDataPath build -allowProvisioningUpdates test
```

화면을 띄워 확인할 때는 실제 기록과 분리된 검증 전용 빌드(별도 번들 ID, iCloud 없음)를 씁니다.
방법은 [ARCHITECTURE.md](ARCHITECTURE.md)의 "검증 전용 빌드"에 있습니다.

```
Daylog/
├── App/          앱 시작, 화면이 읽는 상태(AppStore), 메뉴 명령
├── Models/       SwiftData 모델, 저장소 열기·백업·형식 변환
├── Services/     기록·루틴·통계·동기화 병합 규칙 (화면과 무관한 계산)
├── Views/        대시보드, 루틴 관리, 통계, 설정, 사이드바
├── Components/   카드, 통계 타일, 진행 표시 같은 공통 부품
└── Theme/        색과 간격, 외관 설정
DaylogTests/      단위 테스트와 형식 변환용 예시 저장소
Tools/            아이콘 생성, 설치 스크립트
```

설계 결정과 그 이유(날짜 처리, 과거 기록 보존, 동기화 병합, 삭제 방식 등)는 [ARCHITECTURE.md](ARCHITECTURE.md)에 정리되어 있습니다.

## 데이터와 개인정보

- 기록은 이 Mac에 저장되고, iCloud를 켠 빌드에서는 **내 iCloud 개인 데이터베이스**로만 동기화됩니다.
- 자체 서버, 회원 가입, 사용 정보 수집이 없습니다.
- 앱은 기록을 물리적으로 지우지 않습니다. 삭제한 루틴도 지난 날짜의 기록과 통계에는 남습니다.

## 알려진 한계

- 두 Mac 사이의 실제 동기화는 아직 충분히 검증되지 않았습니다. 병합 규칙은 테스트로만 확인했습니다.
- iCloud는 개발(Development) 환경을 씁니다.
- Dock·Finder의 앱 아이콘은 라이트 한 가지입니다. 다크 아이콘은 앱이 다크로 실행 중일 때 Dock에만 보입니다.

## 버전 기록

| 버전 | 내용 |
|---|---|
| 1.3.3 | 새 앱 아이콘(라이트·다크), 사이드바 브랜드 머리말 |
| 1.3.2 | 체크 해제가 되지 않던 오류 수정, 외관 설정(시스템/라이트/다크) |
| 1.3.1 | 루틴 관리 화면 개편, 삭제 기능, 기간별 통계와 활동 히트맵, 식사 타임라인 |
| 1.3 | 루틴 그룹, 멀티컬러 디자인, 식사 기록 조회 |
| 1.2 | iCloud 동기화 |
| 1.1 | 첫 버전: 대시보드, 루틴, 식사 기록, 통계 |
