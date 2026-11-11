# Turtles mutation-testing pilot: `core/bytes.mbt`

A bounded pilot that applies [turtles](https://github.com/gpui-mbt/turtles.mbt)
0.4.7 (the `cargo-mutants` equivalent for MoonBit) to one small core helper,
records an unchanged baseline, adds focused tests for the survivors, and
records a final report. It is deliberately **not** a mutation score for the
whole BDF module.

## Scope

| Item | Value |
| --- | --- |
| Module | `f4ah6o/bdf` |
| Target | `js` (explicit `--target js`) |
| Mutated file | `core/bytes.mbt` (140 lines, `Reader` + `valid_hash`) |
| Operator group | `boolean` only (`&&` <-> `||`) |
| Test oracle | module-wide `moon test --target js` (2746 tests) |
| Mutants | 7 |

`core/bytes.mbt` was chosen because it is small, pure, and load-bearing: 60 of
the module's 260 packages import `f4ah6o/bdf/core` directly, so a module-wide
test run is the honest oracle. `--affected` was not used; it is experimental and
would still select most of the module.

The default operator set yields 56 mutants for this file, which needs roughly
19 minutes per pass at this oracle cost. The pilot was narrowed to the
`boolean` group so that a complete unchanged baseline and a complete final
measurement both fit the budget. That is a slice, not a score for the file.

## Installing turtles 0.4.7

`moon install f4ah6o/turtles/cmd/turtles@0.4.7` is the documented route, but it
cannot run here: `~/.moon` is read-only in this environment, so the registry
cache lock fails. The official v0.4.7 native release asset was used instead and
verified against the digest GitHub publishes for the asset:

```sh
curl -sSL -o /tmp/turtles-linux-x86_64 \
  https://github.com/gpui-mbt/turtles.mbt/releases/download/v0.4.7/turtles-linux-x86_64
sha256sum /tmp/turtles-linux-x86_64
# 5b8e342a3362e2239d261615733a0267081accdf5c838466cd390a5ec8c8c411
install -m 0755 /tmp/turtles-linux-x86_64 bin/turtles
./bin/turtles --version   # turtles 0.4.7
```

`bin/` is worktree-local and git-ignored. turtles is a development tool only;
it is not a dependency of the module and nothing in `moon.mod` changed.

## Reproducing the pilot

Baseline (unchanged tests, before any test was added):

```sh
./bin/turtles --dir . --target js --file core/bytes.mbt --operators boolean \
  --jobs 2 --timeout 240 --output-dir .turtles-artifacts/baseline \
  --json .turtles-artifacts/baseline/report.json
```

Final (after the focused tests in `core/bytes_test.mbt`):

```sh
./bin/turtles --dir . --target js --file core/bytes.mbt --operators boolean \
  --jobs 2 --timeout 240 --output-dir .turtles-artifacts/final \
  --json .turtles-artifacts/final/report.json
```

Both runs write a schema-3 `report.json`, per-survivor diffs under
`survivors/`, and the console transcript. The raw artifacts are kept under
`.turtles-artifacts/`.

## Ratchet

`scripts/turtles-ratchet.mbtx` runs the same command and fails when the score
drops below the floor declared at the top of `main`:

```sh
MOON_HOME=$PWD/.moon-home moon run scripts/turtles-ratchet.mbtx
```

The workflows inherit the caller's `MOON_HOME`; if unset, Moon uses its normal
`$HOME/.moon` installation. A normal clean checkout does not require a private
`.moon-home`. The examples above use one only because this sandbox makes
`~/.moon` read-only while `.mbtx` commands need a writable dependency cache.
`.moon-home/` is a worktree-local home whose `bin`, `lib`, `include`, `share`
are symlinks to the real toolchain and whose `cache` and `registry` are
writable copies. It is git-ignored.

`scripts/turtles-env-check.mbtx` checks the selected home in the local workflow,
but its custom setup message is only reachable when `moon run` can start. With
an unusable toolchain or cache, `moon run` fails first
(`Unable to lock dependency source cache` / `module moonbitlang/async not
found`), so the step still fails loudly but the actionable text is the setup
block above, not the script's output.

To check an existing report without re-running the mutants:

```sh
MOON_HOME=$PWD/.moon-home moon run scripts/turtles-ratchet.mbtx --check-only \
  .turtles-artifacts/final/report.json
```

The ratchet rule: raise `min_score` when the suite improves, never lower it to
make a run pass. `--fail-under` inside the script enforces the same number, so
a regression fails the command rather than only printing a warning.

The script does not trust the report's own summary. It requires schema 3,
target `js`, `test_scope` `module`, zero inactive mutants, and exactly the
seven expected `boolean` mutant ids of `core/bytes.mbt`. Every row must be in
`core/bytes.mbt`, in group `boolean`, carry a supported `||`/`&&` flip, have a
unique id, and have a recognized outcome. It then counts the outcomes itself,
requires nonnegative integer summary counts that match those rows, recomputes
`killed / (killed + survived + timeout) * 100`, and rejects a summary score
that disagrees. Missing fields are errors, never zeros.

`scripts/turtles-ratchet-test.mbtx` exercises those paths against generated
fixtures:

```sh
MOON_HOME=$PWD/.moon-home moon run scripts/turtles-ratchet-test.mbtx
```

It checks that a valid report is accepted and that malformed JSON, a wrong
target, a duplicated id, an inconsistent score, inconsistent counts, an
unsupported replacement, and 6 or 7 `UNVIABLE` rows are all rejected. Last
run: 9/9 behaved as expected.

## Local actrun verification

Three local-only workflows live in `.github/local/`, outside
`.github/workflows`, so GitHub never discovers them. Each triggers only on
`push: branches-ignore: ['**']`, which no branch satisfies.

| File | When | What it runs |
| --- | --- | --- |
| `turtles-pilot.yml` | default | serial JS / wasm-gc / native matrix: env check, `moon check`, focused tests, ratchet fixtures |
| `turtles-audit.yml` | explicit, needs `TURTLES_AUDIT_REPORT` | audit one supplied schema-3 report |
| `turtles-mutate.yml` | explicit | the 7-mutant boolean ratchet |

```sh
ACTRUN=<integration>/node_modules/.bin/actrun
node $ACTRUN workflow run .github/local/turtles-pilot.yml --local
TURTLES_AUDIT_REPORT=$PWD/.turtles-artifacts/final/report.json \
  node $ACTRUN workflow run .github/local/turtles-audit.yml --local
node $ACTRUN workflow run .github/local/turtles-mutate.yml --local
```

This was validated with `@mizchi/actrun` 0.32.0 and Moon 0.1.20261104.
Set up a working Moon installation and project dependencies first. The default
workflow reads no historical report and does not require the pilot's private
cache. A clean checkout needs those ordinary tools and dependencies, not the
ignored evidence directory. In a restricted sandbox, export a usable absolute
`MOON_HOME` before invoking actrun; the workflows do not override it.

The audit and mutation runs are separate files rather than gated
jobs because actrun's `if:` cannot see process environment variables — a gate
would silently never fire. Invoking the file is the opt-in, and the audit file
fails when no path is supplied.

## Results

See `turtles-pilot-results.md` in this directory for the recorded numbers, the survivor
classification, and the limits of this pilot.
