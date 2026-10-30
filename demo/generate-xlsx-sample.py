"""Generate the project's original Excel demo workbook using the standard library."""
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo
from xml.sax.saxutils import escape

root = Path(__file__).resolve().parent
ns = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'
office_rel = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
package_rel = 'http://schemas.openxmlformats.org/package/2006/relationships'


def cell(ref, value, style=0):
    if isinstance(value, str):
        return f'<c r="{ref}" s="{style}" t="inlineStr"><is><t>{escape(value)}</t></is></c>'
    return f'<c r="{ref}" s="{style}"><v>{value}</v></c>'


def row(number, cells, height=None):
    size = f' ht="{height}" customHeight="1"' if height else ''
    return f'<row r="{number}"{size}>' + ''.join(cell(*c) for c in cells) + '</row>'


styles = '''<styleSheet xmlns="%s">
<fonts count="4"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="18"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font><font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font><font><b/><sz val="11"/><color rgb="FF174C5B"/><name val="Calibri"/></font></fonts>
<fills count="6"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FF174C5B"/></patternFill></fill><fill><patternFill patternType="solid"><fgColor rgb="FFE4F2F0"/></patternFill></fill><fill><patternFill patternType="solid"><fgColor rgb="FFF3F7F7"/></patternFill></fill><fill><patternFill patternType="solid"><fgColor rgb="FFFFE4C7"/></patternFill></fill></fills>
<borders count="2"><border/><border><bottom style="thin"><color rgb="FFB4CFCB"/></bottom></border></borders>
<cellStyleXfs count="1"><xf/></cellStyleXfs><cellXfs count="9"><xf/><xf fontId="1" fillId="2" applyAlignment="1"><alignment vertical="center"/></xf><xf fontId="3" fillId="3" applyAlignment="1"><alignment vertical="center" wrapText="1"/></xf><xf fontId="2" fillId="2" borderId="1" applyAlignment="1"><alignment vertical="center"/></xf><xf borderId="1"/><xf borderId="1" fillId="4"/><xf borderId="1" numFmtId="4"/><xf borderId="1" numFmtId="10"/><xf borderId="1" applyAlignment="1"><alignment wrapText="1" vertical="center"/></xf></cellXfs>
<dxfs count="2"><dxf><font><b/><color rgb="FF8E351D"/></font><fill><patternFill patternType="solid"><fgColor rgb="FFFFE4C7"/></patternFill></fill></dxf><dxf><font><b/><color rgb="FFFFFFFF"/></font><fill><patternFill patternType="solid"><fgColor rgb="FF347A78"/></patternFill></fill></dxf></dxfs>
<tableStyles count="1" defaultTableStyle="DemoHeader"><tableStyle name="DemoHeader" pivot="0" table="1" count="1"><tableStyleElement type="headerRow" dxfId="1"/></tableStyle></tableStyles></styleSheet>''' % ns

sales_rows = [
    row(1, [('A1', 'Quarterly sales overview', 1)], 32),
    row(2, [('A2', 'A sample workbook with formats, tables and conditional highlights', 2)], 30),
    row(4, [('A4', 'Product', 3), ('B4', 'Region', 3), ('C4', 'Units', 3), ('D4', 'Revenue', 3), ('E4', 'Margin', 3), ('F4', 'Notes', 3)], 23),
]
data = [
    ('Notebook', 'East', 120, 1860.50, .34, 'Strong spring demand across the region'),
    ('Pencil', 'West', 85, 510.00, .21, 'Restock planned'),
    ('Marker', 'North', 64, 768.25, .28, 'New colors'),
    ('Paper', 'South', 42, 252.00, .12, 'Review stock levels'),
    ('Folders', 'East', 96, 864.00, .31, 'Repeat orders'),
    ('Labels', 'West', 38, 190.00, .18, 'Seasonal item'),
]
for number, values in enumerate(data, 5):
    base = 5 if number % 2 == 0 else 4
    sales_rows.append(row(number, [(f'{chr(65+i)}{number}', v, 6 if i == 3 else 7 if i == 4 else 8 if i == 5 and number == 5 else base) for i, v in enumerate(values)], 33 if number == 5 else 21))
sales_rows += [row(12, [('A12', 'Reading this sheet', 3)], 23), row(13, [('A13', 'Orange highlights identify low margins. Amounts and percentages use number formats.', 2)], 35)]
sales = (f'<worksheet xmlns="{ns}" xmlns:r="{office_rel}"><cols><col min="1" max="1" width="20" customWidth="1"/><col min="2" max="2" width="13" customWidth="1"/><col min="3" max="3" width="11" customWidth="1"/><col min="4" max="4" width="16" customWidth="1"/><col min="5" max="5" width="12" customWidth="1"/><col min="6" max="6" width="25" customWidth="1"/></cols><sheetData>' + ''.join(sales_rows) + '</sheetData><mergeCells count="3"><mergeCell ref="A1:F1"/><mergeCell ref="A2:F2"/><mergeCell ref="A13:F13"/></mergeCells><conditionalFormatting sqref="E5:E10"><cfRule type="cellIs" operator="lessThan" dxfId="0" priority="1"><formula>0.2</formula></cfRule></conditionalFormatting><tableParts count="1"><tablePart r:id="t1"/></tableParts></worksheet>')

summary_rows = [row(1, [('A1', 'Seasonal summary', 1)], 32), row(2, [('A2', 'Compare seasonal totals and search across sheets', 2)], 30), row(4, [('A4', 'Season', 3), ('B4', 'Orders', 3), ('C4', 'Revenue', 3), ('D4', 'Margin', 3)], 23)]
for number, values in enumerate([('Spring', 269, 4444.75, .29), ('Summer', 315, 5132.50, .32), ('Autumn', 288, 4719.25, .27), ('Winter', 240, 3920.00, .24)], 5):
    summary_rows.append(row(number, [(f'{chr(65+i)}{number}', v, 6 if i == 2 else 7 if i == 3 else (5 if number % 2 == 0 else 4)) for i, v in enumerate(values)], 23))
summary = (f'<worksheet xmlns="{ns}"><cols><col min="1" max="1" width="22" customWidth="1"/><col min="2" max="2" width="14" customWidth="1"/><col min="3" max="3" width="18" customWidth="1"/><col min="4" max="4" width="14" customWidth="1"/></cols><sheetData>' + ''.join(summary_rows) + '</sheetData><mergeCells count="2"><mergeCell ref="A1:D1"/><mergeCell ref="A2:D2"/></mergeCells></worksheet>')

parts = {
    '[Content_Types].xml': '<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/><Override PartName="/xl/tables/table1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.table+xml"/>' + ''.join(f'<Override PartName="/xl/worksheets/sheet{i}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>' for i in range(1, 3)) + '</Types>',
    '_rels/.rels': f'<Relationships xmlns="{package_rel}"><Relationship Id="r1" Type="{office_rel}/officeDocument" Target="xl/workbook.xml"/></Relationships>',
    'xl/workbook.xml': f'<workbook xmlns="{ns}" xmlns:r="{office_rel}"><sheets><sheet name="Sales" sheetId="1" r:id="r1"/><sheet name="Summary" sheetId="2" r:id="r2"/></sheets></workbook>',
    'xl/_rels/workbook.xml.rels': f'<Relationships xmlns="{package_rel}"><Relationship Id="r1" Type="{office_rel}/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="r2" Type="{office_rel}/worksheet" Target="worksheets/sheet2.xml"/><Relationship Id="r3" Type="{office_rel}/styles" Target="styles.xml"/></Relationships>',
    'xl/styles.xml': styles,
    'xl/worksheets/sheet1.xml': sales,
    'xl/worksheets/sheet2.xml': summary,
    'xl/worksheets/_rels/sheet1.xml.rels': f'<Relationships xmlns="{package_rel}"><Relationship Id="t1" Type="{office_rel}/table" Target="../tables/table1.xml"/></Relationships>',
    'xl/tables/table1.xml': f'<table xmlns="{ns}" id="1" name="SalesTable" displayName="SalesTable" ref="A4:F10" headerRowCount="1"><autoFilter ref="A4:F10"/><tableColumns count="6">' + ''.join(f'<tableColumn id="{i}" name="{name}"/>' for i, name in enumerate(['Product', 'Region', 'Units', 'Revenue', 'Margin', 'Notes'], 1)) + '</tableColumns><tableStyleInfo name="DemoHeader" showRowStripes="0" showColumnStripes="0"/></table>',
}
with ZipFile(root / 'samples/sales.xlsx', 'w') as archive:
    for name, content in parts.items():
        entry = ZipInfo(name, (2020, 1, 1, 0, 0, 0))
        entry.compress_type = ZIP_DEFLATED
        entry.external_attr = 0o644 << 16
        archive.writestr(entry, content.encode('utf-8'))
