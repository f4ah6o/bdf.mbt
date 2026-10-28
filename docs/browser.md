# Browser MVP

The `browser` package compiles to a JS-target foreign library exporting
`mount_bdf_async`, `mount_bdf_split_async`, the encrypted-document entry points, and `mount_bdf`. It draws a BDF document into Canvas elements without the original
TypeScript renderer. The BDF parser, command decoder and page positions are MoonBit.

```sh
moon build --target js
# Find the linked browser artifact under _build/js.
```

```js
// import { mount_bdf_async, mount_bdf_split_async, mount_bdf_encrypted_async, mount_bdf_encrypted_split_async, mount_bdf } from "<compiled browser JS module>";
const bytes = new Uint8Array(await (await fetch("/sample.bdf")).arrayBuffer());
const pageCount = await mount_bdf_async(document.querySelector("#preview"), bytes, "spread");
// mount_bdf is synchronous and supports documents without images or embedded fonts.
```

This currently supports fixed/flow and sheet BDF documents whose BOBJ parts use
the implemented drawing subset. It does not try to convert
PDF/Office documents. The asynchronous entry point loads image and embedded font
parts before drawing and releases them afterward. It supports raster images, SVG,
and image patterns. A complete port needs Worker transport and additional viewer features.

For a sheet, the asynchronous mount uses the host's width and height as its
viewport, fetching visible tiles as it scrolls. Give the host dimensions in CSS;
when they are absent, it defaults to 640 by 400 pixels. It returns `1` for the
sheet view. `unmount_bdf` releases images, fonts, observers and pending work.
The interactive entry points add selectable text and safe links for loaded
tiles, retaining visited text layers while scrolling. Rectangular sheet-cell
selection and frozen panes are still being ported. The synchronous
`mount_bdf` entry point supports fixed/flow pages only.

To draw a single sheet region instead of a scrolling view, use the single or
split viewport entry point. Coordinates and dimensions are document units;
`scale` is device pixels per unit. The returned number is the count of visible
tiles drawn.

```js
const tilesDrawn = await render_bdf_sheet_region_async(host, bytes, x, y, width, height, scale);
// For split BDF: await render_bdf_sheet_region_split_async(host, manifest, loadPart, x, y, width, height, scale);
```


For a split document, supply the UTF-8 manifest bytes and a loader that
returns each stored part as a `Uint8Array`. The loader receives the validated
part hash and the maximum stored size from the manifest. It must enforce this
limit while reading or downloading, before buffering the entire response. The
library verifies the returned size and decodes the part. Only parts referenced
by the selected view are requested, at most once each.

```js
const manifest = new Uint8Array(await (await fetch('/split/manifest.json')).arrayBuffer());
const loadPart = async (hash, limit) => {
  const response = await fetch(`/split/parts/${hash}`);
  if (!response.ok || !response.body) throw new Error('part request failed');
  const reader = response.body.getReader();
  const chunks = [];
  let size = 0;
  try {
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      size += value.length;
      if (size > limit) throw new Error('part exceeds declared size');
      chunks.push(value);
    }
  } finally { await reader.cancel(); }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
  return bytes;
};
const pages = await mount_bdf_split_async(host, manifest, loadPart, 'single');
```


Encrypted single-file documents can be mounted in a secure browser context
using a password or a Web Crypto P-256 `CryptoKeyPair`:

```js
await mount_bdf_encrypted_async(host, bytes, password, 'single');
// Alternatively: await mount_bdf_encrypted_async(host, bytes, keyPair, 'single');
```

For split documents, use the same bounded part loader described above:

```js
await mount_bdf_encrypted_split_async(host, manifest, loadPart, password, 'single');
```

The browser derives the wrapping key with PBKDF2 or ECDH/HKDF and opens the
content key and authenticated parts with Web Crypto. Wrong credentials,
invalid key slots, and altered ciphertext cause the promise to reject. The
password is normalized using NFKC. These entry points require Web Crypto, which
browsers expose in secure contexts such as HTTPS and localhost.


Selectable text and safe links are available through the interactive variants (import these functions from the same compiled module):

```js
await mount_bdf_interactive_async(host, bytes, 'single');
// mount_bdf_interactive_split_async(host, manifest, loadPart, layout)
// mount_bdf_interactive_encrypted_async(host, bytes, passwordOrKeyPair, layout)
// mount_bdf_interactive_encrypted_split_async(host, manifest, loadPart, passwordOrKeyPair, layout)
const selectedText = bdf_selection_text(host);
const selectedCells = bdf_selection_cells(host); // undefined unless the selection spans table cells
// selectedCells, when present, has text (TSV) and html properties.
const found = await bdf_find_async(host, 'example', 0); // { query, index, total, more, detail, rects }
bdf_open_find(host); // show the search field
bdf_clear_find(host); // clear highlights and close the field
unmount_bdf(host);
```

The text layer includes headings, lists, tables, figures, language attributes,
and links restricted to HTTP, HTTPS, mailto and BDF internal fragments. Copy
and cut serialize selected text using the document's run separators. A selection
spanning cells of the same table expands to include intersecting merged cells;
copy and cut provide both TSV and an HTML table. A selection within a single
cell stays a text selection. Oversized cell ranges fall back to text for copy
and cut; `bdf_selection_cells` rejects them.
The search field handles Command/Ctrl+F, Command/Ctrl+G, F3, Enter,
Shift+Enter, and Escape while the host has focus. It waits for IME composition
to finish before searching and marks matches using the loaded font metrics.
`bdf_find_async` accepts step `0` for the current match, `1` for next, and `-1` for
previous; the result's index is zero-based and `more` indicates a 1,000-hit
limit. An interactive split page mount attempts to prefetch its stored text index;
if that fails, rendering remains available and search reports the error. Sheet
search loads a stored index on demand, or rebuilds one from tile text when it
is absent; it loads fonts only for hits being located. The synchronous
`bdf_find` API remains available for fixed/flow views.
Embedded fonts remain loaded until the host is unmounted, remounted, or removed
from the document. Viewer navigation between views is not yet implemented.
