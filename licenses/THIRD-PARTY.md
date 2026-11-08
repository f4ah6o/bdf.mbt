# Third-party assets

Every asset in this repository that is not original bdf.mbt work, with its origin, licence, and what we changed. The published site carries the same list on `/docs/licenses.html`, with full licence texts in `site/licenses/`.

| Asset | Origin | Licence | What we changed |
| --- | --- | --- | --- |
| `docs/*.ja.md` text, shipped as `site/docs-src/*.md` and rendered to `_build/pages/docs/` | [shibukawa/bdf](https://github.com/shibukawa/bdf) `docs/*.ja.md`, pinned by `site/docs-src/UPSTREAM-COMMIT` | MIT (`licenses/Shibukawa-bdf.txt`) | Japanese text kept; each page names its source and carries short "bdf.mbt では" notes where bdf.mbt differs; links to pages this site drops point at the upstream pages |
| `site/docs-src/images/` — the 2 image files the shipped pages reference | shibukawa/bdf `docs/images/` | MIT | Unchanged |
| `site/assets/site.css` | shibukawa/bdf `site/site.css` | MIT | bdf.mbt additions appended at the end; upstream rules untouched |
| Thumbnail geometry rules (auto/crop/sheet mode, square crop from the top-left, size clamp) | shibukawa/bdf `thumbnail/thumbnail.go` | MIT | Re-expressed as browser JavaScript in `site/assets/thumbnail.js` on top of bdf.mbt's renderer |
| `minisearch/` — the dist files the published site serves | [lucaong/minisearch](https://github.com/lucaong/minisearch) | MIT (`licenses/MiniSearch-MIT.txt`) | Copied as built |
| `marked` | [markedjs/marked](https://github.com/markedjs/marked) | MIT | Build-time only: `site/docs.mjs` turns Markdown into HTML with it. It is not part of the published artifact |
| Playwright | [microsoft/playwright](https://github.com/microsoft/playwright) | Apache-2.0 (`licenses/Apache-2.0.txt`) | Site tests and the benchmark harness; not distributed |
| Fonts embedded inside `site/samples/` documents (Liberation, IPAex, WenQuanYi, STIX Two Math, Bravura) | Upstream's test documents and published test PDFs | OFL 1.1, IPA font licence, GPL v2 + font exception (texts in `site/licenses/`) | Present only as parts of the sample documents; not installed or served as fonts |
| Algorithm ports from Go sources (image, text, encoding, CMaps, Cephes maths) | Repos named in `licenses/Go-x-image.txt`, `Go-x-text.txt`, `WHATWG-Encoding.txt`, `Adobe-CMap.txt`, `Cephes.txt` | As stated in each file | Ported to MoonBit with coverage recorded in `docs/port-status.md` |
| Upstream's Go WASM builds (`lib/bdf-*.wasm`), their `wasm_exec.js` runtime, and `fonts/` | shibukawa/bdf | MIT | **Not used and not shipped.** Every conversion and every drawing on the published site is bdf.mbt (MoonBit compiled to JavaScript or wasm-gc), so the Emscripten notice upstream attaches to its Go WASM runtime has no counterpart here |
