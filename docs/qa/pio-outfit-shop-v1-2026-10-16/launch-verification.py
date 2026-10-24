from pathlib import Path
import subprocess,sys,os,signal,json
platform=sys.argv[1]; appearance=sys.argv[2]
args=['-DaylogStoreName','pio-wardrobe-v1-20261016','-DaylogDebugCharacter','routimori','-DaylogDebugSplash','off','-DaylogDebugAppearance',appearance,'-DaylogDebugToday','2026-10-16','-DaylogDebugSettings','wardrobe','-DaylogDebugScript','onboardingDone;section:settings'+(';window:1040,900' if platform=='mac' else '')]
if platform=='mac':
 app='/tmp/DaylogStage4.noindex/verify/Build/Products/Debug/Daylog.app'
 exe=app+'/Contents/MacOS/Daylog'
 for line in subprocess.check_output(['ps','-axo','pid=,comm='],text=True).splitlines():
  parts=line.strip().split(None,1)
  if len(parts)==2 and parts[1] in [exe,'/private'+exe]: os.kill(int(parts[0]),signal.SIGTERM)
 subprocess.run(['open','-n',app,'--args',*args],check=True)
else:
 udid=json.loads((Path(__file__).parent/'runtime-environment.json').read_text())['iphone17Simulator']
 app=Path('/tmp/DaylogStage4.noindex/ios/Build/Products/Debug-iphonesimulator/Daylog.app')
 if '--install' in sys.argv:
  widget=app/'PlugIns/DaylogWidgets.appex'
  subprocess.run(['/usr/libexec/PlistBuddy','-c','Set :CFBundleIdentifier com.daylog.verify.ios.widgets',str(widget/'Info.plist')],check=True)
  for f in [widget,app]: subprocess.run(['codesign','--force','--sign','-',str(f)],check=True)
  subprocess.run(['xcrun','simctl','install',udid,str(app)],check=True)
 subprocess.run(['xcrun','simctl','terminate',udid,'com.daylog.verify.ios'],check=False,stderr=subprocess.DEVNULL)
 subprocess.run(['xcrun','simctl','launch',udid,'com.daylog.verify.ios',*args],check=True)
