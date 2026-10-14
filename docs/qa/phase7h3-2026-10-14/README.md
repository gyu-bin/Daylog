# Phase 7-H3 새싹이 캐릭터 통일 (2026-10-14)

- `stages-before-after.png`: 위 = 공식 새싹이와 예전 성장 3단계, 아래 = 새 3단계(새싹·잎사귀·꽃).
- `mac-growth-card-light-dark.png`: Mac 성장 카드 Lv.2·11·26, 라이트·다크.
- `mac-mascots-1x.png`, `iphone-mascots-3x.png`: 카드 속 새싹이 확대(1배율 Mac, 3배율 iPhone).
- `mac-flower-transition-frames.png`: Lv.24→25 완료 순간의 연속 캡처(두리번거리기, 깜빡임, 폴짝·반짝임, 꽃이 돋아남).

만든 방법: 몸·얼굴·눈·입·발은 공식 `saessagi_idle` 레이어 그대로. 잎사귀 단계의 셋째 잎은 공식 오른쪽 잎을 줄여 세운 것(외곽선은 공식 갈색으로 다시 두껍게),
꽃은 받은 성장 그림의 꽃잎만 떼어 외곽선을 공식 갈색으로 바꾼 것. `Tools/saessagi-growth-compose.swift`가 만든다. 예전 성장 그림은 `Tools/saessagi-growth-art/*_v1.png`에 보존.

휴가 해먹 캐릭터(손대지 않음): 얼굴(둥근 머리, ω 입, 볼터치, 두 잎)은 공식과 같은 계열이지만 채색이 더 진하고 외곽선이 굵으며, 누운 자세라 잎의 각도·크기가 다르다.
잎 레이어(`vacation_hammock_leaf`)가 이미 따로 있어, 성장 단계를 반영하려면 그 잎의 각도·크기에 맞춘 단계별 잎(셋째 잎·꽃)을 같은 방식으로 만들어 바꿔 끼우면 된다.
가장 좋은 것은 공식 그림체로 다시 그린 해먹 포즈 3장(쉬기·마시기·선글라스)과, 단계별 머리 위 잎·꽃 원화다.
