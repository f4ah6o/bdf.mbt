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
