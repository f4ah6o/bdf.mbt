# Interactive text fixture

`fixture.bdf` was generated with `generate.go` using
[shibukawa/bdf v0.2.1](https://github.com/shibukawa/bdf/tree/v0.2.1).
It contains multiple pages and layers, selectable text, headings, a table, a
figure, an internal link, and an unsafe URL that must not become a link.

The visual test compares the upstream renderer and text layer with the MoonBit
interactive mount using `vlmkit`; Playwright checks semantic roles, run
positions, keyboard activation, partial and cross-page selection, merged-cell selection, oversized-range fallback, TSV/HTML clipboard serialization, and font cleanup. Selected-cell screenshots are compared against upstream in three viewports. Split and encrypted interactive mounts are
also exercised using the visual fixtures.

To regenerate from the upstream checkout:

```sh
go run /absolute/path/to/bdf.mbt/compat/interactive/generate.go /absolute/path/to/bdf.mbt/compat/interactive/fixture.bdf
```
