# Diagram format plugins: Excalidraw and Mermaid

This directory-level note documents the new diagram input-format plugins
(Excalidraw, Mermaid) built against the file-format plugin API of
`docs/format-plugin-api.md`. It is a NEW document: nothing in the existing
plugin API snapshot was modified to write it, and no file the parent owns
was edited in this worktree. Everything here is additive; the small parent
-side changes the eventual merge needs are listed as instructions, not diffs.

## What landed

| Owner | File | Role |
| --- | --- | --- |
| coordinator (this session) | `plugin/src/diagram-bdf.js` | shared diagram-to-BDF encoder (pure ESM, zero dependencies) |
| coordinator | `plugin/test/diagram-reader.mjs` | shared test reader built on the staged read-only `@bdfkit/core` |
| coordinator | `plugin/test/diagram-bdf.test.mjs` | encoder + reader tests (semantics, determinism, limits, PBT) |
| coordinator | `plugin/types/diagram-bdf.d.ts` | shared type declarations |
| subagent `excalidraw` | `plugin/src/adapters/excalidraw.js`, `plugin/test/excalidraw.test.mjs`, `plugin/types/excalidraw.d.ts` | Excalidraw scene adapter + tests |
| subagent `mermaid` | `plugin/src/adapters/mermaid.js`, `plugin/test/mermaid.test.mjs`, `plugin/types/mermaid.d.ts` | Mermaid flowchart-subset adapter + tests |

## Architecture

Both adapters implement the API version 1 plugin descriptor
(`defineFormatPlugin`) with a synchronous, total `detect` and an async
`convert`, exactly like the builtin `docuworksPlugin` adapter. They do not
own any BDF byte encoding: they parse untrusted input into bounded, validated
primitives and hand them to `encodeDiagram`:

```
Excalidraw JSON                                  Mermaid text (subset)
      |                                                   |
      |  parse + bounds + warnings                        |  parse + bounds + rejects
      v                                                   v
      +--------------- primitives (shared schema) --------+
                          |
                          v
              plugin/src/diagram-bdf.js
              encodeDiagram({width, height, source, title, primitives})
                          |
                          v
              single-file BDF bytes (header + manifest + obj part)
```

### The shared primitive schema

`encodeDiagram` accepts a serializable primitive array whose order is the
z order (later entries draw on top):

- `{kind:"rect", x, y, w, h, rounded?, style...}`
- `{kind:"ellipse", cx, cy, rx, ry, style...}`
- `{kind:"polygon", points:[[x,y],...>=3], style...}` — closed
- `{kind:"polyline", points:[[x,y],...>=2], style...}` — open, fill ignored
- `{kind:"text", x, y, text, fontSize, family?, weight?, style?, align?, baseline?, fill?, advance?, ...}`

Shared style fields: `fill`/`stroke` as `{r,g,b,a}` (0..255 each),
`strokeWidth` (positive pt, at most 10000), `dash` (pt segments),
`opacity` (0..1 of the BDF alpha op — the adapter converts from the source
format's own scale), `angle` (radians), and `pivot: [x, y]` — the rotation
pivot. When `pivot` is absent, shapes rotate about their own center and text
about its anchor; decomposed parts (an arrow's shaft and head, each line of
a multi-line text) pass the ORIGINAL element pivot so they stay attached
under rotation. Text `advance` optionally overrides the default
0.6em-per-codepoint width estimate; adapters pass a CJK-aware estimate for
wide characters, which also drives the recorded op and the text extent.

Encoder-side contract details (all enforced, all tested):
- page size `0 < w, h <= 1<<24` pt; at most 20000 primitives; all
  coordinates finite with `|v| <= 1e6`; per-primitive points capped at
  10000 and the whole document at 100000 points; text capped at 4096
  characters per primitive and 200000 per document; violations throw
  `DiagramEncodeError` with code `invalid-input` or `too-large`.
- every value that reaches a float32 operand is finite AS FLOAT32: a finite
  JS double such as `1e300` is rejected instead of encoded as `Infinity`.
- every visible primitive is wrapped in its own `save`/`restore` block, so
  dash, stroke, color and alpha state can never leak between primitives.
- output is the real single-file BDF: 32-byte header (`bdf\0`, version 1,
  flags 0), identity-encoded JSON manifest at offset 32, one `obj` part
  whose 32-hex-char name is the first 128 bits of the part's SHA-256, one
  `fixed` view, one page, one `content` layer. Pure-JS SHA-256 (same
  constant table as the MoonBit core) is verified against Node's `crypto`
  in the shared tests.
- the object bbox covers real rendering extents: alignment- and
  baseline-aware text bands, strokeWidth/2 padding, and the rotated AABB
  about the rotation pivot.
- encoding is deterministic: identical input yields byte-identical output
  (within one platform; `Math.cos/sin` never differ per run, but
  cross-engine f32 rounding of rotation matrices is not guaranteed).
- the input is treated as read-only: primitives are never mutated
  (frozen primitives convert identically).

### The independent reader

`plugin/test/diagram-reader.mjs` opens encoded bytes with the staged,
read-only `@bdfkit/core` package (`parseHeader`, `BufferSource`,
`BdfDocument`, `decodeObject`, `walk`) and returns decoded semantics:
header, manifest, view, page, layers, part entries, the object's tables,
its inline paths, and a recorded op stream (`fillRect`, `strokePath`,
`fillText`, `transform`, `alpha`, colors as 0xRRGGBBAA u32). The diagram
tests never assert against a magic header or their own encoder; they assert
what the independent reader decoded.

## Scope and deliberate limitations

Excalidraw (per the public scope decision):
- In: rectangles, ellipses, diamonds, straight lines, arrows, plain text;
  solid fills; stroke colors; opacity is the Excalidraw PERCENT scale
  (0..100, missing ~ 100, so `opacity: 1` really means 1%); rotation about
  the element pivot with decomposed parts (arrow shaft/head, text lines)
  sharing it; z order; deleted elements never render.
- Out (reported as warnings, never silently dropped): hand-drawn jitter,
  sketch hatching fill styles, freehand (`freedraw`) strokes, embedded
  images and their linked resources (never fetched), per-user/custom fonts
  (Virgil/Excalifont approximated by Helvetica), rounded-corner radii
  approximated on rectangles, element hyperlinks (not rendered), frame
  clipping (not applied).

Mermaid:
- In: a documented static flowchart subset — `flowchart`/`graph` with
  `td/tb/lr/rl`, node shapes `id`, `id[...]`, `id(...)`, `id([...])`,
  `id{...}`, `id{{...}}`, edges `---`, `-->`, `-.->`, `==>` with label
  forms, edge chains, `%%` comments. Node ids and labels are Unicode
  (Japanese labels are a first-class case: bare `開始 --> 処理中` ids and
  `[...]`-quoted labels both work); control characters, HTML/markup,
  callbacks and directives are rejected. Deterministic layered layout,
  edges drawn under nodes and clipped against the actual shape outline.
- Out (explicit rejects with named errors): all other diagram kinds,
  `subgraph`, `class`/`classDef`, `click`/callbacks, `init`/`%%{...}%%`
  directives, `linkStyle`/`style`, HTML labels, unknown shapes/arrows,
  scripts; caps on bytes, nodes, edges, ids, labels; untrusted text is
  never evaluated, no Mermaid engine, no DOM, no network.

Both plugins accept no `params` (any key is an error), reject passwords,
and never fetch or execute anything.

## Parent-side integration steps (for the merge; none done here)

The plugin API snapshot is read-only in this worktree, so the eventual
parent merge must add these small, already-agreed hooks itself:

1. `plugin/package.json` `exports` (additive entries):

   ```json
   "./diagram-bdf": { "types": "./types/diagram-bdf.d.ts", "default": "./src/diagram-bdf.js" },
   "./adapters/excalidraw": { "types": "./types/excalidraw.d.ts", "default": "./src/adapters/excalidraw.js" },
   "./adapters/mermaid": { "types": "./types/mermaid.d.ts", "default": "./src/adapters/mermaid.js" }
   ```

   plus the same three `dist/plugin/*` mappings in
   `plugin/tools/library-pack.mjs`'s allowlist for the `bdf.mbt` package
   (mirror of the `./plugin/adapters/docuworks` row in
   `docs/format-plugin-api.md`).

2. Worker install (where a diagram-capable plugin worker is wanted): pass
   the two descriptors at startup —
   `installPluginConverterWorker([docuworksPlugin({...}), excalidrawPlugin(), mermaidPlugin()])`
   — matching the v1 "startup registration only" rule; extension claims
   (`.excalidraw`, `.mmd`, `.mermaid`) do not collide with `.xdw`/`.xbd`.

3. The two adapters use only the existing contract surface
   (`defineFormatPlugin`, `acceptedParams`, `noPassword`); the only new
   runtime module they need inside the worker bundle is
   `plugin/src/diagram-bdf.js` (pure ESM, no dependencies).

## Running the tests (targeted only)

```sh
node --test plugin/test/diagram-bdf.test.mjs      # shared encoder + reader
node --test plugin/test/excalidraw.test.mjs      # Excalidraw adapter
node --test plugin/test/mermaid.test.mjs         # Mermaid adapter
```

The adapter tests import `@bdfkit/core` through the read-only symlink
`node_modules/@bdfkit/core -> ../../bdf-format-plugin-20261111/node_modules/@bdfkit/core`
(the target is never written). No installations, no full builds.
