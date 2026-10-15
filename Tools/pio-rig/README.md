# 피오 부위 레이어 만들기 (시범)

마스터(`Pio_Style_Locked_Kit/01_master/pio_master.png`, 1536 캔버스, 실제 1254px) 한 장에서 앱의 레이어를 만든다.

```
swiftc -O -o /tmp/pio-separate Tools/pio-rig/separate.swift && /tmp/pio-separate <master.png> <출력 폴더>
swiftc -O -o /tmp/pio-lids Tools/pio-rig/lids.swift && /tmp/pio-lids <출력 폴더>
swiftc -O -o /tmp/pio-pose Tools/pio-rig/pose.swift && /tmp/pio-pose <출력 폴더> out.png 30343F wingL=30 wingR=-30 crest=-8   # 확인용 합성
```

- 날개·볏·눈: 마스터 픽셀 그대로 잘라 낸다(윤곽은 확대 그림에서 손으로 딴 다각형, 오른쪽 날개는 대칭).
- 몸: 부위에 가려진 몸은 둘레 음영에서 라플라스 방정식으로 메우고 몸의 잔결을 같은 세기로 입힌다. 가려진 윤곽은 극좌표 반지름을 매끄럽게 이어 그린다.
  날개가 몸에 드리운 접촉 그림자는 날개 그림자 레이어로 뺀다(날개를 들면 옅어진다).
- 발: 몸 실루엣 아래의 부분.
- 눈꺼풀(감은·웃는·졸린 눈): 몸 레이어의 피부를 눈 위에 덮고, 가운데가 두꺼운 갈색 눈매와 부드러운 그림자를 그린다(3D 렌더가 아니다).
- 마스터와 다시 합친 결과의 PSNR 약 43dB(부위 경계의 반투명 픽셀에서만 차이).
