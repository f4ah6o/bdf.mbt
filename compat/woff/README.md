# WOFF compatibility fixtures

The fixtures compare WOFF 1.0 decoding with shibukawa/bdf at commit
`4f9af52dca60be1eb0daade39f7dc41d6a1fe431`. They cover compressed and
uncompressed tables from TrueType and CFF fonts, invalid headers, zlib errors,
large table directories, and reproducibly mutated containers. Successful
results are compared byte for byte with upstream's reconstructed SFNT.

After `moon build --target js`, run `npm run test:woff-compat`. To regenerate,
copy `generate_test.go` into `converter/font/codex_woff_test.go` in an upstream
checkout without its first `//go:build ignore` line, then run:

```sh
BDF_FIXTURE_ROOT=/path/to/bdf.mbt go test ./converter/font -run '^TestCodexWOFFFixtures$' -count=1
```

The test writes `compat/woff/upstream.json` into the repository named by
`BDF_FIXTURE_ROOT`.
