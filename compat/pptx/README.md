# PPTX compatibility fixtures

These fixtures compare presentation-part discovery, slide order, visibility,
slide dimensions and first-slide numbering with the upstream Go converter.
They use six upstream `converter/pptx/testdata` presentations and a generated
package with a custom main part, strict relationship namespace, hidden slide,
missing relationship and universal-measure units. To regenerate, copy
`generate_manifest_test.go` without its build tag into upstream `converter/pptx`,
set `BDF_PPTX_FIXTURES` to its testdata directory and `BDF_REFERENCE_OUTPUT`
to the generated MoonBit test file, and run `TestCodexPPTXManifest`. Run
`moon fmt convert/pptx` afterward. Both JavaScript and wasm-gc execute the
same expectations.

The presentation reader is an internal building block, not a PPTX converter.
