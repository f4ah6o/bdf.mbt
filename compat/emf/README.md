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
