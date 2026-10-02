#!/usr/bin/env python3
"""Check the newest committed AC-10 evidence from scripts/performance_check.sh against the frozen limits.

AC-10 (amended 2026-10-01): 100 mixed documents understood in <= 400 s with the system model
(<= 30 s parser-only); no main-thread hang over 250 ms; peak memory under 600 MB.
Evidence: XCTest metrics and signposts. The run must be of the current app sources.
"""
import json
import pathlib
import subprocess
import sys

root = pathlib.Path.cwd()
LIMIT_SECONDS = {"system": 400.0, "parser": 30.0}
MAX_HANG_SECONDS = 0.25
MAX_PEAK_BYTES = 600 * 1000 * 1000
SOURCES = ["Apps", "Packages", "Paperloft.xcodeproj", "Tests/PaperloftPerformanceTests", "scripts/generate_performance_inputs.swift"]
failures = []


def fail(message):
    failures.append(message)
    print("FAIL   " + message)


def check(mode):
    folders = sorted((root / "evidence/performance").glob(mode + "-*/"))
    if not folders:
        return fail(f"{mode}: no evidence/performance/{mode}-* folder")
    folder = folders[-1]
    name = folder.relative_to(root)
    print(f"{mode}: {name}")
    commit_file = folder / "commit.txt"
    if not commit_file.exists():
        return fail(f"{mode}: {name} doesn't record the commit it measured (commit.txt)")
    commit, *flags = commit_file.read_text().split()
    if "dirty" in flags:
        fail(f"{mode}: {name} measured uncommitted app or test changes")
    changed = subprocess.run(["git", "diff", "--quiet", commit, "HEAD", "--", *SOURCES]).returncode
    if changed:
        fail(f"{mode}: app or test sources changed since the measured commit {commit[:9]}")
    log = (folder / "test.log").read_text(errors="replace") if (folder / "test.log").exists() else ""
    if "** TEST SUCCEEDED **" not in log:
        fail(f"{mode}: the XCTest run didn't succeed")
    rows = json.loads((folder / "iterations.json").read_text()) if (folder / "iterations.json").exists() else []
    if not rows:
        fail(f"{mode}: no pipeline reports in iterations.json")
    for row in rows:
        label = f"{mode} iteration {row.get('iteration')}"
        if row.get("backend") != mode or row.get("recordedBackends") != {mode: 100}:
            fail(f"{label}: not all 100 documents used the {mode} backend")
        if row.get("inputCount") != 100 or row.get("completed") != 100 or row.get("persistedCompleted") != 100 or row.get("failures"):
            fail(f"{label}: {row.get('completed')} of {row.get('inputCount')} completed")
        if row.get("seconds", 1e9) > LIMIT_SECONDS[mode]:
            fail(f"{label}: {row.get('seconds'):.1f} s, limit {LIMIT_SECONDS[mode]:.0f} s")
        if row.get("maximumMainHeartbeatGapSeconds", 1e9) > MAX_HANG_SECONDS:
            fail(f"{label}: main-thread gap {row.get('maximumMainHeartbeatGapSeconds') * 1000:.0f} ms, limit 250 ms")
        if row.get("lifetimePeakPhysicalBytes", 1e18) >= MAX_PEAK_BYTES or row.get("memoryReadFailures"):
            fail(f"{label}: peak memory {row.get('lifetimePeakPhysicalBytes', 0) / 1e6:.0f} MB, limit 600 MB")
    metrics_file = folder / "metrics.json"
    metrics = []
    if metrics_file.exists():
        for test in json.loads(metrics_file.read_text()):
            for run in test.get("testRuns", []):
                metrics += run.get("metrics", [])
    for required in ("Clock", "Memory Peak", "UnderstandInboxBatch"):
        found = [m for m in metrics if required in m.get("displayName", "") or required in m.get("identifier", "")]
        if not found or not any(m.get("measurements") for m in found):
            fail(f"{mode}: XCTest metric '{required}' has no measurements")
    signposts = [v for m in metrics if "UnderstandInboxBatch" in m.get("displayName", "") + m.get("identifier", "")
                 and m.get("unitOfMeasurement") == "s" for v in m.get("measurements", [])]
    if signposts and max(signposts) > LIMIT_SECONDS[mode]:
        fail(f"{mode}: UnderstandInboxBatch signpost {max(signposts):.1f} s, limit {LIMIT_SECONDS[mode]:.0f} s")


for mode in ("system", "parser"):
    check(mode)
print("AC-10 evidence: " + ("PASS" if not failures else f"FAIL ({len(failures)})"))
sys.exit(1 if failures else 0)
