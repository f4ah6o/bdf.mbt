# Music compatibility fixtures

The BDF files in `fixtures/` are copied from `testdata/music/` in
[shibukawa/bdf](https://github.com/shibukawa/bdf) at commit `4f9af52`
(MIT). They cover MML, MusicXML, compressed MusicXML and karaoke inputs.
`verify.mjs` compares their stored MIDI and cues and hundreds of generated,
truncated and malformed MIDI inputs against `@bdfkit/core` and
`@bdfkit/render` 0.2.1. Both MoonBit targets also run the native unit tests.

`piano-test.mjs` compares the rendered piano-roll pixels, geometry, labels and
zoom behavior with the upstream viewer, and checks lazy split loading and
stale asynchronous renders. The visual workflow also uses vlmkit at three
viewport widths.

`audio-test.mjs` compares recording playback controls, events, errors, speed,
and cue behavior with the upstream player. `audio-browser-test.mjs` mounts
single and split recordings on page and sheet views, plays a synthetic WAV in
Chromium, and verifies lazy loading and resource cleanup.

`player-test.mjs` compares the MIDI transport, controller state, timing,
metronome, all 128 instrument programs, drum sounds and voice limit with the
upstream player. `player-browser-test.mjs` compares synthesized Web Audio
samples and tests playback and resource cleanup in page and sheet views.
