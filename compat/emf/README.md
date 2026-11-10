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
