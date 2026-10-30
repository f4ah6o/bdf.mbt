# PDF compatibility fixtures

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
