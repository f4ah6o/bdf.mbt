#!/usr/bin/env python3
"""Generate inputs that must remain unsupported when drawings contain elements."""
import base64
import io
import json
import sys
import zipfile
from pathlib import Path

fixtures = Path(sys.argv[1])
case = json.loads((fixtures / 'empty-drawing-variants.json').read_text())[0]
original = zipfile.ZipFile(io.BytesIO(base64.b64decode(case['input'])))
out = []
for shape in ('sp', 'grpSp', 'graphicFrame', 'cxnSp', 'pic', 'contentPart'):
    target = io.BytesIO()
    with zipfile.ZipFile(target, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
        for name in original.namelist():
            data = original.read(name)
            if name == 'xl/drawings/drawing1.xml':
                data = f'<wsDr><twoCellAnchor><{shape}/></twoCellAnchor></wsDr>'.encode()
            entry = zipfile.ZipInfo(name, (1980, 1, 1, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(entry, data)
    out.append(base64.b64encode(target.getvalue()).decode())
(fixtures / 'empty-drawing-active-unsupported.json').write_text(json.dumps(out))
