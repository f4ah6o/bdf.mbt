import base64, io, json, re, zipfile
from pathlib import Path
root = Path(__file__).resolve().parent
cases = json.loads((root / 'picture-crop-mixed.json').read_text())
source = cases[10]
mutations = [
    ('negative-overflow', lambda s: re.sub(r'<a:srcRect\b[^>]*/>', '<a:srcRect l="-100001"/>', s, count=1)),
    ('positive-overflow', lambda s: re.sub(r'<a:srcRect\b[^>]*/>', '<a:srcRect l="100000"/>', s, count=1)),
    ('invalid-sum', lambda s: re.sub(r'<a:srcRect\b[^>]*/>', '<a:srcRect l="70000" r="40000"/>', s, count=1)),
    ('unknown-attribute', lambda s: re.sub(r'<a:srcRect\b[^>]*/>', '<a:srcRect foo="1"/>', s, count=1)),
    ('duplicate-attribute', lambda s: re.sub(r'<a:srcRect\b[^>]*/>', '<a:srcRect l="1" l="2"/>', s, count=1)),
    ('duplicate-rect', lambda s: re.sub(r'(<a:srcRect\b[^>]*/>)', r'\1\1', s, count=1)),
]
out=[]
for label, change in mutations + [('bad-png-crc',None), ('other-format',None), ('gif-palette-truncated',None), ('gif-empty',None), ('bmp-compressed',None), ('bmp-wrong-offset',None), ('jpeg-truncated',None), ('jpeg-precision',None), ('jpeg-components',None), ('jpeg-sampling',None), ('webp-riff-short',None), ('webp-bad-chunk',None), ('webp-size-overflow',None), ('webp-raw-magic',None), ('webp-raw-version',None), ('webp-raw-sync',None), ('webp-raw-chunk-overflow',None)]:
    with zipfile.ZipFile(io.BytesIO(base64.b64decode(source['input']))) as archive:
        parts={entry.filename: archive.read(entry) for entry in archive.infolist()}
    path='xl/drawings/drawing1.xml'; before=parts[path].decode()
    if change:
        after=change(before)
        if after==before: raise ValueError(label)
        parts[path]=after.encode()
    elif label=='bad-png-crc':
        img=bytearray(parts['xl/media/image1.png']); img[32]^=1; parts['xl/media/image1.png']=bytes(img)
    elif label=='other-format':
        parts['xl/media/image1.png']=b'\xff\xd8\xff\x00'
    elif label=='gif-palette-truncated':
        parts['xl/media/image1.png']=b'GIF89a\x01\x00\x01\x00\x80\x00\x00'
    elif label=='gif-empty':
        parts['xl/media/image1.png']=b'GIF89a\x00\x00\x01\x00\x00\x00\x00'
    elif label.startswith('bmp-'):
        bmp=bytearray(54); bmp[:2]=b'BM'; bmp[10:14]=(54 if label=='bmp-compressed' else 55).to_bytes(4,'little'); bmp[14:18]=(40).to_bytes(4,'little'); bmp[18:22]=(12).to_bytes(4,'little'); bmp[22:26]=(8).to_bytes(4,'little'); bmp[26]=1; bmp[28]=24
        if label=='bmp-compressed': bmp[30]=1
        parts['xl/media/image1.png']=bytes(bmp)
    elif label.startswith('jpeg-'):
        jpeg_case=json.loads((root/'picture-crop-jpeg.json').read_text())[0]
        with zipfile.ZipFile(io.BytesIO(base64.b64decode(jpeg_case['input']))) as source_archive:
            jpeg=bytearray(source_archive.read('xl/media/image2.png'))
        sof=jpeg.find(b'\xff\xc0')
        if sof < 0: raise ValueError('JPEG SOF0 not found')
        if label=='jpeg-truncated': jpeg=jpeg[:10]
        if label=='jpeg-precision': jpeg[sof+4]=7
        if label=='jpeg-components': jpeg[sof+13]=jpeg[sof+10]
        if label=='jpeg-sampling': jpeg[sof+11]=0
        parts['xl/media/image1.png']=bytes(jpeg)
    elif label.startswith('webp-raw-'):
        kind='lossy' if label in ('webp-raw-sync','webp-raw-chunk-overflow') else 'lossless'
        webp_case=json.loads((root/f'picture-crop-webp-{kind}.json').read_text())[0]
        with zipfile.ZipFile(io.BytesIO(base64.b64decode(webp_case['input']))) as source_archive:
            webp=bytearray(source_archive.read('xl/media/image2.png'))
        if label=='webp-raw-magic': webp[20]=0
        if label=='webp-raw-version': webp[24]|=0x20
        if label=='webp-raw-sync': webp[23]=0
        if label=='webp-raw-chunk-overflow': webp[16:20]=(4294967295).to_bytes(4,'little')
        parts['xl/media/image1.png']=bytes(webp)
    else:
        webp=bytearray(b'RIFF\x16\x00\x00\x00WEBPVP8X\x0a\x00\x00\x00'+b'\x00'*10)
        if label=='webp-riff-short': webp[4]=21
        if label=='webp-bad-chunk': webp[16]=11
        if label=='webp-size-overflow': webp[24:30]=b'\xff'*6
        parts['xl/media/image1.png']=bytes(webp)
    buf=io.BytesIO()
    with zipfile.ZipFile(buf, 'w', zipfile.ZIP_DEFLATED) as archive:
        for name, data in parts.items():
            entry=zipfile.ZipInfo(name,(1980,1,1,0,0,0));entry.compress_type=zipfile.ZIP_DEFLATED;archive.writestr(entry,data)
    out.append({'input':base64.b64encode(buf.getvalue()).decode(), 'mode':source['mode'], 'no_index':source['no_index'], 'label':label})
(root/'picture-crop-invalid.json').write_text(json.dumps(out,separators=(',',':')))
