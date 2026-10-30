"""Create the original, single-sheet illustrated workbook with stdlib only."""
from pathlib import Path
from struct import pack
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo
from zlib import compress, crc32

root = Path(__file__).resolve().parent
ns = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'
office = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
package = 'http://schemas.openxmlformats.org/package/2006/relationships'


def chunk(kind, data):
    return pack('>I', len(data)) + kind + data + pack('>I', crc32(kind + data) & 0xffffffff)


def landscape_png():
    """Paint a small original landscape, without external image assets."""
    width, height = 240, 120
    rows = []
    for y in range(height):
        row = bytearray([0])
        for x in range(width):
            color = (224, 242, 239)
            if (x - 140) ** 2 + (y - 23) ** 2 < 12 ** 2:
                color = (247, 190, 86)
            if y >= 95 - abs(x - 61) * 0.62:
                color = (104, 167, 153)
            if y >= 106 - abs(x - 146) * 0.55:
                color = (49, 119, 109)
            if y >= 112 - abs(x - 220) * 0.48:
                color = (27, 88, 82)
            row.extend(color)
        rows.append(bytes(row))
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)) + chunk(b'IDAT', compress(b''.join(rows), 9)) + chunk(b'IEND', b''))


styles = f'''<styleSheet xmlns="{ns}">
<fonts count="3"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="18"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font><font><b/><sz val="11"/><color rgb="FF174C5B"/><name val="Calibri"/></font></fonts>
<fills count="4"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FF174C5B"/></patternFill></fill><fill><patternFill patternType="solid"><fgColor rgb="FFE4F2F0"/></patternFill></fill></fills>
<borders count="1"><border/></borders><cellStyleXfs count="1"><xf/></cellStyleXfs>
<cellXfs count="3"><xf/><xf fontId="1" fillId="2" applyAlignment="1"><alignment vertical="center"/></xf><xf fontId="2" fillId="3" applyAlignment="1"><alignment vertical="center" wrapText="1"/></xf></cellXfs></styleSheet>'''

sheet = f'''<worksheet xmlns="{ns}" xmlns:r="{office}"><cols><col min="1" max="1" width="5" customWidth="1"/><col min="2" max="6" width="13" customWidth="1"/></cols><sheetData>
<row r="1" ht="32" customHeight="1"><c r="A1" s="1" t="inlineStr"><is><t>Weekend field guide</t></is></c></row>
<row r="2" ht="28" customHeight="1"><c r="A2" s="2" t="inlineStr"><is><t>A landscape illustration inside a worksheet</t></is></c></row>
<row r="13" ht="26" customHeight="1"><c r="A13" s="2" t="inlineStr"><is><t>Mountain trail | 4.2 km | Easy</t></is></c></row>
<row r="15"><c r="B15" t="inlineStr"><is><t>Pack water and enjoy the view.</t></is></c></row>
</sheetData><mergeCells count="3"><mergeCell ref="A1:F1"/><mergeCell ref="A2:F2"/><mergeCell ref="A13:F13"/></mergeCells><drawing r:id="drawing1"/></worksheet>'''

drawing = f'''<xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="{office}"><xdr:twoCellAnchor><xdr:from><xdr:col>1</xdr:col><xdr:colOff>0</xdr:colOff><xdr:row>3</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:from><xdr:to><xdr:col>5</xdr:col><xdr:colOff>0</xdr:colOff><xdr:row>11</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:to><xdr:pic><xdr:nvPicPr><xdr:cNvPr id="1" name="Mountain landscape" descr="An illustrated mountain landscape"/><xdr:cNvPicPr/></xdr:nvPicPr><xdr:blipFill><a:blip r:embed="image1"/><a:stretch><a:fillRect/></a:stretch></xdr:blipFill><xdr:spPr><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></xdr:spPr></xdr:pic><xdr:clientData/></xdr:twoCellAnchor></xdr:wsDr>'''

parts = {
    '[Content_Types].xml': f'<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Default Extension="png" ContentType="image/png"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/drawings/drawing1.xml" ContentType="application/vnd.openxmlformats-officedocument.drawing+xml"/></Types>',
    '_rels/.rels': f'<Relationships xmlns="{package}"><Relationship Id="r1" Type="{office}/officeDocument" Target="xl/workbook.xml"/></Relationships>',
    'xl/workbook.xml': f'<workbook xmlns="{ns}" xmlns:r="{office}"><sheets><sheet name="Field guide" sheetId="1" r:id="r1"/></sheets></workbook>',
    'xl/_rels/workbook.xml.rels': f'<Relationships xmlns="{package}"><Relationship Id="r1" Type="{office}/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="r2" Type="{office}/styles" Target="styles.xml"/></Relationships>',
    'xl/styles.xml': styles,
    'xl/worksheets/sheet1.xml': sheet,
    'xl/worksheets/_rels/sheet1.xml.rels': f'<Relationships xmlns="{package}"><Relationship Id="drawing1" Type="{office}/drawing" Target="../drawings/drawing1.xml"/></Relationships>',
    'xl/drawings/drawing1.xml': drawing,
    'xl/drawings/_rels/drawing1.xml.rels': f'<Relationships xmlns="{package}"><Relationship Id="image1" Type="{office}/image" Target="../media/image1.png"/></Relationships>',
    'xl/media/image1.png': landscape_png(),
}
with ZipFile(root / 'samples/field-guide.xlsx', 'w') as archive:
    for name, content in parts.items():
        entry = ZipInfo(name, (2020, 1, 1, 0, 0, 0))
        entry.compress_type = ZIP_DEFLATED
        entry.external_attr = 0o644 << 16
        archive.writestr(entry, content if isinstance(content, bytes) else content.encode('utf-8'))
