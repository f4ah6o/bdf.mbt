# Viewer API compatibility

`api-test.mjs` compares `new Viewer(host, options)` from the installed
`@bdfkit/viewer` package with the local `_build/js` browser build
(`new Viewer(host, options)` and the `bdf_create_viewer` factory extension).
It is a standalone Playwright test: it starts its own static server, loads
`api-test.html` with the upstream import map, supplies both viewers the same
deterministic renderer, and compares the API surface, return values, DOM,
geometry, and events.

Run it after a JavaScript build:

```sh
MOON_HOME=$PWD/.moon-home moon build --target js
node compat/viewer/api-test.mjs
```

The npm script line for package.json (not edited here) is:

```json
"test:viewer": "node compat/viewer/api-test.mjs"
```

## What the test covers

- Constructor surface: `Viewer.name`, `Viewer.length`,
  `Viewer.prototype` methods and getters, descriptors, arities, method names,
  `instanceof EventTarget`, prototype parent, own vs inherited members.
- Construction: `host`, `stage`, `surface`, `renderer`, default
  `single` layout, embedded vs lightbox styles, and the find bar markup
  (labels, roles, buttons, input attributes).
- `open` with a password (forwarded to the renderer), manifest return value,
  `document`/`view`/`pageLayout` getters, `documentchange` and
  `viewchange` details (including identity with the getters), lazy canvas
  loading, page frames, rows, and scroll extents.
- `setView` (missing id, restore, and re-running the find query shown in the
  bar when another view comes), `setLayout` (spread/continuous/single),
  `setZoom` (geometry and `RangeError` for 0, negative, >8, NaN, Infinity,
  and a string), and `scrollToPage` (valid and out-of-range).
- `find`: first/next/previous/same-match states, `findchange` details and
  identity with the resolved state, match marks, automatic scrolling, no-match
  and >1,000-match (`more`) results, `openFind`, `clearFind`, and the
  keyboard path (Ctrl/Cmd+F, Enter, Shift+Enter, Ctrl/Cmd+G, F3, Shift+F3,
  Escape). Focus-mode viewers leave the shortcut outside the viewer to the
  browser.
- `openFile`: converter fallback (`convert`) and streamed conversion
  (`open`/`page`/`finish`/`close`), progress/done events, returned
  manifest, and renderer `addPage`/`replace` calls.
- Lightbox `show`/`hide`, embedded no-ops, page-mode find keys while the
  lightbox is hidden (ignored) and shown (opened), Escape closing the bar,
  and `destroy` (surface removal, shared renderer not terminated, key
  listener removed).
- Return values: setters and controls resolve to `undefined`; `open`,
  `openFile`, and `find` return their documented promises/values.
- `bdf_create_viewer` (local factory extension): own methods, getters,
  EventTarget, not `instanceof Viewer`, and the same open/layout/find
  behavior.

## API differences found and disposition

| Difference | Disposition |
| --- | --- |
| `scrollToPage` returned the `Promise` from the current Chromium `scrollIntoView()` implementation; upstream returns `undefined` because its call is a statement. | Fixed: the facade now uses a block body. |
| `setView` dropped an active search but did not search the query shown in the find bar again in the new view. | Fixed: the controller re-runs the shown query after `viewchange`, matching upstream. |
| The class prototype was installed lazily on construction; every prototype method was an anonymous `length: 0` wrapper and `Viewer.name`/`Viewer.length` were the mangled MoonBit names. | Fixed on first construction: named wrappers have upstream arities, getters exist on the prototype, and `Viewer.name === "Viewer"` and `Viewer.length === 1`. See the remaining gap below. |
| Find-bar shown/query state was internal to the JS snippet, so view changes could not test "the bar goes on". | Added `dom.findShown()` and read it together with `dom.findQuery()` in `setView`. |
| Everything else checked by `api-test.mjs` matched upstream: options and defaults, DOM construction, `show`/`hide`, `open`/`openFile`, getters, `setLayout`, `setMusicMode`, `setZoom`, `find`/`openFind`/`clearFind` and key handling, lightbox keys, sheet/music modes (covered by the existing viewer tests), `destroy`, return values, and event details. | No change needed. |

## Remaining gaps and intentional extensions

- **Prototype before the first construction.** The local `Viewer` binding is a
  MoonBit-exported function. MoonBit `foreign_library` output drops top-level
  initializers that are not part of an export and `#export_name` is only
  valid on functions, so there is no module-load hook to populate
  `Viewer.prototype` before a host inspects it. The prototype, name, length,
  and getters are installed by the
  first `new Viewer(...)` (or a throwing constructor, because installation
  runs first). After that they match upstream. Only code that inspects
  `Viewer.prototype` before constructing any viewer can observe the
  difference; normal host code cannot.
- **`bdf_create_viewer` is a local extension.** It returns a plain object
  whose methods are own properties; it is an `EventTarget` but not
  `instanceof Viewer`. Upstream exports only the class. This is intentional
  for hosts that prefer a factory.
- **Options tolerance.** `new Viewer(host, null)` throws in upstream but is
  treated as an empty options object locally. A non-function truthy
  `options.music` with `musicMode: "piano-roll"` is accepted by upstream at
  construction and fails when it draws, while the local constructor rejects
  it early; with the default score mode both accept it (locally it is then
  treated as no music renderer). The local viewer also reads
  `options.music` live while upstream snapshots it. These are deliberate
  tolerant/stricter local choices, not behavior hosts should rely on.
- **Subclassing and calling without `new`.** Because the constructor returns
  an object rather than using `new.target`, `class Sub extends Viewer` does
  not produce a `Sub` instance locally (upstream supports it), and calling
  `Viewer(host, options)` without `new` returns a viewer where the upstream
  class throws. MoonBit-exported functions have no `new.target` hook to
  distinguish the two calls. Hosts should use `new Viewer(...)` or
  `bdf_create_viewer(...)` and compose rather than subclass. The prototype
  methods also expect the internal method slot that only a constructed viewer
  has.
- **Default render worker URL.** Upstream calls `createRenderWorker()` from
  `@bdfkit/render`; local derives the worker URL from the loaded
  `browser/browser.js` resource URL or from the local-only
  `options.workerUrl`. Existing worker/viewer compatibility tests cover the
  result.
- **Find location batching.** Upstream locates hits a page (or sheet tile) at
  a time; the local viewer batches the near hits of a search into one
  `renderer.locate` call. The public match marks, revealed position, and
  `findchange`/bar state are the same. A custom renderer can observe the
  different number of `locate` calls.
- **Non-renderer error identity.** Renderer, page, search, and converter
  failures keep the original error object (covered by
  `compat/continuous/viewer-error-test.mjs`). A manifest parse failure is
  wrapped locally because it crosses the MoonBit async boundary; upstream
  would deliver the parser's original error.
- **Sheet/music modes.** The standalone API test does not duplicate the
  dedicated upstream comparisons. They remain covered by
  `compat/continuous/viewer-music-test.mjs`,
  `compat/sheet/viewer-api-test.mjs`, and the rest of the viewer suite
  invoked by `compat/visual/compare.mjs`. Sheet find/tile edge cases are
  covered for a single query; arbitrary multi-tile locate patterns are not
  fuzzed.

## Verification

```sh
MOON_HOME=$PWD/.moon-home moon build --target js              # pass
MOON_HOME=$PWD/.moon-home moon test --target js -p browser    # 13/13
MOON_HOME=$PWD/.moon-home moon test --target js -p viewer     # 4/4
MOON_HOME=$PWD/.moon-home moon test --target wasm-gc -p viewer # 4/4
MOON_HOME=$PWD/.moon-home moon build --target wasm-gc viewer  # pass
node compat/viewer/api-test.mjs                               # viewer API compatibility: ok
```

The existing viewer comparisons were also run against the local build after
the changes: `viewer-api`, `viewer-file`, `viewer-find`, `viewer-errors`,
`viewer-music`, and `viewer-sheet` all pass.
