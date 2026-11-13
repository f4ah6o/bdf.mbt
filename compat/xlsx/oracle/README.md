# Fresh XLSX oracle and bounded notes source

The compatibility suite generates expected values for each invocation from the
fixed Linux/ARM64 Go oracle. Only the original three multi-note fixture values
(264 cases) are selected from `notes.data`; their exact file names, ordered
case IDs and SHA-256 values are pinned in `lock.manifest`. The existing
`verify-sheet-multiple-notes.mjs` comparison is unchanged. Raw newly generated
notes remain in each run directory and are checked for exact input/options, but
are not substituted for the retained expectations. The receipt reports each raw
BDF that differs from the static value by case ID and both SHA-256 hashes. These
differences are deliberately unclassified: a difference is not treated as
evidence of semantic equality, nor does it trigger a fallback.

Every other historical fixture must be generated (or exported from the
explicit input/media bundle). The fresh result is checked against fixed historical value hashes (including a typed digest that
distinguishes `-0` from `+0`) and used by the existing verifier; those hashes are
additional integrity/inventory checks, not a replacement for its BDF, metadata,
warning or other assertions. The six adapter sideproducts have exact names and
content hashes; the three percent-link inputs must also equal the already
covered link input fixture and the other five must be empty. A missing output,
unknown extra, changed content, corrupted input, changed build or adapter, or
wrong run ID fails. There is no generated-to-static fallback.

## Offline preparation

Provision the pinned upstream Git commit, Go 1.27.0 and all of its already
required module dependencies locally. No command below needs network access
when those assets are available. To build an oracle in a new directory:

```sh
GOPROXY=off python3 compat/xlsx/tools/build-oracle.py \
  --upstream /path/to/upstream-git --go /path/to/go1.27.0/bin/go \
  --goos linux --goarch arm64 --output /path/to/new-oracle-build
```

The build must reproduce the binary SHA256
`6425c89b0af6753bfc03735695f655e7d4d11c7fcaab33b325049fe2b6fc7035` and
all build identity, adapter and runtime-seed hashes in `lock.manifest`. A build
with the right Go version but a different binary is rejected. Reuse a verified
build directory as a cache; do **not** reuse generated fixture directories as a
test cache. On Linux ARM64 the binary can run natively. On another architecture,
provision the approved Ubuntu qemu-user 8.2.2 `qemu-aarch64` executable with
SHA256 `0338d0ed6013abe5e0f41c5a22976ac6fe2f1b5869edf05d4a9098c121248f02`.
The binary, its dependencies, and QEMU must be provisioned separately; they
are not downloaded automatically.

```sh
export BDF_XLSX_ORACLE_BUILD=/path/to/oracle-build
# Required on non-ARM64 hosts:
export BDF_XLSX_ORACLE_EMULATOR=/path/to/approved/qemu-aarch64
node compat/retained-test.mjs --mode build js
npm run test:xlsx-compat
```

The same exported variables are required by the `visual` gate of
`npm run verify:local` and by `npm run verify:local:visual`. Before actrun
starts that gate, the local runner checks the build identity, binary, adapter
and runtime-seed hashes, and checks the approved emulator's executable access
and hash when it is configured. On native Linux ARM64 it checks that the oracle
binary is executable. A no-test execution probe also checks that the selected
binary and emulator actually start. Missing or invalid configuration blocks the visual gate
with exit code 2; it does not download or build assets automatically. Other
selected gates do not depend on the oracle. Run the same preparation offline
when the pinned upstream, Go toolchain and modules are already provisioned.

The local runner self-tests always cover missing and invalid configuration and,
when actrun is installed, verify environment propagation with a temporary
workflow. To also exercise the real pinned binary, runtime seeds and emulator
in those tests, set `BDF_XLSX_ORACLE_TEST_BUILD` and, outside native Linux ARM64,
`BDF_XLSX_ORACLE_TEST_EMULATOR` to the same provisioned paths before running
`npm run test:local-verify`. These test-only variables are separate from the
runtime variables so a bad runtime configuration blocks visual without making
the unrelated self-test gate fail.

`npm run test:xlsx-visual` uses the same fresh generation and source selection.
Each suite invocation creates an empty isolated output, checks pinned assets,
generates all 724 adapters, validates all 804 selected fixture identities and
the six sideproducts, and propagates a single run ID and receipt digest to all verifier and shard
subprocesses. Render case IDs and four-shard ownership are checked against the
fixed baseline before the complete suite; all 810 outputs and bundled inputs are
checked again after the suite. No generated expectations are accepted from a previous run.
Successful runs are removed by default; set `BDF_XLSX_ORACLE_KEEP=1` to retain
them. Failed runs and their raw generated notes are retained with the printed
path. The 44 generation seeds and 26 explicitly retained input/media corpora
are protected by checksums and are independent of old expected-output blobs.

To run a single verifier with a fresh oracle, use for example:

```sh
node compat/xlsx/oracle/run-suite.mjs --script compat/xlsx/verify-workbook.mjs
node compat/xlsx/oracle/run-suite.mjs --script compat/xlsx/verify-render.mjs -- --list --ids /tmp/xlsx-render.ids
node compat/xlsx/oracle/run-suite.mjs --script compat/xlsx/probe-conditional.mjs -- --all-conditional
node compat/xlsx/oracle/run-suite.mjs --suite picture-visual
```

The older packed-store measurement and proposal tools describe historical
experiments. Run them in a checkout of the original baseline; they must not
treat generated values as an independent static baseline.

## Migration evidence

The legacy strict whole-corpus comparison is not relaxed or replaced. To audit
the split against the original 804-fixture baseline, retain a run and use:

```sh
node compat/xlsx/oracle/audit-migration.mjs --run /path/to/retained/output \
  --repo /path/to/git-repository --report /path/to/report.json
```

The audit reads the exact baseline commit
`ab0b102ced2ef6e43bdb00590daff83d0f316986` and its shared blob store from Git,
compares every selected value and ordered case to that independent corpus, and
checks the six sideproducts. A shallow clone or offline checkout without the
baseline objects fails rather than treating current generated output as its
own baseline. A normal compatibility run does not require those old Git blobs.
The input and notes bundles are generated by `tools/create-split-assets.mjs`
only while an independently verified original corpus is available; the tool
first compares all 804 historical files before writing any asset.
The scope, size, timing and validation results of the measured migration are
recorded in [measurements.md](measurements.md). The independently generated
run's audit result and unclassified per-case raw notes hashes are preserved in
[evidence-20261113.json](evidence-20261113.json).

## CI and cache boundaries

Provision the npm dependencies, MoonBit toolchain, Go module cache, pinned
upstream Git objects and (on non-ARM64 workers) the approved QEMU package before
running offline. The Ubuntu package used in the recorded checks has SHA256
`9655f3e7e50af597e1b845822c47af9231f9f1bcb8c99e586db9da775d70c041`.
Cache or distribute the complete *build directory* (binary, `identity.json`
and runtime testdata) keyed by the oracle lock, platform and toolchain. The
runner verifies its actual content and rejects a bad cache before generation.
Do not cache `compat/xlsx` generated outputs, the temporary run directory or a
successful receipt as an expectation cache. Each CI suite invocation generates
its own output and ID; multiple verifier subprocesses in that invocation share
only that one authenticated run. Preserve a failed run directory and its logs
as CI artifacts. For a migration audit, provision the fixed baseline Git objects
as well; a normal test run does not need them.
