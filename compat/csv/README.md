# CSV compatibility fixtures

The JSON fixtures are generated with `converter/csv.Records` from
`shibukawa/bdf` at commit `4f9af52`. They cover the upstream CSV test files,
character encodings, BOM precedence, dialect and header detection, and
deterministic malformed inputs. `pairs.json` contains Go-generated SHA-256
digests of decoder output for every two-byte sequence in the listed encodings,
EUC-JP triples, ISO-2022-JP states, GB18030 ranges, and every byte in the
single-byte encodings. Each output is prefixed with its four-byte big-endian
length before hashing.

To regenerate both files from the pinned upstream checkout, run:

```sh
go run /path/to/bdf.mbt/compat/csv/generate.go > /path/to/bdf.mbt/compat/csv/upstream.json
go run /path/to/bdf.mbt/compat/csv/generate-pairs.go > /path/to/bdf.mbt/compat/csv/pairs.json
cp /path/to/bdf.mbt/compat/csv/generate-table_test.go converter/csv/
BDF_CSV_TABLE_FIXTURE=/path/to/bdf.mbt/compat/csv/table.json go test ./converter/csv -run '^TestGenerateTableFixture$' -count=1
go run /path/to/bdf.mbt/compat/csv/generate-convert.go > /path/to/bdf.mbt/compat/csv/conversion.json
cp /path/to/bdf.mbt/compat/csv/generate-detect_test.go converter/csv/
BDF_CSV_DETECT_FIXTURE=/path/to/bdf.mbt/compat/csv/detect.json go test ./converter/csv -run '^TestCodexGenerateDetection$' -count=1
```

After `moon build --target js`, run `npm run test:csv-compat` in this module.
`npm run test:csv-visual` compares the rendered upstream and MoonBit documents
with vlmkit and checks the reference is not blank. The page keeps a
`visual-wait` request open until its asynchronous conversion and rendering have
finished, so vlmkit's `networkidle` capture cannot screenshot a blank page;
`visual-barrier-test.mjs` proves the wait under an artificial render delay and
checks that a failed wait aborts before any capture work.
