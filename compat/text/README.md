# Text extraction fixture

`parent.bobj` and `child.bobj` were generated with `generate.go` using
[shibukawa/bdf v0.2.1](https://github.com/shibukawa/bdf/tree/v0.2.1).
They cover reading order, separators, transforms, language, alternative text,
child objects, links, text inside masks, semantic nodes, A1 cell references, clipped and nested figure bounds. `verify.mjs` checks the same
expectations against the published `@bdfkit/core` extractor. The MoonBit tests
embed the generated object bytes so they can also run on wasm-gc.

To regenerate the fixtures from the upstream checkout:

```sh
go run /absolute/path/to/bdf.mbt/compat/text/generate.go /absolute/path/to/bdf.mbt/compat/text
```
