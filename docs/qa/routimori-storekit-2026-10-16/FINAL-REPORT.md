# Routimori 자율 구현 결과 — 2026-10-16

**전체 상태: PARTIAL.** 로컬 StoreKit 구매 기반과 중앙 착장 연결을 구현하고 실제 앱에서 검증했습니다. 실결제 출시 준비 완료, 모든 장면의 의상 적용 완료, 13개 의상의 독립 관절 애니메이션 완료를 의미하지 않습니다.

작업 위치: `/Users/mungyubin/Desktop/Coding/Daylog`, `main`. 기존 변경을 보존했고 커밋·푸시·배포·App Store Connect 등록·실결제·프로덕션 앱 교체를 하지 않았습니다. 실제 카탈로그는 **기본 무료 1개 + 유료 13개 = 총 14개**입니다.

## 구현 및 검증 상태

| 항목 | 상태 | 확인한 범위 / 남은 조건 |
| --- | --- | --- |
| 상품 등록표 | PASS | 유료 13개 비소모성 ID와 원화 매핑, KOR/ko_KR 로컬 구성, 목표 ₩2,000 |
| 가격 표시 | PARTIAL | 실제 `Product.displayPrice`의 ₩2,000 표시 확인. 해당 SDK에서 숫자 `Product.price`가 2로 보고되는 불일치 존재. 로컬 구성값은 2000 유지 |
| 구매·검증·소유권·복원 구현 | PASS | 검증된 알려진 비소모성 거래만 인정, 중복 처리·권한 갱신·복원·실패/대기 상태·완료 처리 동시 실행 보호 구현 |
| iPhone 실제 Apple 로컬 구매창 | PASS | 벚꽃 구매·취소·복원·착용·프로세스 재실행 후 복구. Xcode 테스트 환경이며 실제 청구 없음 |
| 13개 상품 자동 구매·착용·원화 로딩 | PASS / 제한적 | 최신 단독 실행 통과. 과거 마지막 거래 미완료 실패도 기록 유지. 후속 관측 테스트는 최대 3초 안에 미완료 목록이 비는 것을 요구하며 거래를 조작하지 않음 |
| StoreKit 전체 통합 검증 | PARTIAL | 최신 전체 실행 11개 중 7 통과·4 실패. 후속 단독 성공을 전체 성공으로 대체하지 않음 |
| Mac 실제 구매 확인창 | FAIL | 최종 로컬 재시도에서도 구매 진행 상태에 머물고 Apple 확인창이 나타나지 않음. 테스트 호스트 종료 성공과 구매 성공은 별개 |
| 중앙 착장 상태 | PASS | 검증된 소유권과 선택값을 공통 해석. 상점 미리보기는 소유권·착용값을 변경하지 않음 |
| 홈·성장 카드·스플래시 | PARTIAL | 기존 고해상도 원화와 공통 착장 연결, Mac/iPhone 대표 화면 확인. 전체 의상/모든 화면 크기/콜드 런치 조합 미검증 |
| 휴가 낮·밤 및 클라우드 3상태 | PARTIAL | 중앙 상태 연결 및 누락 안내. 전용 의상 원화가 없어 승인된 기본 장면 유지. 밤은 실제 밤 원화 사용 |
| 기타 화면 | PARTIAL | 주간 회고·복귀 안내·옷장 연결. 전체 사용자 이동 경로와 반응 동작은 추가 검증 필요 |
| 단계 1–4 | PARTIAL | Lv.1–9 / 10–24 / 25–49 / 50+ 유지. 현재 의상은 동일 원화이며 단계별 다른 외형은 없음 |
| 애니메이션 | PARTIAL | Christmas 220pt 전신 점프 실제 영상 확인. 13개 전체의 눈·날개·소품 독립 동작 완료 아님 |
| 동작 줄이기 | PARTIAL | 실제 iPhone 설정 ON에서 활성 창의 리그/트랙 0 확인. 모든 화면과 OFF 재개·화면 밖 복귀 조합 미검증 |
| Mac / iPhone Debug 빌드 | PASS | 최종 앱 및 테스트 호스트 컴파일 확인 |
| iPhone Release 빌드 | PASS | 시뮬레이터 대상 Release 컴파일. 물리 기기 서명·아카이브·배포 검증 아님 |
| Mac Release 빌드 | PASS | Release 컴파일 확인. 최종 추가 빌드 로그는 아래 참고 |
| 관련 단위 테스트 | PASS | 4개 제품 관련 테스트 묶음 44개 통과 |
| 실기기 Sandbox / 실제 판매 | NOT_TESTED | 실행하지 않음. 일반 실행과 Release 판매는 잠금 상태 |
| 앱 아이콘 변경 | PARTIAL | 소유권/플랫폼 가드 구현. 등록된 프리미엄 대체 아이콘 원화가 없어 실제 변경 제공 안 함 |
| 장시간 성능·메모리 안정성 | NOT_TESTED | 아래 짧은 관찰만 수행; 합격 기준 비교 없음 |

## 실제 화면과 영상

- [실제 홈 — 벚꽃 착장 재실행 후 유지](ios-home-cherry-relaunch-closeup.png)
- [iPhone 성장 카드 — 크리스마스](ios-global-christmas-growth-light.png)
- [Mac 성장 카드 — 한복 다크](mac-global-hanbok-growth-dark.png)
- [iPhone 스플래시 — 할로윈](ios-global-halloween-splash-verified.png)
- [휴가 밤 — 기본 장면 유지 및 누락 안내](ios-global-halloween-vacation-night-verified.png)
- [클라우드 성공 — 기본 장면 및 누락 안내](ios-global-halloween-cloud-success-dark-verified.png)
- [Apple Xcode 결제창](ios-apple-xcode-purchase-sheet.png), [구매 성공](ios-apple-purchase-success.png), [복원 성공](ios-restore-success.png)
- [실제 Christmas 점프 영상 10초](ios-native-christmas-jump.mp4)
- [실제 동작 줄이기 ON](ios-native-reduce-motion-on-a.png)

성장·휴가·클라우드 비교는 테스트용 외곽 컨트롤 안에서 실제 제품 View를 렌더링한 화면입니다. 실제 CloudKit 동기화나 휴가 기록을 만들어 캡처한 것이 아닙니다. `capture-drafts`와 시간 만료 후 캡처는 증거에서 제외합니다.

## 남은 원화

원화 77개 PNG와 카탈로그 88개 JSON은 시작 시점과 바이트가 동일합니다. 기존 13개 유료 의상을 재생성하거나 낮은 품질 이미지로 교체하지 않았습니다.

각 프리미엄 의상에 아래 5가지 장면이 필요합니다. **13 × 5 = 65개**, 정확한 식별자와 자세 요구 사항은 [누락 원화 목록](missing-scene-artwork.csv)에 있습니다.

1. 낮 해먹에서 음료를 든 기대어 쉬는 모습
2. 밤 해먹의 동일 자세와 밤 조명에 맞는 모습
3. 태블릿을 든 클라우드 다운로드 모습
4. 클라우드 완료의 기쁜 양날개 모습
5. 태블릿을 든 클라우드 오류 표정

서 있는 의상 PNG를 해먹이나 태블릿 장면에 덮어씌우지 않았습니다. 단계별 고유 외형, 모든 의상의 독립 눈·날개·소품 레이어, 실제 대체 앱 아이콘도 별도 작업이 필요합니다. 기존 네 가지 레이어 파일럿은 별도 DEBUG 선택 조건이 있으며 전체 카탈로그 완성을 뜻하지 않습니다.

## 테스트와 성능

[상세 StoreKit 결과](STOREKIT-RESULTS.md), [네이티브 구매 검증](NATIVE-REVIEW.md), [네이티브 동작 검증](NATIVE-MOTION.md), [화면 호환성 표](../pio-global-outfit-2026-10-16/SCREEN-COMPATIBILITY-MATRIX.md), [코드 검토](code-review.md)를 함께 남겼습니다.

- 44개 단위 테스트: [최종 로그](mac-final-unit-allowed.log)
- 전체 iOS StoreKit 11개: [7 통과·4 실패 로그](ios-storekit-clean-fixture.log)
- 후속 13개 상품 단독 검증: [통과 로그](ios-finish-observation.log). 첫 관측에서 이미 미완료 목록이 비었음. SDK 지연 또는 이전 실패 원인이 해결됐다고 입증한 결과는 아님
- Mac Debug 최종 검증 호스트: [빌드 로그](mac-final-review-build.log)
- iPhone Release: [빌드 로그](ios-release-build.log)
- Mac Release: [초기 로그](mac-release-build.log), [최종 추가 빌드 로그](mac-release-final-build.log)

실제 활성 Christmas 점프를 iPhone 시뮬레이터에서 15.175초 관찰한 프로세스 CPU는 한 코어 기준 약 **0.86%**, RSS는 **404,352–407,376 KiB**였습니다. Device Hub 녹화도 실행 중이었으며 대조군이 없습니다. [원시 측정](ios-active-christmas-jump-samples.json)

따라서 기존 보고값 16.08% 대비 개선율, 모든 의상의 성능 PASS, 메모리 누수 없음은 주장하지 않습니다. 이전 Mac 0.33% 관찰은 비활성 검증 호스트였을 가능성이 있어 활성 애니메이션 성능 근거로 사용하지 않습니다.

## 상품 ID와 다음 작업

13개 App Store Connect 상품 ID, 한국어 설명, 목표 KRW 2,000 설정 절차는 [상품 등록 문서](../../../APP_STORE_CONNECT_PRODUCTS.md)에 있습니다. 실제 등록은 수행하지 않았습니다.

다음 순서가 적절합니다.

1. Mac 구매 확인창 문제와 StoreKit 통합 테스트의 취소·보류·환불 이벤트 실패를 해결하고 격리/전체 실행을 함께 통과시키기.
2. 65개 장면 원화 및 단계별/독립 동작 레이어를 승인된 디자인으로 준비하고 공통 상태에 연결하기.
3. 모든 의상·크기·밝기·화면 밖 복귀·동작 줄이기를 동일 조건으로 비교하고 장시간 CPU/메모리 측정하기.
4. 별도 승인 후 App Store Connect 등록·실기기 Sandbox 검증. 출시 전까지 현재 판매 잠금 유지하기.

보존 확인: [최종 해시 결과](final-preservation-check.json). 168개 보호 대상 중 167개 동일하며, 변경된 한 파일은 의도한 `Saessagi.swift`의 중앙 착장 연결입니다. 그림 파일 변경은 없습니다. SwiftData 모델·CloudKit 설정·기존 번들 ID는 변경하지 않았습니다.
