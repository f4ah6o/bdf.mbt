# Split migration measurements

These measurements are evidence for the isolated migration, not portable CI
performance guarantees. The baseline is Git commit
`ab0b102ced2ef6e43bdb00590daff83d0f316986`. The measurements were made on
2026-11-13 using the pinned Go 1.27.0 Linux ARM64 binary under the approved
Ubuntu QEMU 8.2.2 on an x86-64 host.

## Data size

The baseline's 804 fixture JSON files and 512 shared `.pk`/`.idx` files total
205,578,324 bytes of file content. The replacement's `inputs.data` (247,414),
`notes.data` (26,169), and four lock/inventory manifests (409,555) total
683,138 bytes, 99.67% less for this scope. The values exclude the separately
provisioned Go toolchain, upstream checkout, oracle binary, emulator, source
scripts, npm dependencies and temporary generated output; they are not Git
pack or filesystem-block sizes.

## Integrity and coverage

With the old files absent from the worktree, a fresh run's migration audit
read the fixed Git baseline and compared all 804 selected fixtures exactly:
804 equal, 0 missing or unequal, 316,370 comparison units, including 264
retained notes cases. All six generated sideproducts matched their locked
contents and explicit correspondence checks. The separately retained oversized
border input is covered by its rejection regression. The old files remain
recoverable from the baseline Git commit.

The full compatibility suite completed with 144,298 render IDs distributed
across four shards (36,066 / 36,100 / 36,079 / 36,053), with exact ordered ID
and ownership manifests. Its original 27 XLSX/OOXML verifiers ran along with
fixture-store, emission and shard checks. The separate shard PBT completed 16
checks. Table and picture visual smoke tests on a retained generated run passed
at 0.00% pixel difference for their sampled viewports; they are not an
exhaustive visual comparison.

One independent fresh run had 92 of 264 raw note BDFs differ byte-for-byte
from the static expectations. That count is not a semantic classification of
those differences. All 264 original notes values were selected unconditionally
and compared unchanged; generated raw notes were still checked for input,
options, BDF structure and part integrity.
The final code's second fresh run had 89 raw note differences; its independent
Git audit again found 804/804 selected values equal and 316,370 comparison
units. Both runs contained the same 810 raw output names, and only the three
raw notes files differed between the runs. The second run's case IDs and raw
hashes are retained in [evidence-20261113.json](evidence-20261113.json).

## Timing

An offline cold Go build took 21.55 seconds and a subsequent build with the Go
cache took 4.63 seconds; both produced the locked binary hash. These builds
were measured during other work and are not controlled benchmarks. With the
cold-built binary, a full post-removal `npm run test:xlsx-compat` took 1,214.03
seconds wall time: 880.146 seconds for fresh generation and 333.328 seconds for
validation and the suite. No generated expectations were cached. The baseline
full compatibility run recorded 334.41 seconds without fresh generation.
The second run, using the cached build but fresh generated expectations,
completed in 1,273.42 seconds: 839.622 seconds generating and 433.129 seconds
validating and testing. It overlapped another QEMU generation and a Git audit,
so its timing is not directly comparable with the first run.
The independent fresh `npm run test:xlsx-visual` run passed the table visual
checks at 0.00% difference and took 1,049.02 seconds: 1,015.719 seconds
generating and 33.122 seconds validating and testing. Its generation overlapped
the second compatibility run. The earlier picture visual smoke used a retained
generated run and took 97.95 seconds for table and picture checks together;
the complete aggregate local visual workflow was not run.
