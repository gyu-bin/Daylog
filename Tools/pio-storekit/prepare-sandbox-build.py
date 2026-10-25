#!/usr/bin/env python3
"""Prepare and verify an unsigned iOS Sandbox-only build; NEVER install or run it."""
import argparse
import hashlib
import json
import plistlib
import re
import subprocess
import tempfile
from pathlib import Path

EXPECTED_IDS = {
    'outfit.cherryblossom', 'outfit.summer', 'outfit.autumn', 'outfit.winter',
    'outfit.halloween', 'outfit.christmas', 'outfit.hanbok', 'outfit.cafe',
    'outfit.student', 'outfit.workout', 'outfit.rainy', 'outfit.pajamas', 'outfit.space',
}
BUNDLE_ID = 'com.mungyubin.daylog.ios'
KEYS = {'PioStoreKitCatalogConfirmed', 'PioStoreKitEnvironment'}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence', required=True, type=Path, help='New evidence directory; must not exist')
    parser.add_argument('--package-cache', type=Path, help='Existing SourcePackages directory; read/reuse only')
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[2]
    evidence = args.evidence.resolve()
    if evidence.exists():
        parser.error('Evidence directory already exists; refusing overwrite: ' + str(evidence))
    original = repo / 'Config/DaylogiOS-Info.plist'
    registry = repo / 'Daylog/Services/PioProductRegistry.swift'
    asc = repo / 'docs/qa/pio-storekit-integration-2026-10-23/asc-products-confirmed.json'
    normal = plistlib.loads(original.read_bytes())
    # Since 2026-10-25 the ordinary plist ships the release opt-in (appStore + confirmed).
    # Anything else there is ambiguous; the temporary copy below narrows it to Sandbox only.
    if KEYS.intersection(normal) and (normal.get('PioStoreKitEnvironment'), normal.get('PioStoreKitCatalogConfirmed')) != ('appStore', True):
        parser.error('Ordinary Info.plist has an unexpected purchase opt-in; refusing ambiguous preparation')
    found = re.findall(r'productID: "([^"]+)"', registry.read_text())
    asc_data = json.loads(asc.read_text())
    if len(found) != 13 or set(found) != EXPECTED_IDS or {p[0] for p in asc_data['products']} != EXPECTED_IDS:
        parser.error('Confirmed 13 product IDs no longer match; no guessed IDs accepted')
    if asc_data['app']['bundleId'] != BUNDLE_ID:
        parser.error('ASC evidence bundle mismatch')
    if args.package_cache and not (args.package_cache.resolve() / 'checkouts').is_dir():
        parser.error('Package cache must be an existing SourcePackages directory with checkouts')
    protected = [original, registry, repo / 'Daylog.xcodeproj/project.pbxproj',
                 repo / 'Config/DaylogiOS.entitlements', repo / 'Config/DaylogWidgets-Info.plist',
                 repo / 'Daylog.xcodeproj/xcshareddata/xcschemes/DaylogiOS.xcscheme',
                 repo / 'Daylog.xcodeproj/xcshareddata/xcschemes/DaylogiOSStoreKit.xcscheme']
    before = {str(p.relative_to(repo)): digest(p) for p in protected}
    evidence.mkdir(parents=True, exist_ok=False)
    workspace = Path(tempfile.mkdtemp(prefix='pio-sandbox-build-'))
    temp_info = workspace / 'DaylogiOS-Sandbox-Info.plist'
    sandbox = dict(normal)
    sandbox['PioStoreKitCatalogConfirmed'] = True
    sandbox['PioStoreKitEnvironment'] = 'sandbox'
    temp_info.write_bytes(plistlib.dumps(sandbox, sort_keys=False))
    derived = workspace / 'DerivedData'
    # A global plain Info override would also corrupt the widget extension plist.
    # Expand the temporary override by target, leaving its dependency unchanged.
    command = ['xcodebuild', '-project', 'Daylog.xcodeproj', '-scheme', 'DaylogiOS',
               '-configuration', 'Debug', '-destination', 'generic/platform=iOS',
               '-derivedDataPath', str(derived), 'CODE_SIGNING_ALLOWED=NO',
               'INFOPLIST_FILE=$(PIO_SANDBOX_INFO_$(TARGET_NAME))',
               'PIO_SANDBOX_INFO_DaylogiOS=' + str(temp_info),
               'PIO_SANDBOX_INFO_DaylogWidgets=' + str(repo / 'Config/DaylogWidgets-Info.plist')]
    if args.package_cache:
        command += ['-clonedSourcePackagesDirPath', str(args.package_cache.resolve()),
                    '-disableAutomaticPackageResolution']
    command += ['build']
    (evidence / 'command.json').write_text(json.dumps(command, indent=2) + '\n')
    result = {'status': 'FAIL', 'buildOnly': True, 'installed': False, 'signed': False,
              'runtimeSandboxTested': False, 'temporaryWorkspace': str(workspace),
              'temporaryInfoPlist': str(temp_info), 'protectedSHA256Before': before,
              'productIDs': sorted(EXPECTED_IDS)}
    print('BUILD ONLY: unsigned iOS Sandbox preparation; no install, launch, account input or purchase.', flush=True)
    try:
        with (evidence / 'build.log').open('w') as log:
            completed = subprocess.run(command, cwd=repo, stdout=log, stderr=subprocess.STDOUT, timeout=1200)
        result['buildExitCode'] = completed.returncode
        if completed.returncode:
            raise RuntimeError('xcodebuild failed; inspect build.log')
        app = derived / 'Build/Products/Debug-iphoneos/Daylog.app'
        emitted = plistlib.loads((app / 'Info.plist').read_bytes())
        if emitted.get('CFBundleIdentifier') != BUNDLE_ID:
            raise RuntimeError('Emitted app bundle ID changed')
        if type(emitted.get('PioStoreKitCatalogConfirmed')) is not bool or emitted['PioStoreKitCatalogConfirmed'] is not True:
            raise RuntimeError('Catalog opt-in is not a genuine Boolean true')
        if emitted.get('PioStoreKitEnvironment') != 'sandbox':
            raise RuntimeError('Emitted environment is not Sandbox-only')
        widget = plistlib.loads((app / 'PlugIns/DaylogWidgets.appex/Info.plist').read_bytes())
        if widget.get('CFBundleIdentifier') != BUNDLE_ID + '.widgets' or not widget.get('NSExtension') or KEYS.intersection(widget):
            raise RuntimeError('Widget identity/extension plist was affected by app-only override')
        result.update(status='PASS', app=str(app), appInfo={k: emitted[k] for k in ('CFBundleIdentifier', *sorted(KEYS))},
                      widgetBundleID=widget['CFBundleIdentifier'], widgetPreserved=True)
    except Exception as error:
        result['error'] = str(error)
    finally:
        after = {str(p.relative_to(repo)): digest(p) for p in protected}
        result['protectedSHA256After'] = after
        result['normalConfigurationUnchanged'] = after == before
        if after != before:
            result['status'] = 'FAIL'
            result['error'] = 'Protected sources changed during preparation; inspect without reverting others edits'
        (evidence / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({k: v for k, v in result.items() if not k.startswith('protectedSHA')}, indent=2), flush=True)
    return 0 if result['status'] == 'PASS' else 1


if __name__ == '__main__':
    raise SystemExit(main())
