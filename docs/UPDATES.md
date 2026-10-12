# macOS 업데이트 운영

## 현재 상태

Sparkle 2.10.0은 macOS 앱 타깃에만 고정 버전으로 연결된다. 메뉴의 업데이트 확인은 구성 전에는 준비 중 안내를 보여 준다. `Config/Daylog-Info.plist`의 `DaylogUpdatesEnabled=false`와 빈 `SUPublicEDKey` 때문에 네트워크 조회·설치가 시작되지 않는다.

예정 feed는 `https://github.com/gyu-bin/Daylog/releases/latest/download/appcast.xml`이다. 아직 게시하지 않았다. Developer ID·CloudKit entitlement·release.sh 서명/공증 흐름을 변경하지 않았다. 전체 업데이트 완료가 아니라 활성화를 기다리는 기반 구현이다.

## 설정 화면 (2026-10-12)

설정 → 정보의 버전 아래에 "업데이트" 줄이 있다. 메뉴의 "업데이트 확인…"과 같은 동작을 부른다.

- 준비 전(지금): "앱 안의 업데이트는 아직 준비 중" 안내와 [릴리스 페이지 열기](`https://github.com/gyu-bin/Daylog/releases/latest`). 메뉴의 준비 중 알림에도 같은 단추가 있다.
- 준비 후: [업데이트 확인…]. 새 버전·변경 사항·설치 승인·"최신 버전" 안내·오류는 Sparkle 표준 창이 보여 주고, 설정에는 마지막 결과(최신 / 새 버전 x.y.z / 실패 사유)와 확인 시각이 남는다.
- 결과 판정은 `UpdateCheckOutcome.resolve`: 새 버전 없음(Sparkle 1001)은 실패가 아니고, 사용자가 설치를 취소한 것(4007)도 실패가 아니다. 나머지 오류(내려받기·서명 검증·설치 실패)는 메시지와 함께 실패로 남는다.

꺼져 있는 동안에는 Sparkle이 시작되지 않으므로 "업데이트 없음 / 발견 / 설치 실패"의 실제 흐름은 검증하지 못했다. 판정 규칙만 단위 테스트로 확인했다.

## 버전 정책 (활성화 전에 정할 것)

지금의 배포(`Tools/update.sh`)는 Mac 버전을 1.5.1 (1)로 둔 채 같은 릴리스의 DMG만 바꾼다. Sparkle은 `CFBundleVersion`이 올라가야 새 버전으로 보므로, 켜면 이 방식으로는 업데이트가 전달되지 않는다. 제안:

1. "새 버전 올려" 때마다 Mac의 빌드 번호(`CURRENT_PROJECT_VERSION`)를 1씩 올리고, 버전(`MARKETING_VERSION`)은 패치 자리를 올린다(1.5.2, 1.5.3 …). 릴리스마다 새 태그가 생긴다.
2. `Tools/release.sh`가 DMG를 만든 뒤 `generate_appcast`로 `appcast.xml`을 만들어 DMG와 함께 올린다. 서명에는 키체인의 Sparkle 개인 키를 쓴다(저장소·로그에 넣지 않는다).
3. `Tools/update.sh`의 "같은 버전이면 DMG만 교체" 경로는 Sparkle을 켠 뒤에는 쓰지 않는다(같은 버전의 내용이 바뀌면 서명·길이가 appcast와 어긋난다).
4. 이 Mac은 지금처럼 `update.sh`로 바로 바꾸고, 다른 Mac은 앱 안의 업데이트로 받는다.

승인이 필요한 것: Sparkle 키 생성, 샌드박스 권한(mach-lookup 예외) 추가, `DaylogUpdatesEnabled` 켜기, 위 버전 정책, 첫 appcast 게시.

## 활성화 승인 후 수행할 작업

1. 배포 담당자가 Sparkle 배포물의 `generate_keys`로 Ed25519 키를 생성한다. 개인 키는 macOS 키체인 또는 보안 CI에 보관하고 파일·소스·로그에 넣지 않는다. 공개 키만 Info.plist의 `SUPublicEDKey`에 넣는다.
2. 샌드박스 통신 권한 변경을 승인받고 macOS entitlement에 현재 bundle ID의 `-spks`, `-spki` mach lookup 예외를 추가한다. Installer/Downloader XPC 설정은 plist에 준비되어 있다. 기존 iCloud 권한은 유지한다.
3. `DaylogUpdatesEnabled`를 켜고 기존 `Tools/release.sh`의 archive/export Developer ID·공증 DMG 과정을 따른다. 이번 개발 작업에서는 실행하지 않는다. Sparkle 내부 helper 서명도 exported app에서 확인한다.
4. 검증된 DMG 복사본만 담은 임시 폴더에서 공식 `generate_appcast`를 사용한다. 다운로드 주소는 해당 GitHub release tag의 DMG 자산으로 지정한다. appcast의 build 번호는 CFBundleVersion과 같고 이전보다 높아야 한다. 최소 macOS 버전은 Daylog의 14.0이다.
5. DMG의 EdDSA 서명·길이·URL 및 appcast XML을 검토한다. `SUVerifyUpdateBeforeExtraction=true`를 유지한다. 임의 서명 생략·검증 완화 코드를 추가하지 않는다.
6. 릴리스 게시 승인을 받고 **매 릴리스에 DMG와 appcast.xml을 함께** 올린다. latest/download 주소가 항상 최신 feed를 가리키도록 prerelease/draft 상태도 확인한다. 과거 앱이 따라올 수 있게 과거 항목을 보존한다.
7. 별도 테스트 Mac에서 이전 버전 → 최신 버전 업데이트·취소·네트워크 실패·변조 DMG 거부·잘못된 키 거부를 확인한다. 사용자 데이터와 iCloud 환경이 유지되는지 확인한다.

키 생성·권한 변경·공증·GitHub Releases 게시·실제 설치는 이번 작업의 승인 범위에서 제외되어 있다. 승인 전에는 updater 활성화 플래그를 켜지 않는다. 전체 백업은 복원 기능이 아니므로 업데이트 검증용 데이터 복구 수단으로 오해하지 않는다.

## 공식 참고

- [Sparkle 배포 및 서명](https://sparkle-project.org/documentation/): HTTPS, 공개 키, EdDSA archive 검증, archive/export 배포.
- [SwiftUI 프로그램 방식 연동](https://sparkle-project.org/documentation/programmatic-setup/): updater 수명과 메뉴 사용 가능 상태 관찰.
- [샌드박스 구성](https://sparkle-project.org/documentation/sandboxing/): Installer/Downloader와 필요한 통신 권한.
- [2.10.0 릴리스](https://github.com/sparkle-project/Sparkle/releases/tag/2.10.0): 사용 버전. 의존성 갱신 시 릴리스 내용을 검토하고 재검증한다.
