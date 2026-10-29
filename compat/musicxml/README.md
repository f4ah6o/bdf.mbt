# MusicXML input compatibility fixtures

These fixtures compare text detection, UTF-16 byte-order recognition, XML
encoding declarations and text repair against upstream `converter/musicxml`.
After building the JavaScript target, run `npm run test:musicxml-input`.

To regenerate the fixtures, copy each `generate_*_test.go` without its build tag
into upstream `converter/musicxml` and run the corresponding `TestCodexMusicXML*`
test with `BDF_FIXTURE_ROOT` set to this repository.
