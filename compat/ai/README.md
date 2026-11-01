# Illustrator compatibility fixtures

`convert/ai` exposes `detect` and `convert`. The fixtures are the upstream
`converter/ai/testdata` files at shibukawa/bdf `4f9af52dca60be1eb0daade39f7dc41d6a1fe431`
(MIT license, see `licenses/Shibukawa-bdf.txt`).

`convert/ai/fixtures_generated_wbtest.mbt` embeds the three files and the
MoonBit tests cover PDF artboard conversion, PostScript rejection and the
no-PDF-content placeholder error.

`compat/converter/phase1-test.mjs` converts the fixtures through the upstream
`@bdfkit/convert-all` Wasm and the MoonBit native Worker, and compares page
counts and page geometry. Illustrator 8 and earlier (PostScript) and files
saved without PDF content fail explicitly.
