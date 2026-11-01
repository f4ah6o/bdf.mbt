# Markdown compatibility fixtures

`basic.md` is the upstream `converter/markdown/testdata` fixture at
shibukawa/bdf `4f9af52dca60be1eb0daade39f7dc41d6a1fe431`
(MIT license, see `licenses/Shibukawa-bdf.txt`).

`convert/markdown/fixtures_generated_wbtest.mbt` embeds it for the MoonBit
tests. This port reads front matter, headings, paragraphs, lists, task lists,
fenced code, quotes, rules, simple tables and inline links/images as reader
text. CommonMark/GFM edge cases, raw HTML layout, images and embedded fonts are
documented gaps.
