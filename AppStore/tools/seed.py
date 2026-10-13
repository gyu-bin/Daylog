# 스토어 촬영용 예시 데이터의 디버그 스크립트를 만든다(개인 기록 아님). 출력: 한 줄에 스크립트 하나.
import datetime, random, sys
random.seed(20261013)
R = ["물 한 잔 마시기","스트레칭 10분","영양제 챙기기","30분 걷기","물 2L 마시기","독서 20분","일기 쓰기"]
ease = {"물 한 잔 마시기":0.18,"스트레칭 10분":0.0,"영양제 챙기기":0.10,"30분 걷기":-0.12,"물 2L 마시기":-0.04,"독서 20분":-0.08,"일기 쓰기":-0.02}
B = ["그릭요거트와 그래놀라","통밀 토스트, 삶은 달걀","바나나, 아몬드 한 줌","오트밀, 블루베리","사과와 땅콩버터","두유 라테, 고구마"]
L = ["닭가슴살 샐러드","현미밥, 된장찌개, 나물","연어 포케","비빔밥","잡곡밥, 불고기, 쌈 채소","메밀국수, 샐러드"]
D = ["두부 스테이크, 구운 채소","현미밥, 생선구이","닭가슴살 볶음밥","토마토 파스타, 샐러드","소고기 미역국, 잡곡밥","샤브샤브"]
N = ["아메리카노","방울토마토","견과류 한 줌","플레인 요거트","", ""]
start = datetime.date(2026,8,3); today = datetime.date(2026,10,13)
vac = {datetime.date(2026,9,24), datetime.date(2026,9,25), datetime.date(2026,9,26)}
cmds = []
d = start; n = (today-start).days
while d < today:
    i = (d-start).days
    if d in vac: d += datetime.timedelta(days=1); continue
    base = 0.52 + 0.36*i/n - (0.10 if d.weekday()>=5 else 0)
    if i % 11 == 6: base -= 0.45          # 가끔 무너지는 날
    if (today-d).days in (1,2,3,5): base = 0.97   # 최근 연속 달성
    if (today-d).days == 4: base = 0.62
    day = ["day:%s" % d.isoformat()]
    any_done = False
    for r in R:
        p = max(0.03, min(0.99, base + ease[r]))
        x = random.random()
        if x < p: day.append("check:"+r); any_done = True
        elif x < p + 0.04 and (today-d).days > 6: day.append("skip:"+r)
    if (today-d).days <= 16 or random.random() < 0.55:
        k = i
        day.append("text:breakfast="+B[k % len(B)]); day.append("text:lunch="+L[(k*5+1) % len(L)])
        if random.random() < 0.9 or (today-d).days <= 6: day.append("text:dinner="+D[(k*3+2) % len(D)])
        s = N[(k*7) % len(N)]
        if s: day.append("text:snack="+s)
    if len(day) > 1: cmds += day
    d += datetime.timedelta(days=1)
print(";".join(cmds + ["day:2026-10-13","dump:seeded"]))
