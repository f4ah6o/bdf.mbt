import base64, io, json, zipfile
from pathlib import Path
root = Path(__file__).resolve().parent
source = json.loads((root / 'simple-rectangle.json').read_text())[0]
variants = {
    'ellipse': ('prst="rect"', 'prst="ellipse"'),
    'unknown-color': ('val="FF0000"', 'val="FF00ZZ"'),
    'color-transform': ('<a:srgbClr val="FF0000"/>', '<a:srgbClr val="FF0000"><a:lumMod val="50000"/></a:srgbClr>'),
    'alpha-too-large': ('<a:srgbClr val="FF0000"/>', '<a:srgbClr val="FF0000"><a:alpha val="100001"/></a:srgbClr>'),
    'alpha-negative': ('<a:srgbClr val="FF0000"/>', '<a:srgbClr val="FF0000"><a:alpha val="-1"/></a:srgbClr>'),
    'alpha-decimal': ('<a:srgbClr val="FF0000"/>', '<a:srgbClr val="FF0000"><a:alpha val="1.5"/></a:srgbClr>'),
    'alpha-duplicate': ('<a:srgbClr val="FF0000"/>', '<a:srgbClr val="FF0000"><a:alpha val="1"/><a:alpha val="2"/></a:srgbClr>'),
    'alpha-extra-attribute': ('<a:srgbClr val="FF0000"/>', '<a:srgbClr val="FF0000"><a:alpha val="1" foo="2"/></a:srgbClr>'),
    'theme-color': ('<a:srgbClr val="FF0000"/>', '<a:schemeClr val="accent1"/>'),
    'gradient': ('<a:solidFill><a:srgbClr val="FF0000"/></a:solidFill>', '<a:gradFill/>'),
    'dashed-line': ('<a:ln><a:noFill/></a:ln>', '<a:ln><a:solidFill><a:srgbClr val="000000"/></a:solidFill><a:prstDash val="dash"/></a:ln>'),
    'line-missing-color': ('<a:ln><a:noFill/></a:ln>', '<a:ln><a:solidFill/></a:ln>'),
    'rotation-out-of-range': ('<spPr>', '<spPr><a:xfrm rot="86400001"/>'),
    'text': ('</sp>', '<txBody><a:bodyPr/><a:lstStyle/></txBody></sp>'),
    'duplicate-fill': ('</a:solidFill>', '</a:solidFill><a:solidFill><a:srgbClr val="00FF00"/></a:solidFill>'),
}
out = []
for label, (old, new) in variants.items():
    with zipfile.ZipFile(io.BytesIO(base64.b64decode(source['input']))) as archive:
        parts = {entry.filename: archive.read(entry) for entry in archive.infolist()}
    name = 'xl/drawings/drawing1.xml'
    drawing = parts[name].decode()
    assert drawing.count(old) == 1, label
    parts[name] = drawing.replace(old, new, 1).encode()
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, 'w', zipfile.ZIP_DEFLATED) as archive:
        for name, data in parts.items():
            entry = zipfile.ZipInfo(name, (1980, 1, 1, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(entry, data)
    out.append({'input': base64.b64encode(buf.getvalue()).decode(), 'mode': source['mode'], 'no_index': source['no_index'], 'label': label})
(root / 'rectangle-invalid.json').write_text(json.dumps(out, separators=(',', ':')))
