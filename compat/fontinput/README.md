# Font input compatibility fixtures

These fixtures record upstream font detection, file loading and collection
selection at shibukawa/bdf commit `4f9af52dca60be1eb0daade39f7dc41d6a1fe431`.
They include SFNT, TTC, WOFF, malformed WOFF2 directories and selection
limits. WOFF2 errors use upstream's `bdf_noconv` build, which omits Brotli.

Run `moon build --target js` and `npm run test:font-input`. To regenerate, copy
`generate_test.go` without its first `//go:build ignore` line to
`converter/font/codex_input_test.go` in the upstream checkout, then run:

```sh
BDF_FIXTURE_ROOT=/path/to/bdf.mbt go test -tags bdf_noconv ./converter/font -run '^TestCodexFontInput$' -count=1
```

The fixture generator reads the font and WOFF fixtures in the target repository
and writes its `compat/fontinput/upstream.json`.
