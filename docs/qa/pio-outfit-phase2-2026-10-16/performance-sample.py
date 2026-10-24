from pathlib import Path
import subprocess,time,json,statistics,sys
phase=sys.argv[1]
exe='/tmp/DaylogStage4.noindex/verify/Build/Products/Debug/Daylog.app/Contents/MacOS/Daylog'
rows=subprocess.check_output(['ps','-axo','pid=,comm='],text=True).splitlines()
pids=[int(x.strip().split(None,1)[0]) for x in rows if len(x.strip().split(None,1))==2 and x.strip().split(None,1)[1] in [exe,'/private'+exe]]
if len(pids)!=1:raise SystemExit('Expected exactly1 verification app PID: '+str(pids))
pid=pids[0];samples=[]
for _ in range(10):
 out=subprocess.check_output(['ps','-p',str(pid),'-o','%cpu=,rss='],text=True).strip().split()
 samples.append({'cpuPercent':float(out[0]),'rssKiB':int(out[1]),'time':time.time()})
 time.sleep(1)
r={'phase':phase,'pid':pid,'executable':exe,'build':'Debug verification, not release benchmark','method':'10 ps samples at1second intervals, whole process, RSS resident memory; CPU includes app background work','samples':samples,'meanCPUPercent':statistics.mean(s['cpuPercent'] for s in samples),'maxCPUPercent':max(s['cpuPercent'] for s in samples),'rssMiBRange':[min(s['rssKiB'] for s in samples)/1024,max(s['rssKiB'] for s in samples)/1024]}
Path(__file__).with_name('performance-'+phase+'.json').write_text(json.dumps(r,indent=2))
print(json.dumps({k:v for k,v in r.items() if k!='samples'},indent=2))
