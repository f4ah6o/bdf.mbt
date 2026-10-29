# GSUB substitution compatibility fixtures

These fixtures record parsing and transitive glyph reachability from
shibukawa/bdf commit `4f9af52dca60be1eb0daade39f7dc41d6a1fe431`. They cover
single, multiple, alternate, ligature, reverse and extension lookups, coverage
ranges, duplicate rules, work-budget exhaustion, malformed tables and
reproducibly mutated inputs. The oracle lists each lookup once and applies
its substitutions to a fixed point, like the upstream font specimen converter.

After `moon build --target js`, run `npm run test:gsub`. To regenerate, copy
`generate_test.go` without its first `//go:build ignore` line into the upstream
checkout at `internal/otlayout/codex_gsub_test.go`, then run:

```sh
BDF_FIXTURE_ROOT=/path/to/bdf.mbt go test ./internal/otlayout -run '^TestCodexGSUBFixtures$' -count=1
```

The test writes `compat/gsub/upstream.json.gz` in the target repository.

`layout.json.gz` records scripts, language systems, feature parameters, lookup
flags and feature variations for GSUB and GPOS, including corrupt and oversized
inputs. Run `npm run test:layout` after a JS build. To regenerate it, copy
`generate-layout_test.go` without its build tag into upstream `internal/otlayout`
alongside `generate_test.go`, and run `TestCodexLayoutMetadata` with the same
`BDF_FIXTURE_ROOT`.

`gdef.json.gz` checks glyph and mark-attachment classes, mark sets, malformed
tables, and aggregate bounds. Run `npm run test:gdef` after a JS build;
regenerate by copying `generate-gdef_test.go` without its build tag into upstream
`internal/otlayout` with `generate_test.go`, then running `TestCodexGDEF` with
the same fixture root.

`gpos.json.gz` compares repeated GPOS pair counts, extension lookups, malformed
tables and the shared lookup work budget. Run `npm run test:gpos` after a JS
build. To regenerate, copy `generate-gpos_test.go` without its build tag into
upstream `internal/otlayout` with `generate_test.go`, and run
`TestCodexGPOSPairs` with the same fixture root.

`names.json` verifies all registered feature, script and language names,
numbered feature ranges, feature defaults, and GSUB/GPOS lookup type names.
Run `npm run test:opentype-names` after a JS build. To regenerate, copy
`generate-names_test.go` without its build tag into upstream `internal/otlayout`
and run `TestCodexTagNames` with the same fixture root. Generate the MoonBit
tables with `python3 compat/gsub/generate-names.py /path/to/upstream/internal/otlayout/names.go`
and format them using `moon fmt font/otlayout`.

`substitutions.json.gz` checks individual lookup enumeration, duplicate
handling, early callback termination and the shared work budget. Regenerate
`upstream.json.gz` first, then copy `generate-substitutions_test.go` without its
build tag into upstream `internal/otlayout` and run `TestCodexSubstitutions`
with the same fixture root. It is checked by `npm run test:gsub`.

`context.json.gz` compares GSUB and GPOS contextual lookup rule counts, nested
references, malformed inputs and shared work-budget behavior. Generate
`layout.json.gz` first, then copy `generate-context_test.go` without its build
tag into upstream `internal/otlayout` alongside `generate_test.go` and run
`TestCodexLookupContexts` with the same fixture root. Run `npm run test:layout`
after a JS build.

`position-values.json.gz` compares single-glyph adjustments, pair queries,
subtable precedence, missing records, zero-sized values and shared work budgets.
Generate `context.json.gz` first, then copy `generate-position-values_test.go`
without its build tag into upstream `internal/otlayout` alongside
`generate_test.go` and run `TestCodexPositionValues` with the same fixture root.
Run `npm run test:gpos` after a JS build.
