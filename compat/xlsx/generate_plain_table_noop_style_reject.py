#!/usr/bin/env python3
"""Generate effective style references from a no-op table-style fixture."""

import base64
import io
import json
import os
from pathlib import Path
import zipfile

root = Path(os.environ["BDF_FIXTURE_ROOT"]) / "compat/xlsx"
sample = json.loads((root / "plain-table-noop-style-ids.json").read_text())[0]["input"]
data = base64.b64decode(sample)
inputs = []
for value in ("0", "NaN", "-0.5", "0.9"):
    source = zipfile.ZipFile(io.BytesIO(data))
    result = io.BytesIO()
    with zipfile.ZipFile(result, "w", zipfile.ZIP_DEFLATED) as target:
        for info in source.infolist():
            payload = source.read(info.filename)
            if info.filename == "xl/styles.xml":
                payload = payload.replace(
                    b'dxfId="9"', b'dxfId="' + value.encode() + b'"'
                )
            target.writestr(info.filename, payload)
    inputs.append(base64.b64encode(result.getvalue()).decode())
(root / "plain-table-noop-style-reject.json").write_text(
    json.dumps(inputs, separators=(",", ":"))
)
