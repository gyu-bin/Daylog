# Pio 원화 감사 및 레이어 제작 인계 — PARTIAL

새 원화 제작·앱 수정 없이 기존 파일, 실제 부품 좌표와 과거 네이티브 렌더를 검토했다. **추가 원화가 필요한 6개 blocker 중 이번 감사에서 해결된 것은 0개**다. 현재 리그의 재사용 가능 범위와 필요한 복원 영역을 구체화한 결과물이다.

- [제작 사양](ARTWORK-SPEC.md): 좌표, parent/z-order, 가림, hidden roots, 납품 및 승인 조건.
- [의상별 목록](PER-OUTFIT.md): 14종의 기존 연결 좌표와 실제 소품 차이.
- [정확한 파일·좌표·SHA-256](inventory.json): 213개 standing 부품, 유료 cloud 120개 레이어, 휴가 28장과 runtime 대응 파일.
- [시각 검토](VISUAL-REVIEW.md) / [56개 기존 렌더 갤러리](review.html).
- [원본 그대로 복사한 참고 PNG 16장](reference-copies.json): 각 파일의 기존 경로·복사 경로·SHA-256 포함. 합계 18,096,119 bytes. 재인코딩·crop·보정하지 않았다.

## 확인 결과

| 항목 | 결과 | 근거와 한계 |
|---|---|---|
| 기존 standing rig 14종 | PASS: 파일 추적 | 213개 full-canvas 부품 모두 1254×1254 RGBA. 기존 packed runtime 사각형과 RGBA 픽셀 일치 213/213. 전체 홈 화면 14종 runtime 검증을 의미하지 않음. |
| 유료 cloud 13종 | PARTIAL | 120개 실제 레이어와 app 복사본 SHA 일치. 눈/눈꺼풀/눈썹은 분리됨. 손·태블릿·몸통은 body에 합쳐져 있음. |
| Basic cloud | BLOCKED_ASSET | 기존 대기/실패 원본은 1254×1254 RGBA로 존재. 분리된 clean seated face와 eyes 없음. |
| Vacation 14종 낮·밤 | PARTIAL | 28개 기존 1024×1536 RGBA와 등록 파일 대응 확인. 전체 foreground 한 장이며 독립 눈·손·소품·줄 리그는 없음. 유료 astronaut는 v2 사용. |
| 필요한 새 원화 6개 그룹 | BLOCKED_ASSET | 기본 cloud 눈, 유료 cloud 손, 유료 cloud 태블릿, vacation 눈, vacation 손/실제 소품, 두 고정점이 있는 해먹 줄/천. |
| 새 runtime/빌드/동작 테스트 | NOT_TESTED | 이 하위 작업은 원화 감사·제작 사양 전용. 기존 테스트 재실행하지 않음. |

`inventory.json`의 새 어깨·grip·양쪽 매듭 좌표 `null`은 누락 실수가 아니라 아직 제작되지 않은 부위를 가리킨다. standing 좌표를 seated/reclining에 임의로 이식하지 않는다. 기존 manifest의 “미통합/후보” 문자열 일부는 과거 provenance이며 현재 앱 등록 여부와 따로 취급했다. 파일 존재나 source registration만으로 Production 또는 Stage 1–4 완성을 주장하지 않는다.

과거 Basic cloud 4개 fixture 캡처는 잘못 강제된 independent branch 때문에 무효다. 원본 누락이나 실제 SwiftUI fallback 실패로 단정하지 않는다. 자세한 파일과 분기는 [시각 검토](VISUAL-REVIEW.md)에 남겼다. 다른 담당자의 수정·재촬영 결과는 이 과거 증거와 구분해야 한다.
