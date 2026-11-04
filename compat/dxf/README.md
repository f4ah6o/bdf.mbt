# DXF compatibility fixtures

The fixtures are the upstream `converter/dxf/testdata` files at
shibukawa/bdf `4f9af52dca60be1eb0daade39f7dc41d6a1fe431` (MIT license, see
`licenses/Shibukawa-bdf.txt`).

- `shapes.dxf`: model-space shapes, text and layers.
- `shapes-bin.dxf`: the binary encoding of a drawing with 16-bit group codes.
- `r12-sjis.dxf`: an R12 drawing with Shift_JIS text.
- `layout.dxf`: model space plus paper-space layouts.

`compat/converter/phase5-test.mjs` compares the converted pages with the
upstream converter. Text and binary R12 to 2018 files are read; paper-space
layouts, HATCH entities and entities whose OCS normal is not +Z are documented
gaps and are reported with warnings or an explicit error. For `layout.dxf`,
upstream emits model and paper-space views; this port emits the model-space
view and reports the layout warning.
