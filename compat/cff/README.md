# CFF compatibility fixtures

These fixtures compare the MoonBit CFF subsetter with
[shibukawa/bdf](https://github.com/shibukawa/bdf), pinned at commit
`4f9af52dca60be1eb0daade39f7dc41d6a1fe431`.

`upstream.json` uses the STIX Two Text OpenType fixture in `compat/font`.
`synthetic.json` exercises local and global subroutines, accent components,
CID FDSelect formats, and execution limits. `sfnt.json` wraps those programs
in OpenType fonts to test the complete subset and fallback path. `prune.json`
compares glyph-number-preserving pruning on synthetic and real CFF programs. `large.json`
contains a compressed generated font that exceeds the whole-font embedding
limit and exercises the corresponding warning. `npm run test:cff-compat`
compares bytes, glyph orders, BDF parts and warnings.

To regenerate, copy each Go generator into a directory inside the pinned
upstream checkout (the generators import internal packages), then run it from
that checkout. Pass this repository's absolute path to `generate.go`,
`generate-sfnt.go`, `generate-large.go`, and `generate-prune.go`; `generate-synthetic.go` takes no
arguments. Generate `synthetic.json` before `sfnt.json` and `prune.json`. Redirect each output
to the matching JSON file. `generate-standard.go` generates
`font/cff/standard_generated.mbt` from upstream's standard name tables; run
`moon fmt font/cff` after regeneration.
