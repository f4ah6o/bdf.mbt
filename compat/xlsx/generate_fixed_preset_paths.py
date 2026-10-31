#!/usr/bin/env python3
"""Generate MoonBit fixed preset paths from upstream presets.xml.gz.

Usage: python3 compat/xlsx/generate_fixed_preset_paths.py /path/to/presets.xml.gz
The output is written to stdout; run moon fmt after saving it.
"""
import gzip
import sys
import xml.etree.ElementTree as ET

names = [
    'flowChartCollate', 'flowChartManualInput', 'flowChartManualOperation',
    'flowChartOffpageConnector', 'irregularSeal1', 'irregularSeal2', 'lightningBolt',
]
with gzip.open(sys.argv[1], 'rb') as source:
    root = ET.fromstring(source.read())
print('///|')
print('// Fixed-coordinate paths from the upstream DrawingML preset geometries.')
print('fn sheet_fixed_preset_path(geometry : String, width : Double, height : Double) -> @core.Path {')
print('  let (extent, points) : (Double, Array[(Double, Double)]) = match geometry {')
for name in names:
    path = root.find(name).find('pathLst')[0]
    assert path.get('w') == path.get('h')
    assert all(child.tag in ('moveTo', 'lnTo', 'close') for child in path)
    print(f'    "{name}" => ({path.get("w")}.0, [')
    for child in path:
        if child.tag != 'close':
            point = child.find('pt')
            print(f'      ({point.get("x")}.0, {point.get("y")}.0),')
    print('    ])')
print('    _ => abort("unknown fixed preset")')
print('  }')
print('  let sx = width / extent')
print('  let sy = height / extent')
print('  let verbs : Array[Byte] = []')
print('  let coordinates : Array[Double] = []')
print('  for i, (x, y) in points {')
print("    verbs.push(if i == 0 { b'\\x00' } else { b'\\x01' })")
print('    coordinates.push(x * sx)')
print('    coordinates.push(y * sy)')
print('  }')
print("  verbs.push(b'\\x04')")
print('  { verbs: Bytes::from_array(verbs), coordinates, }')
print('}')
