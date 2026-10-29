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
```

After `moon build --target js`, run `npm run test:csv-compat` in this module.
