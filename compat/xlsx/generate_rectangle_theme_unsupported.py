import base64, io, json, re, zipfile
from pathlib import Path
root = Path(__file__).resolve().parent
source = json.loads((root / 'rectangle-theme-colors.json').read_text())[1]
out = []
for name in ('alpha', 'alphaMod', 'alphaOff'):
    with zipfile.ZipFile(io.BytesIO(base64.b64decode(source['input']))) as archive:
        parts = {entry.filename: archive.read(entry) for entry in archive.infolist()}
    path = 'xl/theme/theme1.xml'
    xml = parts[path].decode()
    xml, count = re.subn(r'<a:srgbClr val="([0-9A-F]{6})"/>', lambda m: f'<a:srgbClr val="{m.group(1)}"><a:{name} val="50000"/></a:srgbClr>', xml, count=1)
    assert count == 1
    parts[path] = xml.encode()
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, 'w', zipfile.ZIP_DEFLATED) as archive:
        for path, data in parts.items():
            entry = zipfile.ZipInfo(path, (1980, 1, 1, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(entry, data)
    out.append({'input': base64.b64encode(buf.getvalue()).decode(), 'mode': source['mode'], 'no_index': source['no_index'], 'label': name})
(root / 'rectangle-theme-unsupported.json').write_text(json.dumps(out, separators=(',', ':')))
