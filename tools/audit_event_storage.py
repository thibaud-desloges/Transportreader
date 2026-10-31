#!/usr/bin/env python3
"""Audit declared cyclic storage and unknown record patterns, offline and read-only.

File kinds follow CNA ToolUtils (1 binary, 2 linear, 4 cyclic, 8/9 counters).
Only explicit, application-scoped paths are accepted. Conflicting responses fail
instead of selecting a convenient payload. Identical records are not interpreted
as trips, and a zero record is not proof that a file was never used.
"""
import argparse
import collections
import json
import re
from pathlib import Path

ROOTS = {
    '334D54522E494341': '', 'A0000004040125092001': '2000',
    'A0000004040225092001': '1000', 'A0000004044125092001': '2300',
    'A000000291A00000019102': '2100', 'A000000291D25008009301': '2200',
}
KINDS = {1: 'binary', 2: 'linear', 4: 'cyclic', 8: 'simulated counters', 9: 'counters'}


def audit(report):
    headers, records = {}, collections.defaultdict(dict)
    for e in report['exchanges']:
        op = e['operation']
        selected = re.fullmatch(r'SELECT PATH (APP )?([0-9A-F]+)', op)
        read = re.fullmatch(r'READ PATH (APP )?([0-9A-F]+) / (\d+)(?: \(Le corrigé\))?', op)
        match = selected or read
        if not match or e['statusWord'] != '9000':
            continue
        relative, path = match.group(1, 2)
        if relative:
            root = ROOTS.get(e.get('application', report.get('selectedApplication')))
            if root is None:
                continue
            path = root + path
        if path.startswith('3F00'):
            path = path[4:]
        payload = bytes.fromhex(e['response'])
        if selected:
            if len(payload) != 25 or payload[:2] != b'\x85\x17' or payload[3] != 4:
                continue
            info = payload[2:]
            kind, size, count = info[2:5]
            if kind == 1:
                size, count = size * 256 + count, 1
            header = (kind, size, count, info[5], int.from_bytes(info[14:16], 'big'))
            if path in headers and headers[path] != header:
                raise ValueError('Conflicting headers: ' + path)
            headers[path] = header
        else:
            index = int(read[3])
            if index in records[path] and records[path][index] != payload:
                raise ValueError('Conflicting records: ' + path)
            records[path][index] = payload

    result = []
    for path, (kind, size, count, access, shared) in sorted(headers.items()):
        if kind == 1:
            continue
        valid = {i: data for i, data in records[path].items()
                 if 1 <= i <= count and len(data) == size}
        distinct = collections.Counter(valid.values())
        common_prefix = 0
        if valid:
            rows = list(valid.values())
            while common_prefix < size and len({row[common_prefix] for row in rows}) == 1:
                common_prefix += 1
        result.append({
            'path': path, 'kind': KINDS.get(kind, str(kind)),
            'recordSize': size, 'declaredRecords': count,
            'completeRecordsRead': len(valid),
            'zeroRecords': [i for i, data in sorted(valid.items()) if not any(data)],
            'nonzeroRecords': [i for i, data in sorted(valid.items()) if any(data)],
            'distinctPayloads': len(distinct), 'commonPrefixBytes': common_prefix,
            'readAccess': f'{access:02X}', 'sharedReference': f'{shared:04X}',
        })
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('capture', type=Path)
    args = parser.parse_args()
    result = audit(json.loads(args.capture.read_text()))
    print(json.dumps({'files': result, 'cyclicFiles': [r for r in result if r['kind'] == 'cyclic']}, indent=2))


if __name__ == '__main__':
    main()
