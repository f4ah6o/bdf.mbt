import base64, io, json, zipfile
from pathlib import Path
root=Path(__file__).resolve().parent
source=json.loads((root/'picture-crop-svg.json').read_text())[10]
values={
 'missing-size': b'<svg xmlns="http://www.w3.org/2000/svg" height="2"/>',
 'zero-size': b'<svg xmlns="http://www.w3.org/2000/svg" width="0" height="2"/>',
 'percentage-size': b'<svg xmlns="http://www.w3.org/2000/svg" width="20%" height="2"/>',
 'oversized-dimension': b'<svg xmlns="http://www.w3.org/2000/svg" width="1000001" height="2"/>',
 'wrong-root': b'<root><svg width="2" height="2"/></root>',
 'entity': b'<!DOCTYPE svg [<!ENTITY e "2">]><svg width="&e;" height="2"/>',
 'oversized-source': b'<svg width="2" height="2">'+b' '*4194304+b'</svg>',
}
out=[]
for label, image in values.items():
    with zipfile.ZipFile(io.BytesIO(base64.b64decode(source['input']))) as archive:
        parts={entry.filename: archive.read(entry) for entry in archive.infolist()}
    parts['xl/media/image2.png']=image; buf=io.BytesIO()
    with zipfile.ZipFile(buf,'w',zipfile.ZIP_DEFLATED) as archive:
        for name,data in parts.items():
            entry=zipfile.ZipInfo(name,(1980,1,1,0,0,0));entry.compress_type=zipfile.ZIP_DEFLATED;archive.writestr(entry,data)
    out.append({'input':base64.b64encode(buf.getvalue()).decode(),'mode':source['mode'],'no_index':source['no_index'],'label':label})
(root/'picture-crop-svg-invalid.json').write_text(json.dumps(out,separators=(',',':')))
