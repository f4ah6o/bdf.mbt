import base64,io,json,re,zipfile
from pathlib import Path
root=Path(__file__).resolve().parent
source=json.loads((root/'picture-absolute-negative.json').read_text())[0]
values={
 'x-too-negative':'<pos x="-254000001" y="0"/>',
 'y-too-negative':'<pos x="0" y="-254000001"/>',
 'x-too-positive':'<pos x="254000001" y="0"/>',
 'missing-position':'',
 'duplicate-position':'<pos x="0" y="0"/><pos x="0" y="0"/>',
 'noninteger-position':'<pos x="1.5" y="0"/>',
}
out=[]
for label,value in values.items():
    with zipfile.ZipFile(io.BytesIO(base64.b64decode(source['input']))) as archive: parts={entry.filename:archive.read(entry) for entry in archive.infolist()}
    name='xl/drawings/drawing1.xml';s=parts[name].decode();s,n=re.subn(r'<pos\b[^>]*/>',lambda _:value,s,count=1)
    if n != 1: raise ValueError(label)
    parts[name]=s.encode();buf=io.BytesIO()
    with zipfile.ZipFile(buf,'w',zipfile.ZIP_DEFLATED) as archive:
        for name,data in parts.items():
            entry=zipfile.ZipInfo(name,(1980,1,1,0,0,0));entry.compress_type=zipfile.ZIP_DEFLATED;archive.writestr(entry,data)
    out.append({'input':base64.b64encode(buf.getvalue()).decode(),'mode':source['mode'],'no_index':source['no_index'],'label':label})
(root/'picture-absolute-invalid.json').write_text(json.dumps(out,separators=(',',':')))
