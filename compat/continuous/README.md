# Continuous and scroll fixtures

The flow fixture has three pages with body rectangles, a fractional gap,
RTL direction, background/body/annotation layers, and unbounded drawing that
must be clipped. The scroll fixture contains three differently sized strips.
Both are generated with shibukawa/bdf v0.2.1, including split and encrypted
variants.

The browser tests compare continuous regions with upstream `PageRenderer`,
including cropped bodies, transparent gaps, overlapping bands, viewport
offsets and scaling. They also compare scroll-strip and RTL spread positions
with the upstream `Viewer`, and verify scrolling, search, encrypted mounts,
resource loading, per-object drawing state and invalid viewport handling. `vlmkit` checks the rendered
fixtures at three viewport widths and scans the scroll container.

`svg.bdf` exercises a viewBox-only SVG drawn as a full image, a cropped
source rectangle and a transformed repeating pattern. The controls test
compares all three against upstream across zooms and device pixel ratios.

From an upstream checkout, regenerate with absolute paths:

```sh
go run /absolute/path/to/bdf.mbt/compat/continuous/generate.go /absolute/path/to/bdf.mbt/compat/continuous/flow.bdf /absolute/path/to/bdf.mbt/compat/continuous/flow-split /absolute/path/to/bdf.mbt/compat/continuous/scroll.bdf /absolute/path/to/bdf.mbt/compat/continuous/scroll-split /absolute/path/to/bdf.mbt/compat/continuous/scroll-encrypted.bdf /absolute/path/to/bdf.mbt/compat/continuous/scroll-encrypted-split /absolute/path/to/bdf.mbt/compat/continuous/flow-encrypted.bdf /absolute/path/to/bdf.mbt/compat/continuous/flow-encrypted-split
go run /absolute/path/to/bdf.mbt/compat/continuous/generate_svg.go /absolute/path/to/bdf.mbt/compat/continuous/svg.bdf
```
