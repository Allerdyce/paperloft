#!/usr/bin/env python3
"""Structural checks; the independent verifier judges visual difficulty."""
import collections
import json
import pathlib

root = pathlib.Path('Tests/Fixtures')
rows = [json.loads(line) for line in (root / 'labels.jsonl').read_text().splitlines() if line]
assert len(rows) >= 150, 'At least 150 documents required'
assert len({r['id'] for r in rows}) == len(rows), 'Duplicate IDs'
assert len({r['vendor'] for r in rows if r.get('vendor')}) >= 40, 'At least 40 represented merchants required'
assert len({r['layout'] for r in rows}) >= 12, 'At least 12 layout variants required'
counts = collections.Counter(tag for row in rows for tag in row.get('tags', []))
counts['not_receipt'] = sum(r['kind'] == 'not_receipt' for r in rows)
for tag, minimum in {'photo': .3, 'long': .2, 'not_receipt': .1, 'confusable': .1}.items():
    assert counts[tag] / len(rows) >= minimum, f'Insufficient {tag} mix'
for row in rows:
    assert pathlib.Path(row['id']).name == row['id'], 'Unsafe ID'
    files = [p for p in root.glob(row['id'] + '.*') if p.suffix in {'.png', '.jpg', '.pdf', '.heic'}]
    assert len(files) == 1 and files[0].stat().st_size > 0, f'Missing or ambiguous document: {row["id"]}'
print(f'PASS: {len(rows)} documents, 40+ merchants, 12+ layouts, required tagged mix and corresponding files.')
print('Visual realism and difficulty still require independent review.')
