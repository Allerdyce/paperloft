#!/usr/bin/env python3
"""Check xccov's entire PaperloftKit target, without file exclusions."""
import json
import pathlib
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parent.parent
source_files = {p.name for p in (root / 'Packages/PaperloftKit/Sources/PaperloftKit').glob('*.swift')}

def kit_target(result):
    """The whole PaperloftKit target in an xcresult, or None if xccov doesn't list one."""
    data = json.loads(subprocess.check_output(['xcrun', 'xccov', 'view', '--report', '--json', result], cwd=root))
    targets = [target for target in data['targets'] if target['name'] == 'PaperloftKit']
    if len(targets) > 1:
        sys.exit('FAIL: more than one PaperloftKit coverage target in ' + result)
    if not targets:
        return None
    measured = {f['name'] for f in targets[0]['files']}
    if not source_files <= measured:
        sys.exit('FAIL: engine source absent from coverage: ' + ', '.join(sorted(source_files - measured)))
    return targets[0]

# The package's own unhosted test run always has the whole target (ci.sh). The app-hosted run is
# checked as well whenever xccov lists PaperloftKit there. Every available measurement must pass.
measurements = []
kit_file = root / 'build/latest-kit-coverage.txt'
if not kit_file.exists():
    sys.exit('FAIL: no PaperloftKit package coverage result; run scripts/ci.sh')
for source, result in (('package tests', kit_file.read_text().strip()),
                       ('app-hosted tests', (root / 'build/latest-test-result.txt').read_text().strip())):
    target = kit_target(result)
    if target is None:
        if source == 'package tests':
            sys.exit('FAIL: expected exactly one whole PaperloftKit coverage target in ' + result)
        continue
    measurements.append(dict(source=source, coveredLines=target['coveredLines'], executableLines=target['executableLines'],
                             lineCoverage=target['lineCoverage'], xcresult=result))
passed = all(m['lineCoverage'] >= .75 for m in measurements)
report = dict(target='PaperloftKit', measurements=measurements, result='PASS' if passed else 'FAIL')
(root / 'evidence/P2-coverage.json').write_text(json.dumps(report, indent=2) + '\n')
for m in measurements:
    print(f"{'PASS' if m['lineCoverage'] >= .75 else 'FAIL'}: whole PaperloftKit coverage {m['lineCoverage']:.2%} ({m['coveredLines']}/{m['executableLines']}) from {m['source']}; needs 75%")
sys.exit(0 if passed else 1)
