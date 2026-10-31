#!/usr/bin/env python3
"""Local, exact cross-references between explicit card files; no network access."""
import argparse
import collections
import json
import re
from pathlib import Path

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('capture', type=Path)
a = p.parse_args()
r = json.loads(a.capture.read_text())
roots = {'334D54522E494341': '', 'A0000004040125092001': '2000',
         'A0000004040225092001': '1000', 'A0000004044125092001': '2300',
         'A000000291A00000019102': '2100', 'A000000291D25008009301': '2200'}
parts = collections.defaultdict(dict)
for e in r['exchanges']:
    m = re.fullmatch(r'READ (BINARY )?PATH (APP )?([0-9A-F]+) / (\d+)(?: \(Le corrigé\))?', e['operation'])
    if not m or e['statusWord'] not in ('9000', '6282'): continue
    binary, relative, path, index = m.groups()
    if relative:
        root = roots.get(e.get('application', r['selectedApplication']))
        if root is None: continue
        path = root + path
    if path.startswith('3F00'): path = path[4:]
    key = (bool(binary), int(index)); data = bytes.fromhex(e['response'])
    if key in parts[path] and parts[path][key] != data: raise ValueError('conflicting file replies: '+path)
    parts[path][key] = data
files = {}
for path, chunks in parts.items():
    if any(binary for binary, _ in chunks):
        joined = bytearray()
        for (_, offset), data in sorted(chunks.items()):
            if offset > len(joined): raise ValueError('binary gap: '+path)
            overlap = min(len(joined)-offset, len(data))
            if joined[offset:offset+overlap] != data[:overlap]: raise ValueError('binary overlap: '+path)
            joined.extend(data[overlap:])
        files[path] = bytes(joined)
    else:
        for (_, index), data in sorted(chunks.items()): files[f'{path} record {index}'] = data
print('# Références exactes et zones restant à interpréter\n')
print('Les positions sont comptées depuis zéro. Une valeur isolée, surtout sur 16 bits, ne suffit pas à nommer un champ.\n')
print('| Zone non nulle | Taille | Octets non nuls |')
print('|---|---:|---:|')
for name, data in sorted(files.items()):
    if any(data): print(f'| {name} | {len(data)} | {sum(x != 0 for x in data)} |')
amc = files.get('22002203', b'')
if len(amc) >= 357 and amc[3:6] == bytes.fromhex('250E00') and amc[12] == 35:
    print('\n## Identifiants AMC recopiés ailleurs\n')
    matches = []
    for i in range(35):
        identifier = amc[17+8*i:21+8*i]
        for name, data in files.items():
            if name == '22002203': continue
            for endian, value in [('normal', identifier), ('inversé', identifier[::-1])]:
                bits = ''.join(f'{x:08b}' for x in data)
                needle = ''.join(f'{x:08b}' for x in value)
                start = bits.find(needle)
                while start >= 0:
                    matches.append((i+1, name, start, endian)); start = bits.find(needle, start+1)
    for sector, name, bit, endian in matches: print(f'- Secteur {sector} : {name}, bit {bit}, ordre {endian}.')
    if not matches: print('Aucun des 35 identifiants de 32 bits n’est recopié dans un autre fichier lu, dans les deux ordres d’octets et à toute position de bits.')
print('\n## Codes des gares, à toutes les positions de bits\n')
print('| Code | Zone | Position en bits | Ordre d’octets |')
print('|---:|---|---:|---|')
for code in (8582, 13143, 16008):
    for name, data in sorted(files.items()):
        if not any(data): continue
        bits = ''.join(f'{x:08b}' for x in data)
        for endian in ('big', 'little'):
            needle = ''.join(f'{x:08b}' for x in code.to_bytes(2, endian))
            start = bits.find(needle)
            while start >= 0:
                print(f'| {code} | {name} | {start} | {endian} |'); start = bits.find(needle, start+1)
print('\nLe motif 8582 à la position 156 du titre principal chevauche les champs appareil/agent de vente déjà décodés : il ne constitue pas une seconde origine Marseille. C’est un exemple de correspondance brute à rejeter.')
print('\nCette recherche ne couvre pas un format compressé, chiffré ou une transformation inconnue des identifiants.')
