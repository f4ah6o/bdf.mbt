# MML compatibility fixtures

These fixtures compare detection, text decoding, preprocessing, command
scanning, playback, and complete score and TAB documents against upstream
`converter/mml` and `converter/internal/music`.

After building the JavaScript target, run `npm run test:mml-input` and
`npm run test:mml-document`, and `npm run test:mml-visual`. To regenerate fixtures, copy each
`generate_*_test.go` without its build tag into upstream `converter/mml` and
run the corresponding `TestCodexMML*` test with `BDF_FIXTURE_ROOT` set to this
repository. Generate the playback fixtures before the document fixtures.
