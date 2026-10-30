import base64, io, json, re, zipfile
from pathlib import Path
root = Path(__file__).resolve().parent
source = json.loads((root / 'picture-fill-mixed.json').read_text())[0]
mutations = [
    ('fill-negative', lambda s: re.sub(r'<a:fillRect\b[^>]*/>', '<a:fillRect l="-1"/>', s, count=1)),
    ('fill-overflow', lambda s: re.sub(r'<a:fillRect\b[^>]*/>', '<a:fillRect l="100001"/>', s, count=1)),
    ('fill-sum', lambda s: re.sub(r'<a:fillRect\b[^>]*/>', '<a:fillRect l="60000" r="60000"/>', s, count=1)),
    ('fill-unknown', lambda s: re.sub(r'<a:fillRect\b[^>]*/>', '<a:fillRect foo="0"/>', s, count=1)),
    ('fill-duplicate', lambda s: re.sub(r'<a:fillRect\b[^>]*/>', '<a:fillRect l="1" l="2"/>', s, count=1)),
    ('alpha-negative', lambda s: re.sub(r'<a:alphaModFix\b[^>]*/>', '<a:alphaModFix amt="-1"/>', s, count=1)),
    ('alpha-overflow', lambda s: re.sub(r'<a:alphaModFix\b[^>]*/>', '<a:alphaModFix amt="100001"/>', s, count=1)),
    ('alpha-duplicate', lambda s: re.sub(r'(<a:alphaModFix\b[^>]*/>)', r'\1\1', s, count=1)),
    ('offset-negative', lambda s: s.replace('<colOff>0</colOff>', '<colOff>-1</colOff>', 1)),
    ('offset-overflow', lambda s: s.replace('<colOff>0</colOff>', '<colOff>254000001</colOff>', 1)),
    ('offset-duplicate', lambda s: s.replace('<colOff>0</colOff>', '<colOff>0</colOff><colOff>0</colOff>', 1)),
]
out=[]
for label, change in mutations:
    with zipfile.ZipFile(io.BytesIO(base64.b64decode(source['input']))) as archive:
        parts={entry.filename: archive.read(entry) for entry in archive.infolist()}
    path='xl/drawings/drawing1.xml'; before=parts[path].decode(); after=change(before)
    if after == before: raise ValueError(label)
    parts[path]=after.encode(); buf=io.BytesIO()
    with zipfile.ZipFile(buf, 'w', zipfile.ZIP_DEFLATED) as archive:
        for name, data in parts.items():
            entry=zipfile.ZipInfo(name, (1980,1,1,0,0,0)); entry.compress_type=zipfile.ZIP_DEFLATED; archive.writestr(entry,data)
    out.append({'input':base64.b64encode(buf.getvalue()).decode(), 'mode':source['mode'], 'no_index':source['no_index'], 'label':label})
(root / 'picture-invalid.json').write_text(json.dumps(out,separators=(',',':')))
