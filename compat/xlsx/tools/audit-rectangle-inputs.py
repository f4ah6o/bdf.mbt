#!/usr/bin/env python3
"""Diagnostic attribution only: never changes input bytes or migration acceptance."""
import argparse
import base64
import collections
import io
import json
import re
import zipfile

NUMBER = rb'[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?%?'
PATTERN = re.compile(rb'(<a:scrgbClr r=")' + NUMBER + rb'(" g=")' + NUMBER + rb'(" b=")' + NUMBER + rb'(?=")')

def mask_color_values(data):
    return PATTERN.sub(rb'\1R\2G\3B', data)

def audit(before, after):
    if len(before) != len(after):
        raise ValueError('Case count differs')
    result = {'diagnosticOnly': True, 'cases': len(before), 'changedInputs': 0,
              'colorAttributeOnlyCases': [], 'otherChanges': [], 'memberChanges': {}}
    members = collections.Counter()
    for index, (old, new) in enumerate(zip(before, after)):
        if old['input'] == new['input']:
            continue
        result['changedInputs'] += 1
        with zipfile.ZipFile(io.BytesIO(base64.b64decode(old['input'], validate=True))) as a, \
             zipfile.ZipFile(io.BytesIO(base64.b64decode(new['input'], validate=True))) as b:
            if a.namelist() != b.namelist() or len(set(a.namelist())) != len(a.namelist()):
                result['otherChanges'].append({'index': index, 'reason': 'member inventory/order'})
                continue
            changed = []
            for name in a.namelist():
                x, y = a.read(name), b.read(name)
                if x != y:
                    members[name] += 1
                    changed.append(name)
                    if name != 'xl/drawings/drawing1.xml' or mask_color_values(x) != mask_color_values(y):
                        result['otherChanges'].append({'index': index, 'member': name, 'reason': 'non-color member content'})
            if changed and not any(v['index'] == index for v in result['otherChanges']):
                result['colorAttributeOnlyCases'].append(index)
            elif not changed:
                result['otherChanges'].append({'index': index, 'reason': 'ZIP representation only'})
    result['memberChanges'] = dict(members)
    return result

if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--before', required=True, help='unpacked baseline fixture JSON')
    p.add_argument('--after', required=True, help='fresh fixture JSON')
    p.add_argument('--report', required=True)
    args = p.parse_args()
    with open(args.before) as f:
        before = json.load(f)
    with open(args.after) as f:
        after = json.load(f)
    result = audit(before, after)
    with open(args.report, 'w') as f:
        json.dump(result, f, indent=2)
        f.write('\n')
    print(json.dumps({k: len(v) if isinstance(v, list) else v for k, v in result.items()}))
