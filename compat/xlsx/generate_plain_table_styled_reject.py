#!/usr/bin/env python3
"""Generate a nonempty custom table style from the empty-style fixture."""

import base64
import io
import json
import os
from pathlib import Path
import zipfile

root = Path(os.environ["BDF_FIXTURE_ROOT"]) / "compat/xlsx"
sample = json.loads((root / "plain-table-empty-style.json").read_text())[0]["input"]
source = zipfile.ZipFile(io.BytesIO(base64.b64decode(sample)))
result = io.BytesIO()
with zipfile.ZipFile(result, "w", zipfile.ZIP_DEFLATED) as target:
    for info in source.infolist():
        payload = source.read(info.filename)
        if info.filename == "xl/styles.xml":
            payload = payload.replace(
                b'<tableStyle name="EmptyStyle"/>',
                b'<tableStyle name="EmptyStyle"><tableStyleElement '
                b'type="wholeTable" dxfId="0"/></tableStyle>',
            )
        target.writestr(info.filename, payload)
(root / "plain-table-styled-reject.json").write_text(
    json.dumps([base64.b64encode(result.getvalue()).decode()], separators=(",", ":"))
)
