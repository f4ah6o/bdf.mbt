import assert from 'node:assert/strict';
import { existsSync } from 'node:fs';
import { createReadStream } from 'node:fs';
import { createServer } from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';

// Browser Viewer multipage text selection and copy. The moon viewer
// (bdf_create_viewer) opens a synthetic multi-page fixed document generated
// by plugin/src/diagram-bdf.js (24 pages, every page its own obj part and
// text) served over HTTP and mounts a real rendering Worker. The test
// reproduces the two confirmed baseline defects and pins the fixed behavior:
//
//   1. Copy while intermediate pages of the selection are still loading must
//      fail with `clipboarderror` and no partial text, then succeed with the
//      complete ordered text once they load (baseline copied a truncated
//      "Page 00..Page 01..Page 04" silently missing Pages 02/03).
//   2. A selection whose pages are scrolled out of the lazily rendered region
//      must keep its text layers and copy in full (baseline returned empty
//      text without even canceling the copy event).
//   3. A selection extended across pages that were never rendered must
//      lazily prepare them (clipboardready) and copy all pages in order.
//   4. A page whose content fetch fails rejects copies with clipboarderror;
//      a retry after the failure clears succeeds again.
//   5. Opening another document while preparation is pending discards the
//      stale generation without leaking events, and the new document copies
//      normally.
//
// Run with --report to print observed behavior instead of asserting.
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
const reportMode = process.argv.includes('--report');

// Synthetic documents: 24 pages of 240x320 pt (two per page, page-unique
// text) and a 2-page document for the lifecycle case.
const { encodeDiagramDocument } = await import('../../plugin/src/diagram-bdf.js');
const makePages = (count) => Array.from({ length: count }, (_, index) => {
  const tag = String(index).padStart(2, '0');
  return {
    width: 240,
    height: 320,
    primitives: [
      { kind: 'text', x: 20, y: 48, text: `Page ${tag} alpha`, fontSize: 16 },
      { kind: 'text', x: 20, y: 96, text: `Page ${tag} beta`, fontSize: 16 },
    ],
  };
});
const fixture = await encodeDiagramDocument({ source: 'page-selection', title: 'page selection', pages: makePages(24) });
const second = await encodeDiagramDocument({ source: 'page-selection', title: 'second document', pages: makePages(2) });
const updated = await encodeDiagramDocument({ source: 'page-selection', title: 'updated page', pages: [{ width: 240, height: 320, primitives: [{ kind: 'text', x: 20, y: 48, text: 'NEW TEXT alpha', fontSize: 16 }, { kind: 'text', x: 20, y: 96, text: 'Page 00 beta', fontSize: 16 }] }] });
// Page 7 carries only a rectangle: its worker text content is genuinely
// ready but has no text layer to retain or release.
const blankPages = makePages(24).map((page, index) => index === 7
  ? { width: 240, height: 320, primitives: [{ kind: 'rect', x: 20, y: 40, w: 200, h: 240, fill: { r: 0, g: 100, b: 200, a: 1 } }] }
  : page);
const blank = await encodeDiagramDocument({ source: 'page-selection', title: 'blank page selection', pages: blankPages });
const pageText = (index) => {
  const tag = String(index).padStart(2, '0');
  return `Page ${tag} alpha Page ${tag} beta`;
};
const pagesText = (first, last) => Array.from({ length: last - first + 1 }, (_, n) => pageText(first + n)).join('\n\n');
const pagesTextExcept = (except, first, last) => Array.from({ length: last - first + 1 }, (_, n) => first + n)
  .filter((index) => !except.includes(index)).map(pageText).join('\n\n');

const types = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8' };
const server = createServer((request, response) => {
  const pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
  if (pathname === '/' || pathname === '/page-selection.html') {
    response.setHeader('Content-Type', types['.html']);
    response.end('<!doctype html><meta charset="utf-8"><title>viewer page selection</title>');
    return;
  }
  const inMemory = {
    '/page-selection/fixture.bdf': fixture,
    '/page-selection/second.bdf': second,
    '/page-selection/blank.bdf': blank,
    '/page-selection/updated.bdf': updated,
  };
  if (inMemory[pathname]) {
    response.setHeader('Content-Type', 'application/octet-stream');
    response.end(inMemory[pathname]);
    return;
  }
  const allowed = [
    '/_build/js/debug/build/browser/',
    '/_build/js/debug/build/render_worker/',
  ];
  const resolved = path.resolve(root, '.' + pathname);
  if (!allowed.some((prefix) => resolved.startsWith(path.resolve(root, '.' + prefix) + path.sep) || resolved === path.join(root, prefix))) {
    response.writeHead(403).end();
    return;
  }
  response.setHeader('Content-Type', types[path.extname(resolved)] ?? 'application/octet-stream');
  const stream = createReadStream(resolved);
  stream.once('error', () => { if (!response.headersSent) response.writeHead(404); response.end(); });
  stream.pipe(response);
});
await new Promise((resolve, reject) => {
  server.once('error', reject);
  server.listen(0, '127.0.0.1', resolve);
});
const base = 'http://127.0.0.1:' + server.address().port;

const browser = await chromium.launch({ headless: true });
try {
  const page = await browser.newPage({ viewport: { width: 900, height: 800 } });
  // Count the Viewer's retained rejection entries without adding a product API.
  // Native Map semantics are preserved; only its error-key maps are observed.
  await page.addInitScript(() => {
    const NativeMap = globalThis.Map;
    globalThis.__pageSelectionErrorMaps = new Set();
    globalThis.Map = class extends NativeMap {
      set(key, value) {
        if (typeof key === 'string' && key.startsWith('bdf-viewer-error:')) globalThis.__pageSelectionErrorMaps.add(this);
        return super.set(key, value);
      }
    };
  });
  const browserErrors = [];
  page.on('pageerror', (error) => browserErrors.push(String(error)));
  await page.goto(base + '/page-selection.html', { waitUntil: 'networkidle' });
  const result = await page.evaluate(async () => {
    const moon = await import('/_build/js/debug/build/browser/browser.js');
    const workerUrl = '/_build/js/debug/build/render_worker/render_worker.js';
    const bytes = async (file) => new Uint8Array(await (await fetch(file)).arrayBuffer());
    const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
    const wait = async (check, what) => {
      const start = performance.now();
      while (!check()) {
        if (performance.now() - start > 20000) throw new Error('viewer timed out: ' + what);
        await sleep(10);
      }
    };
    const frame = (host, index) => host.querySelector(`div[data-bdf-page="${index}"]`);
    const span = (host, index, text) => {
      const layer = frame(host, index)?.querySelector('.bdfTextLayer');
      return layer && [...layer.querySelectorAll('[data-bdf-ordinal]')].find((s) => s.textContent === text);
    };
    const events = (host) => {
      const seen = [];
      for (const kind of ['clipboarderror', 'error', 'clipboardready']) {
        host.addEventListener(kind, (event) => seen.push({ kind, at: performance.now(), detail: String(event.detail?.message ?? event.detail ?? '') }));
      }
      return seen;
    };
    const copy = (host) => {
      const event = new ClipboardEvent('copy', { bubbles: true, cancelable: true, clipboardData: new DataTransfer() });
      host.dispatchEvent(event);
      return { prevented: event.defaultPrevented, text: event.clipboardData.getData('text/plain') };
    };
    const cut = (host) => {
      const event = new ClipboardEvent('cut', { bubbles: true, cancelable: true, clipboardData: new DataTransfer() });
      host.dispatchEvent(event);
      return { prevented: event.defaultPrevented, text: event.clipboardData.getData('text/plain') };
    };
    const selectFromTo = (a, b) => {
      if (!a || !b) throw new Error('selection spans missing');
      const range = document.createRange();
      range.setStart(a.firstChild, 0);
      range.setEnd(b.firstChild, b.firstChild.textContent.length);
      const selection = getSelection();
      selection.removeAllRanges();
      selection.addRange(range);
      document.dispatchEvent(new Event('selectionchange'));
    };
    const pageText = (index) => {
      const tag = String(index).padStart(2, '0');
      return `Page ${tag} alpha Page ${tag} beta`;
    };
    const pagesText = (first, last) => Array.from({ length: last - first + 1 }, (_, n) => pageText(first + n)).join('\n\n');

    // A gate over the worker client: content calls for gated pages can be
    // held back (a not-yet-rendered intermediate page) or rejected (a missing
    // or unreadable part).
    const makeViewer = async (source) => {
      const gate = { held: new Set(), reject: new Set(), closed: true, waiting: [], counts: new Map() };
      const host = document.createElement('div');
      host.style.cssText = 'width:480px;height:1100px;position:relative';
      document.body.append(host);
      const client = moon.bdf_render_worker_client(new Worker(workerUrl, { type: 'module' }));
      const renderer = new Proxy(client, {
        get(target, name) {
          const value = target[name];
          if (name === 'content') {
            return (view, index) => {
              const page = Number(index);
              gate.counts.set(page, (gate.counts.get(page) ?? 0) + 1);
              if (gate.reject.has(page)) return Promise.reject(new Error('part for page ' + page + ' is unavailable'));
              const called = value.call(target, view, index);
              if (gate.closed && gate.held.has(page)) {
                return new Promise((resolve) => gate.waiting.push(resolve)).then(() => called);
              }
              return called;
            };
          }
          return typeof value === 'function' ? value.bind(target) : value;
        },
      });
      const viewer = moon.bdf_create_viewer(host, { renderer });
      const viewerErrors = [];
      viewer.addEventListener('error', (event) => viewerErrors.push(String(event.detail?.message ?? event.detail ?? '')));
      await viewer.open({ kind: 'buffer', buffer: (await bytes(source)).buffer });
      const scroll = (top) => {
        viewer.stage.scrollTop = top;
        viewer.stage.dispatchEvent(new Event('scroll'));
      };
      return { host, viewer, gate, client, scroll, viewerErrors };
    };
    const out = {};

    // A worker client is required to terminate cleanly for repeated mounts.
    const closeViewer = (holder) => { try { holder.viewer.destroy(); } finally { holder.client.close(); } };

    // 1. Page-local copy while everything visible is mounted.
    const sanity = await makeViewer('/page-selection/fixture.bdf');
    try {
      await wait(() => !!span(sanity.host, 0, 'Page 00 alpha'), 'sanity page 0 layer');
      selectFromTo(span(sanity.host, 0, 'Page 00 alpha'), span(sanity.host, 0, 'Page 00 beta'));
      out.local = copy(sanity.host);
    } finally {
      closeViewer(sanity);
    }

    // 2. Copy with held (not-yet-rendered) intermediate pages 2 and 3.
    const held = await makeViewer('/page-selection/fixture.bdf');
    try {
      held.gate.closed = true;
      held.gate.held.add(2);
      held.gate.held.add(3);
      seen: {
        const seen = events(held.host);
        await wait(() => !!span(held.host, 0, 'Page 00 alpha'), 'held page 0 layer');
        await wait(() => !!span(held.host, 4, 'Page 04 beta'), 'held page 4 layer');
        await wait(() => frame(held.host, 2)?.querySelector('canvas') && frame(held.host, 4).querySelector('canvas').width > 0, 'held page canvases');
        selectFromTo(span(held.host, 0, 'Page 00 alpha'), span(held.host, 4, 'Page 04 beta'));
        await sleep(100);
        out.heldCopy = copy(held.host);
        out.heldEventsAfterCopy = seen.filter((entry) => entry.kind !== 'error');
        held.gate.waiting.splice(0).forEach((resolve) => resolve());
        const releaseAt = performance.now();
        out.releaseAt = releaseAt;
        await wait(() => !!span(held.host, 2, 'Page 02 alpha') && !!span(held.host, 3, 'Page 03 beta'), 'held pages 2-3 layers after release');
        await wait(() => seen.some((entry) => entry.kind === 'clipboardready' && entry.at > releaseAt), 'clipboardready after release');
        out.heldCopyAfterRelease = copy(held.host);
        out.heldEvents = seen;
      }
    } finally {
      closeViewer(held);
    }

    // 3. A selection kept while its pages are scrolled out of the rendered
    //    region, extended across never-rendered pages.
    const scrolled = await makeViewer('/page-selection/fixture.bdf');
    try {
      await wait(() => !!span(scrolled.host, 4, 'Page 04 beta'), 'scrolled page 4 layer');
      selectFromTo(span(scrolled.host, 0, 'Page 00 alpha'), span(scrolled.host, 4, 'Page 04 beta'));
      out.scrolledCopyBeforeScroll = copy(scrolled.host);
      scrolled.scroll(scrolled.viewer.stage.scrollHeight);
      await wait(() => !!span(scrolled.host, 23, 'Page 23 alpha'), 'scrolled far layer');
      out.scrolledFirstLayerAtTop = !!span(scrolled.host, 0, 'Page 00 alpha') && !!scrolled.host.querySelector('[data-bdf-page="0"] .bdfTextLayer');
      out.scrolledCopyOnFarPages = copy(scrolled.host);
      const seen = events(scrolled.host);
      selectFromTo(span(scrolled.host, 0, 'Page 00 alpha'), span(scrolled.host, 23, 'Page 23 beta'));
      out.farCopyWhilePreparing = copy(scrolled.host);
      await wait(() => seen.some((entry) => entry.kind === 'clipboardready'), 'far pages clipboardready');
      out.farCopyAfterPrepare = copy(scrolled.host);
      // Deselecting releases the retained layers of pages 0-4 at the top;
      // pages near the scrolled viewport (22) keep their layers.
      selectFromTo(span(scrolled.host, 22, 'Page 22 alpha'), span(scrolled.host, 23, 'Page 23 beta'));
      await sleep(200);
      out.releaseAfterDeselect = [
        !!scrolled.host.querySelector('[data-bdf-page="0"] .bdfTextLayer'),
        !!scrolled.host.querySelector('[data-bdf-page="4"] .bdfTextLayer'),
        !!scrolled.host.querySelector('[data-bdf-page="22"] .bdfTextLayer'),
      ];
      out.scrolledEvents = seen;
    } finally {
      closeViewer(scrolled);
    }

    // 3b. A genuinely ready textless (image-only) page inside the selection
    //     keeps its readiness: no refetch on selection changes or scrolling,
    //     and copies stay complete.
    const blankView = await makeViewer('/page-selection/blank.bdf');
    try {
      const seen = events(blankView.host);
      await wait(() => !!span(blankView.host, 0, 'Page 00 alpha') && !!span(blankView.host, 4, 'Page 04 beta'), 'blank page 0/4 layers');
      selectFromTo(span(blankView.host, 0, 'Page 00 alpha'), span(blankView.host, 4, 'Page 04 beta'));
      blankView.scroll(blankView.viewer.stage.scrollHeight);
      await wait(() => !!span(blankView.host, 23, 'Page 23 alpha'), 'blank far layer');
      selectFromTo(span(blankView.host, 0, 'Page 00 alpha'), span(blankView.host, 23, 'Page 23 beta'));
      const extendAt = performance.now();
      await wait(() => seen.some((entry) => entry.kind === 'clipboardready' && entry.at > extendAt), 'blank clipboardready');
      out.blankCopyAfterPrepare = copy(blankView.host);
      const calls7 = blankView.gate.counts.get(7) ?? 0;
      out.blankContentCalls7 = calls7;
      document.dispatchEvent(new Event('selectionchange'));
      out.blankCopyAfterSelectionChange = copy(blankView.host);
      document.dispatchEvent(new Event('selectionchange'));
      document.dispatchEvent(new Event('selectionchange'));
      blankView.scroll(blankView.viewer.stage.scrollHeight - 100);
      await sleep(200);
      blankView.scroll(blankView.viewer.stage.scrollHeight);
      await sleep(200);
      out.blankRefetchAfterChurn = (blankView.gate.counts.get(7) ?? 0) - calls7;
      out.blankCopyAfterScroll = copy(blankView.host);
      out.blankClipboardErrors = seen.filter((entry) => entry.kind === 'clipboarderror').length;
    } finally {
      closeViewer(blankView);
    }

    // 4. A failing intermediate page rejects copies and a retry heals it.
    const failing = await makeViewer('/page-selection/fixture.bdf');
    try {
      failing.gate.reject.add(3);
      const seen = events(failing.host);
      await wait(() => !!span(failing.host, 0, 'Page 00 alpha') && !!span(failing.host, 4, 'Page 04 beta'), 'failing endpoint layers');
      // The failed page stops at its rendered bitmap with no text layer:
      // render_page swallows the content error, so the page never becomes
      // content-ready.
      await wait(() => {
        const canvas = frame(failing.host, 3)?.querySelector('canvas');
        return canvas && canvas.dataset.loaded === 'ready' && !frame(failing.host, 3).querySelector('.bdfTextLayer');
      }, 'failed page 3 render');
      selectFromTo(span(failing.host, 0, 'Page 00 alpha'), span(failing.host, 4, 'Page 04 beta'));
      // The preparation of the failed page rejects, and the first refused
      // copy retries and fails again while the server still fails: three
      // clipboarderror host events before the server heals, then a refused
      // cut whose retry succeeds, then clipboardready and a complete copy.
      await wait(() => seen.filter((entry) => entry.kind === 'clipboarderror').length >= 1, 'clipboarderror for the failed page');
      out.failingCopy = copy(failing.host);
      await wait(() => seen.filter((entry) => entry.kind === 'clipboarderror').length >= 3, 'clipboarderror for the retried failed page');
      // Every additional failed preparation must release its temporary
      // retained Error; the earlier render failure is an existing baseline.
      out.errorsBeforeRetries = Array.from(globalThis.__pageSelectionErrorMaps, map => map.size);
      for (let repeat = 0; repeat < 3; repeat++) {
        const before = seen.filter(entry => entry.kind === 'clipboarderror').length;
        copy(failing.host);
        await wait(() => seen.filter(entry => entry.kind === 'clipboarderror').length >= before + 2, 'additional failed retry ' + repeat);
      }
      out.errorsAfterRetries = Array.from(globalThis.__pageSelectionErrorMaps, map => map.size);
      failing.gate.reject.clear();
      // The refused copy's retry refetched and failed; a cut passes the same
      // guard, is refused with clipboarderror, and its retry refetches the
      // healed page, so the host reports clipboardready.
      out.failingRetryCut = cut(failing.host);
      await wait(() => seen.some((entry) => entry.kind === 'clipboardready'), 'clipboardready after the retry');
      out.failingCopyAfterRetry = copy(failing.host);
      out.failingEvents = seen;
      out.errorsAfterRecovery = Array.from(globalThis.__pageSelectionErrorMaps, map => map.size);
    } finally {
      closeViewer(failing);
    }

    // 5. Opening a new document while a page preparation is pending: the
    //    pending work is discarded for the stale generation and the new
    //    document selects and copies normally.
    const lifecycle = await makeViewer('/page-selection/fixture.bdf');
    try {
      lifecycle.gate.closed = true;
      lifecycle.gate.held.add(2);
      lifecycle.gate.held.add(3);
      const seen = events(lifecycle.host);
      await wait(() => !!span(lifecycle.host, 0, 'Page 00 alpha') && !!span(lifecycle.host, 4, 'Page 04 beta'), 'lifecycle page layers');
      selectFromTo(span(lifecycle.host, 0, 'Page 00 alpha'), span(lifecycle.host, 4, 'Page 04 beta'));
      await wait(() => lifecycle.gate.waiting.length > 0, 'pending held prepare');
      await lifecycle.viewer.open({ kind: 'buffer', buffer: (await bytes('/page-selection/second.bdf')).buffer });
      lifecycle.gate.waiting.splice(0).forEach((resolve) => resolve());
      await sleep(300);
      out.lifecycleLeakedEvents = seen.filter((entry) => entry.kind === 'clipboardready' || entry.kind === 'clipboarderror');
      await wait(() => !!span(lifecycle.host, 1, 'Page 01 alpha'), 'lifecycle second document layer');
      selectFromTo(span(lifecycle.host, 0, 'Page 00 alpha'), span(lifecycle.host, 1, 'Page 01 beta'));
      out.lifecycleSecondDocumentCopy = copy(lifecycle.host);
      // After destroy the host answers no copies and the disposed selection
      // machinery reacts to neither selection change nor copy events.
      lifecycle.viewer.destroy();
      lifecycle.gate.closed = false;
      document.dispatchEvent(new Event('selectionchange'));
      out.lifecycleAfterDestroy = copy(lifecycle.host);
      out.lifecyclePagesAfterDestroy = lifecycle.host.querySelectorAll('[data-bdf-page]').length;
    } finally {
      closeViewer(lifecycle);
    }
    // 6. The real Worker replaces a page while its old text is selected.
    // Neither an in-flight update nor the completed update may copy stale text.
    {
      const fixtureBytes = await bytes('/page-selection/fixture.bdf');
      const updatedBytes = await bytes('/page-selection/updated.bdf');
      const host = document.createElement('div');
      host.style.cssText = 'width:480px;height:1100px;position:relative';
      document.body.append(host);
      const client = moon.bdf_render_worker_client(new Worker(workerUrl, { type: 'module' }));
      let added = false, changedSeen = 0, oldHeld = 0, oldDelivered = 0, armOld = false, releasePage, releaseAdd, releaseContent, releaseOld;
      const pageGate = new Promise(resolve => { releasePage = resolve; });
      const addGate = new Promise(resolve => { releaseAdd = resolve; });
      const contentGate = new Promise(resolve => { releaseContent = resolve; });
      const oldContentGate = new Promise(resolve => { releaseOld = resolve; });
      const renderer = new Proxy(client, { get(target, name) {
        const value = target[name];
        if (name === 'addPage') return async (...args) => {
          const result = await value.apply(target, args); added = true; await addGate; return result;
        };
        if (name === 'content') return async (view, index) => {
          const content = await value.call(target, view, index);
          if (!added && armOld && Number(index) === 0) { armOld = false; oldHeld++; await oldContentGate; oldDelivered++; }
          if (added && Number(index) === 0 && content.runs.some(run => run.text.includes('NEW TEXT alpha'))) {
            changedSeen++; await contentGate;
          }
          return content;
        };
        return typeof value === 'function' ? value.bind(target) : value;
      }});
      const converter = {
        convert: async () => ({ bdf: fixtureBytes }),
        open: async () => ({ bdf: fixtureBytes, pages: 1, stream: 7 }),
        page: async () => { await pageGate; return { bdf: updatedBytes }; },
        finish: async () => await new Promise(() => {}),
        close: async () => {},
      };
      const viewer = moon.bdf_create_viewer(host, { renderer, find: false });
      try {
        await viewer.openFile(converter, new Uint8Array([1]), { name: 'synthetic' });
        await wait(() => !!span(host, 0, 'Page 00 alpha') && !!span(host, 0, 'Page 00 beta'), 'stream initial text');
        selectFromTo(span(host, 0, 'Page 00 alpha'), span(host, 0, 'Page 00 beta'));
        out.streamBefore = copy(host);
        // Leave one old content response in flight while the stream replaces
        // the page; it must never overwrite the newer text layer.
        armOld = true;
        viewer.stage.scrollTop = viewer.stage.scrollHeight;
        viewer.stage.dispatchEvent(new Event('scroll'));
        await wait(() => !!span(host, 23, 'Page 23 alpha'), 'stream far page');
        viewer.stage.scrollTop = 0;
        viewer.stage.dispatchEvent(new Event('scroll'));
        await wait(() => oldHeld > 0, 'old page content held');
        releasePage();
        await wait(() => added, 'Worker added updated page before the reply');
        out.streamAfterWorker = copy(host);
        releaseAdd();
        await wait(() => changedSeen > 0, 'Worker replaced page content');
        out.streamDuring = copy(host);
        releaseContent();
        const limit = performance.now() + 3000;
        while (!span(host, 0, 'NEW TEXT alpha') && performance.now() < limit) await sleep(10);
        out.streamNewLayer = !!span(host, 0, 'NEW TEXT alpha');
        out.streamAfter = copy(host);
        if (out.streamNewLayer) {
          selectFromTo(span(host, 0, 'NEW TEXT alpha'), span(host, 0, 'Page 00 beta'));
          out.streamReselected = copy(host);
        }
        // Deselect before the old reply arrives: preserving a selected layer
        // must not accidentally hide an old-response overwrite.
        getSelection().removeAllRanges();
        releaseOld();
        await wait(() => oldDelivered > 0, 'old page content delivered');
        await sleep(0);
        const newLayer = !!span(host, 0, 'NEW TEXT alpha');
        if (newLayer) selectFromTo(span(host, 0, 'NEW TEXT alpha'), span(host, 0, 'Page 00 beta'));
        out.streamAfterOld = { newLayer, oldLayer: !!span(host, 0, 'Page 00 alpha'), copied: copy(host) };
      } finally { releaseOld(); releaseAdd(); releaseContent(); viewer.destroy(); client.close(); host.remove(); }
    }
    // 7. An old offscreen preparation fails after a blank intermediate
    // page was replaced. The stale failure must not poison the new page.
    {
      const fixtureBytes = await bytes('/page-selection/blank.bdf');
      const updatedBytes = await bytes('/page-selection/updated.bdf');
      const host = document.createElement('div');
      host.style.cssText = 'width:480px;height:1100px;position:relative';
      document.body.append(host);
      const client = moon.bdf_render_worker_client(new Worker(workerUrl, { type: 'module' }));
      let page7Waiting = false, oldWaiting = false, oldRejected = false, added = false;
      let releasePage7, rejectOld;
      const page7Gate = new Promise(resolve => { releasePage7 = resolve; });
      const oldGate = new Promise((_, reject) => { rejectOld = reject; });
      const renderer = new Proxy(client, { get(target, name) {
        const value = target[name];
        if (name === 'addPage') return async (view, index, buffer) => {
          if (Number(index) !== 7) return;
          const result = await value.call(target, view, index, buffer); added = true; return result;
        };
        if (name === 'content') return async (view, index) => {
          const content = await value.call(target, view, index);
          if (!added && Number(index) === 7) {
            oldWaiting = true;
            try { await oldGate; } catch (error) { oldRejected = true; throw error; }
          }
          return content;
        };
        return typeof value === 'function' ? value.bind(target) : value;
      }});
      const converter = {
        convert: async () => ({ bdf: fixtureBytes }),
        open: async () => ({ bdf: fixtureBytes, pages: 8, stream: 8 }),
        page: async (_stream, index) => {
          if (Number(index) === 7) { page7Waiting = true; await page7Gate; }
          return { bdf: updatedBytes };
        },
        finish: async () => await new Promise(() => {}),
        close: async () => {},
      };
      const viewer = moon.bdf_create_viewer(host, { renderer, find: false });
      const seen = events(host);
      try {
        await viewer.openFile(converter, new Uint8Array([1]), { name: 'synthetic' });
        await wait(() => page7Waiting && !!span(host, 0, 'Page 00 alpha') && !!span(host, 4, 'Page 04 beta'), 'stream page 7 gate');
        // Match an internal page link appearing before the target page frame.
        const link = document.createElement('a'); link.dataset.bdfPage = '7'; frame(host, 0).append(link);
        selectFromTo(span(host, 0, 'Page 00 alpha'), span(host, 4, 'Page 04 beta'));
        viewer.stage.scrollTop = viewer.stage.scrollHeight;
        viewer.stage.dispatchEvent(new Event('scroll'));
        await wait(() => !!span(host, 23, 'Page 23 beta'), 'stale prepare far endpoint');
        selectFromTo(span(host, 0, 'Page 00 alpha'), span(host, 23, 'Page 23 beta'));
        await wait(() => oldWaiting, 'old blank page preparation held');
        releasePage7();
        await wait(() => added, 'updated blank page added');
        await sleep(0);
        out.stalePrepareSelectionCleared = getSelection().isCollapsed;
        const errorsBefore = seen.filter(entry => entry.kind === 'clipboarderror').length;
        rejectOld(new Error('old page content rejected'));
        await wait(() => oldRejected, 'old preparation rejected');
        await sleep(0);
        out.stalePrepareErrors = seen.filter(entry => entry.kind === 'clipboarderror').length - errorsBefore;
        const target = frame(host, 7), stageRect = viewer.stage.getBoundingClientRect();
        viewer.stage.scrollTop += target.getBoundingClientRect().top - stageRect.top;
        viewer.stage.dispatchEvent(new Event('scroll'));
        await wait(() => !!span(host, 7, 'NEW TEXT alpha') && !!span(host, 7, 'Page 00 beta'), 'updated blank page text');
        selectFromTo(span(host, 7, 'NEW TEXT alpha'), span(host, 7, 'Page 00 beta'));
        out.stalePrepareCopy = copy(host);
      } finally { releasePage7(); rejectOld(new Error('test cleanup')); viewer.destroy(); client.close(); host.remove(); }
    }
    // 8. A current bitmap or text request that settles while detached must
    // not leave the canvas permanently loading when the host is reattached.
    out.detached = [];
    for (const [kind, outcome] of [['page', 'reject'], ['page', 'resolve'], ['content', 'reject'], ['content', 'resolve']]) {
      const data = await bytes('/page-selection/fixture.bdf');
      const host = document.createElement('div');
      host.style.cssText = 'width:480px;height:220px;position:relative';
      document.body.append(host);
      const client = moon.bdf_render_worker_client(new Worker(workerUrl, { type: 'module' }));
      let waiting = false, delivered = false, released = false, finishGate, failGate, calls = 0;
      const gate = new Promise((resolve, reject) => { finishGate = resolve; failGate = reject; });
      const renderer = new Proxy(client, { get(target, name) {
        const value = target[name];
        if (name === kind) return async (...args) => {
          if (Number(args[1]) === 5) {
            calls++;
            if (!released) {
              const content = kind === 'content' ? await value.apply(target, args) : undefined;
              waiting = true;
              try {
                await gate;
                return kind === 'content' ? content : await value.apply(target, args);
              } finally { delivered = true; }
            }
          }
          return await value.apply(target, args);
        };
        return typeof value === 'function' ? value.bind(target) : value;
      }});
      const viewer = moon.bdf_create_viewer(host, { renderer, find: false });
      viewer.addEventListener('error', event => event.preventDefault());
      try {
        await viewer.open({ kind: 'buffer', buffer: data.buffer });
        await wait(() => frame(host, 5)?.querySelector('canvas')?.width === 0, 'detached test offscreen page');
        const target = frame(host, 5), stage = viewer.stage;
        stage.scrollTop += target.getBoundingClientRect().top - stage.getBoundingClientRect().top;
        stage.dispatchEvent(new Event('scroll'));
        await wait(() => waiting, 'detached test pending ' + kind);
        host.remove(); released = true;
        if (outcome === 'reject') failGate(new Error('synthetic detached failure')); else finishGate();
        await wait(() => delivered, 'detached test response delivered');
        await sleep(0);
        const detachedLoaded = target.querySelector('canvas').dataset.loaded;
        document.body.append(host);
        stage.scrollTop = 0;
        stage.dispatchEvent(new Event('scroll'));
        await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
        stage.scrollTop += target.getBoundingClientRect().top - stage.getBoundingClientRect().top;
        stage.dispatchEvent(new Event('scroll'));
        await wait(() => target.querySelector('canvas').dataset.loaded === 'ready' && !!span(host, 5, 'Page 05 alpha'), 'detached page reloaded ' + kind + '/' + outcome);
        out.detached.push({ kind, outcome, detachedLoaded, calls, textPresent: !!span(host, 5, 'Page 05 alpha') });
      } finally { released = true; finishGate(); viewer.destroy(); client.close(); host.remove(); }
    }
    // 9. A pending page replacement survives zoom and view redraws; both
    // success and failure unblock the page even if another view is current.
    out.redrawUpdates = [];
    for (const mode of ['zoom', 'view-return', 'view-away-success', 'view-away-failure']) {
      const initial = await bytes('/page-selection/fixture.bdf');
      const replacement = await bytes('/page-selection/updated.bdf');
      const host = document.createElement('div');
      host.style.cssText = 'width:480px;height:1100px;position:relative';
      document.body.append(host);
      const client = moon.bdf_render_worker_client(new Worker(workerUrl, { type: 'module' }));
      let releasePage, releaseAdd, waiting = false, progress = false, failure = false;
      const pageGate = new Promise(resolve => { releasePage = resolve; });
      const addGate = new Promise(resolve => { releaseAdd = resolve; });
      const renderer = new Proxy(client, { get(target, name) {
        const value = target[name];
        if (name === 'addPage') return async (...args) => {
          waiting = true; await addGate;
          if (mode === 'view-away-failure') throw new Error('synthetic addPage failure');
          return await value.apply(target, args);
        };
        return typeof value === 'function' ? value.bind(target) : value;
      }});
      const converter = {
        convert: async () => ({ bdf: initial }),
        open: async () => ({ bdf: initial, pages: 1, stream: 9 }),
        page: async () => { await pageGate; return { bdf: replacement }; },
        finish: async () => await new Promise(() => {}),
        close: async () => {},
      };
      const viewer = moon.bdf_create_viewer(host, { renderer, find: false });
      viewer.addEventListener('conversionprogress', () => { progress = true; });
      viewer.addEventListener('error', event => { failure = true; event.preventDefault(); });
      try {
        await viewer.openFile(converter, new Uint8Array([1]), { name: 'synthetic' });
        await wait(() => !!span(host, 0, 'Page 00 alpha') && !!span(host, 0, 'Page 00 beta'), 'redraw initial text');
        const viewId = viewer.view.id;
        selectFromTo(span(host, 0, 'Page 00 alpha'), span(host, 0, 'Page 00 beta'));
        releasePage();
        await wait(() => waiting, 'pending addPage before redraw');
        if (mode === 'zoom') viewer.setZoom(1.1);
        else { viewer.setView('__missing__'); if (mode === 'view-return') viewer.setView(viewId); }
        let pending;
        if (mode === 'zoom' || mode === 'view-return') {
          await wait(() => !!frame(host, 0)?.querySelector('canvas'), 'redrawn page');
          await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
          pending = { updating: frame(host, 0).querySelector('canvas').dataset.contentUpdating, oldVisible: !!span(host, 0, 'Page 00 alpha'), copied: copy(host) };
        }
        releaseAdd();
        await wait(() => progress || failure, 'stream update completed');
        if (mode.startsWith('view-away')) viewer.setView(viewId);
        const expected = mode === 'view-away-failure' ? 'Page 00 alpha' : 'NEW TEXT alpha';
        await wait(() => !!span(host, 0, expected) && !!span(host, 0, 'Page 00 beta'), 'redrawn page content');
        selectFromTo(span(host, 0, expected), span(host, 0, 'Page 00 beta'));
        out.redrawUpdates.push({ mode, pending, copy: copy(host), failure });
      } finally { releasePage(); releaseAdd(); viewer.destroy(); client.close(); host.remove(); }
    }
    return out;
  });

  if (reportMode) {
    console.log(JSON.stringify(result, null, 2));
    console.log('browser errors:', JSON.stringify(browserErrors));
  } else {
    const failures = [];
    const check = (name, condition, actual) => {
      if (!condition) failures.push(name + (actual === undefined ? '' : ': ' + JSON.stringify(actual)));
    };
    check('local copy prevented', result.local?.prevented, result.local);
    check('local copy text', result.local?.text === 'Page 00 alpha Page 00 beta', result.local);
    check('held copy refused', result.heldCopy?.prevented === true && result.heldCopy?.text === '', result.heldCopy);
    check('held copy no partial text', result.heldCopy?.text === '', result.heldCopy);
    check('held clipboarderror on refused copy', (result.heldEvents ?? []).some((entry) => entry.kind === 'clipboarderror'), result.heldEvents);
    check('held copy complete after release', result.heldCopyAfterRelease?.text === pagesText(0, 4), result.heldCopyAfterRelease);
    check('held clipboardready after release', (result.heldEvents ?? []).some((entry) => entry.kind === 'clipboardready'), result.heldEvents);
    check('scrolled copy before scroll', result.scrolledCopyBeforeScroll?.text === pagesText(0, 4), result.scrolledCopyBeforeScroll);
    check('scrolled layers retained', result.scrolledFirstLayerAtTop === true, result.scrolledFirstLayerAtTop);
    check('scrolled copy after scroll', result.scrolledCopyAfterScroll === undefined && result.scrolledCopyOnFarPages?.text === pagesText(0, 4), { onFarPages: result.scrolledCopyOnFarPages });
    check('far copy preparing refused', result.farCopyWhilePreparing?.prevented === true && result.farCopyWhilePreparing?.text === '', result.farCopyWhilePreparing);
    check('far copy complete after prepare', result.farCopyAfterPrepare?.text === pagesText(0, 23), result.farCopyAfterPrepare);
    check('retained layers released after deselect', result.releaseAfterDeselect?.[0] === false && result.releaseAfterDeselect?.[1] === false && result.releaseAfterDeselect?.[2] === true, result.releaseAfterDeselect);
    check('blank copy complete', result.blankCopyAfterPrepare?.text === pagesTextExcept([7], 0, 23), result.blankCopyAfterPrepare);
    check('blank copy complete after selection change', result.blankCopyAfterSelectionChange?.text === pagesTextExcept([7], 0, 23) && result.blankCopyAfterSelectionChange?.prevented === true, result.blankCopyAfterSelectionChange);
    check('blank ready page not refetched', result.blankRefetchAfterChurn === 0, result.blankRefetchAfterChurn);
    check('blank copy complete after scroll', result.blankCopyAfterScroll?.text === pagesTextExcept([7], 0, 23), result.blankCopyAfterScroll);
    check('blank copy without clipboarderror', result.blankClipboardErrors === 0, result.blankClipboardErrors);
    check('failing copy refused', result.failingCopy?.prevented === true && result.failingCopy?.text === '', result.failingCopy);
    check('failing clipboarderror', (result.failingEvents ?? []).some((entry) => entry.kind === 'clipboarderror'), result.failingEvents);
    check('failing cut refused', result.failingRetryCut?.prevented === true && result.failingRetryCut?.text === '', result.failingRetryCut);
    check('failing copy complete after retry', result.failingCopyAfterRetry?.text === pagesText(0, 4), result.failingCopyAfterRetry);
    check('failed retries release retained errors', JSON.stringify(result.errorsAfterRetries) === JSON.stringify(result.errorsBeforeRetries), { before: result.errorsBeforeRetries, after: result.errorsAfterRetries });
    check('recovery does not retain additional errors', JSON.stringify(result.errorsAfterRecovery) === JSON.stringify(result.errorsBeforeRetries), { before: result.errorsBeforeRetries, after: result.errorsAfterRecovery });
    check('stream initially copies selected page', result.streamBefore?.text === pageText(0), result.streamBefore);
    check('stream update never copies stale text before addPage replies', !result.streamAfterWorker?.text?.includes('Page 00 alpha'), result.streamAfterWorker);
    check('stream update never copies stale text while loading', !result.streamDuring?.text?.includes('Page 00 alpha'), result.streamDuring);
    check('stream update never copies stale text after loading', !result.streamAfter?.text?.includes('Page 00 alpha'), result.streamAfter);
    check('stream updated layer is mounted', result.streamNewLayer === true, result.streamNewLayer);
    check('stream updated text can be reselected', result.streamReselected?.text === 'NEW TEXT alpha Page 00 beta', result.streamReselected);
    check('old response never overwrites updated text', result.streamAfterOld?.newLayer === true && result.streamAfterOld?.oldLayer === false && result.streamAfterOld?.copied?.text === 'NEW TEXT alpha Page 00 beta', result.streamAfterOld);
    check('updating a selected blank intermediate page clears the selection', result.stalePrepareSelectionCleared === true, result.stalePrepareSelectionCleared);
    check('stale failed preparation does not emit a clipboard error', result.stalePrepareErrors === 0, result.stalePrepareErrors);
    check('updated intermediate page can be selected and copied', result.stalePrepareCopy?.text === 'NEW TEXT alpha Page 00 beta', result.stalePrepareCopy);
    check('detached in-flight pages can reload', result.detached?.length === 4 && result.detached.every(entry => entry.detachedLoaded === '' && entry.calls >= 2 && entry.textPresent), result.detached);
    check('pending updates block stale text across redraws', ['zoom', 'view-return'].every(mode => result.redrawUpdates?.some(entry => entry.mode === mode && entry.pending?.updating === 'true' && !entry.pending.oldVisible && !entry.pending.copied.text?.includes('Page 00 alpha'))), result.redrawUpdates);
    check('redrawn views recover after update success or failure', result.redrawUpdates?.length === 4 && result.redrawUpdates.every(entry => entry.copy?.text === (entry.mode === 'view-away-failure' ? 'Page 00 alpha Page 00 beta' : 'NEW TEXT alpha Page 00 beta') && entry.failure === (entry.mode === 'view-away-failure')), result.redrawUpdates);
    check('lifecycle stale events discarded', (result.lifecycleLeakedEvents ?? []).length === 0, result.lifecycleLeakedEvents);
    check('lifecycle second document copy', result.lifecycleSecondDocumentCopy?.text === pagesText(0, 1), result.lifecycleSecondDocumentCopy);
    check('lifecycle destroyed host silent', result.lifecycleAfterDestroy?.prevented === false && result.lifecycleAfterDestroy?.text === '' && result.lifecyclePagesAfterDestroy === 0, { afterDestroy: result.lifecycleAfterDestroy, pages: result.lifecyclePagesAfterDestroy });
    check('no browser errors', browserErrors.length === 0, browserErrors);
    if (failures.length) {
      console.error(JSON.stringify({ failures, result }, null, 2));
      process.exitCode = 1;
    } else {
      console.log('viewer multipage page-selection: all checks passed');
    }
  }
} finally {
  await browser.close();
  server.close();
}
