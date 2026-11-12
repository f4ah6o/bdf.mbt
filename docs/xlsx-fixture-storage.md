# XLSX fixture storage measurements and migration

This records the measurements that chose the current storage format for
`compat/xlsx` fixtures, the decision, and the migration evidence, per
`issues/open/20261112-xlsx-fixture-size.md`.

`measure-fixtures.mjs` reads raw fixture JSON and never opens the blob
store, so on the migrated branch it must not run against the packed
manifests (it would measure markers, not bytes). Packed manifests are a
`BXF1` envelope, and the tool now reports that instead of parsing them.
Measure an unpacked export of the committed fixtures, outside the worktree;
the all-case equivalence gate is what makes the exported bytes stand in for
the base commit's:

```
tmp=$(mktemp -d)
git -C /path/to/bdf.mbt archive HEAD compat/xlsx | tar -x -C "$tmp"  # committed state, copy only
node "$tmp/compat/xlsx/tools/pack-fixtures.mjs" --unpack              # plain JSON inside the copy
node "$tmp/compat/xlsx/tools/measure-fixtures.mjs" --quick           # fast report, no compression passes
node "$tmp/compat/xlsx/tools/measure-fixtures.mjs" --json "$tmp/measurement.json"  # full pass
rm -rf "$tmp"
```

Both tools resolve their fixtures relative to their own file, and the whole
fixture set (manifests, store, tools) lives under `compat/xlsx/`, so the
copy is self-contained and the active fixtures are untouched. A quick pass
against such an export reproduces the baseline totals to within 0.005%
(740,268,205 vs 740,302,006 B on 2026-11-12): the all-case equivalence is
value-level, and a handful of never-packed files stringify with slightly
different escaping than the Go generator's original bytes.

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

- File bytes, verified from the committed tree: manifests and plain
  fixtures 179,191,583 B + packs 149,289,156 B + store indexes 12,603,132 B
  = 341,083,871 B = 325.28 MiB, which is 46.07% of the 740,302,006 B
  baseline (53.93% saved). `du` for `compat/xlsx`: 714 MiB -> 334 MiB, a
  ~53% working-tree reduction.
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
- Against regeneration on demand: the stored bytes remain authoritative.
  The representative Go generators were subsequently verified against pinned
  upstream source and toolchain (see below), but that does not establish
  reproducibility for every generator or justify replacing all saved inputs.
  `pack-fixtures.mjs` continues to ingest plain generator output.
- Store split: the first experiment (155,240 individual blob files) measured
  810 MiB `du` - worse than baseline - because the filesystem charges a
  block per tiny file; the 256-group layout fixed that and is recorded here
  so nobody reverts to per-blob files for apparent simplicity.

## Migration evidence (2026-11-12)

- Packed: 777 of 803 fixture files (26 contain no large values and stay
  plain); 155,240 blobs; store = 256 `.pk` packs (149,289,156 B = 142.4 MiB)
  + 256 `.idx` indexes (12,603,132 B = 12.0 MiB); manifests and remaining
  plain fixtures 179,191,583 B = 170.9 MiB.
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

The final full-suite wall time increased by about 3.2%, while the render-only
wall time was effectively unchanged (about 0.7% lower). Peak RSS increased
by about 30% for the full suite and 17% for render-only. Every shard child
gunzips the pack groups it touches, hashes each blob slice and rebuilds the
manifest object tree; cached decompressed packs account for the additional
memory. These observations do not isolate the storage layer's CPU cost
because baseline and final runs had different concurrent loads. The storage
reduction is retained with this documented memory trade-off. Both render
runs verify the same 144,297 case identifiers, repeats and shard union.

Packing the whole tree costs ~13 s wall and ~4 GiB peak in one process
(one-off; not part of verification runs).

## Representative Go regeneration verification

A follow-up inspection found the upstream source and testdata locally; the
initial assumption that the upstream environment was unavailable was incorrect.
The existing checkout was not modified. Verification used an isolated archive of
upstream `a5e4d7a6b202cfe73de44b0be51f6fb86cd8ee22`, Go 1.27.0 linux/amd64,
and that commit's `go.mod`/`go.sum`, with `-mod=readonly`. Missing dependencies
were obtained from `https://proxy.golang.org`, verified with `sum.golang.org`.
The system PATH's Go 1.25.5 was not replaced; Go selected the required toolchain.

Copy `generate_conditional_top_test.go` and `generate_simple_picture_test.go`
into the isolated upstream `converter/xlsx` directory, removing only their
`//go:build ignore` line. Set `BDF_FIXTURE_ROOT` to a separate output directory
containing `compat/xlsx`; never point this experiment at the active packed set.
Run from the isolated upstream root:

```sh
BDF_FIXTURE_ROOT=/path/to/isolated-output go test -mod=readonly ./converter/xlsx \
  -run '^(TestCodexConditionalTop|TestCodexSimplePicture)$' -count=1
```

Results, 2026-11-12:

| Fixture | Regenerated cases | Comparison with stored fixture |
| --- | ---: | --- |
| conditional-top.json | 257 | Deep equality, zero mismatches |
| conditional-top-unsupported.json | 8 | Deep equality, zero mismatches |
| simple-picture.json | 48 | Deep equality, zero mismatches |

The regenerated JSON was compared with `loadFixture` output, including every
case's Base64 input/expected BDF strings, options, warnings and array order.
All 313 cases matched. A second `-count=1` run with `GOPROXY=off` produced
byte-identical JSON files (SHA-256 checks passed for all three outputs).
The first run, including dependency acquisition and compilation, took 39.67 s
and peaked at 610,016 KiB RSS; the warm repeat took 0.29 s and 159,208 KiB.
These results establish reproducibility only for these pinned representative
generators in this environment. Full regeneration of all 803 fixture files
was not run; the full storage migration is instead covered by the existing
803-file / 316,365-case equivalence check.

## Stage 2: compressed manifests (2026-11-12)

Stage 1 left 341,083,871 B in the working tree: 149,289,156 B of packs,
12,603,132 B of store indexes, 164,783,241 B of manifests and 14,408,342 B
of plain fixtures. The manifests were the largest remaining repetitive JSON
(`store-sheet.json` alone was 42,576,435 B of table/column metadata), so this
stage compresses the manifest container and leaves the blob store, its
grouping and its indexes untouched.

### Measured options for the 164,783,241 B of manifests

| codec | bytes | % of manifest JSON | pack wall time |
| --- | ---: | ---: | ---: |
| gzip level 9 | 46,572,074 | 28.3% | 1.8 s |
| brotli quality 9, lgwin 24 | 29,246,212 | 17.7% | 8.3 s |
| brotli quality 11, lgwin 24 | 26,949,294 | 16.4% | 81.3 s |
| zstd level 19 | 29,186,239 | 17.7% | 14.6 s |
| zstd level 12 | 29,541,469 | 17.9% | 1.6 s |

Chosen: brotli quality 9 behind a `BXF2` envelope: the four-byte magic, the
uncompressed JSON length (4 bytes, big endian), the SHA-256 of the
uncompressed JSON (32 bytes), then the brotli stream. Quality 11 saves
another 2.3 MB but costs ten times the one-off pack time; zstd is within
0.1 MB of brotli 9 but needs a newer Node API for no measured gain here;
gzip is 17.3 MB larger.

The digest is not optional. Brotli has no checksum, so a single flipped
compressed byte can still decompress to valid JSON; without a digest the
loader would parse the mutated value and silently change a case. The loader
verifies the length and SHA-256 before `JSON.parse`, and rejects the older
`BXF1` envelope (magic plus brotli, no digest) with a repack instruction
instead of guessing at it. The magic keeps the container self-identifying,
so plain generator output still loads unchanged.

### Result

The table compares the same full-tree components on both sides, including
the tools and README, so the totals match `git ls-tree -r -l`:

| component | stage 1 | stage 2 | change |
| --- | ---: | ---: | ---: |
| packs (`store/*.pk`) | 149,289,156 | 149,289,156 | unchanged |
| store indexes (`store/*.idx`) | 12,603,132 | 12,603,132 | unchanged |
| manifests | 164,783,241 | 29,277,292 | -82.2% |
| plain fixtures | 14,408,342 | 14,408,342 | unchanged |
| tools and other files | 4,953,895 | 4,968,281 | +14,386 |
| **total** | **346,037,766** | **210,546,203** | **-39.2%** |

210,546,203 B is 60.84% of the 346,037,766 B stage-1 tree and 28.44% of the
740,302,006 B original baseline. `du -sh compat/xlsx` fell from 335 MiB to
206 MiB. The store bytes are byte-identical to stage 1: a full pack reports
256 unchanged groups and `git status` shows no store change. The manifest
total includes the 40-byte `BXF2` header on each of the 777 packed files
(27,972 B more than the bare brotli payload).

### Tradeoffs

- Manifests are binary in `git diff`. `pack-fixtures.mjs --print --files
  name.json` writes the decoded JSON to stdout, and `--unpack --files
  name.json` writes the plain file back; both are one command, and the
  envelope is documented in `compat/xlsx/README.md`. `--print` waits for the
  stdout write to flush before exiting, so a pipe receives the whole fixture
  (775,545 B for `conditional-top.json`, not the 81,920 B pipe buffer).
- Partial regeneration is unchanged: a plain regenerated fixture loads
  through the same loader, `--files` packs it, and a later full pack restores
  the canonical store order. The round trip was checked on
  `conditional-top.json`: unpack, repack, identical SHA-256.
- `measure-fixtures.mjs` refuses packed manifests with an explicit message
  rather than reporting stored bytes as baseline bytes; the documented
  unpacked-export workflow still works.
- The remaining store is still 161.9 MB of packs and indexes. Measured but
  deferred: brotli on the existing packs (149.3 -> 129.1 MB), gzip on the
  indexes (12.6 -> 6.6 MB), and similarity-ordered packs (first-seen order
  chunked at ~1.3 MB: 82.1 MB with brotli 9, or 67.0 MB as one stream).
  The last option needs a global index or a pack id in every marker and
  changes partial-pack semantics, so it is a separate change with its own
  equivalence evidence.

### Evidence

- All-case equivalence, raw base `e02e4e02`: 803/803 files identical,
  316,365 cases compared, 155,240 distinct blobs, 0 failures, 25.5 s wall,
  1.50 GiB peak RSS.
- All-case equivalence, packed base `a35db856`: 803/803 identical, 316,365
  cases, 0 failures, 41.2 s wall, 2.03 GiB peak RSS. The base side is
  resolved through that commit's own store read from git, and the tool fails
  if either side still contains a `$blob` marker, so this is a value-level
  comparison rather than a marker comparison.
- Store integrity and corruption: `fixture-store-test.mjs` 33 checks pass
  (19 before this change; the stage-1 note's 14 is historical), including the
  envelope round trip, plain passthrough, a same-length mutation that still
  decompresses to valid JSON but fails the SHA-256 check, a shorter mutation
  that fails the length check, a single-bit sweep over the header and payload
  that never changes the decoded text silently, the legacy `BXF1` rejection,
  compressed-manifest marker resolution, two store readers sharing one cache
  without masking each other, and a piped `--print` child that parses and
  matches the loaded fixture.
- Packing invariants: `pack-fixtures.mjs --check` - 803 files checked, 0
  failures.
- Sharding: `shard-test.mjs` and `shard-pbt-test.mjs` pass unchanged (16
  checks each, 40 cases across 4 shards in the aggregator test).
- Full `npm run test:xlsx-compat` passed in this worktree using a shared
  built checkout: `_build/js/debug/build/compat/xlsx/xlsx.js` from a sibling
  worktree whose `convert/xlsx` is identical to `a35db856`, and the pinned
  `@bdfkit/core` 0.2.1 from a shared `node_modules`. Exit 0, 3:49.07 wall,
  1.94 GiB peak RSS; `verify-render` verified 144,297 cases across 8 shards
  in 213.9 s. The machine carried unrelated load (load average ~19), so the
  wall time is indicative. The build artifact and `node_modules` are
  gitignored and not part of the commit.
- Packing the whole tree costs 22.7 s wall and 4.06 GiB peak RSS in one
  process (one-off, unchanged from stage 1).
