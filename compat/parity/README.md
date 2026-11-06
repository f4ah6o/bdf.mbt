# Upstream parity harness

These scripts convert the same fixture with the upstream TinyGo Wasm
converter (`@bdfkit/convert-all` 0.2.1) and the MoonBit native converter
worker, decode both BDF documents with `@bdfkit/core`, and compare a
canonical form. They are the gate for the document conversion port.

## Run

```sh
MOON_HOME=$PWD/.moon-home moon build --target js
MOON_HOME=$PWD/.moon-home node compat/parity/verify.mjs
```

Useful selectors:

```sh
node compat/parity/verify.mjs --format=pdf,docx
node compat/parity/verify.mjs --case=pdf/chrome-doc#default
node compat/parity/verify.mjs --strict       # exit 1 on a difference
node compat/parity/verify.mjs --dump         # write the canonical JSON
```

The run writes `_scratch/parity/report.json` with every case, its status,
the upstream and MoonBit summaries/warnings, the full `diffCount`, a
category histogram, and the first differences. `docs/parity.md` records the
baseline and the progress driven by the report. The
default run exits 0 even when differences are found, so it can produce a
baseline report; `--strict` is what CI uses.

## What is compared

`canonical.mjs` normalizes the document before comparison:

- manifest metadata (source, generator, Dublin Core), the document version,
  opset and unit;
- every view (id, kind, title, pages, body rectangles, layer roles and
  objects, continuous gap, direction, tiles, sheet geometry, gridlines);
- every object's decoded instructions, including MARK, LINK and ALT_TEXT,
  paths, paints, text runs and child objects;
- the text index runs;
- the tables the document holds beside its drawing;
- the summary, the warnings in order, the reported format and the
  `protected` flag.

Floating point values are compared with a 0.01 tolerance (these are f32
positions). Text, warnings, summaries, marks and part identities must match
exactly.

## Why font parts are not byte-compared

Upstream embeds fonts through Go's WOFF2 encoder; the MoonBit encoder
produces different bytes for the same face and glyph set. The canonical form
therefore replaces a FONT record's part hash with its family, weight and
style, and compares only the number of font parts. Everything the viewer
draws — advances, glyph outlines and the text index — is still compared.

Object and path parts are also excluded from the part table: their content is
compared through the decoded instructions and paths. Image parts are compared
by decoded PNG pixels (and object image references by those content keys), so
encoder compression and image order do not count as differences. Index,
sequence and table parts are compared by content hash.

## Fixtures

`fixtures/` holds the upstream `converter/<format>/testdata` files at
`shibukawa/bdf` commit `a5e4d7a6b202cfe73de44b0be51f6fb86cd8ee22`
(MIT; see `fixtures/SOURCE.md`). They are copied verbatim. The font files
keep their SIL Open Font License beside them.

The matrix currently covers the default conversion of every fixture plus
`views`, `pages`, `kind`, `box`, `no-share`, `hidden` and `width`
cases. Font-directory cases and the upstream CLI reference (for options the
browser Wasm does not expose) are the next extension.

## Adding a case

Add an entry in `caseList()` in `verify.mjs` (format, file, options,
stable suffix). The input must be under `fixtures/<format>/`. A case whose
both converters reject the input is reported as `both-error`; a case where
only one rejects is a failure.

Do not weaken a comparison to make a case pass. If a difference is a
documented upstream limitation, the MoonBit converter must produce the same
warning or error, not a silently different document.
