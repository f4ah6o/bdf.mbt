# Document parity harness

This page records the differential harness for the document converters and
the work it drives. It is a living status page: the baseline numbers move as
the port closes gaps.

## Target

- Upstream: `shibukawa/bdf` at commit
  `a5e4d7a6b202cfe73de44b0be51f6fb86cd8ee22` (the `.upstream` checkout).
- Browser reference: `@bdfkit/convert-all` 0.2.1 (TinyGo Wasm), the same
  runtime the other compatibility tests use.
- MoonBit side: the native converter Worker built from this repository
  (`_build/js/debug/build/native_converter_worker/native_converter_worker.js`).
- Fixtures: `compat/parity/fixtures` (the upstream `testdata` trees, MIT;
  see `fixtures/SOURCE.md`).

## Run

```sh
MOON_HOME=$PWD/.moon-home moon build --target js
MOON_HOME=$PWD/.moon-home node compat/parity/verify.mjs
```

The run writes `_scratch/parity/report.json`. `--strict` exits 1 on a
difference; the default exits 0 so the report can be generated while gaps
remain. See `compat/parity/README.md` for selectors and the canonical form.

## Baseline (2026-11-05)

52 cases: **12 pass, 40 diff, 0 one-sided error, 0 both-error**.

Passing:

- `pdf/cairo-cff`, `pdf/cairo-type1`, `pdf/cjk-cmaps`,
  `pdf/reportlab-master`, `pdf/reportlab-mixed`,
  `pdf/reportlab-mixed#no-share`, `pdf/reportlab-type1`
- `pptx/basic#slide-1`
- `xlsx/print#default`, `xlsx/form-pages`, `xlsx/form-rows`,
  `xlsx/form-fixed`

The pass list already includes the font-part normalization: the converters
produce different WOFF2 bytes for the same face, while the FONT records,
text, marks and geometry match.

## Main differences and the work they drive

| Area | First differences | Work |
|---|---|---|
| PDF | `pages[].layers[].obj.ops` (MARK inserted by upstream, absent in MoonBit); tagged structure; child-object grouping; a few JPX colour conversions | port `converter/pdf/structure.go` and the marked-content block tags; add form fields; then the remaining JPX/mask cases |
| PDF viewer | a radial gradient (shading type 3) drawn inside a group loses its inner colour and shows as a flat disc (`chrome-slides.pdf`); the BDF paint and coordinates match upstream, so the difference is in the Canvas 2D group compositing in `browser/compositing.mbt` | draw the group canvas without a scaled transform, or bake the gradient into device space at fill time; verify against `pdf/chrome-slides` |
| DOCX | theme fonts (including East Asian script fonts) and the fallback advance now match; paragraph/line/wrap/LANG MARKs exist; header bbox, per-word run emission, table/cell/figure marks and scroll strips remain | finish `emit.go` MARKs (header/footer, tables, figures); emit text per word as upstream does; table styles; tight/through wrap; shadows; footnotes; vertical CJK; SECTIONPAGES |
| Markdown | the upstream fallback advances (0.25/1.0/0.55) are in use; page height and font count still differ | port the wordproc reader rules (line boxes, headings, tables); add `base`/`remote`/`private` resource resolution into the shared fontset |
| PPTX | font records, 0.55 advance, text-local transform, box/title marks, linear-RGB tint and vertical metrics now match; chart labels, some text-rect inheritance and MARKs remain | shared chart renderer extraction; SmartArt `dgm` drawing; full MARKs |
| XLSX | `views=print` ignored (view id `sheet1` instead of `print1`); chart SVG pictures; number-format runs | implement the print view (page setup, print areas/titles, breaks, header/footer, paper); move charts to the shared BDF renderer; close the number-format/border gaps |

The harness is deliberately strict: text, warnings, summaries, MARK/LINK and
part identities must match exactly; only f32 geometry has a 0.01 tolerance.
A case is not made to pass by relaxing the comparison. The report records
`diffCount` and `diffCategories`; the printed per-case number is the full
count, not a truncation.

Progress made since the first baseline:

- PDF vertical text embeds the font program (font kind and count now match;
  `cjk-cmaps` passes);
- PDF image smoothing is emitted only when a small image is scaled up more
  than twice, matching upstream's `Interpolate` rule (`reportlab-mixed`
  passes);
- PDF link annotations are written without the inverse-transform wrapper;
  only annotation appearances use the correction (`reportlab-mixed` and its
  `no-share` variant pass);
- image parts are compared by decoded PNG pixels rather than encoder bytes,
  and object image references use those content keys, so compression and
  image-array order no longer count as differences;
- PPTX fallback FONT records use the shared CSS family list
  (`"Calibri", sans-serif`), and DOCX uses the same `@fontdb.css_family`;
- upstream fallback advances (space 0.25, East Asian 1, controls 0, other
  0.55) replace the local 0.5 estimates in DOCX, Markdown and DrawingML;
- DOCX resolves `w:rFonts` theme references through the package theme,
  including the language's East Asian script (Jpan/Hans/Hant/Hang), and
  classifies families with `@fontdb.classify`; `math.docx` now produces the
  same 游ゴシック Light / Arial / 游明朝 / Century FONT records;
- DOCX emits paragraph/heading marks, the LINE/WRAP join marks for
  continuation lines, and LANG marks when a run language differs from the
  document default; a test locks the language-to-script mapping;
- PPTX now uses the upstream 0.55 fallback advance. Text drawing also
  deduplicates FONT and fill-color state between lines, so a wrapped
  paragraph emits the color once as upstream does; phase 15 stays green;
- PPTX wraps shape text in `save`/`translate` with local coordinates,
  emits the BOX and title HEADING marks, and centers title placeholders;
- PPTX applies tint in linear RGB, uses the upstream 0.9/0.25 fallback
  ascent/descent, skips the first paragraph's space-before, and tolerates
  the f64 line-break boundary; `pptx/basic#slide-1` now passes exactly;
- PPTX applies the `pages` option while converting (so summary, page count
  and text index describe only the selected slides) and falls back to the
  deck's core title for the view title.

## Next gates

1. Shared fontset metrics and embedding for DOCX/Markdown/XLSX, then the
   PPTX chart labels and remaining text-rect cases.
2. PDF child-object grouping and tagged structure; then form fields and the
   8 remaining PDF cases.
3. DOCX MARK emission and font metrics; then the 12 remaining DOCX cases.
4. Markdown reader metrics and resources; then the 6 remaining cases.
5. PPTX MARKs, charts and SmartArt; then the 7 remaining cases.
6. XLSX print view and BDF charts; then the 7 remaining workbooks.

## Expanded scope: form/ and print/

The program also includes the two upstream packages the initial document
plan left out:

- `form/`: the tag language (`form/tag`), the template engine
  (`form/form.go`, `partial.go`, `schema.go`, `values.go`), and the
  per-format fillers in `converter/{docx,pptx,xlsx}/template.go`,
  `converter/pdfform`, `converter/pdfme` and `form/textpart`.
- `print/`: IPP/CUPS clients and the print server, PWG raster and PDF/PS
  output, spool, media/tickets, and the fake printer used by the upstream
  tests.

They follow the document converter parity gates: the template fillers reuse
the same layout, font and view code, and the print path consumes the same
BDF pages. Their own parity harnesses will use the same reference/decoding
approach and will be added under `compat/form` and `compat/print`.

Progress: `form/tag` now ported the upstream tokenizer (text/values,
sections, pictures, formats, modes, text columns and code options) and the
scope lookup (JSON truthiness/items, dates, value text, section variables)
and field collection, with the upstream tag and scope cases as 12 MoonBit
tests. `form/textpart` covers the print image (width, cells, text, JSON
encode/decode, checks and BDF part glue) with 6 more tests, and
`form/data` loads JSON and CSV/TSV data with 3 more, and `form/schema`
writes the JSON Schema with 3 more, and `form/textform` reads the front
matter, body tags, sections, filling/pagination/options/sources with 17 more, workbook sources, OOXML
value tags and a basic pdfme filler, and
`convert/textform` lays the result out as a fixed BDF view (tables and
page selection included) with 4 more; the textform font options, form
partial fill, other fillers and most print packages remain. `print/raster`
now has the PWG Raster header, row compression, the stream writer/reader,
page fitting, RGBA row conversion, Apple Raster, PCLm, one-page raster
encoders and the IPP message codec (collections, decode limits, attribute
accessors and printer URL
parsing, requested attributes, printer groups, job status, the Printer
model, DNS-SD TXT records, the HTTP envelope and client request
builders, status errors, the transport callback and high-level CUPS
operations, PDF document printing, the BDF→PDF→IPP print pipeline and the
JS fetch transport, BDF→PDF printing and DNS-SD wire records included); `print/server` has the in-memory IPP job/printer handlers and the HTTP
envelope.
