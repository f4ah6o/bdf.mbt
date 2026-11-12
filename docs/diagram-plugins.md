# Diagram format plugins: Excalidraw and Mermaid

This document describes the diagram input-format plugins (Excalidraw,
Mermaid) built against the file-format plugin API of
`docs/format-plugin-api.md`. Their shared encoder, adapters and type
declarations are part of the `bdf.mbt` package, and this document
ships inside it alongside the library README.

| File | Role |
| --- | --- |
| `bdf.mbt/plugin/diagram-bdf` | shared diagram-to-BDF encoder (pure ESM, zero dependencies) |
| `bdf.mbt/plugin/adapters/excalidraw` | Excalidraw scene adapter |
| `bdf.mbt/plugin/adapters/mermaid` | Mermaid flowchart-subset adapter |

The prebuilt plugin Worker (`bdf.mbt/workers/plugin`) registers both diagram
adapters next to the builtin DocuWorks adapter at startup, so the standard
converter client converts `.excalidraw`, `.mmd` and `.mermaid` inputs without
any extra wiring. A custom Worker can compose them explicitly:

```js
import { installPluginConverterWorker } from "bdf.mbt/plugin/worker";
import { docuworksPlugin } from "bdf.mbt/plugin/adapters/docuworks";
import { excalidrawPlugin } from "bdf.mbt/plugin/adapters/excalidraw";
import { mermaidPlugin } from "bdf.mbt/plugin/adapters/mermaid";
import { moonbitDocuWorks } from "bdf.mbt/plugin";
import * as xdw from "bdf.mbt/xdw";

installPluginConverterWorker([
  docuworksPlugin({ delegate: moonbitDocuWorks(xdw) }),
  excalidrawPlugin(),
  mermaidPlugin(),
]);
```

`encodeDiagram` is also exported directly (`bdf.mbt/plugin/diagram-bdf`) for
tools that want diagram-to-BDF encoding without the plugin envelope. Its
multi-page, embedded-image generalization `encodeDiagramDocument` lives in
the same module (`bdf.mbt/plugin/diagram-bdf`).

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
              encodeDiagramDocument({source, title, pages, images})
                          |
                          v
              single-file BDF bytes (header + manifest + parts)
              one obj part per page, one img part per unique raster
```

### The shared primitive schema

`encodeDiagram` accepts a serializable primitive array whose order is the
z order (later entries draw on top):

- `{kind:"rect", x, y, w, h, rounded?, style...}`
- `{kind:"ellipse", cx, cy, rx, ry, style...}`
- `{kind:"polygon", points:[[x,y],...>=3], style...}` — closed
- `{kind:"polyline", points:[[x,y],...>=2], style...}` — open, fill ignored
- `{kind:"text", x, y, text, fontSize, family?, weight?, style?, align?, baseline?, fill?, advance?, ...}`
- `{kind:"image", image, x, y, w, h, opacity?, angle?, pivot?}` — an embedded
  raster drawn at the rectangle (both `w` and `h` must be positive: the
  canvas image op does not mirror, so nonpositive rectangles are rejected);
  `image` names a resource of the document's `images` list. This kind is
  document-only: the single-diagram `encodeDiagram` keeps its vector-only
  primitive union and rejects it with `unknown primitive kind "image"`

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
  baseline-aware text bands, strokeWidth/2 padding, miter protrusions of
  stroked polyline/polygon joins (`half/sin(theta/2)` clamped by the
  emitted miter limit 10 — `strokedPolylineExtent` exports the same math
  for adapter page fitting), and the rotated AABB about the rotation
  pivot. Negative rect `w`/`h` are normalized to their corner box before
  padding and rotation (the emitted rect op keeps the caller's values, as
  canvas mirrors negative rectangles).
- encoding is deterministic: identical input yields byte-identical output
  (within one platform; `Math.cos/sin` never differ per run, but
  cross-engine f32 rounding of rotation matrices is not guaranteed).
- the input is treated as read-only: primitives are never mutated
  (frozen primitives convert identically).

`encodeDiagramDocument({source, title, pages, images})` applies the same
contract to multi-page documents (any number of `pages`, each its own
`{width, height, primitives}`), with embedded raster resources:

- `pages`: 1..256 pages, at most 20000 primitives per page and 100000 per
  document (the point/text volume caps apply document-wide). The manifest
  carries one `"fixed"` view (`id: "pages"`) whose pages reference one
  object part each.
- `images`: an optional list of `{id, data}` resources — actual bounded
  PNG or JPEG byte arrays, never URLs, paths, strings, SVG, GIF, BMP or
  WebP: nothing is fetched, read or transcoded, and there is no need (or
  allowance) for anything remote. Validation is structural, bounded and
  read-only: the PNG chunk table must be complete inside the bytes (a
  first 13-byte IHDR, at least one non-empty IDAT, a final IEND with no
  trailing bytes, valid chunk lengths, sane bit-depth/color-type pairs),
  and the JPEG segment table too (one frame header, a start of scan, at
  least one entropy byte, an EOI that ends the file, all segment lengths
  in range); truncated or truncated-looking data is rejected, not
  embedded. CRCs and entropy data are not re-verified — the browser
  decodes the very same bytes at draw time. Caps: 256 resources, 4 MiB
  per image, 32 MiB of unique image bytes, 16384 px per side and 2^24
  pixels per raster. IDs are 1..128 characters and unique; identical
  bytes under several IDs are stored once.
- reference integrity holds both ways: every image primitive resolves to
  a resource, and every resource is drawn by at least one page
  (unreferenced bytes never ship).
- emitted shape: one `obj` part per page (`bdf-diagram` object, its image
  table holds the 32-hex part names of the referenced rasters) plus one
  `img` part per unique raster, all identity-encoded, part offsets
  relative to the manifest end exactly as the core reader measures them.
- image primitives wrap in their own `save`/`restore` block like every
  other primitive: `opacity` maps to the alpha op, `angle`/`pivot` to the
  rotation transform about the drawn rectangle's center (or the explicit
  pivot), and the draw itself is the opset-1 image op (table index plus
  x, y, w, h); the drawn rectangle must be positive, and the bounding
  box uses the normalized, rotated AABB of that rectangle.
- encoding stays deterministic (identical input → byte-identical bytes)
  and read-only, and the same `DiagramEncodeError` codes
  (`invalid-input`, `too-large`) classify every rejection.

### The independent reader

`plugin/test/diagram-reader.mjs` opens encoded bytes with the upstream
`@bdfkit/core` package (`parseHeader`, `BufferSource`,
`BdfDocument`, `decodeObject`, `walk`) and returns decoded semantics
(its multi-page counterpart `openDiagramDocument` additionally decodes
every page's layers, per-page ops and a per-part byte accessor for
verifying embedded `img` parts):
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

## Using the plugins and their current release state

The diagram adapters use only the existing plugin API v1 contract surface
(`defineFormatPlugin`, `acceptedParams`, `noPassword`); the encoder they
share (`plugin/diagram-bdf`) is pure ESM with no dependencies, so a Worker
bundle imports it unchanged. Extension claims (`.excalidraw`,
`.excalidraw.json`, `.mmd`, `.mermaid`) do not collide with each other or
with `.xdw`/`.xbd`.

These diagram adapters are included in the published `bdf.mbt@2026.11.1`
package. See [the library quickstart](https://github.com/f4ah6o/bdf.mbt/blob/main/plugin/library/README.md) for
installation and [the release guide](https://github.com/f4ah6o/bdf.mbt/blob/main/docs/npm-release.md) for publication evidence.

Inputs beyond the documented subsets are rejected with named errors or
reported as warnings, never silently dropped — see *Scope and deliberate
limitations* above for exactly what that means per format.

## Running the tests (targeted only)

```sh
node --test plugin/test/diagram-bdf.test.mjs      # shared encoder + reader
node --test plugin/test/diagram-document.test.mjs # multi-page + image encoder
node --test plugin/test/excalidraw.test.mjs      # Excalidraw adapter
node --test plugin/test/mermaid.test.mjs         # Mermaid adapter
```

The document encoder also has a real-Chromium render smoke
(`node plugin/browser/diagram-render-smoke.mjs`, also
`npm run test:plugin:diagram`): the browser encodes a 2-page document
with two embedded synthetic PNGs, the upstream `@bdfkit` core opens the
bytes and `@bdfkit/render`'s `PageRenderer` draws both pages, and pixel
samples prove the images are visible at their rectangles (one of them
half-transparent, one rotated). Raster fixtures are generated in-process
from the PNG/JPEG specifications (`plugin/test/synthetic-image.mjs`).

The tests verify decoded BDF semantics through an independent reader, so
they assert rendering-level behavior (ops, colors, extents), not just byte
shapes.
