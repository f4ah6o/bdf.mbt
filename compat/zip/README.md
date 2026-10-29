# ZIP compatibility fixtures

These fixtures compare central-directory entries and verified contents with
Go's ZIP reader. They include stored and deflated entries, data descriptors,
ZIP64 directory records, self-extracting prefixes, malformed archives and an
actual `.mxl` file.

After building the JavaScript target, run `npm run test:zip-input`. To
regenerate the fixture, copy `generate_test.go` without its build tag into
upstream `converter/musicxml`, then run `TestCodexZIP` with `BDF_FIXTURE_ROOT`
set to this repository.
