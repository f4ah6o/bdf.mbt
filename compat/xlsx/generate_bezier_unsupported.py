"""Generate unsupported wave adjustment variants from an upstream case."""
import base64
import io
import json
import re
import zipfile
from pathlib import Path

root = Path(__file__).resolve().parent
case = json.loads((root / "bezier-presets.json").read_text())[6]
with zipfile.ZipFile(io.BytesIO(base64.b64decode(case["input"]))) as archive:
    parts = {entry.filename: archive.read(entry) for entry in archive.infolist()}
drawing = parts["xl/drawings/drawing1.xml"].decode()
assert 'prst="wave"' in drawing
variants = {
    "negative beyond limit": '<a:gd name="adj2" fmla="val -100001"/>',
    "positive beyond limit": '<a:gd name="adj2" fmla="val 100001"/>',
    "negative first adjustment": '<a:gd name="adj1" fmla="val -1"/>',
    "undefined third adjustment": '<a:gd name="adj3" fmla="val 1"/>',
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
(root / "bezier-presets-unsupported.json").write_text(json.dumps(output, separators=(",", ":")))
