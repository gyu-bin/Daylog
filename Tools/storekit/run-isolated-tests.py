#!/usr/bin/env python3
"""Run each local StoreKit XCTest in a separate test host process, serially.

Build the dedicated Debug scheme with build-for-testing first. This runner never
builds, installs a production app, changes signing, or calls a StoreKit reset API.
The selected tests themselves clear the local StoreKit ledger in setUp/tearDown.
"""

import argparse
import json
import os
from pathlib import Path
import re
import shlex
import signal
import subprocess
import sys
import time


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "DaylogStoreKitTests/PioStoreKitIntegrationTests.swift"
PROJECT = ROOT / "Daylog.xcodeproj"
CLASS = "PioStoreKitIntegrationTests"


def arguments():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platform", choices=("ios", "macos"), required=True)
    parser.add_argument("--simulator-id", help="Dedicated iOS Simulator UUID; physical devices are unsupported")
    parser.add_argument("--derived-data", type=Path, required=True, help="Existing build-for-testing DerivedData")
    parser.add_argument("--cloned-source-packages", type=Path, help="Existing shared Swift package checkout directory, if used when building")
    parser.add_argument("--output", type=Path, required=True, help="New directory for logs, xcresults, and summary.json")
    parser.add_argument("--test", action="append", help="Exact test method; repeat this option to select several")
    parser.add_argument("--repeat", type=int, default=1, help="Explicit repetitions, each in a new process (default 1)")
    parser.add_argument("--timeout", type=int, default=300, help="Maximum seconds per invocation (default 300)")
    parser.add_argument("--dry-run", action="store_true", help="Print commands without launching tests or writing files")
    args = parser.parse_args()
    methods = re.findall(r"^    func (test\w+)\(", SOURCE.read_text(), re.MULTILINE)
    if not methods or len(methods) != len(set(methods)):
        parser.error("Cannot discover an unambiguous XCTest method list")
    args.tests = args.test or methods
    if len(args.tests) != len(set(args.tests)) or any(test not in methods for test in args.tests):
        parser.error("--test must select distinct, exact methods declared in PioStoreKitIntegrationTests.swift")
    if not 1 <= args.repeat <= 100 or args.timeout < 30:
        parser.error("--repeat must be 1...100 and --timeout must be at least 30 seconds")
    if args.platform == "ios":
        if not args.simulator_id or not re.fullmatch(r"[0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}", args.simulator_id):
            parser.error("iOS requires an explicit --simulator-id UUID")
        args.scheme, args.target = "DaylogiOSStoreKit", "DaylogStoreKitTests"
        args.destination = f"platform=iOS Simulator,id={args.simulator_id}"
    else:
        if args.simulator_id:
            parser.error("--simulator-id is only valid with --platform ios")
        args.scheme, args.target = "DaylogStoreKitTests", "DaylogTests"
        args.destination = "platform=macOS"
    args.derived_data = args.derived_data.expanduser().resolve()
    args.output = args.output.expanduser().resolve()
    if not args.derived_data.is_dir():
        parser.error("--derived-data must already exist; this runner does not build")
    if args.cloned_source_packages:
        args.cloned_source_packages = args.cloned_source_packages.expanduser().resolve()
        if not args.cloned_source_packages.is_dir():
            parser.error("--cloned-source-packages must already exist")
    if args.output.exists():
        parser.error("--output must be a new directory so earlier evidence is preserved")
    if not args.dry_run and not list((args.derived_data / "Build/Products").glob("*.xctestrun")):
        parser.error("No .xctestrun found; run the dedicated Debug scheme with build-for-testing first")
    return args


def command(args, test, result):
    cmd = [
        "/usr/bin/xcodebuild", "-project", str(PROJECT), "-scheme", args.scheme,
        "-configuration", "Debug", "-destination", args.destination,
        "-derivedDataPath", str(args.derived_data), "-disableAutomaticPackageResolution",
        "-parallel-testing-enabled", "NO",
        f"-only-testing:{args.target}/{CLASS}/{test}",
        "-resultBundlePath", str(result), "test-without-building",
    ]
    if args.cloned_source_packages:
        cmd[1:1] = ["-clonedSourcePackagesDirPath", str(args.cloned_source_packages)]
    return cmd


def stop(process):
    """Stop this xcodebuild invocation, never find/kill apps by bundle ID."""
    if process.poll() is not None:
        return
    os.killpg(process.pid, signal.SIGTERM)
    try:
        process.wait(timeout=10)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL)
        process.wait()


def run_one(cmd, log, timeout):
    with log.open("w") as output:
        output.write("Command: " + shlex.join(cmd) + "\n\n")
        output.flush()
        process = subprocess.Popen(cmd, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            return process.wait(timeout=timeout), None
        except subprocess.TimeoutExpired:
            stop(process)
            return process.returncode, "timeout"
        except KeyboardInterrupt:
            stop(process)
            return process.returncode, "interrupted"


def main():
    args = arguments()
    plan = []
    for repetition in range(1, args.repeat + 1):
        for index, test in enumerate(args.tests, 1):
            stem = f"{repetition:02d}-{index:02d}-{test}"
            result = args.output / (stem + ".xcresult")
            plan.append((test, repetition, result, args.output / (stem + ".log"), command(args, test, result)))
    if args.dry_run:
        for _, _, _, _, cmd in plan:
            print(shlex.join(cmd))
        print(f"Dry run: {len(plan)} serial invocations; no files written or processes launched.")
        return 0
    args.output.mkdir(parents=True)
    summary = {
        "scheme": args.scheme, "destination": args.destination, "derivedData": str(args.derived_data),
        "source": str(SOURCE), "plannedInvocations": len(plan), "runs": [],
    }
    summary_path = args.output / "summary.json"
    for test, repetition, result, log, cmd in plan:
        print(f"[{len(summary['runs']) + 1}/{len(plan)}] {test} (iteration {repetition})", flush=True)
        started = time.monotonic()
        code, stop_reason = run_one(cmd, log, args.timeout)
        content = log.read_text(errors="replace")
        # Exit zero without the selected XCTest actually passing is not a pass.
        passed_lines = re.findall(rf"Test Case '[^\n]*\b{re.escape(test)}\]' passed ", content)
        status = stop_reason or ("passed" if code == 0 and len(passed_lines) == 1 and result.exists() else "failed")
        summary["runs"].append({
            "test": test, "iteration": repetition, "status": status, "exitCode": code,
            "durationSeconds": round(time.monotonic() - started, 3), "log": str(log),
            "xcresult": str(result), "command": cmd,
        })
        summary_path.write_text(json.dumps(summary, indent=2) + "\n")
        print(f"  {status}: {log}", flush=True)
        if stop_reason:
            print("Stopped: inspect the dedicated test host before resuming; remaining methods were not run.", file=sys.stderr)
            break
    passed = sum(item["status"] == "passed" for item in summary["runs"])
    print(f"Passed {passed}/{len(plan)} planned invocations. Evidence: {summary_path}")
    return 0 if passed == len(plan) else 1


if __name__ == "__main__":
    raise SystemExit(main())
