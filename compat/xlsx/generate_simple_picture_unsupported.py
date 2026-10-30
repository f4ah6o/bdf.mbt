"""Generate unsupported drawing variants from the simple picture fixtures."""

import base64
import io
import json
import re
import zipfile
from pathlib import Path

root = Path(__file__).resolve().parent
cases = json.loads((root / "simple-picture.json").read_text())
output = []
for index, case in enumerate(cases):
    source = base64.b64decode(case["input"])
    with zipfile.ZipFile(io.BytesIO(source)) as archive:
        parts = {entry.filename: archive.read(entry) for entry in archive.infolist()}
    original = parts.copy()
    drawing = parts["xl/drawings/drawing1.xml"].decode()
    variant = index % 12
    if variant in (4, 5, 11):
        continue
    if variant == 0:
        drawing = drawing.replace("<a:stretch>", '<a:srcRect l="100001"/><a:stretch>')
    elif variant == 1:
        drawing = drawing.replace("<spPr>", '<spPr><a:xfrm rot="86400001"/>')
    elif variant == 2:
        drawing = drawing.replace(
            '<a:blip r:embed="img"/>',
            '<a:blip r:embed="img"><a:alphaModFix amt="50000"/><a:blur rad="1"/></a:blip>',
        )
    elif variant == 3:
        drawing = drawing.replace("</pic>", "</pic><sp/>")
    elif variant == 4:
        parts["xl/workbook.xml"] = parts["xl/workbook.xml"].replace(
            b"</sheets>", b'<sheet name="Second" r:id="r1"/></sheets>'
        )
    elif variant == 6:
        drawing = drawing.replace("<a:fillRect/>", '<a:fillRect l="100001"/>')
    elif variant == 7:
        original_drawing = drawing
        drawing = drawing.replace("<colOff>0</colOff>", "<colOff>254000001</colOff>", 1)
        if drawing == original_drawing:
            drawing = re.sub(r'<pos x="[0-9]+"', '<pos x="254000001"', drawing, count=1)
    elif variant == 8:
        drawing = drawing.replace('prst="rect"', 'prst="ellipse"')
    elif variant == 9:
        drawing = drawing.replace(
            "<spPr>", '<spPr><a:solidFill><a:srgbClr val="FF0000"/></a:solidFill>'
        )
    elif variant == 10:
        drawing = drawing.replace('r:embed="img"', 'r:link="img"')
    else:
        sheet = parts["xl/worksheets/sheet1.xml"].decode()
        sheet = sheet.replace("</row>", '<c r="AZ1"><v>42</v></c></row>')
        parts["xl/worksheets/sheet1.xml"] = sheet.encode()
    parts["xl/drawings/drawing1.xml"] = drawing.encode()
    if parts == original:
        raise ValueError(f"picture variant {variant} did not alter its input")
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
        "variant": variant,
    })
(root / "simple-picture-unsupported.json").write_text(
    json.dumps(output, separators=(",", ":"))
)
