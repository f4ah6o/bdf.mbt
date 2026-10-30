# Browser demo

The demo displays the upstream BDF project's 20-page homepage document. The
sample was generated once from `site/demo/demo.pdf` at upstream commit
`4f9af52dca60be1eb0daade39f7dc41d6a1fe431` with:

```sh
go run ./cmd/bdf generate -q site/demo/demo.pdf upstream-demo.bdf
```

The checked-in sample has SHA-256
`e1cab46517eb3f0b1a4f2aeb4a5d0037e99161c4a1b77017f0c0903439608deb`.
The PDF is converted ahead of time. Rendering and CSV, XLSX, image, and font
specimen conversion in the demo use the
MoonBit JavaScript target, without a Go or WebAssembly runtime. Files chosen
by the user are handled in the browser. The sample contains Liberation fonts
([OFL](licenses/Liberation.txt)), IPA Gothic ([IPA Font License](licenses/IPA.txt)),
and WenQuanYi Zen Hei ([GPLv2](licenses/WenQuanYi.txt), with the font embedding
exception and copyright notice in its [README](licenses/WenQuanYi-README.txt)).
The STIX Two Text sample is from the existing `compat/font/fixtures/stix.ttf`
fixture; copyright and SIL Open Font License 1.1 terms are included in
[STIX-OFL.txt](licenses/STIX-OFL.txt). The demo tests TTF and WOFF2 input.
The upstream project and demo source are distributed under the
[MIT license](licenses/BDF-MIT.txt).

Build and test locally:

```sh
moon update
npm ci
npx playwright install chromium
npm run build:demo
npm run test:demo
python3 -m http.server --directory _build/pages 8000
```

The test serves the site under `/bdf.mbt/`, exercises all sample pages,
search, navigation, downloading, CSV and SVG conversion, TTF and WOFF2 font
specimens, view selection and saving, unsupported files,
and mobile layout. It requires Playwright Chromium. Run the `vlmkit` gates
against the served URL for markup and accessibility checks.

The `Demo pages` workflow builds and tests the site on pushes to `main` and
on manual runs. It deploys only if the repository's Pages source is already
set to **GitHub Actions** and the `github-pages` environment already exists.
It uses that environment and its protection rules without changing repository
settings or creating an environment. If Pages is disabled, an administrator can choose **Settings →
Pages → Build and deployment → Source → GitHub Actions**, then run the workflow
again from the Actions tab. GitHub reports the resulting site URL in the
workflow's deployment step. The expected default project URL is
`https://f4ah6o.github.io/bdf.mbt/`.

The two-sheet `samples/sales.xlsx` is an original synthetic workbook generated
by `python3 demo/generate-xlsx-sample.py`, distributed under this repository’s
[project MIT license](licenses/PROJECT-MIT.txt). The demo converts the supported
XLSX subset without embedded fonts.
