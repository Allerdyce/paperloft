#!/usr/bin/env python3
"""Verifier P4: compare every test defined in Swift files listed in ACCEPTANCE.lock with the tests executed
in an xcresult (xcresulttool get test-results tests JSON). XCTest tests are matched as Class + testName();
Swift Testing @Test functions are matched by function name (and suite type when the xcresult names one).
Usage: compare_locked.py <repo> <tests.json> <out.json> <executed.txt>"""
import json, pathlib, re, sys

root, tree_path, out_path, executed_path = map(pathlib.Path, sys.argv[1:5])
defs = []
for line in (root / "ACCEPTANCE.lock").read_text().splitlines():
    parts = line.split(None, 1)
    if len(parts) != 2 or not parts[1].strip().endswith(".swift"):
        continue
    path = parts[1].strip()
    lines = (root / path).read_text().splitlines()
    xc_class, st_type, pending_test = None, None, False
    for ln in lines:
        m = re.match(r'\s*(?:@\w+\s+)*(?:final\s+)?(?:@\w+\s+)*class\s+(\w+)\s*:\s*XCTestCase', ln)
        if m:
            xc_class = m.group(1)
        m = re.match(r'\s*(?:@\w+(?:\([^)]*\))?\s+)*(?:final\s+)?(?:struct|class|enum|extension)\s+(\w+)', ln)
        if m and not re.search(r':\s*XCTestCase', ln):
            st_type = m.group(1)
        if re.match(r'\s*@Test\b', ln):
            pending_test = True
        fm = re.search(r'\bfunc\s+(\w+)\s*\(', ln)
        if fm:
            name = fm.group(1)
            if pending_test:
                defs.append({"file": path, "kind": "swift-testing", "suite": st_type, "name": name})
                pending_test = False
            elif name.startswith("test") and xc_class:
                defs.append({"file": path, "kind": "xctest", "suite": xc_class, "name": name})

tree = json.loads(tree_path.read_text())
executed = []
def walk(node, bundle=None, suite=None):
    kind = node.get("nodeType")
    if kind in ("Unit test bundle", "UI test bundle"):
        bundle = node.get("name")
    if kind == "Test Suite":
        suite = node.get("name")
    if kind == "Test Case":
        executed.append((bundle, suite, node.get("name") or "", node.get("result")))
    for child in node.get("children") or []:
        walk(child, bundle, suite)
for node in tree.get("testNodes", []):
    walk(node)

rows, missing, not_passed = [], [], []
for d in defs:
    if d["kind"] == "xctest":
        hits = [e for e in executed if e[1] == d["suite"] and e[2] == d["name"] + "()"]
    else:
        hits = [e for e in executed if re.match(re.escape(d["name"]) + r'\(', e[2]) and (e[1] in (None, d["suite"]) or d["suite"] is None)]
        if not hits:
            hits = [e for e in executed if re.match(re.escape(d["name"]) + r'\(', e[2])]
    label = f'{d["suite"]}/{d["name"]}()'
    rows.append({**d, "executions": [list(h) for h in hits]})
    if not hits:
        missing.append(label)
    elif any(h[3] != "Passed" for h in hits):
        not_passed.append([label, [h[3] for h in hits]])
results = {}
for e in executed:
    results[e[3]] = results.get(e[3], 0) + 1
summary = {"locked_swift_files": len({d["file"] for d in defs}), "defined_in_locked_files": len(defs),
           "found_executed": len(defs) - len(missing), "missing": missing, "not_passed": not_passed,
           "total_test_cases_in_xcresult": len(executed), "xcresult_results": results}
out_path.write_text(json.dumps({"summary": summary, "rows": rows}, indent=1))
executed_path.write_text("".join(f"{r}\t{b}\t{s or '-'}\t{n}\n" for b, s, n, r in sorted(executed, key=lambda e: (e[0] or "", e[1] or "", e[2]))))
print(json.dumps(summary, indent=1))
sys.exit(0 if not missing and not not_passed else 1)
