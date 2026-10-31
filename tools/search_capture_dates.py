#!/usr/bin/env python3
"""Find date encoding candidates; matches are hypotheses, never decoded trips."""
import collections, datetime as dt, json, sys
r=json.load(open(sys.argv[1])); payloads=collections.defaultdict(set)
for e in r['exchanges']:
    if e['operation'].startswith('READ') and e['statusWord'] in ['9000','6282'] and e['response']:
        payloads[e['response']].add(e['operation'])
print('# Recherche complémentaire de codages de dates\n')
print('Offsets comptés en bits, à partir de zéro dans la réponse. Une occurrence isolée ne prouve pas un événement.\n')
for day in [10,13,14,15]:
    date=dt.date(2026,9,day);patterns={}
    for year in [1997,2000,2010]:
        value=(date-dt.date(year,1,1)).days
        for width in [14,16]:
            if value < 1<<width:patterns[f'jours depuis {year}, {width} bits']=f'{value:0{width}b}'
        if value<65536:patterns[f'jours depuis {year}, 16 bits little endian']=''.join(f'{x:08b}' for x in value.to_bytes(2,'little'))
    for label,value,width in [
        ('DOS',(2026-1980)<<9|9<<5|day,16),
        ('année 2000/mois/jour',(26<<9)|(9<<5)|day,16),
        ('jour/mois/année 2000',(day<<11)|(9<<7)|26,16),
    ]:patterns[label]=f'{value:0{width}b}'
    for label,h in [('BCD AAAAMMJJ',f'202609{day:02}'),('BCD AAMMJJ',f'2609{day:02}'),('BCD JJMMAA',f'{day:02}0926')]:
        patterns[label]=''.join(f'{x:08b}' for x in bytes.fromhex(h))
    hits=[]
    for h,ops in payloads.items():
        bits=''.join(f'{x:08b}' for x in bytes.fromhex(h))
        for label,pattern in patterns.items():
            offsets=[i for i in range(len(bits)-len(pattern)+1) if bits.startswith(pattern,i)]
            if offsets:hits.append((label,offsets,sorted(ops,key=lambda x:('PATH' not in x,len(x)))[:1]))
    print(f'## {date}\n')
    for label,offsets,ops in hits:print(f'- {label} : {ops[0]}, offsets {offsets}')
    if not hits:print('Aucune occurrence pour les codages testés.')
    print()
