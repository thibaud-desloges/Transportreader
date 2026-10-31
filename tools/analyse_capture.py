#!/usr/bin/env python3
"""Read a private TransportReader capture offline; never writes to the card."""
import argparse
import collections
import datetime
import hashlib
import json
import re
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('capture', type=Path)
parser.add_argument('--date', action='append', default=[], help='ISO calendar date to search as a 14-bit Intercode day')
args = parser.parse_args()
report = json.loads(args.capture.read_text())
exchanges = report['exchanges']
print('# Analyse locale du rapport ZOU!\n')
print('Version du rapport :', report.get('formatVersion'))
print('Échanges :', len(exchanges))
print('Réponses :', dict(collections.Counter(e['statusWord'] for e in exchanges)))
print('\n## Fichiers lus par chemin absolu\n')
print('| Chemin | Emplacements lus | Contenus distincts | Octets non nuls cumulés |')
print('|---|---:|---:|---:|')
records = collections.defaultdict(dict)
conflicts = set()
for e in exchanges:
    if e['statusWord'] not in ('9000', '6282'):
        continue
    match = re.fullmatch(r'READ (BINARY )?PATH ([0-9A-F]+) / (\d+)(?: \(Le corrigé\))?', e['operation'])
    if not match:
        continue
    kind, path, number = match.groups()
    key = (bool(kind), int(number))
    data = bytes.fromhex(e['response'])
    if key in records[path] and records[path][key] != data:
        conflicts.add(path)
    records[path][key] = data
for path, values in sorted(records.items()):
    unique = set(values.values())
    print(f'| {path} | {len(values)} | {len(unique)} | {sum(sum(byte != 0 for byte in data) for data in values.values())} |')
if conflicts:
    print('Copies divergentes :', ', '.join(sorted(conflicts)))
print('\n## Recherche de dates candidates\n')
epoch = datetime.date(1997, 1, 1)
for date in args.date:
    target = datetime.date.fromisoformat(date)
    days = (target - epoch).days
    if not 0 <= days < 16384:
        print(date, ': hors plage Intercode')
        continue
    pattern = f'{days:014b}'
    hits = []
    seen = set()
    for path, values in records.items():
        for key, data in values.items():
            if data in seen:
                continue
            seen.add(data)
            bits = ''.join(f'{byte:08b}' for byte in data)
            positions = [n for n in range(len(bits) - 13) if bits[n:n+14] == pattern]
            if positions:
                hits.append((path, key, positions))
    print(date, ':', hits if hits else 'aucun motif de jour Intercode trouvé dans les contenus lus par chemin')
print('\nUne correspondance binaire isolée ne prouve pas un champ date ; une absence ne permet pas d’exclure un autre codage ou un fichier non lu.')
print('\n## Champs des événements Intercode\n')
for key, data in sorted(records.get('20002010', {}).items()):
    if key[0] or len(data) < 15 or not any(data):
        continue
    bits = ''.join(f'{byte:08b}' for byte in data)
    mask = int(bits[25:53], 2)
    day = int(bits[:14], 2)
    minute = int(bits[14:25], 2)
    if minute >= 1440:
        continue
    print(f'- Enregistrement {key[1]} : {epoch + datetime.timedelta(days=day)} {minute//60:02}:{minute%60:02} ; borne déclarée : {bool(mask & (1<<10))} ; passage déclaré : {bool(mask & (1<<9))}.')
print('\n## Intégrité du fichier analysé\n')
print('SHA-256 :', hashlib.sha256(args.capture.read_bytes()).hexdigest())
