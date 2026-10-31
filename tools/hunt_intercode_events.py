#!/usr/bin/env python3
"""Search Intercode event layouts at every bit offset; candidates are not facts."""
import argparse, collections, datetime as dt, json, re
from pathlib import Path
p = argparse.ArgumentParser()
p.add_argument("capture")
p.add_argument("--any-date", action="store_true")
p.add_argument("--bus-signals", action="store_true", help="Require bus mode and line 59, contract 5/6, or provider 29")
p.add_argument("--ignore-clock", action="store_true", help="Retain impossible times as potentially corrupt clock data")
p.add_argument("--all-codes", action="store_true", help="Do not require a particular mode/transition")
p.add_argument("--contract-signals", action="store_true", help="Require a known contract pointer or route 59, regardless of mode")
args = p.parse_args()
r=json.loads(Path(args.capture).read_text()); payloads=collections.defaultdict(set)
chunks=collections.defaultdict(dict)
for e in r['exchanges']:
    if e['operation'].startswith('READ') and e['statusWord'] in ['9000','6282'] and e['response']:
        payloads[e['response']].add(e['operation'])
        m=re.fullmatch(r'READ BINARY (.*?) / (\d+)(?: \(Le corrigé\))?',e['operation'])
        if m:chunks[(e.get('application'),m[1])][int(m[2])]=bytes.fromhex(e['response'])
for (aid,location),parts in chunks.items():
    offset=0;joined=b''
    while offset in parts and parts[offset]:
        joined+=parts[offset];offset+=len(parts[offset])
    if joined:payloads[joined.hex()].add('READ BINARY '+location+' / fichier assemblé')
widths=[8,24,8,8,8,8,24,16,16,8,16,16,8,16,16,8,5,240,16,8,16,16,16,16,16,5,16]
epoch=dt.date(1997,1,1);start=(dt.date(2026,9,1)-epoch).days;end=(dt.date(2026,10,19)-epoch).days
print('# Recherche d’événements Intercode décalés\n')
print('Options : horloge ignorée='+str(args.ignore_clock)+', tous codes='+str(args.all_codes)+', références de contrats='+str(args.contract_signals))
print('Toutes les positions de bits des réponses distinctes et fichiers binaires assemblés sont testées. '+('Aucun filtre de mode ni transition. ' if args.all_codes else 'Modes bus/car/train et transitions reconnus requis. ')+'Filtre de date : '+('aucun' if args.any_date else '1 septembre–19 octobre 2026')+'. Les correspondances restent des hypothèses.\n')
found=0
for h,ops in payloads.items():
    bits=''.join(f'{x:08b}' for x in bytes.fromhex(h))
    for origin in range(len(bits)-52):
        pos=origin
        def read(n):
            global pos
            if pos+n>len(bits): raise ValueError()
            value=int(bits[pos:pos+n],2);pos+=n;return value
        try:
            day=read(14);minute=read(11)
            if (not args.any_date and not start<=day<=end) or (not args.ignore_clock and minute>=1440):continue
            mask=read(28)
            if not mask&(1<<2):continue
            values={i:read(n) for i,n in enumerate(widths) if mask&(1<<i)}
            if mask&(1<<27):
                extra=read(5)
                for i,n in enumerate([14,11,1,2,2]):
                    if extra&(1<<i):read(n)
            code=values[2];mode=code>>4;transition=code&15
            if not args.all_codes and (mode not in [1,2,5] or transition not in [1,2,3,4,6,7]):continue
            op=sorted(ops,key=lambda x:('PATH' not in x,len(x)))[0]
            if args.bus_signals and (mode not in [1,2] or not (values.get(11)==59 or values.get(25) in [5,6] or values.get(4)==29)):continue
            if args.contract_signals and not (values.get(25) in [5,6] or values.get(11)==59):continue
            found+=1
            if args.any_date and mode == 5 and not args.all_codes:continue
            print(f'- {op}, bit {origin} : {epoch+dt.timedelta(days=day)}, {minute//60:02}:{minute%60:02}, mode {mode}, fournisseur {values.get(4)}, titre {values.get(25)}, lieu {values.get(8)}, ligne {values.get(11)}')
        except ValueError:continue
print(f'\n{found} candidat(s). Une correspondance ne constitue pas à elle seule un événement confirmé. Les autres formats ne sont pas couverts.')
