# WOFF2 decoding compatibility fixtures

These fixtures compare the MoonBit WOFF2 decoder with shibukawa/bdf commit
`4f9af52dca60be1eb0daade39f7dc41d6a1fe431`. They include TrueType and CFF
fonts, transformed outlines and horizontal metrics, bounded overlong streams,
truncation, malformed directories and reproducibly mutated data. Valid decoded
SFNTs are compared byte for byte.

Run `moon build --target js` followed by `npm run test:woff2-compat` and
`npm run test:native-woff2`. To regenerate the fixtures, copy
`generate_test.go` without its first `//go:build ignore` line into upstream
`font/woff2/codex_decode_test.go`, then run:

```sh
BDF_FIXTURE_ROOT=/path/to/bdf.mbt go test ./font/woff2 -run '^TestCodexWOFF2Decode$' -count=1
```

The upstream checkout must include its WOFF2 test files and Brotli encoder. The
fixture generator writes `compat/woff2/upstream.json.gz` in the target repo.
