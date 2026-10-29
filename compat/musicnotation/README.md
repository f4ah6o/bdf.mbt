# Music notation compatibility fixtures

These fixtures compare musical meter, key estimation and pitch spelling with
shibukawa/bdf commit `4f9af52dca60be1eb0daade39f7dc41d6a1fe431`.
They exercise all key signatures, negative and positive pitch numbers,
spelling hints and deterministic duration histograms.

Run `moon build compat/musicnotation --target js` and
`npm run test:music-notation`. To regenerate, copy `generate_test.go` without
its first two lines to `converter/internal/music/codex_key_test.go` in the
upstream checkout, then run:

```sh
BDF_FIXTURE_ROOT=/path/to/bdf.mbt go test ./converter/internal/music -run '^TestCodexMusicKeys$' -count=1
```
