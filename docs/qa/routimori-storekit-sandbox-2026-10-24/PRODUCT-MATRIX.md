# PRODUCT-MATRIX — 피오 유료 의상 13종 (2026-10-24)

조회 방법: 앱의 Debug 전용 읽기 진단(`DebugScript`의 `storeProbe`)이 `AppTransaction`과 `Product.products(for:)`를 직접 부르고 결과만 적는다.
구매·복원·거래 완료는 하지 않는다.

| 환경 | 기기 | 앱 영수증 | 판정 |
|---|---|---|---|
| **A. Apple App Store 서버** | iPad mini 시뮬레이터(로컬 StoreKit 설정을 쓴 적 없음), 계정 없음 | 없음(`noAccount`) | **실제 Apple 조회.** 로컬 파일에 없는 미국 스토어프론트·USD 가격이 돌아왔다 |
| B. 로컬 StoreKit 설정 | iPhone 17 QA 시뮬레이터(예전에 `Routimori.storekit`로 실행한 기기) | `Xcode` | 로컬 설정 값. **Sandbox 결과로 세지 않음** |

원본 출력: [A](evidence/probe-apple-server-ipad-noaccount.txt) · [B](evidence/probe-local-config-iphone17.txt) · [Sandbox 빌드, A와 같은 기기](evidence/probe-sandbox-build-ipad-noaccount.txt)

## 상품별 결과

| 의상 | 제품 ID | A 조회(Apple) | A 유형 | A 표시 이름 | A 가격(미국) | 한국 가격(₩) | 구매 | 검증된 소유 | 착용 | 재실행 유지 |
|---|---|---|---|---|---|---|---|---|---|---|
| 벚꽃 | outfit.cherryblossom | ✅ | 비소모품 | 벚꽃 피오 | $1.99 | NOT_TESTED | NOT_TESTED | NOT_TESTED | NOT_TESTED | NOT_TESTED |
| 여름휴가 | outfit.summer | ✅ | 비소모품 | 여름휴가 피오 | $1.99 | NOT_TESTED | NOT_TESTED | NOT_TESTED | NOT_TESTED | NOT_TESTED |
| 가을 | outfit.autumn | ✅ | 비소모품 | 가을 피오 | $1.99 | NOT_TESTED | NOT_TESTED | NOT_TESTED | NOT_TESTED | NOT_TESTED |
| 겨울 | outfit.winter | ✅ | 비소모품 | 겨울 피오 | $1.99 | NOT_TESTED | NOT_TESTED | NOT_TESTED | NOT_TESTED | NOT_TESTED |
| 할로윈 | outfit.halloween | ✅ | 비소모품 | 할로윈 피오 | $1.99 | NOT_TESTED | NOT_TESTED | NOT_TESTED | NOT_TESTED | NOT_TESTED |
| 크리스마스 | outfit.christmas | ✅ | 비소모품 | 크리스마스 피오 | $1.99 | NOT_TESTED | NOT_TESTED | NOT_TESTED | NOT_TESTED | NOT_TESTED |
| 한복 | outfit.hanbok | ✅ | 비소모품 | 한복 피오 | $1.99 | NOT_TESTED | NOT_TESTED | NOT_TESTED | NOT_TESTED | NOT_TESTED |
| 카페 | outfit.cafe | ✅ | 비소모품 | 카페 피오 | $1.99 | NOT_TESTED | NOT_TESTED | NOT_TESTED | NOT_TESTED | NOT_TESTED |
| 학생 | outfit.student | ✅ | 비소모품 | 학생 피오 | $1.99 | NOT_TESTED | NOT_TESTED | NOT_TESTED | NOT_TESTED | NOT_TESTED |
| 운동 | outfit.workout | ✅ | 비소모품 | 운동 피오 | $1.99 | NOT_TESTED | NOT_TESTED | NOT_TESTED | NOT_TESTED | NOT_TESTED |
| 비 오는 날 | outfit.rainy | ✅ | 비소모품 | 비 오는 날 피오 | $1.99 | NOT_TESTED | NOT_TESTED | NOT_TESTED | NOT_TESTED | NOT_TESTED |
| 잠옷 | outfit.pajamas | ✅ | 비소모품 | 잠옷 피오 | $1.99 | NOT_TESTED | NOT_TESTED | NOT_TESTED | NOT_TESTED | NOT_TESTED |
| 우주복 | outfit.space | ✅ | 비소모품 | 우주복 피오 | $1.99 | NOT_TESTED | NOT_TESTED | NOT_TESTED | NOT_TESTED | NOT_TESTED |

요약:
- **확인된 것**
  - Apple에서 요청 13종이 모두 돌아왔다(누락 0, 중복 0).
  - 모두 비소모품이고, 표시 이름은 한국어 현지화다.
  - 계정이 없는 시뮬레이터라 기본 미국 스토어프론트가 쓰였다.
- **확인되지 않은 것**
  - 한국 스토어프론트의 ₩2,500은 한국 지역 Sandbox 계정으로 다시 조회해야 확인된다. 로컬 설정(B)에서는 ₩2,500이었다.
  - 구매·소유·착용·재실행은 모든 상품에서 NOT_TESTED다. 계정이 필요하다(SANDBOX.md).

## 앱 표시 이름과 App Store 상품 이름

| 제품 | 앱 안 의상 이름(상품 정보를 못 받았을 때) | App Store 상품 표시 이름 |
|---|---|---|
| outfit.space | 우주인 피오 | 우주복 피오 |
| outfit.summer | 여름 휴가 피오 | 여름휴가 피오 |

상품 정보를 받으면 앱은 App Store 이름을 쓴다(`productTitle`). 받기 전·실패 시에만 앱 안 이름이 보인다. P2: 출시 전에 맞추면 좋다.

## 가격 표시

- 앱은 `Product.displayPrice`만 쓴다. 2,500원을 하드코딩한 곳은 없다. 구매 단추는 "\(displayPrice)에 구매하기"이고, 상품 정보가 없으면 "현재 구매 불가"다.
- 기본 피오는 구매 대상이 아니다(레지스트리 13종에 없음). 계정 없는 Sandbox 빌드에서도 기본 피오만 입고 있었다(evidence/ipad-sandbox-noaccount-wardrobe.png).
