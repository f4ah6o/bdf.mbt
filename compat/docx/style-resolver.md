# DOCX style resolver fixtures

`generate_style_resolver_test.go` compares the private resolver with upstream
`wordproc.loadStyles`, `paraProps` and `runProps`. Synthetic styles cover
property precedence, defaults and fallback, duplicate IDs, missing styles,
cycles, the 32-style limit, character-style toggle XOR, fonts, language,
paragraph spacing and tab stops. A separate test checks that copied run
properties do not share mutable arrays.

To regenerate, copy the Go file without its build tag into upstream's
`converter/internal/wordproc`, set `BDF_REFERENCE_OUTPUT` to
`convert/docx/style_resolver_generated_wbtest.mbt`, and run
`TestCodexDOCXStyleResolver`. Run the MoonBit tests on JavaScript and wasm-gc.

Only the already supported paragraph and run properties can be resolved.
Unsupported properties in an applied style are rejected; unused style
properties are not applied. Numbering, table-style layers, theme colors,
style-driven text rendering and document layout remain unsupported. The
DOCX document-text reader uses the resolver and retains supported properties;
it still rejects settings, numbering and unsupported formatting.
