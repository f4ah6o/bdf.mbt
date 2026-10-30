"""Generate picture inputs whose image format is not supported by the converter."""
import base64
import io
import json
import zipfile
from pathlib import Path

root = Path(__file__).resolve().parent
cases = json.loads((root / "simple-picture.json").read_text())
images = [
    b"not an image", b"\xff\xd8", b"GIF89", b"BM"[:1],
    b"RIFF\x00\x00\x00\x00JPEG", b"\x00\x00\x00\x00ftypxxxx",
    b"x" * 512 + b"<svg></svg>",
]
output = []
for index in range(56):
    case = cases[index % len(cases)]
    with zipfile.ZipFile(io.BytesIO(base64.b64decode(case["input"]))) as archive:
        parts = {entry.filename: archive.read(entry) for entry in archive.infolist()}
    parts["xl/media/image1.png"] = images[index % len(images)]
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as archive:
        for name, data in parts.items():
            info = zipfile.ZipInfo(name, (1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, data)
    output.append({
        "input": base64.b64encode(buffer.getvalue()).decode(),
        "mode": case["mode"],
        "no_index": case["no_index"],
    })
(root / "picture-unsupported-formats.json").write_text(
    json.dumps(output, separators=(",", ":"))
)
