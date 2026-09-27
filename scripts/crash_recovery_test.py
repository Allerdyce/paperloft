#!/usr/bin/env python3
"""Kill real file/undo workers at observed durable progress, then verify recovery."""
import hashlib
import json
import pathlib
import shutil
import signal
import subprocess
import tempfile
import time
import uuid

ROOT = pathlib.Path(__file__).resolve().parent.parent


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    build = subprocess.run(['swift', 'build', '--package-path', 'Packages/PaperloftKit', '-c', 'release', '--product', 'PaperloftCrashWorker'], cwd=ROOT, capture_output=True, text=True)
    (ROOT / 'build/crash-worker-build.log').write_text(build.stdout + build.stderr)
    build.check_returncode()
    binary_dir = subprocess.check_output(['swift', 'build', '--package-path', 'Packages/PaperloftKit', '-c', 'release', '--show-bin-path'], cwd=ROOT, text=True).strip()
    binary = str(pathlib.Path(binary_dir) / 'PaperloftCrashWorker')
    base = pathlib.Path(tempfile.mkdtemp(prefix='crash-test-', dir=ROOT / 'build'))
    started = time.monotonic()
    try:
        library = base / 'Library'; library.mkdir()
        inbox = base / 'Inbox'; inbox.mkdir()
        requests = []
        expected = {}
        for index in range(120):
            source = inbox / f'source-{index}.pdf'
            source.write_bytes((f'synthetic document {index}\n'.encode() * 60000))
            identity = str(uuid.uuid4()).upper()
            receipt = dict(id=identity, vendor='Crash Test Merchant', date=dict(year=2026, month=4, day=12), totalMinorUnits=1500, currency='USD', category='Office supplies', kind='receipt')
            requests.append(dict(source=source.as_uri(), receipt=receipt, mode='move' if index % 3 == 0 else 'copy'))
            expected[identity] = (source, digest(source))
        manifest = base / 'manifest.json'
        manifest.write_text(json.dumps(dict(root=library.as_uri(), requests=requests)))

        def kill_during(mode, state, entry_state):
            with (base / f'{mode}.out').open('wb') as out, (base / f'{mode}.err').open('wb') as err:
                process = subprocess.Popen([binary, mode, str(manifest)], stdout=out, stderr=err)
                deadline = time.monotonic() + 60
                killed_at = None
                try:
                    while process.poll() is None and time.monotonic() < deadline:
                        for file in (library / '.paperloft/history').glob('*.json'):
                            try:
                                journal = json.loads(file.read_text())
                            except (OSError, json.JSONDecodeError):
                                continue
                            completed = sum(e['state'] == entry_state for e in journal['entries'])
                            if journal['state'] == state and 0 < completed < len(journal['entries']):
                                process.send_signal(signal.SIGKILL)
                                killed_at = completed
                                break
                        if killed_at is not None:
                            break
                        time.sleep(0.005)
                    if killed_at is None:
                        raise AssertionError(f'{mode}: did not observe and kill an in-progress batch')
                    assert process.wait(timeout=10) == -signal.SIGKILL
                    return killed_at
                finally:
                    if process.poll() is None:
                        process.kill(); process.wait(timeout=10)

        filed_before_kill = kill_during('file', 'filing', 'complete')
        records = json.loads(subprocess.check_output([binary, 'recover', str(manifest)], timeout=120))
        assert len(records) == len(expected)
        assert len({r['relativePath'] for r in records}) == len(expected)
        assert len({r['receipt']['id'].upper() for r in records}) == len(expected)
        for record in records:
            _, expected_hash = expected[record['receipt']['id'].upper()]
            assert digest(library / record['relativePath']) == expected_hash
        visible = [p for p in library.rglob('*') if p.is_file() and '.paperloft' not in p.relative_to(library).parts]
        assert len(visible) == len(expected), 'Unexpected duplicate visible document'
        undone_before_kill = kill_during('undo', 'undoing', 'undone')
        records = json.loads(subprocess.check_output([binary, 'recover', str(manifest)], timeout=120))
        assert records == []
        for source, expected_hash in expected.values():
            assert source.is_file() and digest(source) == expected_hash
        assert not [p for p in library.rglob('*') if p.is_file() and '.paperloft' not in p.relative_to(library).parts]
        report = dict(result='PASS', documents=len(expected), file_process_signal='SIGKILL', filed_before_kill=filed_before_kill,
                      undo_process_signal='SIGKILL', undone_before_kill=undone_before_kill,
                      original_hashes_restored=len(expected), seconds=round(time.monotonic() - started, 2))
        (ROOT / 'evidence/P2-crash-recovery.json').write_text(json.dumps(report, indent=2) + '\n')
        print(json.dumps(report))
    finally:
        assert base.parent == ROOT / 'build' and base.name.startswith('crash-test-')
        shutil.rmtree(base)


if __name__ == '__main__':
    main()
