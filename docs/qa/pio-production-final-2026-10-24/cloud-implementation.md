# Cloud production promotion — 2026-10-24

## 실제 변경

기존14종 V2 원화를 다시 그리지 않았다. 이전 `pio-independent-2026-10-24`의 Mac/iOS 64/220pt light/dark actual-presentation 및 ±1.5° held-joint native 검토를 통과한 **최종** registrations와 referenced texture만 정상 production catalog로 복사했다. 초기 rejected Hanbok/Cherry/Astronaut art는 포함하지 않았다. 신규 원화 제작 수는 이 작업에서0이다.

- `Daylog/PioCloudProduction.xcassets`: 14 registrations +141 unique texture PNG copies, PNG source bytes31,086,147. 기존 BasicV1 5texture+registration은 fallback으로 보존.
- 원본 후보와 PNG bytes/SHA 동일. 좌표·pivot·z·contentsRect·holdGroup도 동일하다. Namespace만 `pio_cloud_prod_v2_*`로 분리하고 revision을 `<outfit>-production-hands-v2`로 구분.
- `PioCloudCharacterRig.swift`: 검증된 production registration 선택, normal image loader/48MiB soft cache, resource 실패 시 이전 fallback, render-only appearance adapter.
- `RoutimoriSyncScene.swift`: receiving/trouble의 모든14종 정상 경로 연결. 기존 blink3.6s/trouble5.2s, hold6.4s ±1.5° 타이밍 불변.
- `FirstSyncView.swift`: 실제 렌더와 같은 appearance adapter로 안내 문구를 계산해, 원화가 연결됐는데 기본 피오로 대체한다고 잘못 표시하는 문구 제거.
- `PioCloudProductionTests.swift`: 전체14 resource/hold, receiving/trouble/ready 전환, ReduceMotion, suppression, authorization-preservation fixtures.
- `PioCloudCandidateReviewTests.swift`: 기존 native capture helpers의 `-PioCloudProductionReview` 모드가 BasicV1 전용 대신 해당 outfit productionV2를 검사. Candidate modes 유지.

보호 대상 `PioAppearanceCoordinator.swift`는 수정하지 않았다. Coordinator가 확정한 `outfit/access/requestedOutfit`을 그대로 받아 production artwork metadata만 조정한다. checking/verificationUnavailable/notOwned/unavailable 상태와 requested/authorized outfit 불일치는 원래 결과를 유지한다. 기존 `.preview`/`.testing` 표시는 그대로 유지하고 구매권한은 변경하지 않는다. 성장단계 원화 missing marker도 유지한다.

## Success 전환

기존 Release는 cloudCompleted에서 기본 피오 원화로 fallback하므로 새 receiving/trouble의 유료 의상과 일치하지 않았다. 기존 `outfit.artAssetName` 완성형 원화를 ready에서 사용하고 기존 bounded celebration bounce를 유지한다. 태블릿 자세가 필요한 receiving/trouble에 standing art를 사용하지 않는다. Basic ready는 기존 `routimori_sync_success` 유지. DEBUG Overhaul opt-in의 기존 celebration rig는 변경하지 않았다.

Ready의 production 동작은 완성형 PNG의 기존 bounce이며, 새 독립 팔/눈 celebration 완성으로 주장하지 않는다. 전체 화면의 silhouette/scale 전환은 native final QA 결과를 참조한다.

## 의상별 배포 코드 경로

모두 receiving/trouble productionV2 등록: basic, cherryBlossom, summerVacation, autumn, winter, halloween, christmas, hanbok, cafe, student, fitness, rainyDay, pajamas, astronaut.

- 여름휴가: 불투명 선글라스 뒤 눈 움직임은 가시적 blink PASS 대상이 아니다.
- 우주복: 최종 `armPairCompact` source와 기존 visor z9 사용. 거절된 큰 root atlas는 복사하지 않음.
- 손2개+tablet은 하나의 hold joint에 속해 접촉을 보존한다. free hand wave, finger joint, hat/sprout 독립 애니메이션은 새 구현 범위가 아니다.
- 기본 V1 fallback과 missing-production 이전 정상 화면을 보존한다.

## 검증 및 경계

이 worker가 실제 실행:
- `xcrun swiftc -frontend -parse` five changed Swift files PASS (typecheck/build가 아님).
- `git diff --check` PASS.
- source/production14 registration의 geometry 동일,141 PNG byte identity, contents filename 존재 확인 PASS. `cloud-production-static-validation.json` 참조.

Native build/test는 parent가 직렬화하여 진행하므로 별도 중복 실행하지 않았다. 본 문서 작성 시 compiled/native promotion 검사는 pending이며 이 문서의 source PASS가 Release runtime PASS를 의미하지 않는다. 최종 `RESULTS.md` / native evidence가 최종 판정이다. 최종 사용자 미적 승인은 pending.

## 권장 집중 실행

Production test host (cloud candidate flags OFF):
- PioCloudProductionTests/testSmallProductionPackAndIndependentEyeFrames
- PioCloudProductionTests/testProductionReduceMotionSuppressionAndSceneStop
- PioCloudProductionTests/testFourteenProductionRegistrationsAndIndependentHold
- PioCloudProductionTests/testFourteenProductionTransitionsSuppressionAndReduceMotion
- PioCloudProductionTests/testProductionAppearanceAdapterPreservesAuthorizationAndNotes
- 기존 native detach/lifecycle tests

Actual production component frames: `-PioCloudProductionReview` + `-PioCloudCandidateBatch basic,cherryBlossom,summerVacation,autumn,winter,halloween,christmas,hanbok,cafe,student,fitness,rainyDay,pajamas,astronaut`, candidate cloud/Overhaul flags OFF. Existing two batch methods emit exact source names and per-outfit assertion counts. Mac/iOS both run; parent의 full scene review tests 추가.

Release catalog validation:141 `pio_cloud_prod_v2_*` textures +14 `_prod_v2_registration` dataset 존재, trial catalog 미포함 확인. 앱 운영 설치/실제 결제/StoreKit 변경 없음.
