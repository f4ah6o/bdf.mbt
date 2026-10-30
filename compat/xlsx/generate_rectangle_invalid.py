import base64, io, json, zipfile
from pathlib import Path
root = Path(__file__).resolve().parent
source = json.loads((root / 'simple-rectangle.json').read_text())[0]
variants = {
    'ellipse': ('prst="rect"', 'prst="ellipse"'),
    'unknown-color': ('val="FF0000"', 'val="FF00ZZ"'),
    'color-transform': ('<a:srgbClr val="FF0000"/>', '<a:srgbClr val="FF0000"><a:lumMod val="50000"/></a:srgbClr>'),
    'alpha-too-large': ('<a:srgbClr val="FF0000"/>', '<a:srgbClr val="FF0000"><a:alpha val="100001"/></a:srgbClr>'),
    'alpha-negative': ('<a:srgbClr val="FF0000"/>', '<a:srgbClr val="FF0000"><a:alpha val="-1"/></a:srgbClr>'),
    'alpha-decimal': ('<a:srgbClr val="FF0000"/>', '<a:srgbClr val="FF0000"><a:alpha val="1.5"/></a:srgbClr>'),
    'alpha-mod-too-large': ('<a:srgbClr val="FF0000"/>', '<a:srgbClr val="FF0000"><a:alphaMod val="100001"/></a:srgbClr>'),
    'alpha-mod-negative': ('<a:srgbClr val="FF0000"/>', '<a:srgbClr val="FF0000"><a:alphaMod val="-1"/></a:srgbClr>'),
    'alpha-off-too-small': ('<a:srgbClr val="FF0000"/>', '<a:srgbClr val="FF0000"><a:alphaOff val="-100001"/></a:srgbClr>'),
    'alpha-off-too-large': ('<a:srgbClr val="FF0000"/>', '<a:srgbClr val="FF0000"><a:alphaOff val="100001"/></a:srgbClr>'),
    'alpha-extra-attribute': ('<a:srgbClr val="FF0000"/>', '<a:srgbClr val="FF0000"><a:alpha val="1" foo="2"/></a:srgbClr>'),
    'fill-and-no-fill': ('</a:solidFill>', '</a:solidFill><a:noFill/>'),
    'duplicate-no-fill': ('<a:solidFill><a:srgbClr val="FF0000"/></a:solidFill>', '<a:noFill/><a:noFill/>'),
    'invert-linear-color': ('<a:srgbClr val="FF0000"/>', '<a:scrgbClr r="50000"><a:inv/></a:scrgbClr>'),
    'invert-hsl-color': ('<a:srgbClr val="FF0000"/>', '<a:hslClr hue="1"><a:inv/></a:hslClr>'),
    'invert-extra-attribute': ('<a:srgbClr val="FF0000"/>', '<a:srgbClr val="FF0000"><a:inv val="1"/></a:srgbClr>'),
    'hsl-color-negative-hue': ('<a:srgbClr val="FF0000"/>', '<a:hslClr hue="-1"/>'),
    'hsl-color-hue-too-large': ('<a:srgbClr val="FF0000"/>', '<a:hslClr hue="21600001"/>'),
    'hsl-color-saturation-too-large': ('<a:srgbClr val="FF0000"/>', '<a:hslClr sat="100001"/>'),
    'hsl-color-luminosity-too-large': ('<a:srgbClr val="FF0000"/>', '<a:hslClr lum="100001"/>'),
    'hsl-color-decimal': ('<a:srgbClr val="FF0000"/>', '<a:hslClr hue="1.5"/>'),
    'hsl-color-extra-attribute': ('<a:srgbClr val="FF0000"/>', '<a:hslClr hue="0" foo="1"/>'),
    'linear-color-negative': ('<a:srgbClr val="FF0000"/>', '<a:scrgbClr r="-1"/>'),
    'linear-color-too-large': ('<a:srgbClr val="FF0000"/>', '<a:scrgbClr g="100001"/>'),
    'linear-color-decimal': ('<a:srgbClr val="FF0000"/>', '<a:scrgbClr b="1.5"/>'),
    'linear-color-extra-attribute': ('<a:srgbClr val="FF0000"/>', '<a:scrgbClr r="0" foo="1"/>'),
    'unknown-preset-color': ('<a:srgbClr val="FF0000"/>', '<a:prstClr val="unknown"/>'),
    'preset-color-extra-attribute': ('<a:srgbClr val="FF0000"/>', '<a:prstClr val="red" foo="1"/>'),
    'system-color-extra-attribute': ('<a:srgbClr val="FF0000"/>', '<a:sysClr val="window" foo="1"/>'),
    'system-color-relationship-attribute': ('<a:srgbClr val="FF0000"/>', '<a:sysClr r:val="window"/>'),
    'system-color-transform': ('<a:srgbClr val="FF0000"/>', '<a:sysClr val="window"><a:tint val="50000"/></a:sysClr>'),
    'unknown-theme-color': ('<a:srgbClr val="FF0000"/>', '<a:schemeClr val="unknown"/>'),
    'gradient': ('<a:solidFill><a:srgbClr val="FF0000"/></a:solidFill>', '<a:gradFill/>'),
    'custom-dash': ('<a:ln><a:noFill/></a:ln>', '<a:ln><a:solidFill><a:srgbClr val="000000"/></a:solidFill><a:custDash><a:ds d="100000" sp="100000"/></a:custDash></a:ln>'),
    'unknown-dash': ('<a:ln><a:noFill/></a:ln>', '<a:ln><a:noFill/><a:prstDash val="unknown"/></a:ln>'),
    'duplicate-dash': ('<a:ln><a:noFill/></a:ln>', '<a:ln><a:noFill/><a:prstDash val="dash"/><a:prstDash val="dot"/></a:ln>'),
    'dash-extra-attribute': ('<a:ln><a:noFill/></a:ln>', '<a:ln><a:noFill/><a:prstDash val="dash" foo="1"/></a:ln>'),
    'line-missing-color': ('<a:ln><a:noFill/></a:ln>', '<a:ln><a:solidFill/></a:ln>'),
    'rotation-out-of-range': ('<spPr>', '<spPr><a:xfrm rot="86400001"/>'),
    'text': ('</sp>', '<txBody><a:bodyPr/><a:lstStyle/></txBody></sp>'),
    'duplicate-fill': ('</a:solidFill>', '</a:solidFill><a:solidFill><a:srgbClr val="00FF00"/></a:solidFill>'),
}
out = []
for label, (old, new) in variants.items():
    with zipfile.ZipFile(io.BytesIO(base64.b64decode(source['input']))) as archive:
        parts = {entry.filename: archive.read(entry) for entry in archive.infolist()}
    name = 'xl/drawings/drawing1.xml'
    drawing = parts[name].decode()
    assert drawing.count(old) == 1, label
    parts[name] = drawing.replace(old, new, 1).encode()
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, 'w', zipfile.ZIP_DEFLATED) as archive:
        for name, data in parts.items():
            entry = zipfile.ZipInfo(name, (1980, 1, 1, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(entry, data)
    out.append({'input': base64.b64encode(buf.getvalue()).decode(), 'mode': source['mode'], 'no_index': source['no_index'], 'label': label})
(root / 'rectangle-invalid.json').write_text(json.dumps(out, separators=(',', ':')))
