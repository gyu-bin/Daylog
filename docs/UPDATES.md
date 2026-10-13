# macOS 앱 안의 업데이트 (Sparkle 2)

Daylog의 Mac 앱은 GitHub Releases에 올린 DMG로 배포한다. 앱 안의 업데이트는 Sparkle 2.10.0이 맡는다:
새 버전 확인 → 변경 사항 표시 → 사용자가 [설치] → 내려받기 → 서명 검증 → 앱 종료·교체 → 다시 열기.
자체 설치기는 만들지 않았다. iPhone·iPad는 App Store·TestFlight로 받는다(이 설정을 보여 주지 않는다).

## 지금 상태 (2026-10-12)

| 항목 | 상태 |
|---|---|
| 배포판에서 켜기 | **켜짐** — 1.5.2 (2)부터. `DaylogUpdatesEnabled=true`, 공개 키 등록 |
| Sparkle 서명 키(배포용) | 로그인 키체인에 있음(2026-10-12 생성). 백업은 아래 "서명 키" |
| 첫 전환 | 1.5.1 이하는 1.5.2를 한 번 수동 설치. 그다음(1.5.3)부터 앱 안에서 받는다 |
| 운영 경로의 설치·자동 재실행 | 1.5.3을 올릴 때 처음 확인한다(아래 "검증") |
| GitHub | `v1.5.2`에 DMG와 `appcast.xml` 게시(2026-10-12). 피드 주소가 이 appcast를 가리키는 것을 확인 |
| 기기 밖 키 백업 | **아직 없음** — 로컬 사본만 있다. "서명 키 → 백업" |
| 다음 릴리스 | 1.5.3 (3) 산출물 준비·검증 끝(2026-10-13, `build/release`). 게시는 승인 대기: `Tools/release.sh --publish-only --allow-unsigned-dmg` |

## 서명 키 (Sparkle EdDSA)

- 개인 키: 이 Mac의 로그인 키체인. 항목 이름(서비스) `https://sparkle-project.org`, 계정 `ed25519`. Sparkle의 `generate_keys`가 만들었다.
- 공개 키: `Config/Daylog-Info.plist`의 `SUPublicEDKey`. 공개해도 되는 값이고 저장소에는 이것만 있다.
- **개인 키는 저장소·문서·로그 어디에도 넣지 않는다.** 화면에 출력하지도 않는다.
- 이 키를 잃으면 이미 설치된 앱(1.5.2 이후)에 업데이트를 보낼 수 없다. 키를 새로 만들면 그 앱들은 새 서명을 거부한다.

### 백업

- 로컬 사본: `~/Library/Application Support/DaylogRelease/sparkle-ed25519-private-key.txt` (폴더 700, 파일 600, 저장소 밖).
  `generate_keys -x`로 내보낸 것이고, 키체인의 키와 같은 서명을 내는 것을 확인했다.
- 이 사본은 같은 Mac에 있어 디스크를 잃으면 함께 사라진다. **기기 밖의 안전한 곳(암호 관리자의 보안 메모, 암호화한 외장 저장소)에 옮겨 두고**,
  옮긴 뒤에는 로컬 사본을 지워도 된다. 메일·메신저·클라우드 폴더에 평문으로 두지 않는다.

### 복구 (새 Mac, 키체인 초기화 뒤)

```bash
BIN=build/update/derived/SourcePackages/artifacts/sparkle/Sparkle/bin   # 한 번 빌드하면 생긴다
$BIN/generate_keys -f <백업 파일>     # 개인 키를 로그인 키체인에 넣는다
$BIN/generate_keys -p                 # 출력된 공개 키가 Config/Daylog-Info.plist의 SUPublicEDKey와 같아야 한다
```

`Tools/release.sh`는 게시 전에 이 둘이 같은지 확인하고, 다르면 게시하지 않는다.

### 키를 바꿔야 할 때

바로 바꾸지 않는다. 설치된 앱은 옛 공개 키만 믿는다. 옛 키로 서명한 릴리스에 새 공개 키를 넣어 먼저 퍼뜨린 뒤, 그다음 릴리스부터 새 키로 서명한다.
옛 키를 잃어 그럴 수 없으면 사용자가 새 DMG를 한 번 수동으로 설치해야 한다.

## 구성

- 피드: `https://github.com/gyu-bin/Daylog/releases/latest/download/appcast.xml`. 최신 릴리스에 `appcast.xml`을 자산으로 올린다.
  앱은 이 주소만 받아들인다(`UpdateConfiguration.isReady`). 다른 주소·http·쿼리가 붙은 주소는 거부한다.
- 내려받는 파일: 같은 릴리스의 `Daylog-v<버전>-macOS.dmg`(소스 ZIP이 아니다). 안의 앱은 Developer ID 서명·공증·스테이플.
- 서명은 두 가지이고 서로 별개다.
  1. Apple: 앱의 Developer ID 서명과 공증(`Tools/release.sh`, Xcode 계정의 Cloud Managed 인증서).
  2. Sparkle: DMG 파일의 EdDSA 서명. appcast의 `sparkle:edSignature`에 들어가고, 앱은 내려받은 파일을 풀기 전에 앱에 든 공개 키(`SUPublicEDKey`)로 검증한다(`SUVerifyUpdateBeforeExtraction=true`).
  DMG 자체는 Apple 서명이 없으므로 EdDSA 검증이 유일한 통로다. 검증을 건너뛰는 설정은 없다.
- 샌드박스: 앱에는 네트워크 권한이 없다. 피드와 DMG는 Sparkle의 Downloader XPC가 받고, 설치는 Installer XPC가 샌드박스 밖의 `Autoupdate`를 띄워서 한다.
  이를 위해 권한 파일에 `com.apple.security.temporary-exception.mach-lookup.global-name`(`<번들 ID>-spks`, `-spki`)을 넣었다. iCloud 권한은 그대로다.
- 자동 확인: `SUEnableAutomaticChecks=true`, 간격 하루(`SUScheduledCheckInterval=86400`). 앱을 열 때 마지막 확인이 하루를 넘었으면 확인한다.
  설정에서 끌 수 있다. `SUAutomaticallyUpdate=false`: 설치는 늘 사용자가 눌러야 한다. 사용 정보는 보내지 않는다.
- 저장소와 설정: 업데이트는 앱 번들만 바꾼다. SwiftData 저장소, 사용자 설정, iCloud 컨테이너·환경(Production)은 번들 ID와 서명이 같아 그대로 이어진다.

## 화면

- 메뉴: Daylog → "업데이트 확인…".
- 설정 → 정보: 현재 버전, 상태 한 줄(최신 / 새 버전 x.y.z / 실패 사유)과 마지막 확인 시각, [업데이트 확인…], "자동으로 업데이트 확인" 스위치(`UpdateSettingsRow`).
  둘 다 `DaylogUpdater.checkForUpdates()`를 부른다. 새 버전 안내·변경 사항·진행·오류 창은 Sparkle 표준 창이다.
- 업데이트를 받을 수 없는 빌드(키가 없는 1.5.1 이하, 개발 빌드)에서는 그 사실을 알리고 릴리스 페이지를 연다. 켜진 빌드에서는 이 대체 화면이 나오지 않는다.
- 결과 판정(`UpdateCheckOutcome.resolve`): 새 버전 없음(1001)과 사용자의 설치 취소(4007)는 실패가 아니다. 그 밖의 오류는 메시지와 함께 실패로 남는다.

캡처: `docs/updates/settings-about-configured.jpg`(켜진 상태의 설정), `docs/updates/update-test-after-install.jpg`(시험 설치 뒤).

## 첫 업데이트 전환

1.5.1 (1)과 그 이전 버전은 업데이트가 꺼져 있어(공개 키 없음) appcast를 보지 않는다. 강제로 실행할 방법은 없다.

- 처음 한 번: 1.5.2를 GitHub 릴리스에서 DMG로 받아 설치한다(이 Mac은 `Tools/update.sh`가 바꿨다).
- 1.5.3부터: 앱 안에서 받는다.
- 1.5.1 이하에 든 Sparkle 공개 키가 없으므로 키 호환 문제는 없다.

## 새 버전을 배포하는 방법

```bash
Tools/bump-version.sh 1.5.3        # Mac 버전을 올리고 빌드 번호를 +1, 릴리스 노트 틀을 만든다
$EDITOR docs/releases/v1.5.3.md    # 달라진 점을 적는다(업데이트 창과 GitHub 릴리스에 그대로 나온다)
git commit -am "mac: 1.5.3" && git push
Tools/update.sh                    # 이 Mac 교체 → 공증 → DMG → Sparkle 서명·appcast → GitHub 게시 → 공개 주소 확인
```

- `Tools/update.sh`는 끝에서 `Tools/release.sh --skip-tests --publish --allow-unsigned-dmg`를 부른다. 이 Mac을 건드리지 않고 게시만 하려면 `Tools/release.sh --publish …`를 직접 쓴다.
- 같은 버전은 다시 게시하지 않는다. 이미 게시한 버전의 파일도 바꾸지 않는다(appcast의 서명·크기와 어긋난다). 앱 소스를 고쳤으면 버전을 올린다.
- 게시 순서(`release.sh`): 초안 릴리스에 DMG와 `appcast.xml`을 올림 → 올라간 파일의 이름·크기 확인 → 공개(latest) → 공개 주소에서 DMG 크기와 피드 내용 확인.
  피드 주소는 공개하는 순간 새 릴리스를 가리키고, 그때 DMG는 이미 올라가 있다.
- appcast(`Tools/appcast.sh`): 지금 공개된 appcast를 내려받아 과거 항목을 이어 가고, 새 항목의 버전·빌드 번호·URL·파일 크기·EdDSA 서명·릴리스 노트를 DMG와 대조한다. 어긋나면 게시하지 않는다.
  공개된 피드의 항목이 하나라도 빠지거나 바뀌면 실패한다. 공개된 피드가 있는데 받지 못하면 만들지 않는다(과거 항목이 빠진 피드를 올리지 않기 위해).
- 만들어 둔 것을 나중에 올릴 때(`release.sh --publish-only`)는 appcast를 **다시 만들지 않는다.** 이미 만들어 확인한 파일을 DMG·공개 피드와 다시 대조만 하고(`appcast.sh --check`) 그대로 올린다.
  다시 만들면 게시 시각이 달라져 확인한 파일과 다른 것이 올라간다.
- 게시 전 확인(`release.sh`): 앱에 든 공개 키가 키체인의 서명 키와 짝인지, 피드 주소, 설치 도구 권한, Sparkle 안의 도구들이 앱과 같은 팀으로 서명됐는지.
- iPhone·iPad(TestFlight)는 전과 같다: iOS 빌드 번호를 올려 따로 올린다.

## 검증

### 격리 환경에서 한 것 (`Tools/update-test.sh`)

실제 앱·기록·GitHub와 분리했다: 번들 ID `com.daylog.updatetest`(iCloud 권한 없음, 자체 컨테이너), 설치 위치 `~/Library/Caches/DaylogUpdateTest`,
피드 `http://127.0.0.1:8765`(앱은 시험·검증 번들일 때만 이 주소를 받아들인다), 이 시험 전용 EdDSA 키(`build/update-test`, Git에 안 들어감).
앱과 Sparkle의 도구들은 이 Mac의 개발 인증서로 같은 팀 서명. 빌드는 Release, 샌드박스·Downloader·Installer XPC는 배포판과 같은 구성이다.

| 시나리오 | 결과 |
|---|---|
| 옛 버전 9.0.0 (900) 실행 → 피드 확인 | 앱이 스스로 `appcast.xml`을 받음(샌드박스 안에서 Downloader XPC로) |
| 새 버전 감지 → 내려받기 | DMG를 받음 |
| Sparkle 서명 검증 | `Autoupdate: OK: EdDSA signature is correct for update` |
| 앱 종료 → 교체 | 종료 뒤 설치 위치의 앱이 9.0.1 (901), 코드 서명 유효 |
| 새 버전 실행·기록 보존 | 9.0.1이 열리고, 업데이트 전에 넣은 루틴·체크·식사 기록·통계가 앞뒤로 같음(스크립트 덤프 비교) |
| 업데이트 없음(같은 버전) | 피드만 받고 내려받지 않음, 다시 설치하지 않음 |
| 서명 불일치(DMG 한 바이트 변조, 크기 같음) | `EdDSA signature does not match` → 설치 안 됨, 9.0.0 유지 |
| 잘못된 다운로드 URL(404) | 내려받기 오류 → 설치 안 됨, 9.0.0 유지 |
| 네트워크 오류(피드 서버 없음) | 확인 실패만 기록, 앱은 정상 동작, 9.0.0 유지 |

위 설치는 "조용한 설치" 변형(`DAYLOG_UPDATE_TEST_SILENT=1`: Sparkle이 내려받아 두었다가 앱 종료 때 설치)으로 했다.
시험용 앱의 창을 누르는 권한을 받지 못해, 창에서 누르는 흐름은 하지 못했기 때문이다.

### 하지 못한 것

- Sparkle 창에서의 흐름: [업데이트 확인…] → 새 버전·릴리스 노트 창 → [설치] → 진행 → **자동으로 다시 열림**. (조용한 변형은 다시 열지 않는다.)
- 내려받는 중 취소, 다시 열기 실패.
- 설정의 상태 줄이 실제 확인 뒤 "최신 / 새 버전 / 실패"로 바뀌는 모습(판정 규칙은 단위 테스트).
- Developer ID로 서명·공증한 빌드에서, GitHub의 실제 피드로 하는 설치(1.5.3을 올릴 때 한다).

1.5.2 게시(2026-10-12)에서 확인한 것: 키체인의 배포용 키로 서명, 초안 → 공개 → 공개 주소 확인, 공개 주소에서 내려받은 DMG의 체크섬·EdDSA 서명·공증.
게시 직후 2분쯤은 피드 주소가 이전 릴리스를 가리킬 수 있다(GitHub가 `latest/download` 응답을 잠깐 기억한다). `release.sh`가 기다렸다가 확인한다.

직접 해 보려면:

```bash
Tools/update-test.sh prepare    # 옛/새 시험용 앱, DMG, appcast
Tools/update-test.sh serve      # 다른 터미널 탭에서
Tools/update-test.sh launch     # 옛 버전 실행 → 메뉴 Daylog → 업데이트 확인… → 설치
Tools/update-test.sh status     # 9.0.1 (901)이 됐는지
Tools/update-test.sh clean
```

## 공식 참고

- [Sparkle 문서](https://sparkle-project.org/documentation/): 배포, EdDSA 서명, appcast.
- [샌드박스 구성](https://sparkle-project.org/documentation/sandboxing/): Installer/Downloader와 mach-lookup 권한.
- [게시](https://sparkle-project.org/documentation/publishing/): `generate_appcast`, `sign_update`.
