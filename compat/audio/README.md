# Audio compatibility fixtures

Fixtures are the upstream `converter/audio/testdata` files at
shibukawa/bdf `4f9af52dca60be1eb0daade39f7dc41d6a1fe431`
(MIT license, see `licenses/Shibukawa-bdf.txt`): `japanese.mp3`,
`lrc.flac`, `plain.aac`, `synced.mp3`, `tagged.aiff`, `tagged.flac`,
`tagged.m4a`, `tagged.mp3`, `tagged.ogg`, `tagged.opus` and `tagged.wav`.

`convert/audio/fixtures_generated_wbtest.mbt` embeds them for the MoonBit
tests. `compat/converter/phase4-test.mjs` exercises the native Worker. This
port reads ID3v2/ID3v1 (multi-value text, SYLT synchronized lyrics, CHAP
chapters and APIC covers), RIFF INFO and ID3 chunks, AIFF text and ID3
chunks with the 80-bit sample rate, FLAC Vorbis comments and pictures, Ogg
Vorbis/Opus comments (including METADATA_BLOCK_PICTURE covers) and granule
durations, and MP4/iTunes metadata, cover art, chapters, language, sample
entry and duration. ID3v2.2 tags, compressed/unsynchronised ID3 frames,
QuickTime `chpl` v1 chapters, Ogg FLAC/Speex and DRM handling remain
documented gaps.
