from pathlib import Path
import hashlib,json,subprocess
root=Path(__file__).parent
before=json.loads((root/'before-hashes.json').read_text())
changed=[];missing=[]
for name,original in before.items():
 p=Path(name)
 if not p.is_file():missing.append(name)
 elif hashlib.sha256(p.read_bytes()).hexdigest()!=original:changed.append(name)
wardrobe=[n for n in before if n.startswith('Daylog/PioWardrobe.xcassets/') and n.endswith('.png')]
expected={'Daylog/App/RootView.swift','Daylog.xcodeproj/project.pbxproj'}
result={'head':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'baselineFiles':len(before),'changedBaselineFiles':changed,'missingBaselineFiles':missing,'unexpectedBaselineChanges':[n for n in changed if n not in expected],'originalWardrobePNGs':len(wardrobe),'wardrobePNGsPreserved':all(n not in changed+missing for n in wardrobe),'allowedExistingEdits':sorted(expected),'diffCheck':subprocess.run(['git','diff','--check'],capture_output=True,text=True).stdout}
(root/'preservation-final.json').write_text(json.dumps(result,indent=2))
(root/'after-status.txt').write_text(subprocess.check_output(['git','status','--short'],text=True))
print(json.dumps(result,indent=2))
assert not missing and not result['unexpectedBaselineChanges'] and result['wardrobePNGsPreserved']
