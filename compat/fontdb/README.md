# Font database compatibility fixtures

`upstream.json` records font selection, family normalization, math selection,
per-character fallback, and complete CSV documents from shibukawa/bdf at commit
`4f9af52dca60be1eb0daade39f7dc41d6a1fe431`. The generated synthetic fonts use
the STIX fixture already in `compat/font/fixtures` and cover different families,
weights, styles, glyph coverage and line metrics. Conversion cases cover
whole-font embedding, subsetting, system-font references and missing fonts.
`order.json` checks embedded-font order with unequal-length and non-ASCII paths.

After building with `moon build --target js`, run `npm run test:fontdb-compat`
and `npm run test:fontdb-visual`. The latter renders the upstream and MoonBit
BDF documents and uses vlmkit to compare the resulting pixels.
To regenerate the fixture, copy `generate.go` to
`converter/codex-fontdb-oracle/main.go` in an upstream checkout, and run it
from that checkout with this repository's absolute path as its argument,
redirecting stdout to `compat/fontdb/upstream.json`. For example:

```sh
go run ./converter/codex-fontdb-oracle/main.go /path/to/bdf.mbt > /path/to/bdf.mbt/compat/fontdb/upstream.json
```

The Go file must reside under `converter` to access upstream internal packages.
Regenerate the resolution tables with `python3 compat/fontdb/generate-rules.py
<upstream-checkout> font/db/rules_generated.mbt`, then run `moon fmt`.

`npm run test:native-fonts` also exercises the native browser Worker with an
HTTP font directory. To compare the Worker directly with the upstream Wasm
converter, build upstream with `GOOS=js GOARCH=wasm go build -tags
'bdf_noconv officeonly' -o /path/to/upstream.wasm ./cmd/bdfwasm`, then set
`BDF_UPSTREAM_WASM` to that file and `BDF_GO_EXEC` to the matching Go toolchain's
`lib/wasm/wasm_exec.js` before running the test.

To regenerate the ordering fixture, copy `generate-order.go` without its build
tag into `converter/codex-fontorder/main.go` in the upstream checkout, then run
`go run ./converter/codex-fontorder /path/to/bdf.mbt > /path/to/bdf.mbt/compat/fontdb/order.json`.
The original `upstream.json` must already exist.

`compressed.json` covers WOFF2 embedding for the same multi-font CSV cases.
To regenerate it, copy `generate-compressed.go` without its build tag to
upstream `converter/codex-fontdb-oracle/main.go`, then run the command above
with stdout redirected to `compat/fontdb/compressed.json`. After a JS build,
`npm run test:csv-font-compressed` checks both multi- and single-font conversion;
`npm run test:csv-font-compressed-visual` compares rendered pages with vlmkit.
