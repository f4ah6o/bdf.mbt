import base64
import importlib.util
import io
from pathlib import Path
import zipfile
spec = importlib.util.spec_from_file_location('audit', Path(__file__).with_name('audit-rectangle-inputs.py'))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
def row(xml):
    b = io.BytesIO()
    with zipfile.ZipFile(b, 'w') as z:
        z.writestr('xl/drawings/drawing1.xml', xml)
    return {'input': base64.b64encode(b.getvalue()).decode()}
a = row('<a:scrgbClr r="1%" g="2%" b="3%"/>')
b = row('<a:scrgbClr r="1.1%" g="2%" b="3%"/>')
c = row('<a:scrgbClr r="1.1%" g="2%" b="3%"/><shape/>')
assert m.audit([a], [b])['colorAttributeOnlyCases'] == [0]
assert m.audit([a], [c])['otherChanges']
assert m.audit([a], [row('<a:scrgbClr r="broken" g="2%" b="3%"/>')])['otherChanges']
assert m.audit([a], [a])['changedInputs'] == 0
try:
    m.audit([a], [])
    raise AssertionError('count change accepted')
except ValueError:
    pass
print('diagnostic color/non-color/count regression PASS')
