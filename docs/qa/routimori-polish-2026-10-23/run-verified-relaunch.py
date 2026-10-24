#!/usr/bin/env python3
"""Opt-in LOCAL StoreKit OS-process relaunch proof. Run serially; shared local ledger."""
import argparse,json,plistlib,subprocess,uuid
from pathlib import Path
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--derived-data',required=True,type=Path)
parser.add_argument('--output',required=True,type=Path)
parser.add_argument('--package-cache',type=Path)
parser.add_argument('--ios-simulator',help='Explicit UUID of an isolated Pio StoreKit test simulator; otherwise uses the separate Mac test identity')
parser.add_argument('--seed-method',required=True,choices=['product-purchase','storekit-test'],help='Explicit distinction: test-driven seeding is not app purchase-flow proof')
args=parser.parse_args()
root=Path('/Users/mungyubin/Desktop/Coding/Daylog')
out=args.output.resolve()
if out.exists():parser.error(f'Output already exists; choose a new evidence folder: {out}')
out.mkdir(parents=True,exist_ok=False)
derived=args.derived_data.resolve();run=str(uuid.uuid4())
(out/'run-plan.json').write_text(json.dumps({'runID':run,'seedMethod':args.seed_method,'iosSimulator':args.ios_simulator,'scope':'Two local StoreKit processes; no persisted ownership is injected'},indent=2)+'\n')
scheme='DaylogPioProcessRelaunchReview';destination='platform=macOS';test_target='DaylogTests'
signing=['PRODUCT_BUNDLE_IDENTIFIER=com.daylog.verify','CODE_SIGN_IDENTITY=-','CODE_SIGN_STYLE=Manual','DEVELOPMENT_TEAM=','PROVISIONING_PROFILE_SPECIFIER=','CODE_SIGN_ENTITLEMENTS=Config/Verify.entitlements']
if args.ios_simulator:
    try:uuid.UUID(args.ios_simulator)
    except ValueError:parser.error('--ios-simulator must be an exact UUID')
    inventory=json.loads(subprocess.run(['xcrun','simctl','list','devices','--json'],capture_output=True,text=True,check=True).stdout)
    device=next((device for devices in inventory['devices'].values() for device in devices if device['udid']==args.ios_simulator),None)
    if not device or not device['name'].startswith('Pio StoreKit Local '):parser.error('Only an isolated Pio StoreKit Local simulator is accepted; no existing user device may be replaced')
    scheme='DaylogiOSStoreKit';destination='platform=iOS Simulator,id='+args.ios_simulator;test_target='DaylogStoreKitTests';signing=['CODE_SIGNING_ALLOWED=NO']
common=['xcodebuild','-project','Daylog.xcodeproj','-scheme',scheme,'-configuration','Debug','-destination',destination,'-derivedDataPath',str(derived),'-parallel-testing-enabled','NO']+signing
if args.package_cache:common+=['-clonedSourcePackagesDirPath',str(args.package_cache.resolve()),'-disableAutomaticPackageResolution']
def execute(command,name):
    (out/(name+'-command.json')).write_text(json.dumps(command,indent=2)+'\n')
    with (out/(name+'.log')).open('w') as log:
        result=subprocess.run(command,cwd=root,stdout=log,stderr=subprocess.STDOUT)
    if result.returncode:raise RuntimeError(f'{name} failed ({result.returncode}); inspect {out/(name+".log")}')
execute(common+['build-for-testing'],'build')
candidates=sorted((derived/'Build/Products').glob('*'+scheme+'*.xctestrun'),key=lambda p:p.stat().st_mtime)
if not candidates:raise RuntimeError('No relaunch-review xctestrun produced; no purchase phase ran')
original=candidates[-1];base=plistlib.loads(original.read_bytes());phase_files=[]
def inject(value,phase):
    count=0
    if isinstance(value,dict):
        if 'TestBundlePath' in value:
            value.setdefault('EnvironmentVariables',{}).update(PIO_RELAUNCH_RUN_ID=run,PIO_RELAUNCH_PHASE=phase,PIO_RELAUNCH_SEED_METHOD=args.seed_method)
            arguments=value.setdefault('CommandLineArguments',[])
            for argument in ['-pio-storekit-testing','-pio-storekit-process-relaunch','-PioOverhaulTrial']:
                if argument not in arguments:arguments.append(argument)
            count+=1
        for child in value.values():count+=inject(child,phase)
    elif isinstance(value,list):
        for child in value:count+=inject(child,phase)
    return count
try:
    for phase,method in [('seed','testSeedVerifiedLedgerInFirstProcess'),('verify','testVerifyLedgerAndEquipmentInFreshProcess')]:
        test=plistlib.loads(plistlib.dumps(base));count=inject(test,phase)
        if count!=1:raise RuntimeError(f'Expected one isolated test target, found {count}; no {phase} run started')
        # Keep __TESTROOT__ resolution identical to the generated xctestrun.
        file=original.parent/f'PioProcessRelaunch-{run}-{phase}.xctestrun';file.write_bytes(plistlib.dumps(test));phase_files.append(file)
        command=['xcodebuild','test-without-building','-xctestrun',str(file),'-destination',destination,'-parallel-testing-enabled','NO','-collect-test-diagnostics','never','-test-timeouts-enabled','YES','-default-test-execution-time-allowance','60','-maximum-test-execution-time-allowance','90','-only-testing:'+test_target+'/PioStoreKitProcessRelaunchTests/'+method,'-resultBundlePath',str(out/(phase+'.xcresult'))]
        execute(command,phase)
        summary=subprocess.run(['xcrun','xcresulttool','get','test-results','tests','--path',str(out/(phase+'.xcresult')),'--compact'],cwd=root,capture_output=True,text=True,check=True)
        document=json.loads(summary.stdout);nodes=[]
        def collect(value):
            if isinstance(value,dict):
                if value.get('nodeType')=='Test Case':nodes.append(value)
                for child in value.values():collect(child)
            elif isinstance(value,list):
                for child in value:collect(child)
        collect(document)
        if not any(n.get('name','').startswith(method) and n.get('result')=='Passed' for n in nodes):
            raise RuntimeError(f'{phase} did not execute and PASS its required test (skips are not evidence)')
        (out/(phase+'-test-results.json')).write_text(json.dumps(document,indent=2)+'\n')
    (out/'run.json').write_text(json.dumps({'runID':run,'seedMethod':args.seed_method,'appPurchaseUI':'NOT_TESTED' if args.seed_method=='storekit-test' else 'Product.purchase result asserted','status':'TWO_PHASE_TEST_COMMANDS_PASSED','scope':'Local Xcode StoreKit only; separate process PID and same verified transaction asserted by tests','cleanup':'Verify phase clears local test ledger and UUID preference suite after verification'},indent=2)+'\n')
    print(out/'run.json')
except Exception as error:
    (out/'failure.json').write_text(json.dumps({'runID':run,'seedMethod':args.seed_method,'status':'FAIL','error':str(error),'cleanup':'Temporary xctestrun files removed; inspect phase evidence for fixture ledger/preferences cleanup'},indent=2)+'\n')
    raise
finally:
    for file in phase_files:file.unlink(missing_ok=True)
