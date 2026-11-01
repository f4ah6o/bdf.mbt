# HTML compatibility fixtures

`article.html` is the upstream `converter/html/testdata` fixture at
shibukawa/bdf `4f9af52dca60be1eb0daade39f7dc41d6a1fe431`
(MIT license, see `licenses/Shibukawa-bdf.txt`).

`convert/html/fixtures_generated_wbtest.mbt` embeds it for the MoonBit tests.
This port keeps the reader-mode text, headings, lists, code, quotes and table
text. Readability article extraction, CSS, remote images, MHTML and embedded
fonts are documented gaps.
