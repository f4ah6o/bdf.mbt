"""Generate the original two-sheet demo workbook using only the standard library."""
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo
from xml.sax.saxutils import escape

root = Path(__file__).resolve().parent
sheets = [
    ("Sales", [["Product", "Region", "Units"], ["Notebook", "East", 120], ["Pencil", "West", 85], ["Marker", "North", 64]]),
    ("Summary", [["Quarter", "Total"], ["Spring", 269], ["Summer", 315], ["Autumn", 288]]),
]
ns = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'
def worksheet(rows):
    out = [f'<worksheet xmlns="{ns}"><sheetData>']
    for r, row in enumerate(rows, 1):
        out.append(f'<row r="{r}">')
        for c, value in enumerate(row):
            ref = f'{chr(65+c)}{r}'
            if isinstance(value, str):
                out.append(f'<c r="{ref}" t="inlineStr"><is><t>{escape(value)}</t></is></c>')
            else:
                out.append(f'<c r="{ref}"><v>{value}</v></c>')
        out.append('</row>')
    return ''.join(out) + '</sheetData></worksheet>'
parts = {
    '[Content_Types].xml': '<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>' + ''.join(f'<Override PartName="/xl/worksheets/sheet{i}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>' for i in range(1,3)) + '</Types>',
    '_rels/.rels': '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>',
    'xl/workbook.xml': f'<?xml version="1.0"?><workbook xmlns="{ns}" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>' + ''.join(f'<sheet name="{name}" sheetId="{i}" r:id="rId{i}"/>' for i,(name,_) in enumerate(sheets,1)) + '</sheets></workbook>',
    'xl/_rels/workbook.xml.rels': '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' + ''.join(f'<Relationship Id="rId{i}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet{i}.xml"/>' for i in range(1,3)) + '</Relationships>',
}
for i, (_, rows) in enumerate(sheets, 1):
    parts[f'xl/worksheets/sheet{i}.xml'] = worksheet(rows)
with ZipFile(root / 'samples/sales.xlsx', 'w') as archive:
    for name, content in parts.items():
        entry = ZipInfo(name, (2020, 1, 1, 0, 0, 0))
        entry.compress_type = ZIP_DEFLATED
        entry.external_attr = 0o644 << 16
        archive.writestr(entry, content.encode('utf-8'))
