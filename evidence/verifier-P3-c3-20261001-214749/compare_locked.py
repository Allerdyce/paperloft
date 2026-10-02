"""Compare test functions defined in ACCEPTANCE.lock Swift files with tests executed in an xcresult.
XCTest entries are 'Class/testName()'; Swift Testing entries are matched by function name."""
import json, re, sys
defs = json.load(open(sys.argv[1]))
tree = json.load(open(sys.argv[2]))
executed = []  # (bundle, suite, name, result)
def walk(node, bundle=None, suite=None):
    t = node.get("nodeType")
    if t in ("Unit test bundle", "UI test bundle"): bundle = node.get("name")
    if t == "Test Suite": suite = node.get("name")
    if t == "Test Case":
        executed.append((bundle, suite, node.get("name"), node.get("result")))
    for c in node.get("children", []) or []:
        walk(c, bundle, suite)
for n in tree.get("testNodes", []): walk(n)
rows, missing, notpassed, ambiguous = [], [], [], []
for path, tests in defs.items():
    for t in tests:
        if t.startswith("SWIFT-TESTING:"):
            fn = re.search(r'func\s+(\w+)\s*\(', t).group(1)
            hits = [e for e in executed if re.match(re.escape(fn) + r'\(', e[2] or "")]
            label = fn + "()"
        else:
            cls, fn = t.split("/")
            hits = [e for e in executed if e[1] == cls and e[2] == fn]
            label = t
        res = [h[3] for h in hits]
        rows.append({"file": path, "test": label, "executions": [list(h) for h in hits]})
        if not hits: missing.append(label)
        elif len(hits) > 1: ambiguous.append(label)
        if hits and any(r != "Passed" for r in res): notpassed.append((label, res))
summary = {"defined_in_locked_files": len(rows), "found_executed": len(rows) - len(missing), "missing": missing,
           "not_passed": notpassed, "ambiguous_name_matches": ambiguous,
           "total_test_cases_in_xcresult": len(executed),
           "xcresult_results": {r: [e[3] for e in executed].count(r) for r in set(e[3] for e in executed)}}
json.dump({"summary": summary, "rows": rows}, open(sys.argv[3], "w"), indent=1)
print(json.dumps(summary, indent=1))
with open(sys.argv[4], "w") as f:
    for b, s, n, r in sorted(executed, key=lambda e: (e[0] or "", e[1] or "", e[2] or "")): f.write(f"{r}\t{b}\t{s or '-'}\t{n}\n")
