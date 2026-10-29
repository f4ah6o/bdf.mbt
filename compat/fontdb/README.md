# Font database compatibility fixtures

`upstream.json` records font selection, family normalization, math selection,
per-character fallback, and complete CSV documents from shibukawa/bdf at commit
`4f9af52dca60be1eb0daade39f7dc41d6a1fe431`. The generated synthetic fonts use
the STIX fixture already in `compat/font/fixtures` and cover different families,
weights, styles, glyph coverage and line metrics. Conversion cases cover
whole-font embedding, subsetting, system-font references and missing fonts.

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
