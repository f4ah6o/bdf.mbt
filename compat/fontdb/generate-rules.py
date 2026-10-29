"""Generate the font-resolution chains from a pinned upstream checkout."""
import json
import re
import sys
from pathlib import Path

source = (Path(sys.argv[1]) / 'internal/fontdb/resolve.go').read_text()
list_names = ['jaGothic', 'jaGothicMono', 'jaMincho', 'jaMinchoMono', 'zhHans',
              'zhHansSerif', 'zhHant', 'zhHantSerif', 'koGothic', 'koSerif',
              'genericSymbols', 'mathFamilies']

def quoted(text):
    return re.findall(r'"(?:\\.|[^"\\])*"', text)

def snake(name):
    return re.sub(r'(?<!^)(?=[A-Z])', '_', name).lower()

out = ['///|\n// Generated from shibukawa/bdf internal/fontdb/resolve.go (MIT).']
for name in list_names:
    match = re.search(r'\b' + name + r'\s*=\s*\[\]string\{([^}]*)\}', source, re.S)
    if not match:
        raise ValueError(name)
    out.append('let ' + snake(name) + ' : Array[String] = [' + ', '.join(quoted(match.group(1))) + ']')
    out.append('///|')
start = source.index('var substitutes')
end = source.index('\n}', start)
entries = re.findall(r'"([^"\n]+)"\s*:\s*(\{[^}]*\}|[A-Za-z]+)', source[start:end])
out.append('fn substitutes(name : String) -> Array[String] {\n  match name {')
for key, value in entries:
    expr = '[' + ', '.join(quoted(value)) + ']' if value.startswith('{') else snake(value)
    out.append('    ' + json.dumps(key, ensure_ascii=False) + ' => ' + expr)
out.append('    _ => []\n  }\n}\n\n///|')
start = source.index('genericLatin =')
end = source.index('\n\t}', start)
entries = re.findall(r'(Sans|Serif|Mono)\s*:\s*\{([^}]*)\}', source[start:end])
out.append('fn generic_latin(name : String) -> Array[String] {\n  match name {')
for key, values in entries:
    family = {'Sans':'sans-serif', 'Serif':'serif', 'Mono':'monospace'}[key]
    out.append('    ' + json.dumps(family) + ' => [' + ', '.join(quoted(values)) + ']')
out.append('    _ => []\n  }\n}')
Path(sys.argv[2]).write_text('\n'.join(out) + '\n')
