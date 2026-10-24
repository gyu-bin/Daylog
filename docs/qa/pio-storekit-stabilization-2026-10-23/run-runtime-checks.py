"""Reproducible local-only serial experiments; no retry, no assertion filtering."""
import subprocess,json,plistlib,uuid
from pathlib import Path
root=Path(__file__).resolve().parents[3]
out=Path(__file__).resolve().parent
products=Path('/tmp/PioStoreKit-20261023-ios/Build/Products')
original=max(products.glob('*DaylogiOSStoreKit*.xctestrun'),key=lambda p:p.stat().st_mtime)
destination='platform=iOS Simulator,id=0426CD78-3807-4650-9776-B649780E2884'
target='DaylogStoreKitTests/PioStoreKitIntegrationTests'
base=['xcodebuild','test-without-building','-xctestrun',str(original),'-destination',destination,'-parallel-testing-enabled','NO','-collect-test-diagnostics','never','-test-timeouts-enabled','YES','-default-test-execution-time-allowance','60','-maximum-test-execution-time-allowance','90']
methods=['testCancellationFromStoreKitDoesNotUnlockOrShowFailure','testInterruptedPurchaseOnlyUnlocksAfterResolution','testRefundUpdateRevokesAccessAndRefreshResetsEquipment','testEveryPremiumOutfitPurchasesEquipsAndLoadsApprovedArtwork','testVerificationFailureNeverGrantsFreshManagerOwnership']
runs=[('isolated-'+m,target+'/'+m,1,False) for m in methods]+[(f'full-final-{n}',target,11,False) for n in range(1,4)]+[('full-random',target,11,True)]
all_results=[]
def nodes(v):
 result=[]
 if isinstance(v,dict):
  if v.get('nodeType')=='Test Case':result.append(v)
  for item in v.values():result.extend(nodes(item))
 elif isinstance(v,list):
  for item in v:result.extend(nodes(item))
 return result
for name,selection,expected,random in runs:
 log=out/(name+'.log'); bundle=Path('/tmp')/('PioStoreKit-Stabilization-'+name+'.xcresult')
 if log.exists() or bundle.exists():raise RuntimeError('Refusing to overwrite evidence '+name)
 command=list(base)
 temporary=None
 if random:
  data=plistlib.loads(original.read_bytes());data['DaylogStoreKitTests']['TestExecutionOrdering']='random'
  temporary=products/f'PioStabilization-random-{uuid.uuid4()}.xctestrun';temporary.write_bytes(plistlib.dumps(data))
  command[command.index('-xctestrun')+1]=str(temporary)
  (out/'random-xctestrun.plist').write_bytes(plistlib.dumps(data))
 command+=['-only-testing:'+selection,'-resultBundlePath',str(bundle)]
 (out/(name+'-command.json')).write_text(json.dumps(command,indent=2)+'\n')
 try:
  with log.open('w') as f:code=subprocess.run(command,cwd=root,stdout=f,stderr=subprocess.STDOUT).returncode
 finally:
  if temporary:temporary.unlink(missing_ok=True)
 summary=subprocess.run(['xcrun','xcresulttool','get','test-results','tests','--path',str(bundle),'--compact'],capture_output=True,text=True)
 record={'name':name,'exitCode':code,'resultBundle':str(bundle),'expectedTests':expected,'random':random}
 if summary.returncode==0:
  document=json.loads(summary.stdout);cases=nodes(document)
  (out/(name+'-tests.json')).write_text(json.dumps(document,indent=2)+'\n')
  record['tests']=[{'name':c.get('name'),'result':c.get('result')} for c in cases]
  record['counts']={state:sum(c.get('result')==state for c in cases) for state in ['Passed','Failed','Skipped']}
  record['allRequiredPassed']=code==0 and len(cases)==expected and all(c.get('result')=='Passed' for c in cases)
 else:record.update(exportError=summary.stderr,allRequiredPassed=False)
 all_results.append(record)
 (out/'runtime-series.json').write_text(json.dumps(all_results,indent=2)+'\n')
 print(json.dumps({k:v for k,v in record.items() if k!='tests'}),flush=True)
