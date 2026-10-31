"""Generate invalid adjustment lists for the adjustable arc presets."""
import base64
import io
import json
import re
import zipfile
from pathlib import Path

root = Path(__file__).resolve().parent
cases = json.loads((root / 'adjustable-arcs.json').read_text())
output = []
for index, name in enumerate(('plaque', 'round1Rect', 'round2DiagRect', 'round2SameRect', 'snipRoundRect', 'bentArrow')):
    case = cases[index]
    with zipfile.ZipFile(io.BytesIO(base64.b64decode(case['input']))) as archive:
        parts = {entry.filename: archive.read(entry) for entry in archive.infolist()}
    part = 'xl/drawings/drawing1.xml'
    source = parts[part].decode()
    first = 'adj' if index < 2 else 'adj1'
    invalid = {
        'unknown': '<a:gd name="adj5" fmla="val 1"/>',
        'wrong-first': f'<a:gd name="{"adj1" if index < 2 else "adj"}" fmla="val 1"/>',
        'negative': f'<a:gd name="{first}" fmla="val -1"/>',
        'too-large': f'<a:gd name="{first}" fmla="val 100001"/>',
        'formula': f'<a:gd name="{first}" fmla="+- 1 2 3"/>',
        'duplicate': f'<a:gd name="{first}" fmla="val 1"/><a:gd name="{first}" fmla="val 2"/>',
    }
    for label, guides in invalid.items():
        pattern = f'(<a:prstGeom prst="{name}"><a:avLst>).*?(</a:avLst>)'
        drawing, count = re.subn(pattern, lambda m: m.group(1) + guides + m.group(2), source, count=1)
        assert count == 1
        buf = io.BytesIO()
        with zipfile.ZipFile(buf, 'w') as archive:
            for filename, data in parts.items():
                entry = zipfile.ZipInfo(filename, (1980, 1, 1, 0, 0, 0))
                entry.compress_type = zipfile.ZIP_DEFLATED
                archive.writestr(entry, drawing.encode() if filename == part else data)
        output.append({'label': f'{name} {label}', 'input': base64.b64encode(buf.getvalue()).decode(), 'mode': case['mode'], 'no_index': case['no_index']})
(root / 'adjustable-arcs-unsupported.json').write_text(json.dumps(output, separators=(',', ':')))
