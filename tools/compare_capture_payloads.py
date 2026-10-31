#!/usr/bin/env python3
"""Compare local READ payload sets; repeated aliases are not distinct records."""
import argparse
import hashlib
import json
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('captures', nargs='+', type=Path)
args = parser.parse_args()
sets = []
for path in args.captures:
    report = json.loads(path.read_text())
    payloads = {bytes.fromhex(e['response']) for e in report['exchanges']
                if e['operation'].startswith('READ') and e['statusWord'] in ('9000', '6282')
                and e['response'] and any(bytes.fromhex(e['response']))}
    sets.append((path.name, payloads))
print('# Comparaison des contenus READ non nuls\n')
print('Une même réponse obtenue par plusieurs adresses ne compte qu’une fois. '
      'Des contenus identiques ne prouvent pas que tous les fichiers ont été explorés.\n')
print('| Capture | Contenus distincts | Nouveaux depuis la précédente | Disparus |')
print('|---|---:|---:|---:|')
previous = None
for name, payloads in sets:
    added = '—' if previous is None else str(len(payloads - previous))
    removed = '—' if previous is None else str(len(previous - payloads))
    print(f'| {name} | {len(payloads)} | {added} | {removed} |')
    previous = payloads
print('\n| Empreinte SHA-256 abrégée | Taille | Présent dans les captures (ordre ci-dessus) |')
print('|---|---:|---|')
for payload in sorted(set.union(*(s for _, s in sets)), key=lambda b: (len(b), b)):
    digest = hashlib.sha256(payload).hexdigest()[:16]
    membership = ', '.join(str(i+1) for i, (_, s) in enumerate(sets) if payload in s)
    print(f'| {digest} | {len(payload)} octets | {membership} |')
