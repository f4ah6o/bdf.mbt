"""Generate unsupported explicit guides for fixed arc presets."""
import base64
import io
import json
import zipfile
from pathlib import Path

root = Path(__file__).resolve().parent
cases = json.loads((root / 'flowchart-arcs-hsl-colors.json').read_text())
output = []
for index, name in enumerate(('flowChartTerminator', 'flowChartDisplay', 'flowChartOnlineStorage', 'flowChartPunchedTape')):
    case = cases[index]
    with zipfile.ZipFile(io.BytesIO(base64.b64decode(case['input']))) as archive:
        parts = {entry.filename: archive.read(entry) for entry in archive.infolist()}
    part = 'xl/drawings/drawing1.xml'
    drawing = parts[part].decode()
    assert f'prst="{name}"' in drawing and '<a:avLst/>' in drawing
    drawing = drawing.replace('<a:avLst/>', '<a:avLst><a:gd name="adj" fmla="val 1"/></a:avLst>', 1)
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, 'w') as archive:
        for filename, data in parts.items():
            entry = zipfile.ZipInfo(filename, (1980, 1, 1, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(entry, drawing.encode() if filename == part else data)
    output.append({'label': name, 'input': base64.b64encode(buf.getvalue()).decode(), 'mode': case['mode'], 'no_index': case['no_index']})
(root / 'flowchart-arcs-unsupported.json').write_text(json.dumps(output, separators=(',', ':')))
