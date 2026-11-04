# Markdown compatibility fixtures

`basic.md`, `math.md` and `svg.md` are the upstream
`converter/markdown/testdata` fixtures at shibukawa/bdf
`a5e4d7a` (MIT license, see `licenses/Shibukawa-bdf.txt`). They are
read by `convert/markdown/fixtures_generated_wbtest.mbt` and by
`compat/converter/phase11-markdown-test.mjs`.

The converter builds a scroll view from the same CommonMark/GFM rules GitHub
uses: headings, nested ordered/unordered lists and task items, block quotes,
fenced and indented code, tables with alignments, raw HTML, links, images and
their alternative text, footnotes, definition lists and YAML/TOML front
matter. Math written as `$...$`, `$$...$$` or a ```math``` fence is
linearized to searchable text with a small LaTeX converter.

The test compares the view kind, id, width, summary and text index against the
upstream converter. Exact line breaks and spacing can differ because the
MoonBit layout uses estimated font metrics; the comparison normalizes
whitespace and requires at least 88% text similarity. Images are drawn only
when they are embedded as data URIs; relative and remote images contribute
their alternative text and a warning, matching the upstream no-directory case.
