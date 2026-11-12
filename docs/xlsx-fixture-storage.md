# XLSX fixture storage measurements and migration

This records the measurements that chose the current storage format for
`compat/xlsx` fixtures, the decision, and the migration evidence, per
`issues/open/20261112-xlsx-fixture-size.md`. Re-measure any time with:

```
node compat/xlsx/tools/measure-fixtures.mjs           # readable report
node compat/xlsx/tools/measure-fixtures.mjs --json out.json
node compat/xlsx/tools/measure-fixtures.mjs --quick    # skip compression passes
```

## Environment

- Commit measured (baseline): `74f8e0bb` on top of the requested base
  `e02e4e02`; between the two commits the fixture JSON files are byte-identical
  (only tooling under `compat/xlsx/tools/` was added).
- Machine: Linux ms-01-alpha, 12th Gen Intel Core i9-12900H; node v26.13.1.
  The machine carried unrelated concurrent load during the baseline timing
  runs, so wall times are indicative, not isolated benchmarks.
- Commands and raw outputs: `compat/xlsx/tools/measure-fixtures.mjs` as
  above; timing with `/usr/bin/time -v`. The full baseline JSON is stored
  alongside this migration's working notes as `baseline-measurements.json`.

## Baseline (all 803 fixture files: 792 top-level + 11 render chunks)

- On-disk JSON: **740,302,006 bytes (706.007 MiB)**; `du -s compat/xlsx` =
  714 MiB with filesystem block overhead.
- 316,365 cases; 217,245 canonical-base64 values with at least 128 characters
  and 1024 decoded bytes ("blob candidates"), **412.655 MiB decoded**.
- Duplication: intra-file dedup 352.469 MiB; across all files **155,240
  distinct blobs (326.944 MiB)** — the base64 bytes were referenced 1.34x
  on average.
- Representative fixtures (case-level, no size threshold):
  `conditional-top.json` 257 cases / 153 distinct inputs / 43 distinct expected
  BDFs; `simple-picture.json` 48 / 48 / 48. Only 1 of conditional-top's 43
  distinct BDFs and 16 of simple-picture's 48 inputs pass the 1024-byte blob
  threshold; the format keeps small values inline by design.

## Storage alternatives measured

| id | scheme | MiB | % of current |
| --- | --- | ---: | ---: |
| a | current JSON (base64 inline) | 706.0 | 100.0% |
| b | gzip each JSON file | 207.5 | 29.4% |
| c | binary blobs, dedup within file + inline JSON | 523.3 | 74.1% |
| d | binary blobs, dedup across all files + inline JSON | 497.8 | 70.5% |
| e | d + gzip each distinct blob | 410.7 | 58.2% |
| f | d + brotli each distinct blob | 396.6 | 56.2% |
| g | all distinct blobs concatenated, one gzip + inline JSON | 280.8 | 39.8% |

## Decision and tradeoffs

Chosen: content-addressed blob store - option d, with one shared gzip stream
per 256 hash-prefix groups (between d/e and g), plus manifests keeping every
case, option, warning and label inline.

- 706.0 MiB -> ~188 MiB of file bytes as measured below (26.6%), `du`
  714 MiB -> 334 MiB, a 53% working-tree reduction.
- Against (b) whole-file gzip: (b) is smaller (207 MiB) but every verification
  run must decompress tens of MiB before seeing any case, fixture diffs
  become binary noise, and the duplication that makes (b) small is exactly
  what content addressing removes for free.
- Against (e)/(f) per-blob compression: measured (g) showed that the shared
  gzip context across adjacent expected BDFs compresses the same blobs
  noticeably better than per-blob streams; prefix group packs keep ~93% of
  that advantage (142.4 MiB, measured after packing) while keeping random
  access and 256-file granularity.
- Against (g) one giant pack: one file changed on every fixture regeneration,
  partial rebuilds become impossible, and the whole 124 MiB stream is in
  memory before any case is verifiable. The prefix groups cost ~19 MiB more
  and avoid all three.
- Against regeneration on demand: the Go generators exist
  (`compat/xlsx/generate_*_test.go`, run inside upstream `converter/xlsx`
  with `BDF_FIXTURE_ROOT`), but deterministic regeneration was not provable
  in this repository: it would need the upstream Go commit, toolchain and
  testdata fixed and byte-compared against the stored cases. The issue
  explicitly forbids treating a fixed seed as proof. Storage keeps the bytes;
  the generators remain the way new fixtures are produced, and
  `pack-fixtures.mjs` ingests their plain output.
- Store split: the first experiment (155,240 individual blob files) measured
  810 MiB `du` - worse than baseline - because the filesystem charges a
  block per tiny file; the 256-group layout fixed that and is recorded here
  so nobody reverts to per-blob files for apparent simplicity.

## Migration evidence (2026-11-12)

- Packed: 777 of 803 fixture files (26 contain no large values and stay
  plain); 155,240 blobs; store = 256 `.pk` packs (142.4 MiB) + 256 `.idx`
  indexes (12.0 MiB); manifests 170.8 MiB -> the remaining inline JSON.
- All-case equivalence vs `e02e4e02`:
  `node compat/xlsx/tools/fixture-equivalence.mjs --base e02e4e02` -
  803/803 files identical, 0 failures, **316,365 cases compared**
  (the full baseline case count, no case added, dropped or duplicated).
  This compares the loaded value of every fixture (inputs, expected BDFs,
  options, warnings, case order) with the `JSON.parse` of the git blob at
  the base commit, string-identical including the restored base64 text.
- Export round trip: `pack-fixtures.mjs --unpack --files conditional-top.json`
  reproduces the base commit's plain fixture byte-for-byte (`cmp` clean),
  and a partial `--files` pack then a canonical full pack rebuild the
  committed store deterministically (the tree returns clean with no store
  or manifest diff).
- Packing invariants: `node compat/xlsx/tools/pack-fixtures.mjs --check` -
  803 checked, 0 failures (no packed fixture without blobs, no plain fixture
  with large inline base64, no manifest/blob-count mismatch, no unreferenced
  or absent store blobs on a full run).
- Failure modes: `node compat/xlsx/tools/fixture-store-test.mjs` - 14 checks
  passed (missing pack group, missing index entry, flipped byte inside a
  pack, truncated gzip container, edited hash, unsupported envelope and
  store-index versions, plain passthrough, marker-in-value, round-trip with
  gzip and raw packs, and the two representative fixtures). Runs first in
  `npm run test:xlsx-compat`.
- Sharding: `verify-render.mjs` aggregator unchanged; its case-ID hash,
  shard selection, duplicate and missing-case detection run over labels that
  did not change. `shard-test.mjs` and `shard-pbt-test.mjs` pass unchanged.

## Verification cost, old vs new

Same machine, `/usr/bin/time -v`; the baseline was recorded under unrelated
machine load and the after-migration runs back to back on a mostly idle
machine, so treat the deltas as indicative, not isolated benchmarks:

| run | before | after (final, post-review fixes) |
| --- | --- | --- |
| `npm run test:xlsx-compat` (store test + emission + shard tests + all verifiers) | 3:14.90, max RSS 1.52 GiB | 3:21.05, max RSS 1.98 GiB - pass |
| `node compat/xlsx/verify-render.mjs` (144,297 cases, 8 shards) | 3:03.61, max RSS 1.52 GiB | 3:02.27, max RSS 1.78 GiB - pass |
| `node compat/xlsx/shard-pbt-test.mjs` (shard oracle) | not recorded | 0:08.43 - 16 checks pass |
| `npm run test:xlsx-visual` (barrier + screenshot compare) | not recorded | 0:24.20 - pass, 0.00% diff |
| `npm run verify:local:ci` (actrun ci/test + ci/demo) | not recorded | 3:43 - pass; moon tests js 3208 / wasm-gc 3140 / native 3140, 0 failed |

The increase (+25% wall, +22-30% peak RSS) is the accepted cost of the
storage layer: every shard child gunzips the pack groups it touches, hashes
each blob slice it resolves and rebuilds the manifest's object tree, where
`JSON.parse` used to hand out base64 strings directly. Integrity on read and
dedup were the goals of the change; ~50s per full render verification was
accepted as maintainable. Both runs also verify the same 144,297 case
identifiers, repeats and shard union as before.

Packing the whole tree costs ~13 s wall and ~4 GiB peak in one process
(one-off; not part of verification runs).
