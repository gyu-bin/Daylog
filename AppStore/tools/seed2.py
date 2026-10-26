# 스토어 촬영용 예시 데이터(2026-10-26 갱신, 개인 기록 아님). 두 줄을 출력한다.
#   1줄: 루틴 만들기 — 앱을 -DaylogDebugToday 2026-08-03 으로 띄워 실행(루틴이 8월 3일부터 있었던 것으로)
#   2줄: 지난 기록 — 오늘 날짜로 띄워 실행
import datetime, random
random.seed(20261026)
GROUPS = [("아침 루틴", [("물 한 잔 마시기", "07:00"), ("스트레칭 10분", "07:10"), ("영양제 챙기기", "07:30")]),
          ("운동", [("30분 걷기", "19:00")]),
          ("자기계발", [("독서 20분", "21:30"), ("일기 쓰기", "22:30")])]
R = [t for _, items in GROUPS for t, _ in items]
ease = {"물 한 잔 마시기":0.18,"스트레칭 10분":0.0,"영양제 챙기기":0.10,"30분 걷기":-0.12,"독서 20분":-0.08,"일기 쓰기":-0.02}
B = ["그릭요거트와 그래놀라","통밀 토스트, 삶은 달걀","바나나, 아몬드 한 줌","오트밀, 블루베리","사과와 땅콩버터","두유 라테, 고구마"]
L = ["닭가슴살 샐러드","현미밥, 된장찌개, 나물","연어 포케","비빔밥","잡곡밥, 불고기, 쌈 채소","메밀국수, 샐러드"]
D = ["두부 스테이크, 구운 채소","현미밥, 생선구이","닭가슴살 볶음밥","토마토 파스타, 샐러드","소고기 미역국, 잡곡밥","샤브샤브"]
setup = ["onboardingDone"]
for g, items in GROUPS:
    setup.append("group:" + g)
    for t, time in items:
        setup += ["add:" + t, "time:%s=%s" % (t, time)]
start = datetime.date(2026,8,3); today = datetime.date(2026,10,26)
vac = (datetime.date(2026,9,24), datetime.date(2026,9,26))
cmds = ["onboardingDone", "vacationMemo:제주 여행", "vacation:%s,%s" % (vac[0].isoformat(), vac[1].isoformat())]
d = start; n = (today-start).days
while d < today:
    i = (d-start).days
    if vac[0] <= d <= vac[1]: d += datetime.timedelta(days=1); continue
    base = 0.52 + 0.36*i/n - (0.10 if d.weekday()>=5 else 0)
    if i % 11 == 6: base -= 0.45
    if 1 <= (today-d).days <= 6: base = 0.97      # 최근 6일 연속 달성
    day = ["day:%s" % d.isoformat()]
    for r in R:
        p = max(0.03, min(0.99, base + ease[r]))
        x = random.random()
        if x < p: day.append("check:"+r)
        elif x < p + 0.04 and (today-d).days > 7: day.append("skip:"+r)
    if (today-d).days <= 16 or random.random() < 0.55:
        k = i
        day += ["text:breakfast="+B[k % len(B)], "text:lunch="+L[(k*5+1) % len(L)], "text:dinner="+D[(k*3+2) % len(D)]]
    cmds += day
    d += datetime.timedelta(days=1)
# 오늘: 아침 루틴 3개 중 2개 완료
cmds += ["day:%s" % today.isoformat(), "check:물 한 잔 마시기", "check:스트레칭 10분", "text:breakfast=그릭요거트와 그래놀라"]
print(";".join(setup))
print(";".join(cmds + ["dump:seeded"]))
