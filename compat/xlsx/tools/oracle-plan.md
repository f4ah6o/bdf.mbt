# Dynamic XLSX oracle migration (in progress)

The compatibility contract stays the same: generate inputs and expected values
with a pinned upstream Go implementation, then pass the **same** cases through
the existing detailed MoonBit verifiers. No tolerance or case removal is part
of this migration. Old static fixtures remain until the all-case migration gate
passes. `npm run test:xlsx-compat` is not changed yet.

The oracle is not the stock CLI: the 726 XLSX test adapters also exercise private
reference parsing, formatting, layout and error contracts. They compile as one
Go test binary against upstream revision
`a5e4d7a6b202cfe73de44b0be51f6fb86cd8ee22`. Go 1.27.0 and the architecture /
GOAMD64 floating-point profile must also be pinned. GOAMD64 v1 can disagree with
FMA-derived static goldens; that is not a permissible silent rebaseline.

Generation must use an empty output directory. Keep real input seeds and legacy
regression inputs, not their expected BDFs. Dependencies are explicit:
`table-values.json` precedes the store-sheet adapter; legacy adapters receive a
separate unpacked input seed root; formula-previously-unsupported inputs are
seeded before generation. Generators producing MoonBit source are outside this
JSON corpus migration and must not overwrite source files during tests.

A future runner will:

1. verify upstream SHA, toolchain and adapter hashes before building/cache reuse;
2. execute fixed adapters into an isolated directory and record binary identity;
3. check the complete expected file/case/identifier inventory and seed identity;
4. run current comparisons with the generated fixture directory (never fallback
   to stored goldens when an oracle output is missing);
5. retain failing inputs, both outputs and reproduction metadata, and delete only
   temporary successful outputs;
6. provide an all-case static-versus-dynamic migration report and repeat-run
   reproducibility report before removing stored expectation blobs.

Build cache is reusable; generated expected values must be fresh each test run.
An upstream/toolchain change is an explicit reviewed compatibility change, not an
automatic update to the reference.

## Migration tools

- `build-oracle.py --upstream <local-git-repo> --go <Go-1.27.0-executable>
  --output <new-build-dir> --goos linux --goarch amd64 --goamd64 v3` builds
  only from the pinned commit's archive. It records source adapter snapshots,
  upstream XLSX/image test data, toolchain/profile and executable SHA256.
  `--goarch arm64` cross-compiles; `--goos darwin` builds for Mac native execution.
- `generate-oracle.mjs --build <build-dir> --output <new-output-dir>` verifies
  build, adapters and seed checksums before running. It never writes a checkout,
  inherits no stale outputs, and records unpacked input-seed checksums.
  `--emulator <executable>` is optional for cross-architecture experiments.
- `compare-oracle.mjs --generated <output-dir> --report <report.json>` checks
  both file inventories and every value in order. Missing, extra or different
  content fails, and the report lists case indexes/fields without embedding
  input documents. This is a migration gate, not the runtime verifier.

These scripts are migration tooling, not a completed storage migration. In
particular the seed exporter still reads legacy static fixtures; generated
corpus coverage and arithmetic-profile equivalence must pass before changing
that source or deleting any tracked manifest/blob.

## Arithmetic investigation

The 26 initially observed render differences are explained by fused arithmetic:
25 colors differ at a rounding boundary (`D396A7` with tint 0.1 gives green
160 with separate operations, 161 with FMA), while one strike-through Y value
is `-2.7533531e-14` versus FMA's `-2.762975e-14`. GOAMD64=v3 regenerates the
9,803 representative render cases with all input bytes unchanged and fixes the
25 colors, but does not fuse the subtraction in the strike coordinate. ARM64
compiler rules include that fusion. This explains the values but does not prove
which historical machine/toolchain created the fixtures. No tolerance has been
introduced and the reference has not been silently rebaselined.

## Explicit migration triage

`classify-migration.mjs --comparison <comparison.json> --report <triage.json>`
classifies the strict gate's mismatches without changing or accepting them.
The current v3 run has 25 missing input-only candidate files (including literal
input arrays and labeled unsupported-input cases) and one media resource corpus,
`picture-visual-media.json`. These are preservation candidates, not evidence
that a generator exists or that a file may be omitted. The resource corpus has
label/index/MIME/dimension/media fields and must be retained explicitly.

The 42 mismatches are not all output rounding: `formatted.json` changes the
numeric input `value` in 4,788 cases (sample 19719.80542860614 versus
19719.805428606138, with unchanged expected text), and
`rectangle-linear-boundary.json` changes input as well as BDF in 116 cases.
Those inputs must be reproduced exactly before deleting static inputs. The
remaining files are expected-value or encoded-output drift requiring separate
arithmetic/structural investigation. Seven extra generated files remain an
explicit inventory mismatch, not automatic additions to the accepted corpus.

The 26 retained corpora now have an explicit `retained-inputs.manifest` SHA256
inventory. The generation runner exports them only after successful Go
execution, validates input/media-only fields (no expected-output fields), and
rejects collisions with generated outputs. Their hashes are included in the
run receipt. This preserves independently supplied regression inputs and media;
it does not present them as newly generated data. Existing stored expectations
and the exact comparison gate remain unchanged.

## Repeat-run and adapter sideproducts

`compare-oracle-runs.mjs --first <run> --second <run> --report <json>`
requires complete, identical build/adapter/seed identities and compares all
JSON outputs, including extra adapter sideproducts. Changed values, missing or
extra files fail. It is additional to, not a substitute for, static comparison.

The seven currently extra files are generator sideproducts unreferenced by the
current verifiers: `base-border-tint-too-large.json` contains one input;
`percent-links-unsupported.json` contains three inputs. The rich-run-data,
rich-run-wrap, sheet-multiple-notes, sheet-multiple-notes-filter and
sheet-notes-filter `-unsupported.json` outputs are empty arrays. The last has
an unreachable i>=192 branch within i<128; the others never append to their
unsupported accumulator. They remain in the exact gate's inventory: do not
silently discard them or count their inputs as existing coverage.

Initial repeated execution changes BDFs in sheet-multiple-notes,
sheet-multiple-notes-filter and sheet-multiple-notes-legacy despite unchanged
input bytes. These require deterministic upstream ordering investigation in
addition to architecture/floating-point analysis. No output sorting or
normalization is introduced by the repeatability gate.

A subsequent fresh 724-adapter repeat using identical complete AMD64 receipts
confirms four nondeterministic files: the above three notes files plus
`multi-font-legacy.json`; all other 806 JSON outputs agree. Pinned upstream
`drawing.go` paintMarks iterates the comments map directly, giving a concrete
ordering hypothesis for notes. The font case still needs source-to-output
tracing. Fixing these requires an explicit oracle determinism decision, not
sorting BDF parts after generation to disguise differences.

## Determinism experiment: case order versus drawing order

The multi-font drift was adapter case order, not glyph or font conversion:
`generate_multi_font_legacy_test.go` iterated a two-key Go map. Its group order
is now explicit, matching static input identities (plain-run indices 2 and 3,
then multi-color index 0). Pinned upstream source remains unchanged. With the
rebuilt Go 1.27 AMD64 v3 oracle, 20 separate processes produced identical bytes
and all static fields/order match. `check-multifont-repeat.mjs --build <build>
--seeds <seed-root>` reproduces that check with binary/adapter/seed validation.

For a notes control, decoding the differing objects shows the two triangle
path tables swapped while FILL_PATH 0 then 1 remains. Coordinates are disjoint
in that specific control: (44.25,0)-(48,3.75) and
(140.25,14.25)-(144,18). This is consistent with paintMarks map iteration.
Sorting would change painting order, however, and is not generally safe for
merged/overlapping cells. No path reordering, semantic normalization or
acceptance rule is added. The three notes corpora still fail repeatability;
the full migration remains incomplete even after the adapter-order fix.

## Proposed bounded static exception, not activated

`notes-static-proposal.manifest` and `audit-static-proposal.mjs` pin a possible
three-file exception: all 264 notes cases, exact old order/content and 783,651
serialized JSON bytes. This is only an audited proposal; no loader, verifier,
CI command or migration gate consumes it. Its hashes fail if preserved data
changes. These cases would still run through the same detailed verifier, never
be skipped, and never be substituted automatically after generation failure.
An eventual split must prove dynamic and static case sets disjoint, their union
equal to the original inventory, and shard membership unchanged. Raw dynamic
notes results must remain available as evidence of unresolved nondeterminism.

This does not solve the remaining deterministic arithmetic drift. Current
42-file whole-file retention would be 44,068,377 serialized bytes / 57,831
cases; retaining only the 5,487 observed differing cases would be 3,560,652
bytes, but is NOT safe for nondeterministic corpora (a later run can select
other cases) and is not adopted. Those are unpacked JSON measurements, not
Git/packed storage savings. ARM64 profile testing and input arithmetic drift
remain necessary before reducing the dynamic/static boundary further.

Keeping original notes expectations preserves a known compatibility contract.
Changing upstream map iteration to sorted coordinates is a different oracle:
it may change overlapping annotations and need not match historical order.
Without changing that oracle, no Go process setting guarantees map iteration
order. Retry-until-match and BDF path sorting are not acceptable substitutes.

## Seeded formatted inputs: explicit arithmetic

The `formatted.json` input generator now expresses the historical random
input formula as `math.FMA(random, 100000, -30000)`. This changes only the
adapter's input construction, not upstream number formatting. Seed, random
calls, options and case order remain unchanged. The prior AMD64 v3 expression
produced 4,788 differing numeric inputs. With the explicit formula and a newly
authenticated Go 1.27/v3 binary, all 10,357 cases match static inputs, expected
values and order exactly; three fresh separate process runs are byte-identical.
`check-formatted-repeat.mjs --build <new-build>` validates binary and current
adapter hashes and requires fresh output each iteration. This does not resolve
FMA differences within upstream rendering or imply full migration success.

The analogous rectangle-boundary adapter experiment was **not adopted**.
Replacing only `1.055*Pow(v,1/2.4)-0.055` with explicit FMA reduced observed
input mismatches from 116 to 74, but 99 of 144 complete cases still differed
(74 input differences). The experiment used a separate authenticated build,
then the adapter change was reverted. Partial improvement is not exact input
reproduction; architecture-specific Pow and downstream color arithmetic still
need investigation. No static rectangle data or acceptance condition changed.

## Rectangle input attribution (diagnostic, not acceptance)

`audit-rectangle-inputs.py` compares unpacked input ZIP members without
extracting them. On all 144 cases, the 116 changed original input archives
changed only `xl/drawings/drawing1.xml`, and only the numeric RGB attributes of
`a:scrgbClr`; no other member content differed. The rejected explicit-FMA
experiment leaves 74 changes in the same attributes. The script masks those
attributes solely to identify other differences; it does not emit normalized
inputs, rewrite cases or feed a verifier. ZIP metadata/order checks remain the
responsibility of the strict input-byte migration gate.

Go 1.27 `math.Pow` routes its fractional exponent via `Exp(yf*Log(x))`, while
Exp has separate amd64 and arm64 assembly. Thus changing only the outer FMA
cannot establish ARM64 equivalence. Attempting `GODEBUG=cpu.fma=off` on the v3
experiment prints `unknown cpu feature "fma"`: internal/cpu deliberately
omits disabling required v3 features. That run was not a valid no-FMA control
and yielded the same 74 input differences. No emulator/software was installed,
no historical ARM64 provenance is claimed, and no partial fix was adopted.

## Fresh full generation after formatted arithmetic correction

A fresh Linux AMD64 v3 generation with the current adapter inventory completed
all 724 adapters. The strict migration gate compared all 803 historical files:
762 equal, 41 different, zero missing, zero read/parse failures, seven extra
outputs. The prior 42-file count included the now-corrected `formatted.json`.
The 41 differing files contain 688 differing cases in this run; this case count
is not a stable exception list because the three notes corpora remain
nondeterministic. Classification is 38 encoded-output files, two scalar
expected-value files (`color.json`, `general.json`), and one input-generation
file (`rectangle-linear-boundary.json`).

An independent BDF decode of all 482 cases whose `bdf` field differed found no
metadata, table, or part-count changes, but every one contained changed part
bytes. Views differed in 480 cases; those records contain content references,
so that alone does not prove changed page geometry. All BDFs decoded without
failure. This diagnostic does not normalize or relax the byte-level gate and
does not establish that remaining differences are harmless arithmetic drift.
The seven extra generated outputs still require an explicit inventory decision;
no historical cases or static expectations have been removed.

## Runtime-specific drift is not always a tiny visual difference

The fresh 41-file report was also decoded to object tables and drawing calls.
This is diagnosis, not a new acceptance criterion:

- 27 picture files / 335 cases changed transformation numbers by up to about
  `6.72e-15` and changed dependent object hashes. `render/009.json` has one
  numeric drawing-argument change of about `9.62e-17`.
- Five conditional-formatting files / 24 cases include changed instruction
  sequences and fonts. They must not be described as merely byte noise.
- `plain-table-filter-ids.json` has eight cases with changed filter-button
  drawing count/positions. Pinned upstream `internal/xmltree.Node.AttrInt`
  falls back from ParseInt to ParseFloat and then int64 conversion. The input
  includes NaN/out-of-range values. Conversion of those values is
  architecture-dependent; this is a concrete investigation target, not proof
  that the historical corpus was built on ARM64.
- Three notes files changed 86 cases in this run through path-table order;
  this count varies. The bounded-static proposal remains inactive.
- Two rectangle files have 28 changed BDF cases; the boundary fixture also
  has input changes. Color/style differences must still be preserved.

Independent scalar comparison confirms `color.json` has identical input
parameters but 116 changed expected values (maximum channel delta
`1.1102230246251565e-16`). Seven also change packed 8-bit RGBA, so allowing
an epsilon would hide an observable output change. HLS arithmetic followed by
Round(channel*255) is the suspected boundary, not an established adapter fix.

`general.json` differs on bits `0000a16d71638eb5`, width 8: historical
`8.8E-310`, current `0.9E-309`. On the pinned AMD64 v3 runtime the subnormal
input is `8.76924159474237e-310` but Log10 returns `-307.93689824998523`.
Upstream's one-step exponent adjustment cannot correct this two-decade error.
Go's architecture-specific Log implementation is implicated, rather than
random input generation. `probe-runtime-arithmetic.go` reproduces the numeric
observations without changing upstream, adapter inputs, or acceptance rules:

```
GOTOOLCHAIN=local GOENV=off GOWORK=off GOAMD64=v3 /path/to/go1.27.0/bin/go run compat/xlsx/tools/probe-runtime-arithmetic.go
```

The same AMD64 probe maps NaN and positive overflow float-to-int64 conversions
to MinInt64. ARM64 execution has not been performed. An actual fixed ARM64
oracle comparison is required before claiming these candidate causes proven
across architectures; patching upstream or adjusting expected values to match
the current host would violate the migration contract.

## Approved ARM64 execution comparison (2026-11-13)

After explicit approval, the official Ubuntu noble-updates `qemu-user`
`1:8.2.2+ds-0ubuntu1.18` package was extracted into a user-local directory.
System installation could not use sudo because the executor has
`no_new_privileges`; no system privilege/security setting was changed.
The downloaded package SHA256 was
`9655f3e7e50af597e1b845822c47af9231f9f1bcb8c99e586db9da775d70c041`.

A fresh oracle was built with the current adapters, pinned upstream and
Go 1.27.0, Linux/ARM64 v8.0. Its binary SHA256 was
`6425c89b0af6753bfc03735695f655e7d4d11c7fcaab33b325049fe2b6fc7035`.
Running the existing authenticated `generate-oracle.mjs --emulator
/path/to/qemu-aarch64` completed all 724 adapters in 573.27 seconds,
maximum RSS 461108 KiB. The unchanged strict `compare-oracle.mjs` compared
803 historical files: **800 equal, 3 different, zero missing, zero
read/parse failures, seven previously inventoried extra outputs**.

The only differences in this run were `sheet-multiple-notes-filter.json`
(35/128 cases), `sheet-multiple-notes-legacy.json` (2/8), and
`sheet-multiple-notes.json` (43/128). Their map-order nondeterminism remains
unresolved; these counts are observations, not an exception allowance.
The other 38 files differing in the AMD64 run now match without tolerance,
normalization, upstream edits, or replacing expected values. This supports
runtime/architecture attribution but does not prove the historical corpus's
build provenance.

The arithmetic probe also confirmed ARM64 Log10 of
`8.76924159474237e-310` is `-309.05703796483925`, unlike the AMD64 result
recorded above. ARM64 float-to-int64 maps NaN to zero and positive overflow
to MaxInt64, rather than AMD64 MinInt64. All 20,000 color and 19,987 general
cases match historical expectations under this build.

The migration gate still exits nonzero because three different files and
seven extra files remain. Static fixtures are retained. This was one full
ARM64 run, not a repeatability proof or a full MoonBit compatibility run.

## ARM64 notes and sideproduct audit

The build receipt and generation receipt agree on every shared identity field;
the binary SHA256 matches the receipt, with 726 adapter sources, 16 build seed
files, and 724 executed adapter tests. Re-running the strict comparison against
the retained ARM64 output again gives 800 equal, three different, zero missing
or read failures, and seven extras. This is a second comparison of the *same*
generation, not an independent generation or repeatability proof.

`audit-notes-order.mjs --generated <output> --comparison <strict-report>`
independently decodes all cases reported different. In this run the 35 filter,
2 legacy and 43 regular cases each have changed note-path sequences; each has
the same per-tile note-path frequencies, and the inspected non-note drawing
operations and selected object properties do not differ. The script also
checks input fields, selected manifest information and the reported changed
indices. This is a diagnostic attribution, not complete BDF equivalence or a
rendering-equivalence test: it deliberately does not accept the reordered
results. The existing detailed multi-note verifier itself compares note paths
unordered; that behavior is not the migration gate and does not prove that
order can be ignored for overlapping drawing operations.

`audit-oracle-sideproducts.mjs --generated <output> --comparison <strict-report>`
checks the exact seven names, observed shapes, counts and serialized-content
hashes. It is an inventory alarm, not an allowlist for the strict gate. The
single base-border-tint input and three percent-links inputs still require an
explicit preservation/coverage decision. The five empty unsupported arrays
still require a reviewed inventory decision; newly populated, changed, missing,
or additional sideproducts fail this audit. All seven remain extra in the
strict report.

The smallest existing proposal retains all 264 historical notes cases and their
original order while generating other corpora. Before activating any split,
prove the case/identifier inventory union, disjointness and shard membership,
run the unchanged verifier on each case, retain raw generated notes as evidence,
and complete full independent repeat runs. A separately reviewed upstream
ordering contract could eventually eliminate the exception, but changing the
pinned oracle or sorting drawing operations is not part of this migration.
