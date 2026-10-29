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

`encode.json.gz` records SFNT inputs and normalized expected tables for the
encoder. Copy `generate-encode_test.go` without its build tag into upstream
`font/woff2` and run `TestCodexWOFF2EncodeInputs` to regenerate it. After a JS
build, `npm run test:woff2-encode` checks the decoded tables and Chromium font
rendering, and writes encoded files under `_build/woff2-encoded`. To verify
them with the upstream Go decoder, copy `verify-encode_test.go` without its
build tag into upstream `font/woff2` and run `TestCodexExternalWOFF2Encoding`
with the same fixture root. The MoonBit encoder uses its own Brotli stream and
the standard null glyf transform, so its compressed bytes differ from Go.
