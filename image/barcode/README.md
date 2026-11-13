# Barcode: Code 39 subset

This package currently implements **Code 39 only**, as a first slice of
upstream `image/barcode`. `encode` returns a linear symbol with `text`,
`width`, `height`, `at`, and `rects` accessors. `path` and `object` create a
scalable BDF drawing; the bounds include the quiet zone. Other symbologies,
barcode MARK metadata, the PNG/TIFF row writer, and use by `form/pdfme` are
not implemented here. The PDFMe barcode path and its input rules are unchanged.

`quiet=0` uses ten quiet modules at each side, a negative value omits the
quiet zone, and a positive value is capped at 64. An optional leading or
trailing `*` is treated as a start/stop marker; an empty payload or an internal
`*` is invalid. Payloads are case-sensitive: lowercase and non-ASCII inputs are
rejected, as is text exceeding 8192 UTF-8 bytes. No optional Code 39 check
character (Mod-43) is added or verified; supplied data characters are encoded
unchanged. Symbology names are normalized incrementally, without
allocating a copy proportional to the input length.

Drawing coordinates and dimensions must be finite; negative dimensions are
rejected (upstream permits them), while zero dimensions produce a degenerate
object. A positive width is rejected if float32 division underflows the module
width to zero, avoiding an invisible drawing.

The object contains black vector bars over a transparent background. It adds
no readable text or font, but **the bars encode the payload and can be
decoded**. Treat generated BDF data according to the sensitivity of the input.

Code 39 framing and pattern tables are adapted from
[`shibukawa/bdf` at `a5e4d7a6`](https://github.com/shibukawa/bdf/tree/a5e4d7a6b202cfe73de44b0be51f6fb86cd8ee22/image/barcode),
under the MIT license reproduced in `licenses/Shibukawa-bdf.txt`.
