# EPUB compatibility fixtures

`basic.epub` is the upstream `converter/epub/testdata` fixture at
shibukawa/bdf `4f9af52dca60be1eb0daade39f7dc41d6a1fe431`
(MIT license, see `licenses/Shibukawa-bdf.txt`).

`convert/epub/fixtures_generated_wbtest.mbt` embeds it for the MoonBit tests.
`compat/converter/phase3-test.mjs` exercises the native Worker. This port
reads the container, package manifest and spine, then lays out reflowable
XHTML chapters in reader mode. Fixed-layout books, remote images, CSS and
embedded fonts are documented gaps.
