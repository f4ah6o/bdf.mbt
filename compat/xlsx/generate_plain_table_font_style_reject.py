#!/usr/bin/env python3
"""Generate combinations outside the supported whole-table font subset."""

import base64
import io
import json
import os
from pathlib import Path
import zipfile

root = Path(os.environ["BDF_FIXTURE_ROOT"]) / "compat/xlsx"
data = base64.b64decode(json.loads((root / "plain-table-font-style.json").read_text())[0]["input"])
outputs = []
for variant in range(5):
    source = zipfile.ZipFile(io.BytesIO(data))
    result = io.BytesIO()
    with zipfile.ZipFile(result, "w", zipfile.ZIP_DEFLATED) as target:
        for info in source.infolist():
            payload = source.read(info.filename)
            if variant == 0 and info.filename == "xl/styles.xml":
                payload = payload.replace(
                    b"</font></dxf>",
                    b'</font><fill><patternFill patternType="solid">'
                    b'<fgColor rgb="FF00FF00"/></patternFill></fill></dxf>',
                    1,
                )
            if variant == 1 and info.filename == "xl/styles.xml":
                payload = payload.replace(
                    b"</tableStyle>",
                    b'<tableStyleElement type="headerRow" dxfId="0"/></tableStyle>',
                    1,
                )
            if variant == 2 and info.filename == "xl/worksheets/sheet1.xml":
                payload = payload.replace(
                    b"</tableParts>",
                    b'<tablePart xmlns:r="http://schemas.openxmlformats.org/'
                    b'officeDocument/2006/relationships" r:id="t2"/></tableParts>',
                    1,
                )
            if variant == 2 and info.filename == "xl/worksheets/_rels/sheet1.xml.rels":
                payload = payload.replace(
                    b"</Relationships>",
                    b'<Relationship Id="t2" Type="x/table" '
                    b'Target="../tables/table2.xml"/></Relationships>',
                    1,
                )
            if variant == 3 and info.filename == "xl/worksheets/sheet1.xml":
                payload = payload.replace(
                    b'<row r="1">', b'<row r="1" s="1" customFormat="1">', 1
                )
            if variant == 4 and info.filename == "xl/worksheets/sheet1.xml":
                payload = payload.replace(
                    b'<col min="1" max="1" ', b'<col min="1" max="1" style="1" ', 1
                )
            target.writestr(info.filename, payload)
        if variant == 2:
            target.writestr(
                "xl/tables/table2.xml",
                b'<table ref="A1:B1" name="Other" displayName="Other"/>',
            )
    outputs.append(base64.b64encode(result.getvalue()).decode())
(root / "plain-table-font-style-reject.json").write_text(
    json.dumps(outputs, separators=(",", ":"))
)
