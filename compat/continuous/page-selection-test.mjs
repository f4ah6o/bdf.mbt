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
    const frame = (host, index) => host.querySelector(`[data-bdf-page="${index}"]`);
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
      failing.gate.reject.clear();
      // The refused copy's retry refetched and failed; a cut passes the same
      // guard, is refused with clipboarderror, and its retry refetches the
      // healed page, so the host reports clipboardready.
      out.failingRetryCut = cut(failing.host);
      await wait(() => seen.some((entry) => entry.kind === 'clipboardready'), 'clipboardready after the retry');
      out.failingCopyAfterRetry = copy(failing.host);
      out.failingEvents = seen;
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
