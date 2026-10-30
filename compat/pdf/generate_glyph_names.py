#!/usr/bin/env python3
"""Generate the PDF glyph-name map from upstream converter/pdf/glyphlist.go."""
import re
import sys
from pathlib import Path

source = Path(sys.argv[1]).read_text()
pairs = re.findall(r'^\s*"([^"\\]+)":\s*(0x[0-9A-Fa-f]+),\s*$', source, re.M)
if not pairs or len(pairs) != len(set(name for name, _ in pairs)):
    raise SystemExit('invalid or duplicate glyph names')
print('///|')
print('// Generated from upstream converter/pdf/glyphlist.go (MIT).')
print('let pdf_glyph_names : Map[String, Int] = {')
for name, value in pairs:
    print(f'  "{name}": {value},')
print('}')
