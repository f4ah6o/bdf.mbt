# MML input compatibility fixtures

The fixtures compare MML detection, dialect classification, syntax recognition,
and text decoding against upstream `converter/mml`.

After building the JavaScript target, run `npm run test:mml-input`. To regenerate
fixtures, copy `generate_detect_test.go` and `generate_decode_test.go` without
their build tags into upstream `converter/mml`, then run `TestCodexMMLDetect`
and `TestCodexMMLDecode` with `BDF_FIXTURE_ROOT` set to this repository.
