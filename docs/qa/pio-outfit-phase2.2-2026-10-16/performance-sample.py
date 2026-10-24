from pathlib import Path
import subprocess,time,json,statistics,sys
name=sys.argv[1];duration=int(sys.argv[2]) if len(sys.argv)>2 else 20
platform=sys.argv[3] if len(sys.argv)>3 else 'mac'
exe='/tmp/DaylogStage4.noindex/verify/Build/Products/Debug/Daylog.app/Contents/MacOS/Daylog'
rows=subprocess.check_output(['ps','-axo','pid=,comm='],text=True).splitlines()
def is_target(command):
 if platform=='ios': return '/87EA3A43-121C-4FFA-A716-A79E614ABEFA/' in command and command.endswith('/Daylog.app/Daylog')
 return command in [exe,'/private'+exe]
pids=[int(x.strip().split(None,1)[0]) for x in rows if len(x.strip().split(None,1))==2 and is_target(x.strip().split(None,1)[1])]
if len(pids)!=1:raise SystemExit('Expected1verification PID '+str(pids))
pid=pids[0]
def cpu_seconds(raw):
 parts=raw.replace('-',':').split(':');total=0.0
 for p in parts:total=total*60+float(p)
 return total
def snapshot():
 vals=subprocess.check_output(['ps','-p',str(pid),'-o','time=,rss=,%cpu='],text=True).split()
 return {'at':time.monotonic(),'cpuSeconds':cpu_seconds(vals[0]),'rssKiB':int(vals[1]),'psCPUPercent':float(vals[2])}
time.sleep(3)
start=snapshot();samples=[];prev=start
for _ in range(duration):
 time.sleep(1);now=snapshot();now['cpuDeltaPercent']=(now['cpuSeconds']-prev['cpuSeconds'])/(now['at']-prev['at'])*100;samples.append(now);prev=now
r={'case':name,'platform':platform,'pid':pid,'environment':'Same isolated Debug app, same diagnostic root, one220pt character, same1040x900window onMac or dedicatediPhone17simulator on iOS, samepreloaded source set; no CUA snapshots or video recording during timed window','method':'3ssettle then process CPUtime delta andRSS each1s;100percent=oneCPUcore. ps%cpu retained forcomparison toolder report. Wholeapp,notGPU','seconds':samples[-1]['at']-start['at'],'meanCPUPercent':(samples[-1]['cpuSeconds']-start['cpuSeconds'])/(samples[-1]['at']-start['at'])*100,'maxIntervalCPUPercent':max(x['cpuDeltaPercent'] for x in samples),'meanPsCPUPercent':statistics.mean(x['psCPUPercent'] for x in samples),'rssMiBRange':[min(x['rssKiB'] for x in samples)/1024,max(x['rssKiB'] for x in samples)/1024],'samples':samples}
Path(__file__).with_name('performance-'+name+'.json').write_text(json.dumps(r,indent=2))
print(json.dumps({k:v for k,v in r.items() if k!='samples'},indent=2))
