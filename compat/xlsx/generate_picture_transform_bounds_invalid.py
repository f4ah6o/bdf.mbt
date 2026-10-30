import base64,io,json,re,zipfile
from pathlib import Path
root=Path(__file__).resolve().parent
source=json.loads((root/'picture-transform-bounds.json').read_text())[0]
mutations={
 'off-only': lambda s: re.sub(r'<a:ext\b[^>]*/>', '', s, count=1),
 'ext-only': lambda s: re.sub(r'<a:off\b[^>]*/>', '', s, count=1),
 'zero-extent': lambda s: re.sub(r'<a:ext\b[^>]*/>', '<a:ext cx="0" cy="1"/>', s, count=1),
 'negative-offset': lambda s: re.sub(r'<a:off\b[^>]*/>', '<a:off x="-1" y="0"/>', s, count=1),
 'oversized-extent': lambda s: re.sub(r'<a:ext\b[^>]*/>', '<a:ext cx="254000001" cy="1"/>', s, count=1),
 'extra-attribute': lambda s: re.sub(r'<a:off\b[^>]*/>', '<a:off x="1" y="1" foo="1"/>', s, count=1),
 'duplicate-offset': lambda s: re.sub(r'(<a:off\b[^>]*/>)', r'\1\1', s, count=1),
}
out=[]
for label,mutate in mutations.items():
    with zipfile.ZipFile(io.BytesIO(base64.b64decode(source['input']))) as archive:
        parts={entry.filename:archive.read(entry) for entry in archive.infolist()}
    name='xl/drawings/drawing1.xml';before=parts[name].decode();after=mutate(before)
    if after==before: raise ValueError(label)
    parts[name]=after.encode();buf=io.BytesIO()
    with zipfile.ZipFile(buf,'w',zipfile.ZIP_DEFLATED) as archive:
        for name,data in parts.items():
            entry=zipfile.ZipInfo(name,(1980,1,1,0,0,0));entry.compress_type=zipfile.ZIP_DEFLATED;archive.writestr(entry,data)
    out.append({'input':base64.b64encode(buf.getvalue()).decode(),'mode':source['mode'],'no_index':source['no_index'],'label':label})
(root/'picture-transform-bounds-invalid.json').write_text(json.dumps(out,separators=(',',':')))
