# Music notation compatibility fixtures

These fixtures compare musical meter, key estimation, pitch spelling measure timelines, note quantization, clef selection, percussion mapping, note-value division, voice assignment and staff events with
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

Timeline fixtures use `generate_timeline_test.go` and
`TestCodexMusicTimeline` in the same way. Quantization fixtures use
`generate_quantize_test.go` and `TestCodexMusicQuantize`. Staff and percussion
fixtures use `generate_staff_test.go` and `TestCodexMusicStaff`. Note-value
fixtures use `generate_values_test.go` and `TestCodexMusicValues`. Voice
fixtures use `generate_voices_test.go` and `TestCodexMusicVoices`. Staff event
fixtures use `generate_events_test.go` and `TestCodexMusicEvents`.
