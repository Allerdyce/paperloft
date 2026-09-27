#!/usr/bin/env python3
"""Run P0 checks and detect changes outside evidence/ and BUGS.md."""
import hashlib
import pathlib
import subprocess
import sys

root = pathlib.Path.cwd()
args = sys.argv[1:]
local = "--local" in args
if local:
    args.remove("--local")
if args != ["P0"]:
    sys.exit("Usage: scripts/gate.sh P0 [--local]")

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
report = root / "evidence/gates" / ("P0-local-self.md" if local else "P0-self.md")
report.parent.mkdir(parents=True, exist_ok=True)
commands = [
    ["scripts/preflight_check.sh", *( ["--local"] if local else [] ), "--log"],
    ["scripts/verify_local_baseline.sh" if local else "scripts/verify_lock.sh"],
    ["scripts/ci.sh"],
    ["scripts/privacy_check.sh"],
]
rows = []
code = 0
try:
    for command in commands:
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
    text = "# P0 " + ("local readiness" if local else "formal") + " self-check\n\n"
    text += "\n".join(f"- `{command}`: exit {status}" for command, status in rows)
    text += "\n- Source integrity: " + ("FAIL: " + ", ".join(changed) if changed else "PASS") + "\n"
    text += "\n" + ("LOCAL CHECKS" if local else "SELF-CHECK") + (": PASS" if code == 0 else ": FAIL") + "\n"
    text += "Independent verifier decision required. Local readiness never closes a formal gate.\n"
    report.write_text(text)
sys.exit(code)
