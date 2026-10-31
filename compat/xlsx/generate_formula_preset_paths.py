#!/usr/bin/env python3
"""Generate closed preset paths from upstream presets.xml.gz.

Usage: python3 compat/xlsx/generate_formula_preset_paths.py /path/to/presets.xml.gz
Write stdout to convert/sheet/formula_presets.mbt, then run moon fmt.
"""
import gzip
import re
import sys
import xml.etree.ElementTree as ET

with gzip.open(sys.argv[1], 'rb') as source:
    root = ET.fromstring(source.read())

names = '''swooshArrow flowChartDocument heart wave doubleWave bentUpArrow corner diagStripe dodecagon downArrow downArrowCallout
halfFrame heptagon leftArrow leftArrowCallout leftRightArrow leftRightArrowCallout
leftRightUpArrow leftUpArrow mathMinus mathPlus nonIsoscelesTrapezoid
notchedRightArrow quadArrow quadArrowCallout rightArrow rightArrowCallout
snip1Rect snip2DiagRect snip2SameRect star10 star7 upArrowCallout upDownArrow
upArrow upDownArrowCallout wedgeRectCallout'''.split()


def value(token):
    try:
        number = format(float(token), '.17g')
        return number + ('.0' if re.fullmatch(r'-?\d+', token) else '')
    except ValueError:
        return f'env.get("{token}").unwrap_or(0.0)'


def formula(text):
    operator, *args = text.split()
    if operator == 'tan':
        assert name == 'swooshArrow' and args[1] == 'alfa'  # The fixed tangent applies only to this preset.
    args = [value(arg) for arg in args] + ['0.0'] * (3 - len(args))
    x, y, z = args[:3]
    operations = {
        'val': lambda: x,
        '*/': lambda: f'sheet_preset_muldiv({x}, {y}, {z})',
        '+-': lambda: f'({x} + {y} - {z})',
        '+/': lambda: f'sheet_preset_adddiv({x}, {y}, {z})',
        '?:': lambda: f'(if {x} > 0.0 {{ {y} }} else {{ {z} }})',
        'pin': lambda: f'sheet_preset_pin({x}, {y}, {z})',
        'min': lambda: f'Double::min({x}, {y})',
        'max': lambda: f'Double::max({x}, {y})',
        'abs': lambda: f'({x}).abs()',
        'tan': lambda: f'({x} * 0x3fbcd8224003e0e7UL.reinterpret_as_double())',
    }
    return operations[operator]()


lines = [
    '///|',
    '// Preset paths generated from the upstream DrawingML definitions.',
    'fn sheet_formula_preset_path(geometry : String, width : Double, height : Double, adjustment : Int64?, extra~ : Map[String, Int64] = Map([])) -> @core.Path {',
    '  let ss = Double::min(width, height)',
    '  let ls = Double::max(width, height)',
    '  let env : Map[String, Double] = Map([])',
    '  env["w"] = width', '  env["h"] = height',
    '  env["l"] = 0.0', '  env["t"] = 0.0',
    '  env["r"] = width', '  env["b"] = height',
    '  env["hc"] = width / 2.0', '  env["vc"] = height / 2.0',
    '  env["ss"] = ss', '  env["ls"] = ls', '  env["cd4"] = 5400000.0',
]
defined_builtin = {'w', 'h', 'l', 't', 'r', 'b', 'hc', 'vc', 'ss', 'ls', 'cd4'}
for divisor in (2, 3, 4, 5, 6, 8, 10, 12, 16, 32):
    for prefix, variable in (('wd', 'width'), ('hd', 'height'), ('ssd', 'ss')):
        key = f'{prefix}{divisor}'
        lines.append(f'  env["{key}"] = {variable} / {divisor}.0')
        defined_builtin.add(key)
lines.append('  match geometry {')

for name in names:
    shape = root.find(name)
    if name == 'swooshArrow':
        angles = [guide for guide in shape.findall('./gdLst/gd') if guide.get('name') == 'alfa']
        assert len(angles) == 1 and angles[0].get('fmla') == '*/ cd4 1 14', 'swooshArrow fixed tangent angle changed'
    paths = shape.find('pathLst')
    assert len(paths) == 1
    path = paths[0]
    assert path.get('fill', 'norm') == 'norm' and path.get('stroke', 'true') == 'true'
    assert path[-1].tag == 'close'
    assert sum(child.tag == 'moveTo' for child in path) == 1
    assert all(child.tag in ('moveTo', 'lnTo', 'quadBezTo', 'cubicBezTo', 'close') for child in path)
    assert all(len(child.findall('pt')) == {'moveTo': 1, 'lnTo': 1, 'quadBezTo': 2, 'cubicBezTo': 3, 'close': 0}[child.tag] for child in path)
    defined = defined_builtin.copy()
    lines.append(f'    "{name}" => {{')
    for guide in shape.findall('./avLst/gd') + shape.findall('./gdLst/gd'):
        expression = guide.get('fmla')
        for token in expression.split()[1:]:
            assert token in defined or re.fullmatch(r'-?\d+(\.\d+)?', token), (name, token)
        key = guide.get('name')
        if (key == 'adj' and name in ('diagStripe', 'snip1Rect', 'star10', 'star7')) or key == 'adj1':
            default = formula(expression)
            lines.append(f'      env["{key}"] = if adjustment is Some(value) {{ value.to_double() }} else {{ {default} }}')
        elif key in ('adj2', 'adj3', 'adj4'):
            default = formula(expression)
            lines.append(f'      env["{key}"] = match extra.get("{key}") {{ Some(value) => value.to_double(); None => {default} }}')
        else:
            lines.append(f'      env["{key}"] = {formula(expression)}')
        defined.add(key)
    width, height = path.get('w'), path.get('h')
    lines.append('      let sx = ' + (f'width / {float(width):.1f}' if width else '1.0'))
    lines.append('      let sy = ' + (f'height / {float(height):.1f}' if height else '1.0'))
    points = [point for child in path for point in child.findall('pt')]
    verbs = ''.join({'moveTo': '\\x00', 'lnTo': '\\x01', 'quadBezTo': '\\x02', 'cubicBezTo': '\\x03', 'close': '\\x04'}[child.tag] for child in path)
    lines.append(f'      {{ verbs: b"{verbs}", coordinates: [')
    for point in points:
        x, y = point.get('x'), point.get('y')
        for token in (x, y):
            assert token in defined or re.fullmatch(r'-?\d+(\.\d+)?', token), (name, token)
        lines.append(f'        {value(x)} * sx, {value(y)} * sy,')
    lines.extend(['      ], }', '    }'])
lines.extend([
    '    _ => abort("unknown formula preset")', '  }', '}', '',
    '///|', 'fn sheet_preset_muldiv(x : Double, y : Double, z : Double) -> Double {',
    '  if z == 0.0 { 0.0 } else { x * y / z }', '}', '',
    '///|', 'fn sheet_preset_adddiv(x : Double, y : Double, z : Double) -> Double {',
    '  if z == 0.0 { 0.0 } else { (x + y) / z }', '}', '',
    '///|', 'fn sheet_preset_pin(x : Double, y : Double, z : Double) -> Double {',
    '  if y < x { x } else if y > z { z } else { y }', '}',
])
print('\n'.join(lines))
