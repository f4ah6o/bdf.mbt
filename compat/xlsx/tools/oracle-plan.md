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
