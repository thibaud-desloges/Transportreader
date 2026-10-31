#!/usr/bin/env python3
"""Audit declared EF coverage using explicit paths, without guessing SFI context."""
import collections, json, re, sys
from pathlib import Path
report = json.loads(Path(sys.argv[1]).read_text())
roots = {'334D54522E494341': '', 'A0000004040125092001': '2000',
         'A0000004040225092001': '1000', 'A0000004044125092001': '2300',
         'A000000291A00000019102': '2100', 'A000000291D25008009301': '2200'}
for e in report['exchanges']:
    m = re.fullmatch(r'GET DATA CURRENT AID (APP|[0-9A-F]+)', e['operation'])
    if m and m[1] != 'APP' and e['statusWord'] == '9000':
        b = bytes.fromhex(e['response'])
        if len(b) >= 2 and b[0] == 0x4F and b[1] == len(b)-2:
            roots[b[2:].hex().upper()] = m[1]
roots['334D54522E494341'] = ''
files, reads, denied = {}, collections.defaultdict(dict), set()
# Direct enumeration can be the sole directory evidence on older cards that do
# not implement GET DATA EF LIST. Index SFI only within its application root.
sfi_paths = {}
for e in report['exchanges']:
    aid = e.get('application', report['selectedApplication'])
    if not e['operation'].startswith('ENUMERATE EF ') or e['statusWord'] != '9000' or aid not in roots:
        continue
    b = bytes.fromhex(e['response'])
    if len(b) != 25 or b[:2] != b'\x85\x17':
        raise ValueError('Bad enumerated descriptor')
    info = b[2:]
    if info[1] != 4 or info[2] not in (1, 2, 4, 8, 9):
        raise ValueError('Bad enumerated EF type')
    offset = 20 if aid in ('334D54522E494341', 'A0000004040125092001') else 21
    lid = int.from_bytes(info[offset:offset+2], 'big')
    path = roots[aid] + (f'{lid:04X}' if lid not in (0, 65535) else f'/SFI{info[0]:02X}')
    descriptor = (info[2], info[3], info[4])
    if path in files and files[path] != descriptor:
        raise ValueError('Conflicting enumerated descriptor: ' + path)
    files[path] = descriptor
    sfi_paths[(roots[aid], info[0])] = path
for e in report['exchanges']:
    aid = e.get('application', report['selectedApplication'])
    m = re.fullmatch(r'GET DATA EF LIST (APP|[0-9A-F]+)', e['operation'])
    if m and e['statusWord'] == '9000':
        context = roots.get(aid) if m[1] == 'APP' else m[1]
        if context is None: continue
        if context == '3F00': context = ''
        b = bytes.fromhex(e['response']); start = 2 if b[1]<128 else 2+(b[1]&127)
        for i in range(start,len(b),8):
            d=b[i:i+8]
            if len(d)!=8 or d[:2]!=b'\xc1\x06': raise ValueError('Bad descriptor')
            path=context+d[2:4].hex().upper()
            descriptor=(d[5],d[6],d[7])
            previous = sfi_paths.get((context, d[4]))
            if previous and '/SFI' in previous and previous != path:
                if files[previous] != descriptor:
                    raise ValueError('SFI alias descriptor mismatch')
                del files[previous]
            sfi_paths[(context, d[4])] = path
            if path in files and files[path]!=descriptor: raise ValueError('Conflicting descriptor')
            files[path]=descriptor
    m = re.fullmatch(r'READ (BINARY )?PATH (APP )?([0-9A-F]+) / (\d+)(?: \(Le corrigé\))?',e['operation'])
    scoped = re.fullmatch(r'READ DIRECTORY ([0-9A-F]+) SFI ([0-9A-F]{2}) / (\d+)', e['operation'])
    if not m and not scoped: continue
    if scoped:
        context, sfi, number = scoped.groups()
        path = sfi_paths.get((context, int(sfi, 16)))
        if path is None: continue
        binary, relative = False, False
    else:
        binary,relative,path,number=m.groups()
    if relative:
        if aid not in roots: continue
        path=roots[aid]+path
    if path.startswith('3F00'): path=path[4:]
    if e['statusWord']=='6982': denied.add(path)
    if e['statusWord'] not in ['9000','6282']: continue
    key=(bool(binary),int(number)); payload=bytes.fromhex(e['response'])
    if key in reads[path] and reads[path][key]!=payload: raise ValueError('Conflicting payload: '+path)
    reads[path][key]=payload
print('# Couverture des fichiers annoncés par la carte\n')
print('| Fichier | Taille annoncée | Octets couverts | Résultat |')
print('|---|---:|---:|---|')
total=covered_total=complete=0
for path,(kind,size,count) in sorted(files.items()):
    expected=(size<<8|count) if kind==1 else size*count
    covered=set()
    for (binary,index),payload in reads[path].items():
        if binary and kind==1: start=index
        elif not binary and kind!=1 and 1<=index<=count: start=(index-1)*size
        else: continue
        covered.update(range(start,min(start+len(payload),expected)))
    covered_total+=len(covered); total+=expected
    full=len(covered)==expected;complete+=full
    status='lu' if full else 'accès refusé (6982)' if path in denied else 'incomplet'
    print(f'| {path} | {expected} | {len(covered)} | {status} |')
print(f'\n{complete}/{len(files)} fichiers entièrement couverts ; {covered_total}/{total} octets annoncés lus.')
print('Ce bilan porte sur les fichiers annoncés, pas sur toute la mémoire physique ni sur des dossiers non découverts.')
