#!/usr/bin/env python3
"""Check xccov's entire PaperloftKit target, without file exclusions."""
import json
import pathlib
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parent.parent
result = (root / 'build/latest-test-result.txt').read_text().strip()
data = json.loads(subprocess.check_output(['xcrun', 'xccov', 'view', '--report', '--json', result], cwd=root))
targets = [target for target in data['targets'] if target['name'] == 'PaperloftKit']
if len(targets) != 1:
    sys.exit('FAIL: expected exactly one whole PaperloftKit coverage target')
target = targets[0]
source_files = {p.name for p in (root / 'Packages/PaperloftKit/Sources/PaperloftKit').glob('*.swift')}
measured = {f['name'] for f in target['files']}
if not source_files <= measured:
    sys.exit('FAIL: engine source absent from coverage: ' + ', '.join(sorted(source_files - measured)))
report = dict(target=target['name'], coveredLines=target['coveredLines'], executableLines=target['executableLines'],
              lineCoverage=target['lineCoverage'], xcresult=result, result='PASS' if target['lineCoverage'] >= .75 else 'FAIL')
(root / 'evidence/P2-coverage.json').write_text(json.dumps(report, indent=2) + '\n')
print(f"{report['result']}: whole PaperloftKit coverage {target['lineCoverage']:.2%} ({target['coveredLines']}/{target['executableLines']}); needs75%")
sys.exit(0 if report['result'] == 'PASS' else 1)
