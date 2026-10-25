#!/usr/bin/env python3
"""Serial LOCAL StoreKit A/B diagnostics; no retry, install over production, or Apple payment."""
import argparse,json,plistlib,subprocess,uuid
from pathlib import Path
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--derived-data',required=True,type=Path)
parser.add_argument('--output',required=True,type=Path)
parser.add_argument('--ios-simulator',required=True)
args=parser.parse_args();repo=Path(__file__).resolve().parents[2]
try:uuid.UUID(args.ios_simulator)
except ValueError:parser.error('Use an exact isolated simulator UUID')
inventory=json.loads(subprocess.run(['xcrun','simctl','list','devices','--json'],capture_output=True,text=True,check=True).stdout)
device=next((d for items in inventory['devices'].values() for d in items if d['udid']==args.ios_simulator),None)
if not device or not device['name'].startswith('Pio StoreKit Local '):parser.error('Refusing a non-isolated simulator')
out=args.output.resolve();derived=args.derived_data.resolve()
if out.exists():parser.error('Refusing to overwrite evidence: '+str(out))
out.mkdir(parents=True,exist_ok=False)
destination='platform=iOS Simulator,id='+args.ios_simulator
base=['xcodebuild','-project','Daylog.xcodeproj','-scheme','DaylogiOSStoreKit','-configuration','Debug','-destination',destination,'-derivedDataPath',str(derived)]
with (out/'build.log').open('w') as log:built=subprocess.run(base+['build-for-testing','CODE_SIGNING_ALLOWED=NO'],cwd=repo,stdout=log,stderr=subprocess.STDOUT)
if built.returncode:raise RuntimeError('Diagnostic build failed; no runtime sessions started')
original=max((derived/'Build/Products').glob('*DaylogiOSStoreKit*.xctestrun'),key=lambda p:p.stat().st_mtime)
results=[]
def run_test(mode,scenario,phase,runid):
 name=mode+'-'+scenario+'-'+phase
 generated=plistlib.loads(original.read_bytes())
 target=generated['DaylogStoreKitTests']
 target.setdefault('EnvironmentVariables',{}).update(PIO_ISOLATION_MODE=mode,PIO_ISOLATION_SCENARIO=scenario,PIO_ISOLATION_RUN_ID=runid,PIO_ISOLATION_PHASE=phase)
 file=original.parent/('PioIsolation-'+runid+'-'+phase+'.xctestrun')
 file.write_bytes(plistlib.dumps(generated))
 (out/(name+'-config.plist')).write_bytes(plistlib.dumps(generated))
 method='testScenario' if phase=='seed' else 'testFinishInFreshProcess'
 bundle=out/(name+'.xcresult')
 command=['xcodebuild','test-without-building','-xctestrun',str(file),'-destination',destination,'-parallel-testing-enabled','NO','-collect-test-diagnostics','never','-test-timeouts-enabled','YES','-default-test-execution-time-allowance','60','-maximum-test-execution-time-allowance','90','-only-testing:DaylogStoreKitTests/PioStoreKitIsolationTests/'+method,'-resultBundlePath',str(bundle)]
 (out/(name+'-command.json')).write_text(json.dumps(command,indent=2)+'\n')
 try:
  with (out/(name+'.log')).open('w') as log:r=subprocess.run(command,cwd=repo,stdout=log,stderr=subprocess.STDOUT)
 finally:file.unlink(missing_ok=True)
 events=[]
 for line in (out/(name+'.log')).read_text(errors='replace').splitlines():
  if line.startswith('PIO_ISOLATION '):events.append(json.loads(line[len('PIO_ISOLATION '):]))
 (out/(name+'-timeline.json')).write_text(json.dumps(events,indent=2)+'\n')
 summary=subprocess.run(['xcrun','xcresulttool','get','test-results','summary','--path',str(bundle),'--compact'],capture_output=True,text=True)
 record={'mode':mode,'scenario':scenario,'phase':phase,'runID':runid,'exitCode':r.returncode,'events':len(events)}
 if summary.returncode==0:
  document=json.loads(summary.stdout);(out/(name+'-summary.json')).write_text(json.dumps(document,indent=2)+'\n')
  record.update({key:document.get(key) for key in ['passedTests','failedTests','skippedTests','totalTestCount','result']})
  # A skip/zero executed test can never count as a successful diagnostic.
  record['executedOne']=document.get('totalTestCount')==1 and document.get('skippedTests')==0
 else:record['exportError']=summary.stderr
 results.append(record);(out/'series.json').write_text(json.dumps(results,indent=2)+'\n')
 print(json.dumps(record),flush=True)
 return events
for mode in ['direct','manager']:
 for scenario in ['cancel','interrupt','refund','finish']:
  runid=str(uuid.uuid4());events=run_test(mode,scenario,'seed',runid)
  # A failed immediate unfinished assertion remains FAIL. Nevertheless observe
  # the same acknowledged ledger in a fresh OS process, without reseeding it.
  if scenario=='finish' and any(e.get('event')=='handoff.ready' for e in events):run_test(mode,scenario,'verify',runid)
# Recheck all original eleven unchanged after fixture cleanup, once; no retries.
command=base+['-parallel-testing-enabled','NO','-collect-test-diagnostics','never','-only-testing:DaylogStoreKitTests/PioStoreKitIntegrationTests','-resultBundlePath',str(out/'original-eleven.xcresult'),'test-without-building']
(out/'original-eleven-command.json').write_text(json.dumps(command,indent=2)+'\n')
with (out/'original-eleven.log').open('w') as log:original_result=subprocess.run(command,cwd=repo,stdout=log,stderr=subprocess.STDOUT)
summary=subprocess.run(['xcrun','xcresulttool','get','test-results','summary','--path',str(out/'original-eleven.xcresult'),'--compact'],capture_output=True,text=True,check=True)
(out/'original-eleven-summary.json').write_text(json.dumps(json.loads(summary.stdout),indent=2)+'\n')
print('Original acceptance suite exit:',original_result.returncode,flush=True)
