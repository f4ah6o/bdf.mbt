# Audio compatibility fixtures

Fixtures are the upstream `converter/audio/testdata` tagged files at
shibukawa/bdf `4f9af52dca60be1eb0daade39f7dc41d6a1fe431`
(MIT license, see `licenses/Shibukawa-bdf.txt`): `tagged.mp3`, `tagged.wav`,
`tagged.flac`, `japanese.mp3` and `plain.aac`.

`convert/audio/fixtures_generated_wbtest.mbt` embeds them for the MoonBit
tests. `compat/converter/phase4-test.mjs` exercises the native Worker. This
port reads ID3v2/ID3v1, RIFF INFO and ID3 chunks, AIFF text and ID3 chunks,
FLAC Vorbis comments and pictures, Ogg Vorbis/Opus comments, WAV/AIFF/FLAC
durations, and MP4 `mvhd` duration. MP4/iTunes tags and cover art, Ogg
duration, synchronized lyrics, chapters and DRM handling are documented gaps.
