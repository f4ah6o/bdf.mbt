#!/usr/bin/env python3
"""Embed upstream's licensed Adobe CMap archive as MoonBit source."""
import base64
import sys
from pathlib import Path

encoded = base64.b64encode(Path(sys.argv[1]).read_bytes()).decode('ascii')
print('///|')
print('// Generated from upstream cjkcmap/cmaps.bin.gz; see licenses/Adobe-CMap.txt.')
print('fn pdf_cjk_compressed() -> Bytes {')
print('  let out = StringBuilder()')
for start in range(0, len(encoded), 1000):
    print(f'  out.write_string("{encoded[start:start + 1000]}")')
print('  let text = out.to_string()')
print('  @base64.decode(text[:]) catch { _ => abort("invalid embedded CMap data") }')
print('}')
