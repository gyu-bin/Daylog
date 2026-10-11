# macOS 업데이트 운영

## 현재 상태

Sparkle 2.10.0은 macOS 앱 타깃에만 고정 버전으로 연결된다. 메뉴의 업데이트 확인은 구성 전에는 준비 중 안내를 보여 준다. `Config/Daylog-Info.plist`의 `DaylogUpdatesEnabled=false`와 빈 `SUPublicEDKey` 때문에 네트워크 조회·설치가 시작되지 않는다.

예정 feed는 `https://github.com/gyu-bin/Daylog/releases/latest/download/appcast.xml`이다. 아직 게시하지 않았다. Developer ID·CloudKit entitlement·release.sh 서명/공증 흐름을 변경하지 않았다. 전체 업데이트 완료가 아니라 활성화를 기다리는 기반 구현이다.

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
