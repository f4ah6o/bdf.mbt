# Converter Worker compatibility

`client-test.mjs` compares the MoonBit client with `@bdfkit/convert` 0.2.1
using a controllable Worker. It covers readiness, concurrent responses, input
buffer copies, errors and termination.

`browser-test.mjs` builds a two-page PDF in memory and runs PDF conversion,
streamed pages and CSV conversion in real Chromium Workers. It compares all
four combinations of upstream and MoonBit client and Worker using the upstream
`@bdfkit/convert-office` 0.2.1 TinyGo Wasm runtime. The runtime and Go support
script are test dependencies only; the converter engines have not been ported
by these tests.

`native-test.mjs` also exercises the native Worker through both clients. Its
MML fixtures compare complete upstream-generated documents, summaries, warnings,
format detection and parameter errors for actual UTF-8 and Shift_JIS files.

`stream-test.mjs` checks the upstream streaming contract on the native Worker:
`open` reports the page count and stream, `page` returns one page with its
warnings, `finish` returns the whole document with its format, summary and
warnings, and `close` releases the stream (a later finish fails).

`phase1-test.mjs` compares the AI, TIFF, PSD and EMF/WMF converters with the
upstream `@bdfkit/convert-all` Wasm. It checks page counts, page geometry,
decoded image pixels, streamed pages, page selection and parameter errors.
JPEG-compressed TIFF pages and the documented metafile subset are covered as
explicit warnings.

`phase8-xlsx-test.mjs` embeds a supplied font in the XLSX sheet and checks the
font part.

`phase8-parquet-test.mjs` converts the generated flat fixture and checks its
sheet text and typed table.

`phase8-type1-test.mjs` checks the PDF Type 1 fixtures embed converted CFF font parts without fallback warnings.

`phase5-test.mjs` compares the HP-GL/2, Jw_cad, DXF, SXF, CGM, Gerber, KiCad and draw.io converters with the upstream
`@bdfkit/convert-all` Wasm. It checks the format registration, page geometry,
layer roles, text indexes, streamed pages, page selection and parameter
errors for the upstream `hpgl1.plt`, `shapes.plt`, `shapes.jww` and `old.jww`
fixtures. Single-file Gerber and the KiCad PCB front view and draw.io are checked for layer registration and non-empty text/pages, because its 1:1 page differs from the upstream board scaling. Binary CGM page geometry matches the picture descriptors except the unscaled second picture of `illustration.cgm`; `shapes-text.cgm` (clear-text CGM) is asserted as an explicit error. SXF SFC page geometry matches the upstream sheet; dimensions and hatches are omitted with warnings. DXF page geometry is checked within 6% because the subset omits
hatches and non-top OCS entities; `shapes-bin.dxf` checks the binary reader, and `layout.dxf` asserts the model-space page plus the documented layout warning. PCL/HP RTL raster jobs are a documented subset: `job.plt` asserts the vector page and the PCL warning while upstream also emits a raster page.

`phase9-drawio-test.mjs` and `phase9-parquet-test.mjs` compare the expanded
CAD-adjacent formats with upstream: draw.io views/pages/layers/text, and
Parquet rows, columns, source table bytes, codecs, encodings and dates.
`phase10-musicxml-test.mjs` compares the MusicXML converter with upstream:
format registration, score and guitar TAB views, page geometry, text and play
data for the upstream `minuet.musicxml` fixture.

`phase11-markdown-test.mjs` compares the Markdown converter with upstream:
scroll view id/kind/width, summary and text indexes for the upstream
`basic.md`, `math.md` and `svg.md` fixtures, including GFM lists, tables,
footnotes and LaTeX linearization. Whitespace is normalized and 88% text
similarity is required because line breaks use estimated metrics.

`phase12-docx-test.mjs` compares the DOCX converter with upstream for the
`basic`, `styles`, `grid`, `vertical` and `math` fixtures: the `pages` (`flow`)
and `scroll` view kinds, page layer roles, body rectangles, strip counts,
Dublin Core metadata and normalized page/scroll text. Page counts may differ
because the MoonBit layout still uses approximate metrics and does not handle
columns or floating text wrapping.
