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

This currently supports fixed/flow, scroll and sheet BDF documents whose BOBJ parts use
the implemented drawing subset. It does not try to convert
PDF/Office documents. The asynchronous entry point loads image and embedded font
parts before drawing and retains them for the lifetime of the mounted view. It supports raster images, SVG,
and image patterns. A Worker-backed viewer is available as described below; additional viewer features remain in progress.

## Worker-backed viewer

```js
const viewer = bdf_create_viewer(document.querySelector('#preview'), {
  workerUrl: '/render_worker.js',
  layout: 'single',
});
await viewer.open({ kind: 'single', url: '/sample.bdf', range: true });
viewer.setLayout('spread');
viewer.setZoom(1.5);
await viewer.find('text');
viewer.destroy();
```

The returned object provides `stage`, `surface`, `renderer`, document and view
getters, and emits `documentchange`, `viewchange`, `findchange`, and conversion
events. Supply an existing `renderer` to retain ownership of that client. A
converter with `open`, `page`, `finish`, and `close` methods can be passed to
`openFile` for incremental conversion. The viewer implementation is still
being checked against the complete upstream API and edge cases.

Asynchronous page mounts use an `IntersectionObserver` with a 600-pixel
margin to load and draw nearby pages. They release a page's Canvas backing
store when it leaves that region and redraw it when it returns. Split
documents fetch image, path and other drawing resources on demand. Interactive
mounts currently preload text objects and fonts for synchronous search and
selection. Without `IntersectionObserver`, mounts fall back to eager drawing
and a 256-page limit; the synchronous `mount_bdf` also uses eager drawing.

For a sheet, the asynchronous mount uses the host's width and height as its
viewport, fetching visible tiles as it scrolls. Give the host dimensions in CSS;
when they are absent, it defaults to 640 by 400 pixels. It returns `1` for the
sheet view. `unmount_bdf` releases images, fonts, observers and pending work.
The interactive entry points add selectable text and safe links for loaded
tiles, retaining visited text layers while scrolling. Each tile currently has
its own accessible table; a single combined accessibility tree and frozen
panes are still being ported. The synchronous `mount_bdf` entry point supports
fixed/flow pages and scroll strips without asynchronous resources.

Scroll strips are stacked without gaps regardless of the requested page layout.
For fixed and flow views, `continuous` mounts full pages without gaps, matching
the upstream viewer. A constrained host remains a scrollable viewport while
the page surface holds the full document extent. To render the cropped body
rectangles and configured gap of a flow view, use the continuous-region
renderer below.

For a mounted fixed, flow, scroll or sheet view, the controls change the
rendering without reloading the document:

```js
bdf_set_zoom(host, 1.5);           // finite values greater than 0 and at most 8
bdf_set_layout(host, 'spread');    // 'single', 'spread', or 'continuous'
bdf_scroll_to_page(host, 2);      // zero-based; an invalid index is ignored
```

Zoom redraws from the original objects at the current device pixel ratio and
keeps the active text selection and search results aligned. A sheet redraws
the visible tiles asynchronously and returns to its origin on zoom or layout
changes, as the upstream viewer does. Raster images and
fonts remain loaded until the host is unmounted, remounted, or removed from
the document. Page bitmaps are limited to 8192 pixels per side and 16,777,216
pixels in total; a zoom that exceeds these limits for a visible page fails
without changing the current view. Newly visible oversized pages report an
`error` event. Page zoom rendering is asynchronous. Layout choice and page navigation apply to page views; a sheet
keeps its layout. A page view with MIDI can switch between its score and a
piano roll:

```js
await bdf_set_music_mode_async(host, 'piano-roll');
await bdf_set_music_mode_async(host, 'score');
```

The piano roll follows zoom, has no searchable text, and loads split MIDI parts
on demand. Views without a MIDI sequence remain in their current display.

Views containing a recording can create a player after mounting. Pass an
existing audio element to show its native controls, or `null` to create one:

```js
const player = await bdf_audio_player_for_view_async(host, null);
if (player) {
  player.onUpdate = () => console.log(player.state, player.position);
  playButton.addEventListener('click', () => player.play());
  pauseButton.addEventListener('click', () => player.pause());
  // player.seek(10) seeks in seconds.
  // player.cursorAt(player.position) returns the current cue line.
  // player.timeAt(0) returns the nearest occurrence of system 0.
}
```

Create the player before the click, then call `play()` in the user gesture;
browsers may block playback started outside one.

The player also exposes `duration`, `playing`, `speedPercent`,
`setSpeedPercent`, `stop`, `onEnd`, and `onError`. Split recordings and cues
are loaded on demand. Unmounting or replacing the host disposes its players;
an absent recording returns `null`. For independent data, use
`bdf_audio_player(bytesOrBlob, mediaType, cuesOrNull, elementOrNull)` and
dispose the returned player when finished. The cue object uses the upstream
`{ systems, cues }` format.

For a MIDI view, prepare a player and start it from a user gesture:

```js
const music = await bdf_music_player_for_view_async(host, null);
if (music) {
  music.onUpdate = () => console.log(music.state, music.position);
  playButton.addEventListener('click', () => music.play());
  pauseButton.addEventListener('click', () => music.pause());
  music.setSpeedPercent(125);
  music.setMetronome(true);
  // music.cursorAt(music.position) locates the cursor in the score.
  // music.timeAt(system, x) finds the nearest playback time at that position.
}
```

The player synthesizes General MIDI instruments and drums with Web Audio,
including pitch bend, channel controls, sustain, tempo changes and the
metronome. It loads split MIDI and cue parts on demand, and closes its audio
context when disposed or when the host is unmounted. An absent MIDI sequence
returns `null`. `bdf_music_player(bytesOrSequence, cuesOrNull, optionsOrNull)`
creates an independent player. Options include `context`, `volume`,
`lookahead`, and `interval`, as in the upstream player. Playback currently uses
a snapshot of the sequence at construction; later changes to the supplied or
exposed sequence object are not reflected yet.

## Converter Worker

The MoonBit converter can run BMP, ICO and JPEG conversion without a Go runtime.
Build with `moon build --target js` and serve the generated
`native_converter_worker/native_converter_worker.js`:

```js
const converter = bdf_create_native_converter('/native_converter_worker.js');
const formats = await converter.ready;
const result = await converter.convert(inputBytes, { name: 'picture.bmp' });
converter.terminate();
```

`open()` returns the complete document with `pages: 0` for these formats.
The native Worker currently supports BMP, ICO and JPEG, and rejects the `fonts`
option. JPEG EXIF, IPTC and well-formed UTF-8 or BOM-marked UTF-16 XMP metadata are
supported. Malformed XMP and other character encodings are not yet supported. `bdf_converter_client`
can also wrap its Worker; pass an empty Wasm URL. Other image formats and the
other conversion engines remain to be ported.

The converter client can also run an existing compatible Go or TinyGo converter Wasm
module in a dedicated Worker. Build with `moon build --target js` and serve the
generated `converter_worker/converter_worker.js` alongside the matching
compiler's `wasm_exec.js` and the converter Wasm file. The `runtime` query
parameter identifies the JavaScript runtime relative to the Worker URL:

```js
const workerUrl = new URL('/converter_worker.js', location.href);
workerUrl.searchParams.set('runtime', '/wasm_exec.js');
const converter = bdf_create_converter(workerUrl.href, '/converter.wasm');
const formats = await converter.ready;
const result = await converter.convert(inputBytes, { name: 'report.pdf' });
const opened = await converter.open(inputBytes, { name: 'report.pdf' });
if (opened.stream) {
  const firstPage = await converter.page(opened.stream, 0);
  const complete = await converter.finish(opened.stream);
  await converter.close(opened.stream);
}
converter.terminate();
```

`bdf_converter_client(worker, wasmUrl)` accepts an existing Worker instead.
The runtime JavaScript must match the compiler used for the Wasm module. The
Go/TinyGo Worker transport requires a separately supplied converter module.

```js
const bandsDrawn = await render_bdf_continuous_region_async(host, bytes, x, y, width, height, scale);
// For split BDF: await render_bdf_continuous_region_split_async(host, manifest, loadPart, x, y, width, height, scale);
// For encrypted BDF: await render_bdf_continuous_region_encrypted_async(host, bytes, credential, x, y, width, height, scale);
// For encrypted split BDF: await render_bdf_continuous_region_encrypted_split_async(host, manifest, loadPart, credential, x, y, width, height, scale);
```

The region uses page-body coordinates, draws body and annotation layers, and
returns the count of intersecting page bodies. Gaps and areas outside the
bodies are transparent. The asynchronous split renderer loads only intersecting
pages, including when the document is encrypted.

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
const selectedCells = await bdf_selection_cells_async(host); // absent unless the selection spans cells
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
and cut; the cell-selection APIs reject them. Sheet selections expand across
merged cells and omit hidden rows and columns. To avoid incomplete copies, a
selection may load the text of unvisited tiles. `bdf_selection_cells_async`
waits for this data; `bdf_selection_cells` throws while it is still loading.
Copying during that interval uses the browser's asynchronous ClipboardItem
API; if it is unavailable, an `error` event asks the user to copy again after
loading.
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
