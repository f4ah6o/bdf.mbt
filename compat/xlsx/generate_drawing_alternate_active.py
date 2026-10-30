#!/usr/bin/env python3
"""Generate drawings with AlternateContent that must not be silently skipped."""
import base64
import io
import json
import sys
import zipfile
from pathlib import Path

fixtures = Path(sys.argv[1])
case = json.loads((fixtures / 'empty-drawing-variants.json').read_text())[0]
original = zipfile.ZipFile(io.BytesIO(base64.b64decode(case['input'])))
xmls = (
    '<wsDr xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"><mc:AlternateContent><mc:Choice><twoCellAnchor><pic/></twoCellAnchor></mc:Choice></mc:AlternateContent></wsDr>',
    '<wsDr xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"><twoCellAnchor><mc:AlternateContent><mc:Choice><pic/></mc:Choice></mc:AlternateContent></twoCellAnchor></wsDr>',
)
out = []
for xml in xmls:
    target = io.BytesIO()
    with zipfile.ZipFile(target, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
        for name in original.namelist():
            data = xml.encode() if name == 'xl/drawings/drawing1.xml' else original.read(name)
            entry = zipfile.ZipInfo(name, (1980, 1, 1, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(entry, data)
    out.append(base64.b64encode(target.getvalue()).decode())
(fixtures / 'drawing-alternate-active-unsupported.json').write_text(json.dumps(out))
