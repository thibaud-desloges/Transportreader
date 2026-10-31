#!/usr/bin/env python3
"""Compare explicit Intercode event fields locally, preserving offsets and raw codes."""
import argparse
import datetime as dt
import json
import re
from pathlib import Path

FIELDS = [
    ('displayData', 8), ('network', 24), ('eventCode', 8), ('result', 8),
    ('provider', 8), ('notOKCounter', 8), ('serial', 24), ('destination', 16),
    ('location', 16), ('gate', 8), ('device', 16), ('route', 16),
    ('routeVariant', 8), ('journeyRun', 16), ('vehicle', 16),
    ('vehicleClass', 8), ('locationType', 5), ('employee', 240),
    ('locationReference', 16), ('journeyInterchanges', 8),
    ('periodJourneys', 16), ('totalJourneys', 16), ('journeyDistance', 16),
    ('amount', 16), ('monetaryUnit', 16), ('contract', 5), ('authenticator', 16),
]


def decode(hex_value):
    bits = ''.join(f'{b:08b}' for b in bytes.fromhex(hex_value))
    if not any(c == '1' for c in bits):
        return None
    offset = 0
    fields = {}

    def read(name, width):
        nonlocal offset
        if offset + width > len(bits):
            raise ValueError('Truncated field ' + name)
        value = int(bits[offset:offset + width], 2)
        fields[name] = {'value': value, 'bit': offset, 'width': width}
        offset += width
        return value

    day = read('day', 14)
    minute = read('minute', 11)
    mask = read('bitmap', 28)
    for i, (name, width) in enumerate(FIELDS):
        if mask & (1 << i):
            read(name, width)
    if mask & (1 << 27):
        extra = read('extraBitmap', 5)
        for i, (name, width) in enumerate([
            ('firstDay', 14), ('firstMinute', 11), ('simulation', 1),
            ('journeyPart', 2), ('direction', 2),
        ]):
            if extra & (1 << i):
                read(name, width)
    return {
        'date': str(dt.date(1997, 1, 1) + dt.timedelta(days=day)),
        'time': f'{minute // 60:02}:{minute % 60:02}' if minute < 1440 else None,
        'fields': fields, 'remainingBits': len(bits) - offset,
        'remainingNonzero': '1' in bits[offset:],
        'remainingHex': hex_value[offset // 4:].upper() if offset % 4 == 0 else None,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('captures', type=Path, nargs='+')
    args = parser.parse_args()
    reports = []
    for path in args.captures:
        capture = json.loads(path.read_text())
        records = {}
        for e in capture['exchanges']:
            match = re.fullmatch(r'READ PATH (APP )?(20002010|20002040|2010|2040) / (\d+)', e['operation'])
            if not match or e['statusWord'] != '9000':
                continue
            if match[1] and e.get('application', capture.get('selectedApplication')) != 'A0000004040125092001':
                continue
            path_name = match[2][-4:]
            index = (path_name, int(match[3]))
            if index in records and records[index] != e['response']:
                raise ValueError('Conflicting event record')
            records[index] = e['response']
        reports.append({'capture': path.name, 'events': [
            {'file': path_name, 'record': i, **event} for (path_name, i), value in sorted(records.items())
            if (event := decode(value)) is not None
        ]})
    print(json.dumps(reports, indent=2))


if __name__ == '__main__':
    main()
