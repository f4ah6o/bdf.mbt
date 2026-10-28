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
