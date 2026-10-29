# MIDI input compatibility fixtures

These fixtures compare detection, RIFF RMID extraction, SMF header timing and
variable-length quantities, track repair boundaries, notes, controls, warnings,
track metadata, text decoding, playback-file repair, and the performance
model and lyric assignment with shibukawa/bdf commit
`4f9af52dca60be1eb0daade39f7dc41d6a1fe431`. They include damaged RIFF
chunks, duplicate metadata, SMPTE divisions, truncated headers and random
inputs. These primitives do not yet implement MIDI-to-BDF notation.

Run `moon build compat/midiinput --target js` and `npm run test:midi-input`.
To regenerate, copy `generate_test.go` without its first two lines to
`converter/midi/codex_input_test.go` in the upstream checkout, then run:

```sh
BDF_FIXTURE_ROOT=/path/to/bdf.mbt go test ./converter/midi -run '^TestCodexMidiInput$' -count=1
```

Track fixtures use `generate_track_test.go` and `TestCodexMidiTrackScan` in
the same way. Generate them first, then use `generate_notes_test.go` and
`TestCodexMidiTrackNotes` for the note and control fixtures. File repair
fixtures use `generate_file_test.go` and `TestCodexMidiFile`; this generator
also needs `generate_test.go` copied into the upstream package. Track metadata
fixtures use `generate_meta_test.go` and `TestCodexMidiTrackMeta`. Text
decoding fixtures use `generate_text_test.go` and `TestCodexMidiText`; credits
and naming fixtures use `generate_credits_test.go` and `TestCodexMidiCredits`.
Performance fixtures use `generate_performance_test.go` and
`TestCodexMidiPerformance`. The latter reads `credits.json`. Lyrics fixtures
use `generate_lyrics_test.go` and `TestCodexMidiLyrics`. Generate the Unicode
letter and script table with `go run compat/midiinput/generate_lyric_scripts.go > convert/midi/lyric_scripts.mbt`
using the upstream Go toolchain. Text and credits
generators require `generate_test.go` in the upstream package.
