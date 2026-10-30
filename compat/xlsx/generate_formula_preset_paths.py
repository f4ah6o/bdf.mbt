#!/usr/bin/env python3
"""Generate straight-line preset paths from upstream presets.xml.gz.

Usage: python3 compat/xlsx/generate_formula_preset_paths.py /path/to/presets.xml.gz
Write stdout to convert/sheet/formula_presets.mbt, then run moon fmt.
"""
import gzip
import re
import sys
import xml.etree.ElementTree as ET

with gzip.open(sys.argv[1], 'rb') as source:
    root = ET.fromstring(source.read())

names = '''bentUpArrow corner diagStripe dodecagon downArrow downArrowCallout
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
    }
    return operations[operator]()


lines = [
    '///|',
    '// Straight-line preset paths generated from the upstream DrawingML definitions.',
    'fn sheet_formula_preset_path(geometry : String, width : Double, height : Double, adjustment : Int64?) -> @core.Path {',
    '  let ss = Double::min(width, height)',
    '  let ls = Double::max(width, height)',
    '  let env : Map[String, Double] = Map([])',
    '  env["w"] = width', '  env["h"] = height',
    '  env["l"] = 0.0', '  env["t"] = 0.0',
    '  env["r"] = width', '  env["b"] = height',
    '  env["hc"] = width / 2.0', '  env["vc"] = height / 2.0',
    '  env["ss"] = ss', '  env["ls"] = ls',
]
defined_builtin = {'w', 'h', 'l', 't', 'r', 'b', 'hc', 'vc', 'ss', 'ls'}
for divisor in (2, 3, 4, 5, 6, 8, 10, 12, 16, 32):
    for prefix, variable in (('wd', 'width'), ('hd', 'height'), ('ssd', 'ss')):
        key = f'{prefix}{divisor}'
        lines.append(f'  env["{key}"] = {variable} / {divisor}.0')
        defined_builtin.add(key)
lines.append('  match geometry {')

for name in names:
    shape = root.find(name)
    paths = shape.find('pathLst')
    assert len(paths) == 1
    path = paths[0]
    assert path.get('fill', 'norm') == 'norm' and path.get('stroke', 'true') == 'true'
    assert path[-1].tag == 'close'
    assert sum(child.tag == 'moveTo' for child in path) == 1
    assert all(child.tag in ('moveTo', 'lnTo', 'close') for child in path)
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
        else:
            lines.append(f'      env["{key}"] = {formula(expression)}')
        defined.add(key)
    width, height = path.get('w'), path.get('h')
    lines.append('      let sx = ' + (f'width / {float(width):.1f}' if width else '1.0'))
    lines.append('      let sy = ' + (f'height / {float(height):.1f}' if height else '1.0'))
    points = [child.find('pt') for child in path if child.tag in ('moveTo', 'lnTo')]
    verbs = '\\x00' + '\\x01' * (len(points) - 1) + '\\x04'
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
