import assert from 'node:assert/strict';
import { createReadStream, existsSync } from 'node:fs';
import { createServer } from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';

// Viewer sheet selection and copy through a real rendering Worker. The moon
// viewer (bdf_create_viewer) opens the synthetic multi-tile sheet fixture
// (compat/sheet/cells.bdf), which has hidden row/column runs, cell merges and
// text far outside a small viewport. The test selects cells across tiles,
// holds the selection while the far tile is scrolled out of view, and checks
// the rectangle sent over the sheetClipboard Worker RPC, the TSV and HTML
// it returns (against the upstream @bdfkit/render serialization of the same
// range), the synchronous and copy-event paths once loaded, the pending state
// while the RPC is in flight, and rejection/clipboarderror handling when a
// split document is missing a tile object part.
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const localBuilds = [
  '_build/js/debug/build/browser/browser.js',
  '_build/js/debug/build/render_worker/render_worker.js',
];
for (const build of localBuilds) {
  if (!existsSync(path.join(root, build))) {
    throw new Error('missing local build ' + build + '; run: moon build browser render_worker --target js');
  }
}

// The page may read the local builds, the upstream packages used as the
// clipboard reference, the sheet fixtures, and a split-part mirror that
// answers 404 for one object part. Everything else is refused. The missing
// part is the tile (1,0) object of compat/sheet/cells-split.
const allowed = [
  '/compat/sheet/cells.bdf',
  '/compat/sheet/cells-split/',
  '/node_modules/@bdfkit/core/',
  '/node_modules/@bdfkit/render/',
  '/_build/js/debug/build/browser/',
  '/_build/js/debug/build/render_worker/',
];
const splitMissing = '/split-missing/';
const missingPart = '6ab7a454cff896ab3a5f366c6bf7d2dd';
const types = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.bdf': 'application/octet-stream',
  '.json': 'application/json',
};
const server = createServer((request, response) => {
  let pathname;
  try { pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname); }
  catch { response.writeHead(400).end(); return; }
  if (pathname === '/' || pathname === '/viewer-selection.html') {
    response.setHeader('Content-Type', 'text/html; charset=utf-8');
    response.end('<!doctype html><meta charset="utf-8"><title>viewer sheet selection</title>'
      + '<script type="importmap">{"imports":{"@bdfkit/core":"/node_modules/@bdfkit/core/dist/index.js","@bdfkit/render":"/node_modules/@bdfkit/render/dist/index.js"}}</script>');
    return;
  }
  let file = pathname;
  if (pathname.startsWith(splitMissing)) {
    const rest = pathname.slice(splitMissing.length);
    if (rest === 'parts/' + missingPart) {
      response.writeHead(404).end();
      return;
    }
    file = '/compat/sheet/cells-split/' + rest;
  }
  const resolved = path.resolve(root, '.' + file);
  if (!allowed.some((prefix) => resolved.startsWith(path.resolve(root, '.' + prefix) + path.sep) || resolved === path.join(root, prefix))) {
    response.writeHead(403).end(); return;
  }
  const stream = createReadStream(resolved);
  stream.once('error', () => { if (!response.headersSent) response.writeHead(404); response.end(); });
  response.setHeader('Content-Type', types[path.extname(resolved)] ?? 'application/octet-stream');
  stream.pipe(response);
});
await new Promise((resolve, reject) => {
  server.once('error', reject);
  server.listen(0, '127.0.0.1', resolve);
});
const base = 'http://127.0.0.1:' + server.address().port;

const browser = await chromium.launch({ headless: true });
try {
  const page = await browser.newPage({ viewport: { width: 900, height: 700 } });
  const browserErrors = [];
  page.on('pageerror', (error) => browserErrors.push(String(error)));
  await page.goto(base + '/viewer-selection.html', { waitUntil: 'networkidle' });
  const result = await page.evaluate(async () => {
    const moon = await import('/_build/js/debug/build/browser/browser.js');
    const workerUrl = '/_build/js/debug/build/render_worker/render_worker.js';
    const bytes = async (file) => new Uint8Array(await (await fetch(file)).arrayBuffer());
    const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
    const wait = async (check, what) => {
      const start = performance.now();
      while (!check()) {
        if (performance.now() - start > 8000) throw new Error('viewer timed out: ' + what);
        await sleep(10);
      }
    };
    const spanIn = (host, key, text) => {
      const layer = host.querySelector(`[data-bdf-sheet-tile="${key}"]`);
      return layer && [...layer.querySelectorAll('[data-bdf-ordinal]')].find((span) => span.textContent === text);
    };
    const selectBetween = (a, b) => {
      if (!a || !b) throw new Error('selection span missing');
      const range = document.createRange();
      range.setStart(a.firstChild, 0);
      range.setEnd(b.firstChild, b.firstChild.textContent.length);
      const selection = getSelection();
      selection.removeAllRanges();
      selection.addRange(range);
      document.dispatchEvent(new Event('selectionchange'));
    };

    // Upstream reference for the same ranges: the fixture's raw view is
    // deserialized with @bdfkit/core and serialized with @bdfkit/render,
    // skipping the hidden row 2 and column 2 run.
    const { BdfDocument, BufferSource, extractContent } = await import('/node_modules/@bdfkit/core/dist/index.js');
    const { tableCells, cellClipboard, concat } = await import('/node_modules/@bdfkit/render/dist/index.js');
    const referenceDoc = await BdfDocument.open(new BufferSource(await bytes('/compat/sheet/cells.bdf')));
    const view = referenceDoc.manifest.views[0];
    const tiles = Object.entries(view.tiles)
      .map(([key, hash]) => { const [x, y] = key.split(',').map(Number); return { x, y, hash }; })
      .sort((a, b) => a.y - b.y || a.x - b.x);
    const parts = [];
    for (const tile of tiles) {
      const object = await referenceDoc.ensure(tile.hash);
      const content = extractContent(object, (hash) => referenceDoc.objectSync(hash));
      parts.push({
        ...content,
        runs: content.runs
          .filter((run) => run.x >= 0 && run.x < view.tile && run.y >= 0 && run.y < view.tile)
          .map((run) => ({ ...run, x: run.x + tile.x * view.tile, y: run.y + tile.y * view.tile })),
      });
    }
    const referenceCells = tableCells(concat(parts));
    const referenceFor = (range) => cellClipboard(referenceCells, range, { skipRow: (row) => row === 2, skipCol: (col) => col === 2 });

    // A viewer with a recording client: sheetClipboard calls and their ranges
    // are captured, and the hold gate defers one RPC for the pending case.
    const makeViewer = async (source) => {
      const host = document.createElement('div');
      host.style.cssText = 'width:120px;height:120px;position:relative';
      document.body.append(host);
      const client = moon.bdf_render_worker_client(new Worker(workerUrl, { type: 'module' }));
      const calls = [];
      const hold = { gate: null };
      const renderer = new Proxy(client, {
        get(target, name) {
          const value = target[name];
          if (name === 'sheetClipboard') {
            return (view, range) => {
              calls.push({ view, range: { ...range } });
              const called = value.call(target, view, range);
              return hold.gate ? hold.gate.then(() => called) : called;
            };
          }
          return typeof value === 'function' ? value.bind(target) : value;
        },
      });
      const viewer = moon.bdf_create_viewer(host, { renderer, find: false });
      await viewer.open(source);
      const scroll = (x, y) => {
        viewer.stage.scrollLeft = x;
        viewer.stage.scrollTop = y;
        viewer.stage.dispatchEvent(new Event('scroll'));
      };
      return { host, viewer, client, calls, hold, scroll };
    };

    const out = {};

    // Scenario 1: selection across tiles, merged cells, hidden axes and an
    // offscreen far tile, retained while scrolled back to the origin.
    const main = await makeViewer({ kind: 'buffer', buffer: (await bytes('/compat/sheet/cells.bdf')).buffer });
    try {
      await wait(() => !!main.host.querySelector('canvas'), 'sheet canvas');
      await wait(() => !!spanIn(main.host, '0,0', 'Header'), 'visible text layer');
      main.scroll(512, 0);
      await wait(() => !!spanIn(main.host, '2,0', 'Far'), 'far text tile');
      selectBetween(spanIn(main.host, '0,0', 'Header'), spanIn(main.host, '2,0', 'Far'));
      const crossTiles = await moon.bdf_selection_cells_async(main.host);
      const clippedCall = main.calls.at(-1);
      main.scroll(0, 0);
      const scrolledBack = await moon.bdf_selection_cells_async(main.host);
      const synced = moon.bdf_selection_cells(main.host);
      const copy = new ClipboardEvent('copy', { bubbles: true, cancelable: true, clipboardData: new DataTransfer() });
      main.host.dispatchEvent(copy);
      const tint = getComputedStyle(spanIn(main.host, '0,0', 'Apple'), '::selection').backgroundColor;
      out.cross = {
        tint,
        range: clippedCall && clippedCall.range,
        reference: referenceFor(clippedCall && clippedCall.range),
        tileMounts: [...main.host.querySelectorAll('[data-bdf-sheet-tile]')].map((el) => el.dataset.bdfSheetTile).sort(),
        value: crossTiles,
        scrolledBack,
        synced,
        copy: { handled: copy.defaultPrevented, text: copy.clipboardData.getData('text/plain'), html: copy.clipboardData.getData('text/html') },
        box: (() => { const box = main.host.querySelector('[data-bdf-cellbox]'); const r = box && box.getBoundingClientRect(); return r ? { x: r.x, y: r.y, width: r.width, height: r.height } : null; })(),
      };
    } finally {
      main.viewer.destroy();
      main.client.terminate();
      main.host.remove();
    }

    // Scenario 2: copy while the sheetClipboard request is still loading: the
    // ClipboardItem + navigator.clipboard.write branch with promise-valued
    // blobs (mocked native clipboard, real Worker), its rejected-write
    // reporting, and the copy-again fallback without ClipboardItem.
    const pending = await makeViewer({ kind: 'buffer', buffer: (await bytes('/compat/sheet/cells.bdf')).buffer });
    const clipboardEvents = [];
    pending.host.addEventListener('clipboarderror', (event) => { clipboardEvents.push(String(event.detail)); });
    const priorClipboard = Object.getOwnPropertyDescriptor(navigator, 'clipboard');
    const priorItem = window.ClipboardItem;
    const written = [];
    const clip = {
      deny: false,
      write(items) {
        written.push(items[0]);
        return clip.deny ? Promise.reject(new Error('mock clipboard denied')) : Promise.resolve();
      },
    };
    window.ClipboardItem = class { constructor(types) { this.types = types; } };
    Object.defineProperty(navigator, 'clipboard', { configurable: true, value: clip });
    try {
      await wait(() => !!pending.host.querySelector('canvas'), 'pending sheet canvas');
      await wait(() => !!spanIn(pending.host, '0,0', 'Header'), 'pending visible text layer');
      pending.scroll(300, 0);
      await wait(() => !!spanIn(pending.host, '1,0', 'East'), 'pending column-E tile');
      pending.scroll(512, 0);
      await wait(() => !!spanIn(pending.host, '2,0', 'Far'), 'pending far tile');
      const pick = (text, key) => spanIn(pending.host, key, text);
      let release;
      pending.hold.gate = new Promise((resolve) => { release = resolve; });
      selectBetween(pick('East', '1,0'), pick('Far', '2,0'));
      let pendingThrow = null;
      try { moon.bdf_selection_cells(pending.host); } catch (error) { pendingThrow = String(error); }
      const asyncValue = moon.bdf_selection_cells_async(pending.host).then(
        (value) => ({ done: true, value }),
        (error) => ({ done: false, error: String(error) }),
      );
      await sleep(30);
      const early = await Promise.race([asyncValue, sleep(50).then(() => 'in-flight')]);
      const firstRange = { ...pending.calls.at(-1).range };
      // While the request is held, copy hands the native writer ClipboardItem
      // items whose typed blobs are promises over the RPC result.
      const heldCopy = new ClipboardEvent('copy', { bubbles: true, cancelable: true, clipboardData: new DataTransfer() });
      const errorsBeforeCopy = clipboardEvents.length;
      pending.host.dispatchEvent(heldCopy);
      await sleep(30);
      const captured = written.find((item) => item.types && 'text/plain' in item.types && item.types['text/html'] instanceof Promise);
      const promiseValued = !!captured && captured.types['text/plain'] instanceof Promise;
      const heldData = { handled: heldCopy.defaultPrevented, empty: heldCopy.clipboardData.getData('text/plain') === '' };
      release();
      const deferred = { text: await (await captured.types['text/plain']).text(), html: await (await captured.types['text/html']).text() };
      const resolved = await asyncValue;
      const synced = moon.bdf_selection_cells(pending.host);
      const writeQuiet = clipboardEvents.length === errorsBeforeCopy;
      // A rejected native write is reported through clipboarderror.
      clip.deny = true;
      let releaseDeny;
      pending.hold.gate = new Promise((resolve) => { releaseDeny = resolve; });
      selectBetween(pick('Value', '1,0'), pick('Far', '2,0'));
      const deniedCopy = new ClipboardEvent('copy', { bubbles: true, cancelable: true, clipboardData: new DataTransfer() });
      pending.host.dispatchEvent(deniedCopy);
      await sleep(30);
      releaseDeny();
      await sleep(30);
      const deniedReported = clipboardEvents.some((entry) => entry.includes('mock clipboard denied'));
      // Without ClipboardItem or navigator.clipboard.write, a pending copy
      // answers with a copy-again clipboarderror and a later copy answers
      // synchronously from the loaded cache.
      window.ClipboardItem = undefined;
      Object.defineProperty(navigator, 'clipboard', { configurable: true, value: undefined });
      let releaseFallback;
      pending.hold.gate = new Promise((resolve) => { releaseFallback = resolve; });
      selectBetween(pick('Merged', '0,0'), pick('Value', '1,0'));
      const earlyFallback = new ClipboardEvent('copy', { bubbles: true, cancelable: true, clipboardData: new DataTransfer() });
      pending.host.dispatchEvent(earlyFallback);
      await sleep(30);
      const fallbackEarly = {
        handled: earlyFallback.defaultPrevented,
        empty: earlyFallback.clipboardData.getData('text/plain') === '',
        askedAgain: clipboardEvents.some((entry) => entry.includes('copy again when ready')),
      };
      releaseFallback();
      const fallbackLoaded = await moon.bdf_selection_cells_async(pending.host);
      const retryFallback = new ClipboardEvent('copy', { bubbles: true, cancelable: true, clipboardData: new DataTransfer() });
      pending.host.dispatchEvent(retryFallback);
      const fallbackRetry = { handled: retryFallback.defaultPrevented, text: retryFallback.clipboardData.getData('text/plain'), html: retryFallback.clipboardData.getData('text/html') };
      const fallbackRange = { ...pending.calls.at(-1).range };
      out.pending = {
        pendingThrow, early, resolved, synced,
        range: firstRange, reference: referenceFor(firstRange),
        write: { promiseValued, ...heldData, deferred, writeQuiet },
        deniedReported,
        fallback: { ...fallbackEarly, loaded: fallbackLoaded, retry: fallbackRetry, range: fallbackRange, reference: referenceFor(fallbackRange) },
      };
    } finally {
      if (priorClipboard) Object.defineProperty(navigator, 'clipboard', priorClipboard); else delete navigator.clipboard;
      window.ClipboardItem = priorItem;
      pending.viewer.destroy();
      pending.client.terminate();
      pending.host.remove();
    }

    // Scenario 3: a split document missing one tile part fails the clipboard
    // RPC with the viewer's clipboarderror event and a rejected async query.
    const broken = await makeViewer({ kind: 'split', base: '/split-missing/' });
    try {
      await wait(() => !!broken.host.querySelector('canvas'), 'broken sheet canvas');
      await wait(() => !!spanIn(broken.host, '0,0', 'Header'), 'broken visible text layer');
      broken.scroll(512, 0);
      await wait(() => !!spanIn(broken.host, '2,0', 'Far'), 'broken far tile');
      const events = [];
      const viewerErrors = [];
      broken.host.addEventListener('clipboarderror', (event) => { events.push(String(event.detail)); });
      broken.viewer.addEventListener('error', (event) => { viewerErrors.push(String(event.detail)); event.preventDefault(); });
      selectBetween(spanIn(broken.host, '0,0', 'Header'), spanIn(broken.host, '2,0', 'Far'));
      let syncThrow = null;
      try { moon.bdf_selection_cells(broken.host); } catch (error) { syncThrow = String(error); }
      let failure = null;
      try { await moon.bdf_selection_cells_async(broken.host); } catch (error) { failure = String(error); }
      await sleep(30);
      out.failure = { syncThrow, failure, events, viewerErrors };
    } finally {
      broken.viewer.destroy();
      broken.client.terminate();
      broken.host.remove();
    }
    // Scenario 4: a tile content load failure is a rendering error on the
    // viewer's error channel, never a clipboarderror.
    const tileFailing = await makeViewer({ kind: 'split', base: '/split-missing/' });
    const tileClipboard = [];
    const tileErrors = [];
    tileFailing.host.addEventListener('clipboarderror', (event) => { tileClipboard.push(String(event.detail)); });
    tileFailing.viewer.addEventListener('error', (event) => { tileErrors.push(String(event.detail)); event.preventDefault(); });
    try {
      await wait(() => !!tileFailing.host.querySelector('canvas'), 'tile-failure sheet canvas');
      await wait(() => !!spanIn(tileFailing.host, '0,0', 'Header'), 'tile-failure visible layer');
      tileFailing.scroll(300, 0);
      await wait(() => tileErrors.length > 0, 'tile content failure reported as a viewer error');
      await sleep(100);
      out.tileFailure = { tileErrors, tileClipboard };
    } finally {
      tileFailing.viewer.destroy();
      tileFailing.client.terminate();
      tileFailing.host.remove();
    }

    return out;
  });

  // Scenario 1 assertions: Header (A1) to Far (G4) grows over the merged
  // cells into rows 0..4 and columns 0..6; row 2 and column 2 are hidden runs.
  const fullRange = { row0: 0, col0: 0, row1: 4, col1: 6 };
  const reference = result.cross.reference;
  assert.deepEqual(result.cross.range, fullRange, 'cell rectangle sent over the sheetClipboard RPC');
  assert.deepEqual(result.cross.tileMounts, ['0,0', '2,0'], 'only the visited tiles are mounted');
  assert.deepEqual(result.cross.value, reference, 'cross-tile selection TSV/HTML matches upstream serialization');
  assert.equal(result.cross.value.text.includes('East'), true, 'cells from the unmounted tile (1,0) are included');
  assert.deepEqual(result.cross.scrolledBack, reference, 'selection survives scrolling back to the origin');
  assert.deepEqual(result.cross.synced, reference, 'synchronous clipboard after loading');
  assert.deepEqual(result.cross.copy, { handled: true, text: reference.text, html: reference.html }, 'copy event carries the TSV/HTML');
  assert.ok(result.cross.box && result.cross.box.width > 0 && result.cross.box.height > 0, 'cell selection box is drawn');
  assert.equal(result.cross.tint, 'rgba(0, 0, 0, 0)', 'native selection tint is suppressed inside sheet cell rectangles');

  // Scenario 2 assertions: while the RPC is in flight the synchronous API
  // throws, the async query does not resolve, copy defers through a
  // ClipboardItem with promise-valued blobs, a rejected write reports
  // clipboarderror, and the no-ClipboardItem fallback asks for a retry.
  assert.match(result.pending.pendingThrow, /still loading/, 'synchronous call reports the pending state');
  assert.equal(result.pending.early, 'in-flight', 'the async query does not resolve while held');
  assert.deepEqual(result.pending.range, { row0: 0, col0: 4, row1: 3, col1: 6 }, 'pending rectangle');
  assert.equal(result.pending.resolved.done, true, 'async query resolves after the RPC completes');
  assert.deepEqual(result.pending.resolved.value, result.pending.reference, 'pending selection matches upstream once loaded');
  assert.deepEqual(result.pending.synced, result.pending.resolved.value, 'synchronous clipboard after the pending RPC');
  assert.deepEqual(result.pending.write, {
    promiseValued: true,
    handled: true,
    empty: true,
    deferred: result.pending.reference,
    writeQuiet: true,
  }, 'pending copy defers through promise-valued ClipboardItem blobs without errors');
  assert.equal(result.pending.deniedReported, true, 'a rejected native write reports clipboarderror');
  assert.deepEqual(result.pending.fallback.range, { row0: 0, col0: 1, row1: 1, col1: 4 }, 'fallback rectangle');
  assert.equal(result.pending.fallback.handled, true, 'early copy without ClipboardItem is still handled');
  assert.equal(result.pending.fallback.empty, true, 'early copy without ClipboardItem writes no data');
  assert.equal(result.pending.fallback.askedAgain, true, 'early copy without ClipboardItem asks to copy again');
  assert.deepEqual(result.pending.fallback.loaded, result.pending.fallback.reference, 'fallback selection loads the rectangle');
  assert.deepEqual(result.pending.fallback.retry, {
    handled: true,
    text: result.pending.fallback.reference.text,
    html: result.pending.fallback.reference.html,
  }, 'retry copy without ClipboardItem returns the loaded TSV/HTML synchronously');

  // Scenario 3 assertions: the missing split part fails the clipboard request
  // and reports through clipboarderror, not through the viewer error channel.
  assert.match(result.failure.syncThrow, /still loading/, 'broken split stays pending on the synchronous path');
  assert.match(result.failure.failure, /404/, 'async clipboard rejects with the fetch failure');
  assert.ok(result.failure.events.some((entry) => /404/.test(entry)), 'clipboarderror reports the failure');
  assert.deepEqual(result.failure.viewerErrors, [], 'clipboard failures stay off the viewer error channel');

  // Scenario 4 assertions: tile content failures are rendering errors on the
  // viewer and never clipboarderror events.
  assert.ok(result.tileFailure.tileErrors.some((entry) => /404/.test(entry)), 'tile content failure surfaces on the viewer error channel');
  assert.deepEqual(result.tileFailure.tileClipboard, [], 'tile content failure does not emit clipboarderror');

  // Scenario 5: every mounted tile renders its text inside its own layer
  // bounds, a real pointer drag (not a Range API) selects cells across tiles,
  // and the same holds after a zoom change.
  const dragSetup = await page.evaluate(async () => {
    const moon = await import('/_build/js/debug/build/browser/browser.js');
    const workerUrl = '/_build/js/debug/build/render_worker/render_worker.js';
    const bytes = new Uint8Array(await (await fetch('/compat/sheet/cells.bdf')).arrayBuffer());
    const host = document.createElement('div');
    host.style.cssText = 'width:660px;height:300px;position:relative';
    document.body.append(host);
    const client = moon.bdf_render_worker_client(new Worker(workerUrl, { type: 'module' }));
    const viewer = moon.bdf_create_viewer(host, { renderer: client, find: false });
    await viewer.open({ kind: 'buffer', buffer: bytes.buffer });
    const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
    const wait = async (check, what) => {
      const start = performance.now();
      while (!check()) {
        if (performance.now() - start > 8000) throw new Error('viewer timed out: ' + what);
        await sleep(10);
      }
    };
    await wait(() => !!host.querySelector('[data-bdf-sheet-tile="0,0"]'), 'drag tile 0,0');
    await wait(() => {
      const layer = host.querySelector('[data-bdf-sheet-tile="2,0"]');
      return layer && [...layer.querySelectorAll('[data-bdf-ordinal]')].some((span) => span.textContent === 'Far');
    }, 'drag far tile');
    // Text geometry: the worker's render_within keeps only runs inside the
    // tile and text_layer_tile_origin maps them back to tile-local
    // coordinates, so any span outside its layer is a coordinate regression.
    const leaks = [];
    for (const layer of host.querySelectorAll('[data-bdf-sheet-tile]')) {
      const r = layer.getBoundingClientRect();
      for (const span of layer.querySelectorAll('[data-bdf-ordinal]')) {
        const s = span.getBoundingClientRect();
        if (s.left < r.left || s.right > r.right || s.top < r.top || s.bottom > r.bottom) {
          leaks.push({ tile: layer.dataset.bdfSheetTile, text: span.textContent, span: [s.left, s.right, s.top, s.bottom], layer: [r.left, r.right, r.top, r.bottom] });
        }
      }
    }
    const rect = (text) => {
      const span = [...host.querySelectorAll('[data-bdf-ordinal]')].find((s) => s.textContent === text);
      if (!span) throw new Error('drag span missing: ' + text);
      const r = span.getBoundingClientRect();
      return { x: r.x, y: r.y, w: r.width, h: r.height };
    };
    window.__drag = { host, viewer, client, moon, wait };
    return { leaks, header: rect('Header'), far: rect('Far') };
  });
  assert.deepEqual(dragSetup.leaks, [], 'text spans stay inside their own tile layers');
  assert.ok(dragSetup.header.x < dragSetup.far.x, 'drag endpoints are distinct and ordered');
  await page.mouse.move(dragSetup.header.x + 2, dragSetup.header.y + dragSetup.header.h / 2);
  await page.mouse.down();
  await page.mouse.move(dragSetup.far.x + dragSetup.far.w - 2, dragSetup.far.y + dragSetup.far.h - 2, { steps: 20 });
  await page.mouse.up();
  const dragResult = await page.evaluate(async () => {
    const { host, viewer, client, moon, wait } = window.__drag;
    const dragged = await moon.bdf_selection_cells_async(host);
    const collapsed = getSelection().isCollapsed;
    viewer.setZoom(2);
    await wait(() => !!host.querySelector('[data-bdf-sheet-tile="0,0"]'), 'zoomed tile 0,0');
    viewer.stage.scrollLeft = 1024;
    viewer.stage.dispatchEvent(new Event('scroll'));
    await wait(() => {
      const layer = host.querySelector('[data-bdf-sheet-tile="2,0"]');
      return layer && [...layer.querySelectorAll('[data-bdf-ordinal]')].some((span) => span.textContent === 'Far');
    }, 'zoomed far tile');
    const leaks = [];
    for (const layer of host.querySelectorAll('[data-bdf-sheet-tile]')) {
      const r = layer.getBoundingClientRect();
      for (const span of layer.querySelectorAll('[data-bdf-ordinal]')) {
        const s = span.getBoundingClientRect();
        if (s.left < r.left || s.right > r.right || s.top < r.top || s.bottom > r.bottom) {
          leaks.push({ tile: layer.dataset.bdfSheetTile, text: span.textContent });
        }
      }
    }
    const spanOf = (text) => [...host.querySelectorAll('[data-bdf-ordinal]')].find((s) => s.textContent === text);
    const a = spanOf('Header'), b = spanOf('Far');
    const range = document.createRange();
    range.setStart(a.firstChild, 0);
    range.setEnd(b.firstChild, b.firstChild.textContent.length);
    const selection = getSelection();
    selection.removeAllRanges();
    selection.addRange(range);
    document.dispatchEvent(new Event('selectionchange'));
    const zoomed = await moon.bdf_selection_cells_async(host);
    viewer.destroy();
    client.terminate();
    host.remove();
    delete window.__drag;
    return { dragged, collapsed, leaks, zoomed };
  });
  assert.deepEqual(dragResult.dragged, result.cross.reference, 'pointer drag across tiles copies the same rectangle');
  assert.equal(dragResult.collapsed, false, 'the pointer drag leaves an active selection');
  assert.deepEqual(dragResult.leaks, [], 'zoomed text spans stay inside their own tile layers');
  assert.deepEqual(dragResult.zoomed, result.cross.reference, 'zoomed selection copies the same rectangle');
  assert.deepEqual(browserErrors, [], 'no uncaught page errors');
} finally {
  await browser.close();
  await new Promise((resolve) => server.close(resolve));
}
console.log('viewer-selection-test: viewer sheet selection scenarios passed');
