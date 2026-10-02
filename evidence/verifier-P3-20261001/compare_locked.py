#!/usr/bin/env python3
"""Compare tests executed in the verifier's .xcresult with every test defined in locked Swift files."""
import json, subprocess, sys, re
xcresult, defs_path, out_path = sys.argv[1:4]
tree = json.loads(subprocess.check_output(['xcrun', 'xcresulttool', 'get', 'test-results', 'tests', '--path', xcresult]))
executed = {}
def walk(node, trail):
    kind = node.get('nodeType'); name = node.get('name', '')
    if kind == 'Test Case':
        base = re.sub(r'\(.*\)$', '', name)
        executed.setdefault(base, []).append({'path': '/'.join(trail + [name]), 'result': node.get('result')})
    for child in node.get('children', []) or []:
        walk(child, trail + [name])
for n in tree.get('testNodes', []): walk(n, [])
defs = json.load(open(defs_path))
report = {'xcresult': xcresult, 'locked': {}, 'missing': [], 'not_passed': []}
for f, tests in defs.items():
    for kind, name in tests:
        runs = executed.get(name, [])
        report['locked'].setdefault(f, []).append({'test': name, 'runs': runs})
        if not runs: report['missing'].append(f + '::' + name)
        elif not any(r['result'] == 'Passed' for r in runs): report['not_passed'].append(f + '::' + name)
counts = {}
for runs in executed.values():
    for r in runs: counts[r['result']] = counts.get(r['result'], 0) + 1
report['executed_result_counts'] = counts
report['locked_total'] = sum(len(v) for v in defs.values())
json.dump(report, open(out_path, 'w'), indent=1)
print('executed result counts:', counts)
print('locked tests defined:', report['locked_total'], 'missing:', len(report['missing']), 'not passed:', len(report['not_passed']))
for m in report['missing']: print('MISSING', m)
for m in report['not_passed']: print('NOT PASSED', m)
