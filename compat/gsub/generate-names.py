#!/usr/bin/env python3
"""Generate OpenType tag-name tables from the pinned upstream checkout."""
import json
import re
import sys
from pathlib import Path

source = Path(sys.argv[1]).read_text()
target = Path(__file__).resolve().parents[2] / 'font/otlayout/tag_names_generated.mbt'
chunks = ['// Generated from shibukawa/bdf internal/otlayout/names.go (MIT).\n']
for go_name, fn in [('featureNames', 'registered_feature_name'), ('scriptNames', 'script_name'), ('langNames', 'registered_language_name')]:
    match = re.search(r'var ' + go_name + r' = map\[string\]string\{(.*?)\n\}', source, re.S)
    if not match:
        raise SystemExit(f'missing upstream map {go_name}')
    entries = re.findall(r'"([^"\\]*)"\s*:\s*"([^"\\]*)"', match.group(1))
    if len(entries) < 10:
        raise SystemExit(f'unexpected upstream map {go_name}')
    visibility = 'pub ' if fn == 'script_name' else ''
    chunks.append(f'///|\n{visibility}fn {fn}(tag : String) -> String {{\n  match tag {{\n')
    chunks.extend(f'    {json.dumps(k, ensure_ascii=False)} => {json.dumps(v, ensure_ascii=False)}\n' for k,v in entries)
    chunks.append('    _ => ""\n  }\n}\n\n')
target.write_text(''.join(chunks))
