#!/usr/bin/env python3
"""Generate unsupported table inputs from the unstyled comparison fixture."""

import base64
import io
import json
import os
from pathlib import Path
import zipfile

root = Path(os.environ["BDF_FIXTURE_ROOT"]) / "compat/xlsx"
sample = json.loads((root / "plain-table-no-style.json").read_text())[0]["input"]
data = base64.b64decode(sample)
variants = [
    '<tableStyleInfo name="TableStyleMedium2"/>',
    '<tableStyleInfo name="Unknown"/>',
    '<autoFilter ref="A1:B1"/>',
]
inputs = []
for extra in variants:
    source = zipfile.ZipFile(io.BytesIO(data))
    result = io.BytesIO()
    with zipfile.ZipFile(result, "w", zipfile.ZIP_DEFLATED) as target:
        for info in source.infolist():
            payload = source.read(info.filename)
            if info.filename == "xl/tables/table1.xml":
                payload = payload.replace(b"</table>", extra.encode() + b"</table>")
            target.writestr(info.filename, payload)
    inputs.append(base64.b64encode(result.getvalue()).decode())
(root / "plain-table-reject-unsafe.json").write_text(
    json.dumps(inputs, separators=(",", ":"))
)
