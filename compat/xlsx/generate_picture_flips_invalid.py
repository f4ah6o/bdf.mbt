import base64,io,json,re,zipfile
from pathlib import Path
root=Path(__file__).resolve().parent
source=json.loads((root/'picture-flips-mixed.json').read_text())[0]
values={
 'rotation-out-of-range':'<a:xfrm rot="86400001"/>',
 'invalid-boolean':'<a:xfrm flipH="yes"/>',
 'duplicate-attribute':'<a:xfrm flipH="1" flipH="0"/>',
 'unknown-attribute':'<a:xfrm foo="1"/>',
 'nested-transform':'<a:xfrm flipH="1"><a:off x="0" y="0"/></a:xfrm>',
 'duplicate-transform':'<a:xfrm flipH="1"/><a:xfrm flipV="1"/>',
}
out=[]
for label,value in values.items():
    with zipfile.ZipFile(io.BytesIO(base64.b64decode(source['input']))) as archive:
        parts={entry.filename: archive.read(entry) for entry in archive.infolist()}
    name='xl/drawings/drawing1.xml';s=parts[name].decode();s,n=re.subn(r'<a:xfrm\b[^>]*/>',lambda _:value,s,count=1)
    if n != 1: raise ValueError(label)
    parts[name]=s.encode();buf=io.BytesIO()
    with zipfile.ZipFile(buf,'w',zipfile.ZIP_DEFLATED) as archive:
        for name,data in parts.items():
            entry=zipfile.ZipInfo(name,(1980,1,1,0,0,0));entry.compress_type=zipfile.ZIP_DEFLATED;archive.writestr(entry,data)
    out.append({'input':base64.b64encode(buf.getvalue()).decode(),'mode':source['mode'],'no_index':source['no_index'],'label':label})
(root/'picture-flips-invalid.json').write_text(json.dumps(out,separators=(',',':')))
