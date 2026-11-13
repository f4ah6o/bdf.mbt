# 264-case notes exception: historical evaluation

> This document records the pre-adoption study. The bounded notes source was subsequently selected for the fresh-oracle workflow; see [oracle/README.md](../oracle/README.md) for its current status. The candidate figures below are not current checkout sizes.

This is a read-only feasibility study, not an implemented migration or a change
to the exact comparison gate. Three notes fixtures remain stored and all 264
cases still run. Source, inputs, expected values and painting order remain
unchanged. Sizes below count regular file contents, not Git pack size or block
allocation; compression is performed by the existing fixture pack algorithm.

## Stored fixture data

Measured after adding the oversized tinted-border input:

| Fixture-data scenario | Fixture files | Stored bytes | What it includes |
| --- | ---: | ---: | --- |
| Current repository | 804 | 205,578,324 | 43,685,789 fixture JSON/manifest bytes plus 161,892,535 shared `.pk`/`.idx` bytes |
| Notes alone, repacked | 3 | 23,755 | All 264 original cases and their 19 distinct blobs; not a complete corpus |
| Notes + retained inputs + new border input | 30 | 434,499 | 264 notes cases, 26 preserved input/media corpora, one border input; omits other generator seeds |
| Notes + retained inputs + 44 input-only seeds + border input | 67 | 706,321 | Experimental candidate; does not implement a fixture loader or change the current runner |
| Notes + retained inputs + all 76 current runner seeds + border input | 98 | 873,588 | Conservative seed-copy scenario; retains additional historical expectations |

The three notes manifest files currently occupy 7,291 bytes. Their blobs share
compressed prefix packs with other fixtures, so their current marginal share is
not the sum of three file sizes. The 23,755-byte figure is a separate in-memory
repack of only those notes fixtures, including newly built gzip packs and indexes;
it is not the size of the existing shared groups attributable to the notes.
Every fixture value in each repacking scenario was loaded back from its actual
encoded manifest and generated pack bytes and compared exactly.

Run `node compat/xlsx/tools/measure-notes-proposal.mjs --receipt
<completed-arm64-output>/identity.json` to repeat the calculation. The 67-file
candidate's 44 seed values are exact input-only values; 26 retained inputs/media
and the border input remain explicit. The current `generate-oracle.mjs` seed
exporter still reads 76 fixture files. Its conservative 98-file scenario keeps
32 BDF-containing seed files, including 277 historical BDF cases outside notes;
it therefore is not a 264-only expectation boundary. Some are output filenames
captured by the runner's broad source-literal scan, and the reduced set needs an
explicitly implemented and validated seed inventory before any migration.

The 67-file figure is not an executable replacement for today's checkout.
The unchanged strict migration comparator reads all 804 historical fixture
files, and existing verifiers also use the current fixture loader. Keeping that
gate and its baseline available requires retaining the full original corpus (or
an independently preserved baseline) until a separately reviewed migration
design provides equivalent access. The proposed figure therefore must not be
reported as current savings or as proof that the existing gate can run from
67 files.

These totals exclude tools, the upstream executable, build/runtime test data,
emulator, libraries, generated working outputs and any future additional seeds.
For scale, the tested ARM64 oracle executable is 23,176,804 bytes, its 16 build
runtime seed files total 91,058 bytes, and the QEMU executable is 4,211,464 bytes
(excluding shared libraries). A completed full output directory with the current
76 seed copies occupied 741,995,906 file-content bytes and is transient working
space, not included in the candidate stored-data figures.

## Time and coverage

A targeted QEMU invocation generating all three notes corpora, with the existing
legacy input seed and no upstream changes, took 0.58 seconds; one invocation of
the current separate notes verifier took 1.03 seconds for all 264 cases. These
are single observations, not robust benchmarks, and the current notes verifier
compares note paths unordered. The second full ARM64 generation took 690.62
seconds while another test ran; the post-border existing XLSX compatibility suite
took 334.41 seconds, including 320.2 seconds for render. These measured times
must not be added as a serial benchmark, and the cost of an implemented dynamic
loader, seed export, copying, CI caching or merged-run execution is not known.

The existing strict comparison of the independent full generation still fails:
801 of 804 historical files match, 3 notes files differ and 6 sideproducts are
extra. The separate repeat gate also fails on those 3 notes files. Per-tile note
frequency diagnostics do not prove reordered paint operations equivalent.

The read-only inventory audit enumerated 316,370 fixture units: 264 notes, 340
units in the 26 retained input/media fixtures, and 315,766 other units. These
file/index units are not all executable test IDs. The actual render verifier
listed and ran 144,298 unique IDs across four shards (36,066 / 36,100 / 36,079 /
36,053), while the 264 multi-note cases are run by a separate unsharded verifier.
No proposed split or new verifier has been run. Any implementation must preserve
all existing verifier paths, establish disjoint sets and their exact union, keep
shard identity and duplicate/missing checks, use the historical notes expectations
without a failure fallback, and retain fresh raw notes outputs for diagnosis.

## Choices under the pinned upstream

Pinned upstream `sheetCtx.paintMarks` ranges over the Go comments map and appends
paths in that iteration order. The two independent complete ARM64 generations
produce different notes results with identical binary and seed identities; no
supported Go setting guarantees the historical map iteration sequence. Sorting
paths could change paint order. Retrying until a stored order appears, changing
inputs, rounding, or using stored outputs as if freshly generated would not meet
the exact migration contract.

The smallest bounded option is to retain all 264 original notes expectations and
regenerate all proven reproducible outputs, with an explicitly reviewed split and
unchanged case coverage; it is not active. Another option is to get an upstream
ordering contract and pin a reviewed new upstream revision, followed by an
explicit compatibility review. That is a different oracle and is outside this
fixed-revision migration. A controlled runtime replay would require proving that
it reconstructs the historical map choices across every case without tampering
with inputs or expected data; no such mechanism or proof is available here.

## Diagnostic 44-seed generation

A separate experiment did not use or alter `generate-oracle.mjs`. It checked the
same binary, all 726 adapter source hashes and 16 build-seed hashes against the
previous receipt, selected the 44 receipt seed files whose entries contain only
input strings or `input`/`label`/`mode`/`no_index`/`variant` fields, and verified
each copied JSON value against its receipt hash. The other 32 receipt seed files
contained BDF expectations and were not put in the temporary source directory.
The sorted `{name: sha256}` map for the 44 selected seed values hashes to
`13688211d9baac1d45e639ef18436309e043b0fac5ff405f59bfac9a38661c25`;
`measure-notes-proposal.mjs` prints the names and checks those value hashes.

With those exact copied inputs, the same 724 adapter tests ran under the pinned
QEMU/binary into an empty output directory, with `GOMAXPROCS=2`, `GODEBUG=`,
`TZ=UTC` and `LC_ALL=C`; the formula input was copied to the output before
the tests, store-sheet ran after the other adapters, and the same 26 retained
inputs were exported afterwards. This diagnostic run finished in 600.95 seconds
and its output directory contained 741,253,618 file-content bytes. The existing
compatibility suite above was running concurrently for part of this experiment,
so the elapsed time is not a controlled benchmark.

The unmodified strict static comparison returned 801 equal / 3 notes different /
6 extras / 0 missing / 0 read failures. Compared to the previous 76-seed run,
807 of 810 outputs matched and the same three notes files differed. The existing
repeatability gate correctly failed both for the changed `inputSeeds` identity
and those three notes outputs; no identity or file exception was introduced.
The 804-file read-only partition audit and four-shard ID sets were unchanged.
These measurements show that the fixed adapters completed one run with the
44 exact input-only values, not that the current seed exporter or a dynamic
fixture loader is already suitable for production. Source selection, repeat
runs with an explicitly pinned 44-seed manifest, complete verifier execution
using the proposed split, and the unresolved inventory decisions are still
required before adopting it.
