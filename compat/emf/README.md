# Windows metafile compatibility fixtures

`test.emf` and `test.wmf` are the metafiles built by the upstream
`converter/internal/metafile/metafile_test.go` tests at shibukawa/bdf
`4f9af52dca60be1eb0daade39f7dc41d6a1fe431` (MIT license, see
`licenses/Shibukawa-bdf.txt`). They exercise GDI state, rectangles, hatch
brushes, text, a DIB and Shift_JIS WMF text.

`convert/emf/fixtures_generated_wbtest.mbt` embeds them for the MoonBit unit
tests. `compat/converter/phase1-test.mjs` compares page geometry with the
upstream converter. The metafile replay is also used for EMF/WMF pictures in
DOCX and PPTX.

The replay is a documented subset: path records, non-rectangular clipping,
EMF+ only files and glyph-indexed text are warnings or gaps, and hatch brushes
fall back to their foreground colour.

## Clip replacement

DocuWorks writes `DW06` (rectangle) and `DW03` (path) clips that replace the
current clip region, like `SelectClipPath(RGN_COPY)`. The object format only
carries a cumulative clip, so `convert/metafile` brackets the replay with a
clip base: a replacing record restores to that base (which keeps the page
bounds clip) and saves a fresh one before applying its region. `RGN_AND`,
`INTERSECTCLIPRECT` and other GDI clips stay cumulative.

`compat/emf/clip-replace-test.mjs` builds synthetic metafiles in memory and
checks the rendered canvas pixels: two disjoint `DW06` or `DW03` clips keep
both draws visible, `INTERSECTCLIPRECT` still hides the disjoint draw, and an
image lands at its destination rectangle. It needs `moon build --target js
browser native_converter_worker` first.

Known gap, separate from clip replacement: `SAVEDC`/`RESTOREDC` still restore
only the converter's `GdiState` and emit no object `save`/`restore`, so a clip
set inside a saved DC is not restored on the canvas. The private document that
motivated the replacement work has no `SAVEDC`/`RESTOREDC` records.

## Pen widths

A GDI pen width is a logical width, and the replay maps logical units to page
points through the same matrix as the coordinates. A geometric pen therefore
emits `width * matrix.scale()` page points. A cosmetic pen (width 0) is one
device pixel on the output, which the object format cannot express: it carries
no cosmetic flag, so the stroke is a fixed 0.75pt hairline. That value is a
96dpi-inspired approximation of one pixel, not a guarantee of one output
device pixel, and browser zoom scales it like any page width.

An anisotropic matrix has no single page width, so the geometric mean of its
axes is used. That is an approximation, not exact GDI: GDI draws an elliptical
pen. A positive geometric width below one page point is emitted as it is; the
renderer antialiases it, and GDI has no minimum for a geometric pen, so no
clamp is applied.

`compat/emf/pen-width-test.mjs` builds synthetic metafiles in memory and reads
the rendered canvas ink for a geometric pen, a legitimately wide pen, a
cosmetic pen, an anisotropic viewport, a halved device dpi (page scaling), a
positive pen below one page point, and browser zoom. It needs `moon build
--target js browser native_converter_worker render_worker` first.
