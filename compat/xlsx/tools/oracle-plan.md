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
