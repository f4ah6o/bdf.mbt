# Markdown compatibility fixtures

`basic.md`, `math.md` and `svg.md` are the upstream
`converter/markdown/testdata` fixtures at shibukawa/bdf
`a5e4d7a` (MIT license, see `licenses/Shibukawa-bdf.txt`). They are
read by `convert/markdown/fixtures_generated_wbtest.mbt` and by
`compat/converter/phase11-markdown-test.mjs`.

The converter builds the same CommonMark/GFM structure GitHub uses:
headings, nested ordered/unordered lists and task items, block quotes,
fenced and indented code, tables with alignments, raw HTML (including
data: image tags and their width/height, and anchors), links (fragment
links target the document page; relative links without a base URL are left
out), images
and their alternative text, footnotes, definition lists and YAML/TOML
front matter. Math written as `$...$`, `$$...$$` or a ```math``` fence
is linearized to searchable text with a small LaTeX converter.

`views` selects the views, as upstream does: `scroll` (the default),
`pages` (A4-like pages), or `both`. The scroll view is a 504-point strip
(432 points of text and 36-point margins). The pages view is a `fixed`
view of 504 × 769.9-point pages with the same 432-point text column and
36-point margins; its text index numbers runs with `a` set to the
0-based page index. A table taller than a page splits between rows, repeats
its header row on each page and keeps row borders on both pages; block-quote
bars are drawn per line, so they repeat on every page a quote spans. `both`
emits the pages view first and the unchanged scroll view second.

## Images and inline SVG

A Markdown image is drawn when its source is a `data:` URL: PNG, GIF,
JPEG, WebP and SVG data URLs are recognised, and the alternative text is
left out of the text layer (upstream draws the image, not its description).
Relative and remote references are not fetched, because the converter has
no document directory or fetcher; they contribute their alternative text
and one warning per address. Raw HTML `<img>` elements contribute their
alternative text and a warning too.

Inline `<svg>` elements are turned into SVG image parts at their position
in the text. Their size comes from the `width` and `height` attributes
(and inline style), following the view box when one is missing; an SVG with
only a view box fills the text column, and CSS pixels become points at
0.75 points per pixel. A sprite sheet (`display:none`, or an element that
holds only `symbol`, `defs`, gradients and other definitions) is not
drawn: its definitions are copied into the `<defs>` of every SVG that may
reference them, so a `<use href="#dot">` or `fill="url(#bar)"` resolves.
The SVG bytes are content-hashed into `img` parts, as upstream stores
them. The svg.md fixture therefore yields two `img` parts (the chart and
the symbol) while the relative badge and check files keep their
"Passing"/"Done" alternative text and warnings, exactly as upstream does
when it has no directory to resolve them in.

## Tests and remaining integration

`phase11-markdown-test.mjs` compares the view kind/id/width, summary,
warnings, image parts and text index with upstream's scroll view (whitespace
is normalized and at least 88% text similarity is required because line
breaks use estimated metrics). It also asserts the two inline SVG image
parts of `svg.md`.

The browser native converter Worker does not forward `views` yet (its
Markdown call in `browser/native_converter_worker.mbt` passes only title,
size, width, font and mono). The mapping needed there is one line:

```moonbit
views=native_converter_param(request, "views"),
```

That file is outside this package, so the pages/both integration is
covered by `convert/markdown/markdown_wbtest.mbt`; the Worker keeps
producing the default scroll view until the parameter is wired.

Remote image fetching, a document directory / `base` URL, and exact
upstream line metrics for inline images remain documented gaps.
