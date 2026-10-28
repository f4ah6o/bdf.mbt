`resource-fixture.bdf` is a synthetic document with three distinct 2×2 PNGs
and pages that use one or two of them. It exercises image cache eviction and
per-render limits. Regenerate it from a checkout of `shibukawa/bdf` v0.2.1
(commit `4f9af52`) with:

```sh
go run /absolute/path/to/bdf.mbt/compat/render_worker/generate_resource_fixture.go /absolute/path/to/bdf.mbt/compat/render_worker/resource-fixture.bdf
```

The instrumented Worker reports image decodes so the compatibility test can
compare cache reuse, eviction, concurrent renders, and lifecycle with the
upstream Worker. The separate `segments/` fixtures cover encrypted streaming.
