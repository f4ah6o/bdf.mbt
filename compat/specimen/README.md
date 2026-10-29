# Font specimen program compatibility

These fixtures record glyph programs and whole and pruned sample programs from
shibukawa/bdf at commit `4f9af52dca60be1eb0daade39f7dc41d6a1fe431`. TrueType,
CFF, TTC, WOFF, color, variable and malformed bitmap-strike cases are included.
The pruned cases use the glyph reachability set computed by upstream's GSUB
parser, which has not yet been ported. Program sizes and SHA-256 hashes are
compared with upstream; representative glyph programs are also rendered and
compared with vlmkit.

After `moon build --target js`, run `npm run test:specimen` and
`npm run test:specimen-visual`. To regenerate, copy `generate_test.go` without
its first `//go:build ignore` line into the upstream checkout at
`converter/font/codex_specimen_test.go`, then run:

```sh
BDF_FIXTURE_ROOT=/path/to/bdf.mbt go test ./converter/font -run '^TestCodexGlyphPrograms$' -count=1
```

The test writes `compat/specimen/upstream.json.gz` in the target repository.
