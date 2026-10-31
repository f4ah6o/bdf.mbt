"""Generate unsupported multi-guide DrawingML variants from an upstream case."""
import base64
import io
import json
import re
import zipfile
from pathlib import Path

root = Path(__file__).resolve().parent
case = json.loads((root / "formula-multi-adjustment.json").read_text())[0]
with zipfile.ZipFile(io.BytesIO(base64.b64decode(case["input"]))) as archive:
    parts = {entry.filename: archive.read(entry) for entry in archive.infolist()}
drawing = parts["xl/drawings/drawing1.xml"].decode()
assert 'prst="bentUpArrow"' in drawing
variants = {
    "duplicate extra": '<a:gd name="adj2" fmla="val 1"/><a:gd name="adj2" fmla="val 2"/>',
    "duplicate first": '<a:gd name="adj1" fmla="val 1"/><a:gd name="adj1" fmla="val 2"/>',
    "guide unavailable on shape": '<a:gd name="adj4" fmla="val 1"/>',
    "unknown guide": '<a:gd name="mystery" fmla="val 1"/>',
    "negative value": '<a:gd name="adj2" fmla="val -1"/>',
    "large value": '<a:gd name="adj2" fmla="val 100001"/>',
    "unsupported formula": '<a:gd name="adj2" fmla="+- 1 2 3"/>',
    "missing formula": '<a:gd name="adj2"/>',
    "nonempty guide": '<a:gd name="adj2" fmla="val 1"><x/></a:gd>',
}
output = []
for label, guides in variants.items():
    changed, count = re.subn(r"<a:avLst>.*?</a:avLst>", "<a:avLst>" + guides + "</a:avLst>", drawing, count=1)
    assert count == 1
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as archive:
        for name, data in parts.items():
            info = zipfile.ZipInfo(name, (1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, changed.encode() if name == "xl/drawings/drawing1.xml" else data)
    output.append({"label": label, "input": base64.b64encode(buffer.getvalue()).decode(), "mode": case["mode"], "no_index": case["no_index"]})
(root / "formula-multi-adjustment-unsupported.json").write_text(json.dumps(output, separators=(",", ":")))
