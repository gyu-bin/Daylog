<p align="center">
  <img src="Daylog/Assets.xcassets/BrandIcon.imageset/DaylogIconLight.png" width="120" alt="Daylog 아이콘">
</p>

<h1 align="center">Daylog</h1>

<p align="center">
  <b>하루를 기록하다.</b><br>
  루틴을 체크하고 식사를 적는, 가볍고 예쁜 Mac 앱<br>
  <sub>iPhone · iPad 버전도 준비 중이에요</sub>
</p>

<p align="center">
  <a href="https://github.com/gyu-bin/Daylog/releases/latest"><img src="https://img.shields.io/github/v/release/gyu-bin/Daylog?color=43BFA6&label=%EC%B5%9C%EC%8B%A0%20%EB%B2%84%EC%A0%84" alt="최신 버전"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-6395E8" alt="macOS 14 이상">
</p>

<p align="center">
  <a href="https://github.com/gyu-bin/Daylog/releases/latest"><b>⬇️ 내려받기</b></a>
</p>

<p align="center">
  <img src="docs/screenshots/dashboard-light.jpg" width="49%" alt="대시보드 (라이트)">
  <img src="docs/screenshots/dashboard-dark.jpg" width="40.8%" alt="대시보드 (다크)">
</p>

<br>

## ✨ 이런 걸 할 수 있어요

- ✅ **오늘의 루틴 체크** — 아침 루틴, 운동처럼 그룹으로 묶어서 하나씩 체크해요. 요일과 예정 시간도 정할 수 있어요.
- 🍚 **식사 기록** — 아침·점심·저녁·간식을 자유롭게 적어요. 저장 버튼은 없어요, 알아서 저장돼요.
- 📅 **캘린더** — 날짜를 누르면 그날의 루틴과 식사를 보고 고칠 수 있어요.
- 📈 **통계** — 달성률, 연속 달성일, 한눈에 보는 활동 달력까지.
- 🔔 **루틴 알림** — 정해 둔 시간에 알려 주고, 알림에서 바로 **완료**를 누를 수 있어요.
- 🧭 **메뉴 막대** — Mac 메뉴 막대에서 창을 열지 않고 오늘의 루틴을 체크해요.
- 🌗 **라이트 / 다크** — 취향대로 고르세요.
- ☁️ **iCloud 동기화** — 같은 Apple 계정의 Mac끼리 기록을 맞춰요.

<p align="center">
  <img src="docs/screenshots/statistics-light.jpg" width="49%" alt="통계">
  <img src="docs/screenshots/routines-light.jpg" width="49%" alt="루틴 관리">
</p>

<sub>스크린샷 속 내용은 예시 데이터예요.</sub>

<br>

## 📥 설치하기

1. [**최신 버전**](https://github.com/gyu-bin/Daylog/releases/latest)에서 `Daylog-…-macOS.dmg`를 받아요.
2. 열어서 **Daylog**를 **Applications** 폴더로 끌어다 놓아요.
3. Daylog를 실행해요. 처음엔 "인터넷에서 받은 앱"이라는 안내가 나오는데, **열기**를 누르면 돼요.

끝! macOS 14 이상이면 되고, 다른 프로그램은 필요 없어요.

**업데이트**는 새 버전을 받아서 같은 방법으로 덮어쓰면 돼요. 기록은 그대로 남아요.

<br>

## 🙋 자주 묻는 것

**기록은 어디에 저장되나요?**
내 Mac에 저장되고, iCloud를 쓰면 내 iCloud에만 올라가요. 따로 가입하는 계정도, 정보를 모으는 서버도 없어요.

**루틴을 지우면 예전 기록도 사라지나요?**
아니요. 지난 날짜의 기록과 통계는 그대로 남아요.

**다른 Mac에서도 같은 기록을 보고 싶어요.**
두 Mac에 같은 방법(위의 DMG)으로 설치하고, 같은 Apple 계정으로 iCloud에 로그인되어 있으면 돼요.
설정 화면에서 iCloud 상태를 확인할 수 있어요.

**알림이 안 와요.**
설정에서 **루틴 알림**을 켜고, 루틴 편집에서 **예정 시간**을 정해 주세요. 알림은 기기마다 따로 켜요.
이미 완료한 루틴은 알리지 않고, 기기가 꺼져 있거나 잠자는 중이면 제시간에 오지 않을 수 있어요.

**메뉴 막대 아이콘을 없애고 싶어요.**
설정의 **메뉴 막대에 Daylog 표시**를 끄면 돼요. 켜 두면 창을 닫아도 Daylog가 계속 실행돼요.

**iPhone이나 iPad에서도 쓸 수 있나요?**
같은 코드로 iPhone·iPad 앱을 만들고 있어요. 아직 App Store나 TestFlight로 나눠 드리지는 않고, Xcode가 있으면 직접 빌드해서 쓸 수 있어요(아래 "개발자라면" 참고).
iPhone·iPad에서는 홈 화면 **위젯**(작게·중간·크게)으로 오늘의 루틴을 보고, 큰 위젯에서는 바로 체크할 수 있어요. 체크는 앱의 저장소에 반영된 뒤 완료로 표시하며, 저장 대기 상태가 남으면 앱을 열어 다시 시도할 수 있어요.

**휴가 모드**는 설정의 휴가 관리 또는 캘린더에서 하루·기간별로 지정해요. 기존 체크와 식사 기록을 보존하고 루틴 통계·알림에서 제외하며, 휴가 전후의 연속 달성 기록은 이어집니다. 모든 기기에서 휴가 기능이 있는 버전을 사용해 주세요.

루틴 알림은 앞으로 1년 안의 가까운 일정부터 최대 60개를 예약해요. 마지막 예약일은 설정에서 확인할 수 있고, 앱을 열면 다시 보충합니다. 앱을 장기간 열지 않으면 마지막 예약 이후에는 알림이 중단될 수 있어요.
iPhone·iPad와 Mac 사이의 iCloud 동기화, 실제 기기에서의 알림·위젯은 아직 확인하지 못했어요.

<br>

## 🛠 개발자라면

<details>
<summary>소스에서 빌드하기, 배포하기, 구조 보기</summary>

<br>

**빌드해서 설치** (Xcode 필요)

```bash
git clone https://github.com/gyu-bin/Daylog.git
cd Daylog
Tools/install.sh
```

**테스트**

```bash
xcodebuild -project Daylog.xcodeproj -scheme Daylog -derivedDataPath build -allowProvisioningUpdates test
```

**iPhone · iPad 앱 빌드** (시뮬레이터)

```bash
xcodebuild -project Daylog.xcodeproj -scheme DaylogiOS -derivedDataPath build-ios \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

실제 기기에 넣으려면 Xcode에서 `DaylogiOS` 스킴을 고르고 기기를 연결해 실행하세요. 시뮬레이터에서는 iCloud 없이 기기 안에만 저장돼요.

**배포판(DMG) 만들기**

```bash
Tools/release.sh                 # 테스트 → 서명 → 공증 → DMG → 검증
Tools/release.sh --publish-only  # 방금 만든 DMG를 GitHub Release에 올리기
```

**알아 둘 점**

- 내려받은 앱(DMG)과 Xcode로 빌드한 앱은 서로 다른 iCloud 환경(Production / Development)을 써서, 둘 사이에는 동기화되지 않아요.
  어느 쪽인지는 설정의 **iCloud 환경**에 나와요. Xcode로 기기에 넣은 iPhone·iPad 앱도 Development라서, DMG로 설치한 Mac과는 맞춰지지 않아요.
- 한 Mac에서 설치 방법을 바꿨다면, 앱을 끄고 아래를 한 번 실행하면 기존 기록을 새 환경에 다시 올려요(백업을 먼저 만들어요).

  ```bash
  open -n /Applications/Daylog.app --args -DaylogReuploadAll YES
  ```

- DMG 안의 앱은 Apple 공증을 받았지만, DMG 파일 자체는 서명되지 않았어요.
- 서명 설정은 만든 사람의 Apple 계정에 맞춰져 있어요. 다른 계정으로 빌드하려면 Xcode의 Signing & Capabilities에서 Team과 Bundle Identifier를 바꾸세요.

**폴더 구조**

```
Daylog/
├── App/          앱 시작, 화면이 읽는 상태, 플랫폼별 차이(Platform.swift), 창 없이 도는 일(AppRuntime.swift)
├── Models/       저장 모델, 백업, 형식 변환
├── Services/     기록·루틴·통계·동기화 규칙
├── Views/        화면
├── Components/   공통 부품
└── Theme/        색과 외관
DaylogShared/     앱과 위젯이 함께 쓰는 코드 (날짜, 색, 위젯 데이터)
DaylogWidgets/    iPhone·iPad 홈 화면 위젯
DaylogTests/      테스트 (macOS에서 실행)
Tools/            설치·배포·아이콘 스크립트
```

`Daylog/` 폴더 하나를 macOS 앱(`Daylog`)과 iPhone·iPad 앱(`DaylogiOS`)이 함께 써요. 위젯(`DaylogWidgets`)은 `DaylogShared/`만 함께 써요.

설계 결정과 그 이유는 [ARCHITECTURE.md](ARCHITECTURE.md)에 있어요.

</details>

<br>

## 📝 버전 기록

| 버전 | 달라진 점 |
|---|---|
| 1.5.0 | 루틴 알림(알림에서 바로 완료), Mac 메뉴 막대 빠른 체크, iPhone·iPad 홈 화면 위젯(준비 중) |
| 1.4.0 | 루틴 관리와 편집 화면 새 단장(요일 빠른 선택, 예정 시간), 식사 기록·캘린더 메뉴, iPhone·iPad 앱(준비 중) |
| 1.3.5 | iCloud 환경을 옮길 때 기록을 다시 올리는 기능, 설정에 iCloud 환경 표시 |
| 1.3.4 | 오늘의 루틴 화면을 더 단순하게, 첫 DMG 배포 |
| 1.3.3 | 새 앱 아이콘과 사이드바 |
| 1.3.2 | 체크 해제가 안 되던 문제 수정, 라이트/다크 선택 |
| 1.3.1 | 루틴 관리 새 단장, 삭제 기능, 기간별 통계와 활동 달력 |
| 1.3 | 루틴 그룹, 컬러풀한 디자인, 지난 식사 보기 |
| 1.2 | iCloud 동기화 |
| 1.1 | 첫 버전 |
