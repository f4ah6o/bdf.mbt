#!/usr/bin/env python3
"""Generate MoonBit preset table styles from upstream tablestyles.xml.gz."""
import gzip
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

source = Path(sys.argv[1]); output = Path(sys.argv[2])
root = ET.fromstring(gzip.open(source, 'rb').read())
kinds = ('wholeTable', 'firstColumnStripe', 'secondColumnStripe', 'firstRowStripe', 'secondRowStripe', 'lastColumn', 'firstColumn', 'headerRow', 'totalRow', 'firstHeaderCell', 'lastHeaderCell', 'firstTotalCell', 'lastTotalCell')
dxfs = []
styles = []
for style in root.findall('style'):
    local = []
    for dxf in style.find('dxfs'):
        xml = ET.tostring(dxf, encoding='unicode', short_empty_elements=True)
        if xml not in dxfs:
            dxfs.append(xml)
        local.append(dxfs.index(xml))
    ids = [-1] * len(kinds); sizes = [1] * len(kinds)
    for elem in style.findall('./tableStyles/tableStyle/tableStyleElement'):
        kind = elem.attrib.get('type', '')
        if kind not in kinds: continue
        ix = int(elem.attrib.get('dxfId', '0')) - 1
        if ix < 0 or ix >= len(local): continue
        j = kinds.index(kind); ids[j] = 1000000000 + local[ix]; sizes[j] = max(1, int(elem.attrib.get('size', '1')))
    styles.append((style.attrib['name'], ids, sizes))
assert len(styles) == 60
parts = ['///|\n// Generated from shibukawa/bdf converter/xlsx/tablestyles.xml.gz.\nfn xlsx_builtin_table_style(name : String) -> XlsxComplexStyle? {\n  match name {\n']
for name, ids, sizes in styles:
    parts.append('    '+json.dumps(name)+' => Some({ ids: ['+', '.join(map(str, ids))+'], sizes: ['+', '.join(str(x)+'L' for x in sizes)+'] })\n')
parts.append('    _ => None\n  }\n}\n\n///|\nfn xlsx_builtin_table_dxf(id : Int32) -> String? {\n  match id {\n')
for i, dxf in enumerate(dxfs):
    xml = '<styleSheet><dxfs>'+dxf+'</dxfs></styleSheet>'
    parts.append('    '+str(i)+' => Some('+json.dumps(xml)+')\n')
parts.append('    _ => None\n  }\n}\n')
output.write_text(''.join(parts))
