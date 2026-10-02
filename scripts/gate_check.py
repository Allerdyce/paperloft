#!/usr/bin/env python3
"""Run local or formal phase checks and detect changes outside evidence/ and BUGS.md."""
import hashlib
import pathlib
import subprocess
import sys

root = pathlib.Path.cwd()
args = sys.argv[1:]
local = "--local" in args
if local:
    args.remove("--local")
if len(args) != 1 or args[0] not in {"P0", "P1", "P2", "P3", "P4"}:
    sys.exit("Usage: scripts/gate.sh P0|P1|P2|P3|P4 [--local]")
phase = args[0]

def snapshot():
    names = subprocess.check_output([
        "git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"
    ]).decode().split("\0")
    result = {}
    for name in sorted(set(names) - {""}):
        if name.startswith("evidence/") or name == "BUGS.md":
            continue
        path = root / name
        if path.is_symlink():
            value = "link:" + str(path.readlink())
        elif path.is_file():
            value = hashlib.sha256(path.read_bytes()).hexdigest()
        else:
            value = "missing"
        result[name] = (value, path.lstat().st_mode if path.exists() else 0)
    return result

before = snapshot()
report = root / "evidence/gates" / (phase + ("-local-self.md" if local else "-self.md"))
report.parent.mkdir(parents=True, exist_ok=True)
commands = [
    ["scripts/preflight_check.sh", *( ["--local"] if local else [] ), "--log"],
    ["scripts/verify_local_baseline.sh" if local else "scripts/verify_lock.sh"],
    ["scripts/ci.sh"],
    ["scripts/privacy_check.sh"],
]
if phase == "P1":
    commands += [["python3", "scripts/check_fixture_set.py"],
                 ["scripts/eval.sh", "--model", "parser"],
                 ["scripts/eval.sh", "--model", "system"]]
elif phase == "P2":
    commands += [["python3", "scripts/coverage_check.py"],
                 ["python3", "scripts/crash_recovery_test.py"],
                 ["scripts/eval.sh", "--model", "parser"],
                 ["scripts/eval.sh", "--model", "system"],
                 ["scripts/eval.sh", "--private"]]
if phase in ("P3", "P4"):
    commands += [["scripts/build_qa.sh"], ["python3", "scripts/coverage_check.py"]]
rows = []
code = 0
try:
    for command in commands:
        if command[0] == "scripts/eval.sh" and phase == "P1":
            result = subprocess.run(command, check=False, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            print(result.stdout, end="", flush=True)
            backend = command[-1]
            (root / "evidence" / ("P1-" + backend + ".txt")).write_text(result.stdout)
            expected_mode = "parser" if backend == "parser" else "fixtures"
            valid = result.returncode in (0, 1) and ("SCORE " + expected_mode + ": ") in result.stdout
            if backend == "parser":
                valid = valid and "PASS   difficulty:" in result.stdout
            else:
                valid = valid and "FAIL   mix:" not in result.stdout
            import json
            predictions = root / "evidence" / ("predictions-" + backend + ".jsonl")
            valid = valid and predictions.exists() and bool(predictions.read_text().strip())
            if backend == "system" and valid:
                valid = any(json.loads(line).get("backend") == "system" for line in predictions.read_text().splitlines())
            rows.append((" ".join(command) + " (P1 pipeline/mix/difficulty only; P2 accuracy remains gated later)", result.returncode))
            if not valid:
                code = 1
                break
        elif command[0] == "scripts/eval.sh" and phase == "P2":
            result = subprocess.run(command, check=False, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            print(result.stdout, end="", flush=True)
            backend = "private" if command[-1] == "--private" else command[-1]
            (root / "evidence" / ("P2-" + backend + ".txt")).write_text(result.stdout)
            valid = result.returncode == 0
            if backend == "system" and valid:
                import json
                predictions = [json.loads(line) for line in (root / "evidence/predictions-system.jsonl").read_text().splitlines()]
                valid = bool(predictions) and all(row.get("backend") == "system" for row in predictions)
            rows.append((" ".join(command), result.returncode if valid else 1))
            if not valid:
                code = 1
                break
        else:
            result = subprocess.run(command, check=False)
            rows.append((" ".join(command), result.returncode))
            if result.returncode:
                code = result.returncode
                break
except BaseException:
    code = 1
    raise
finally:
    after = snapshot()
    changed = sorted(k for k in before.keys() | after.keys() if before.get(k) != after.get(k))
    if changed:
        code = 1
    text = "# " + phase + " " + ("local readiness" if local else "formal") + " self-check\n\n"
    text += "\n".join(f"- `{command}`: exit {status}" for command, status in rows)
    text += "\n- Source integrity: " + ("FAIL: " + ", ".join(changed) if changed else "PASS") + "\n"
    text += "\n" + ("LOCAL CHECKS" if local else "SELF-CHECK") + (": PASS" if code == 0 else ": FAIL") + "\n"
    text += "Independent verifier decision required. Local readiness never closes a formal gate.\n"
    if phase == "P4":
        import os
        signing = os.environ.get("PAPERLOFT_CI_XCCONFIG") or "ad-hoc (App Intents framework tests need development signing; see README)"
        text += "AC-15's App Intents framework tests ran with signing: " + signing + ".\n"
    if phase == "P2":
        text += "AC-04 requires the independent verifier's fresh60-document holdout run. The builder never reads or scores it directly. P1 fixture difficulty was decided before locking; P2 uses the frozen accuracy thresholds on the unchanged corpus.\n"
    report.write_text(text)
sys.exit(code)
