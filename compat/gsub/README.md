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
