# PDF compatibility fixtures

`convert/pdf` exposes `detect` and `convert`, and the native converter Worker
advertises the `pdf` format. The fixtures below exercise the internal path.

The content-stream lexer fixtures compare token types, byte values, numeric
values, malformed-input recovery, nesting and inline-image boundaries with the
upstream Go PDF converter. The lexer is an internal building block; it does not
by itself provide PDF-to-BDF conversion.

To regenerate the Go reference, copy `generate_content_lexer_test.go` without
its build tag beside upstream `converter/pdf/lexer.go`, then run
`BDF_REFERENCE_OUTPUT=/absolute/path/to/content_lexer_generated_wbtest.mbt go test -run '^TestCodexContentLexer$'`.
Run `moon fmt convert/pdf` afterward. Both JavaScript and wasm-gc execute the
same generated expectations.

The CMap fixtures compare 153 predefined CJK encodings, their code spaces,
421,705 range-boundary and midpoint CID lookups, and every CID-to-Unicode and
vertical-form mapping in the supported range against
upstream `converter/internal/cjkcmap`. The archive and its Adobe license are
retained in generated source and `licenses/Adobe-CMap.txt`. Regenerate the
archive with `generate_cjk_data.py` using upstream `cmaps.bin.gz`, and the
glyph list with `generate_glyph_names.py` using upstream `glyphlist.go`.
Copy `generate_cjk_reference_test.go` without its build tag into the upstream
`converter/internal/cjkcmap` package, then run `TestCodexCJKReference`,
`TestCodexCJKRangeDigests`, `TestCodexCJKUnicode` and
`TestCodexCJKUnicodeDigests` separately with `BDF_REFERENCE_OUTPUT` set to the
corresponding generated MoonBit test file. Likewise,
`generate_cmap_test.go` runs as `TestCodexCMap` in upstream `converter/pdf`.

Upstream currently inherits some code spaces during Go map iteration. For
`ETenms-B5-V`, this can produce either inherited ranges or no ranges depending
on iteration order. This port resolves the entire parent chain deterministically;
the fixture generator uses the same complete-chain expectation for that field.
CID and Unicode lookup expectations still come directly from upstream.

PDF stream fixtures compare TIFF and PNG predictors, Flate, RunLength, LZW,
ASCIIHex and ASCII85 filters, and multi-filter pipelines against upstream.
The generated tests include limits, invalid data, truncated streams and LZW
dictionary-width changes. Each `generate_*_test.go` file runs without its
build tag as the correspondingly named `TestCodex*` test in upstream
`converter/pdf`, with `BDF_REFERENCE_OUTPUT` set to its generated test path.

The file-object fixtures compare pdfcpu object parsing against 6,912 generated
inputs and 486 objects extracted from 11 upstream PDF test files. The same
upstream files exercise cross-reference tables and streams, indirect object
resolution, inherited page attributes, and decoded page-content bytes.
Synthetic fixtures cover incremental updates, compressed object streams,
page-tree cycles and repeated leaves. These tests use the PDF files in upstream
`converter/pdf/testdata`; each generator documents its output and dependencies.
The file parser and page walker are internal components, not yet a complete
PDF converter.

The path fixtures compare 512 sequences of moves, lines, cubic curves, closes
and rectangles (16,384 operations), including float32 coordinates, bounds and
current points, against the upstream PDF interpreter. Generate them with
`generate_draw_path_test.go` as `TestCodexPDFDrawPath` beside upstream
`converter/pdf`, with `BDF_REFERENCE_OUTPUT` set to the generated test path.
`generate_draw_operators_test.go` additionally compares path operators and
malformed operand lists with the upstream interpreter, using
`BDF_PDF_FIXTURES` for the testdata directory.

The graphics fixtures compare BDF object bytes produced from path painting,
clipping, color, line and transform operators, and from complete synthetic PDF
pages with Flate compression and all right-angle rotations. The internal
renderer rejects operators it does not yet implement; it is not a complete
PDF-to-BDF converter. Run `TestCodexPDFGraphics` and
`TestCodexPDFGraphicsPages` using the corresponding generator files.
The graphics comparisons also cover dash patterns, rounding-based state
deduplication and device color-space operators. `generate_dash_test.go`
compares 512 pairs of dash values with `TestCodexPDFDashKeys` upstream.
The synthetic page cases also cover inherited named and ICC-based color
spaces, and extended graphics states for transparency, blending and line
dashes. Nontrivial soft masks remain unsupported by this internal renderer.

Metadata fixtures compare PDFDocEncoding, UTF-16BE and UTF-8 text, PDF date
parsing, and document information fields against upstream. Malformed UTF-8
from a UTF-8 BOM string is normalized to replacement characters for MoonBit's
Unicode strings. Regenerate with `generate_metadata_text_test.go`,
`generate_metadata_date_test.go` and `generate_metadata_test.go` beside the
upstream PDF sources; the latter also needs `BDF_PDF_FIXTURES`.
The page fixtures also compare complete PDF-to-BDF documents, including
metadata, page-boundary selection, title overrides, an empty page tree, simple
and composite text, text indexes and shared page prefixes. They compare decoded
manifests and part bytes. Unsupported PDF content, annotations, encryption,
optional content and tagged structure are rejected by this internal path.

The shared-prefix fixtures compare complete documents whose pages begin with a
common instruction stream. `generate_shared_pages_test.go` runs as
`TestCodexPDFSharedPages` beside upstream `converter/pdf` with
`BDF_REFERENCE_OUTPUT` set to
`convert/pdf/draw_graphics_shared_generated_wbtest.mbt`. Eight page scenarios
are each run with the no-sharing and no-text-index masks, and the fixtures
check `SharedPrefixes`, `SharedBytes`, warnings, decoded manifests, and every
part hash and decoded part byte. Compressed part lengths differ between the Go
and MoonBit DEFLATE encoders, so the test canonicalizes the stored `len`
manifest field; decoded sizes, hashes and bytes are exact.

The image tests build synthetic PDFs with image XObjects and inline images.
JPEG `DCTDecode` bytes are stored unchanged, 8-bit Flate samples in
DeviceGray, DeviceRGB and DeviceCMYK are converted to non-interlaced RGB PNG
parts, 1-bit stencil masks paint the current fill colour as RGBA PNGs, and
stencil `/Mask` or 8-bit grayscale `/SMask` attachments supply image alpha.
They check the image part bytes, the page object's image resource, PNG
dimensions, colour type and decoded scanlines. Upstream may re-encode sample
images as WebP or AVIF, so these tests do not claim byte parity with its image
payloads; the pixels are equivalent. Colour-key masks, encoded images with
masks, `Decode` arrays on colour images, JPX, JBIG2, CCITT and form
transparency groups are rejected by this internal path. Form XObjects are
executed with their own resources, `/Matrix` and `/BBox` clip.

The shading tests build synthetic PDFs with axial and radial shadings. They
check the BDF gradient paint kind, coordinates, stop offsets and colours, and
that stitching functions are sampled. Function-based shading types that are not
ported yet fall back to a flat colour sampled at the domain midpoint. Shading
patterns are checked through a `/Pattern` colour space and path fill; tiling
patterns are rejected.

The embedded-font tests build synthetic PDFs whose font descriptor carries a
TrueType `/FontFile2` stream. They check that the font part bytes are stored
unchanged, that Flate-compressed programs are decoded, and that the page's font
resource references the part hash. Type 1 `/FontFile` and bare CFF programs are
rejected until their outline conversion is ported.

The annotation test builds a page whose `/Annots` names a URI link. It checks
that the page body contains a BDF link command with the annotation rectangle and
target URL. Hidden and no-view annotations are skipped; other appearance
streams are not drawn yet.

The text-state fixtures compare text matrix, line movement, spacing, scaling,
leading, rise and rendering-mode operators against upstream before glyph
output. `generate_text_state_test.go` needs `BDF_PDF_FIXTURES` and
`BDF_REFERENCE_OUTPUT` and runs as `TestCodexPDFTextState` upstream. Text
drawing is checked for simple fonts, composite CID fonts with encoding CMaps,
vertical writing, spacing changes and rendering modes. Embedded Type1/CFF font
programs and Type3 glyph procedures are not yet handled; unsupported text
features fail closed.

The simple-font fixtures compare the Standard, WinAnsi and MacRoman glyph
names and Unicode values, encoding differences, system-font style selection
and width fallback against upstream. Run `generate_simple_encodings.py` against
the upstream checkout for the tables, and `TestCodexPDFSimpleEncoding` and
`TestCodexPDFSimpleFont` using the corresponding Go generators. Embedded,
Type 0 and Type 3 fonts are not yet handled by this internal simple-font path.
