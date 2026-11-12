import assert from 'node:assert/strict';
import { createReadStream, existsSync } from 'node:fs';
import { createServer } from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';

// Deterministic sheetClipboard coverage against the synthetic multi-tile
// sheet fixture (compat/sheet/cells.bdf) through a real rendering Worker and
// the moon client (bdf_render_worker_client). The fixture's cells.bdf has
// hidden row/column runs, a hidden-column merge, a vertical merge, a wide
// merge, header scope marks, and text in tiles outside any small viewport.
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

// The page may read the local worker/client builds, the sheet fixtures, and a
// split-part mirror that answers 404 for one object part. Everything else is
// refused. The missing part is the tile (1,0) object of compat/sheet/cells-split.
const allowed = [
  '/compat/sheet/cells.bdf',
  '/compat/continuous/flow.bdf',
  '/compat/sheet/cells-split/',
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
  '.json': 'application/json; charset=utf-8',
};
const server = createServer((request, response) => {
  let pathname;
  try { pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname); }
  catch { response.writeHead(400).end(); return; }
  let file = pathname;
  if (pathname === '/' || pathname === '/clipboard-test.html') {
    response.setHeader('Content-Type', 'text/html; charset=utf-8');
    response.end('<!doctype html><meta charset="utf-8"><title>sheetClipboard</title>');
    return;
  }
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
    response.writeHead(403).end();
    return;
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

// Expected serialization of the whole sheet selection in the fixture:
// visible axes are rows [0,1,3..14] and columns [A,B,D..J] (row 2 and column
// C are hidden runs of size 0). Empty grid rows are nine empty TSV fields.
const emptyRow = '\t'.repeat(8);
const tsvLines = [
  'Header\tMerged\t\tEast\t\t\t\t\t',
  'Apple\t12\t\tValue\t\t\t\t\t',
  'South\tLong\t\tEnd\t\tFar\t\t\t',
  emptyRow,
  'Wide\t\t\t\t\t\t\t\t',
  emptyRow,
  emptyRow,
  emptyRow,
  'Below\t\t\t\t\t\t\t\t',
  emptyRow,
  emptyRow,
  emptyRow,
  emptyRow,
  emptyRow,
];
assert.equal(tsvLines.length, 14, 'fixture has 14 visible rows');
const td = '<td></td>'.repeat(9);
const htmlRows = [
  '<tr><th scope="col">Header</th><th scope="col">Merged</th><td></td><td>East</td><td></td><td></td><td></td><td></td><td></td></tr>',
  '<tr><td>Apple</td><td>12</td><td></td><td>Value</td><td></td><td></td><td></td><td></td><td></td></tr>',
  '<tr><td>South</td><td rowspan="2">Long</td><td></td><td>End</td><td></td><td>Far</td><td></td><td></td><td></td></tr>',
  '<tr>' + '<td></td>'.repeat(8) + '</tr>',
  '<tr><td colspan="2">Wide</td>' + '<td></td>'.repeat(7) + '</tr>',
  '<tr>' + td + '</tr>',
  '<tr>' + td + '</tr>',
  '<tr>' + td + '</tr>',
  '<tr><td>Below</td>' + '<td></td>'.repeat(8) + '</tr>',
  '<tr>' + td + '</tr>',
  '<tr>' + td + '</tr>',
  '<tr>' + td + '</tr>',
  '<tr>' + td + '</tr>',
  '<tr>' + td + '</tr>',
];
assert.equal(htmlRows.length, 14, 'fixture has 14 visible rows');
const fullText = tsvLines.join('\n');
const fullHtml = '<meta charset="utf-8"><table>' + htmlRows.join('') + '</table>';

const browser = await chromium.launch({ headless: true });
try {
  const page = await browser.newPage();
  const browserErrors = [];
  page.on('pageerror', (error) => browserErrors.push(String(error)));
  await page.goto(base + '/clipboard-test.html', { waitUntil: 'networkidle' });
  const results = await page.evaluate(async () => {
    const moon = await import('/_build/js/debug/build/browser/browser.js');
    const workerUrl = '/_build/js/debug/build/render_worker/render_worker.js';
    const bytes = async (path) => new Uint8Array(await (await fetch(path)).arrayBuffer());
    const full = { row0: 0, col0: 0, row1: 14, col1: 9 };
    const client = () => moon.bdf_render_worker_client(new Worker(workerUrl, { type: 'module' }));
    const attempt = async (label, fn) => {
      try {
        return { label, ok: true, value: await fn() };
      } catch (error) {
        return { label, ok: false, name: error.name, message: error.message };
      }
    };
    const out = [];
    const cells = client();
    out.push(await attempt('before-open', () => cells.sheetClipboard('cells', full)));
    const manifest = await cells.open({ kind: 'buffer', buffer: (await bytes('/compat/sheet/cells.bdf')).buffer });
    out.push({ label: 'open', views: manifest.views.map((view) => ({ id: view.id, kind: view.kind })) });
    out.push(await attempt('full', () => cells.sheetClipboard('cells', full)));
    out.push(await attempt('single-far', () => cells.sheetClipboard('cells', { row0: 3, col0: 6, row1: 3, col1: 6 })));
    out.push(await attempt('single-below', () => cells.sheetClipboard('cells', { row0: 9, col0: 0, row1: 9, col1: 0 })));
    out.push(await attempt('skip-hidden', () => cells.sheetClipboard('cells', { row0: 0, col0: 0, row1: 4, col1: 9 })));
    out.push(await attempt('empty-region', () => cells.sheetClipboard('cells', { row0: 6, col0: 8, row1: 8, col1: 9 })));
    for (const [label, range] of [
      ['invalid-missing', undefined],
      ['invalid-null', null],
      ['invalid-reversed', { row0: 1, row1: 0, col0: 0, col1: 0 }],
      ['invalid-negative', { row0: -1, row1: 0, col0: 0, col1: 0 }],
      ['invalid-fraction', { row0: 0.5, row1: 1, col0: 0, col1: 0 }],
      ['invalid-string', { row0: '0', row1: '1', col0: '0', col1: '0' }],
      ['invalid-area', { row0: 0, row1: 1000000, col0: 0, col1: 1000 }],
      ['invalid-over-cap', { row0: 16777217, row1: 16777217, col0: 0, col1: 0 }],
      ['outside-sheet-rows', { row0: 0, row1: 15, col0: 0, col1: 0 }],
      ['outside-sheet-cols', { row0: 0, row1: 0, col0: 0, col1: 10 }],
      ['cap-but-outside-sheet', { row0: 1000001, row1: 1000001, col0: 0, col1: 0 }],
    ]) {
      out.push(await attempt(label, () => cells.sheetClipboard('cells', range)));
    }
    out.push(await attempt('unknown-view', () => cells.sheetClipboard('nope', { row0: 0, row1: 0, col0: 0, col1: 0 })));
    await cells.close();
    out.push(await attempt('after-close', () => cells.sheetClipboard('cells', full)));
    cells.terminate();

    const flow = client();
    const flowManifest = await flow.open({ kind: 'buffer', buffer: (await bytes('/compat/continuous/flow.bdf')).buffer });
    out.push({ label: 'flow-views', views: flowManifest.views.map((view) => ({ id: view.id, kind: view.kind })) });
    const flowView = flowManifest.views[0];
    out.push(await attempt('non-sheet-view', () => flow.sheetClipboard(flowView.id, { row0: 0, row1: 0, col0: 0, col1: 0 })));
    flow.terminate();

    const split = client();
    await split.open({ kind: 'split', base: '/compat/sheet/cells-split/' });
    out.push(await attempt('split-full', () => split.sheetClipboard('cells', full)));
    split.terminate();

    const broken = client();
    await broken.open({ kind: 'split', base: '/split-missing/' });
    out.push(await attempt('split-part-404', () => broken.sheetClipboard('cells', full)));
    broken.terminate();

    const dead = client();
    await dead.open({ kind: 'buffer', buffer: (await bytes('/compat/sheet/cells.bdf')).buffer });
    dead.terminate();
    out.push(await attempt('terminated', () => dead.sheetClipboard('cells', full)));
    return out;
  });

  const label = (name) => {
    const item = results.find((entry) => entry.label === name);
    assert.ok(item, 'result present: ' + name);
    return item;
  };
  const expectError = (name, expected) => {
    const item = label(name);
    assert.ok(!item.ok, name + ' fails');
    assert.equal(item.name, 'BdfWorkerError', name + ' error name');
    if (expected instanceof RegExp) assert.match(item.message, expected, name + ' error message');
    else assert.equal(item.message, expected, name + ' error message');
  };
  const opened = label('open');
  assert.deepEqual(opened.views, [{ id: 'cells', kind: 'sheet' }], 'sheet fixture views');

  // Whole sheet: merged, hidden axes, scope headers, offscreen tiles.
  const full = label('full');
  assert.ok(full.ok, 'whole-sheet range succeeds');
  assert.deepEqual(Object.keys(full.value).sort(), ['html', 'text'], 'result has text and html only');
  assert.equal(full.value.text, fullText, 'whole-sheet TSV');
  assert.equal(full.value.html, fullHtml, 'whole-sheet HTML');

  // Single cells in tiles far from the origin, never drawn by a viewport render.
  assert.deepEqual(label('single-far').value, {
    text: 'Far',
    html: '<meta charset="utf-8"><table><tr><td>Far</td></tr></table>',
  }, 'offscreen single cell');
  assert.deepEqual(label('single-below').value, {
    text: 'Below',
    html: '<meta charset="utf-8"><table><tr><td>Below</td></tr></table>',
  }, 'second tile row single cell');

  // Hidden row/column runs are skipped without shifting the grid.
  assert.deepEqual(label('skip-hidden').value, {
    text: tsvLines.slice(0, 4).join('\n'),
    html: '<meta charset="utf-8"><table>' + htmlRows.slice(0, 4).join('') + '</table>',
  }, 'hidden axes are skipped');

  // Cell-free region still emits the full empty grid (columns I and J).
  assert.deepEqual(label('empty-region').value, {
    text: '\t\n\t\n\t',
    html: '<meta charset="utf-8"><table>' + '<tr><td></td><td></td></tr>'.repeat(3) + '</table>',
  }, 'empty region grid');

  // Malformed and out-of-sheet input is rejected with distinct messages.
  for (const name of ['invalid-missing', 'invalid-null', 'invalid-reversed', 'invalid-negative',
    'invalid-fraction', 'invalid-string', 'invalid-area', 'invalid-over-cap']) {
    expectError(name, 'invalid sheet clipboard range');
  }
  for (const name of ['outside-sheet-rows', 'outside-sheet-cols', 'cap-but-outside-sheet']) {
    expectError(name, 'sheet clipboard range is outside the sheet');
  }
  expectError('before-open', 'bdf: no document open');
  expectError('after-close', 'bdf: no document open');
  expectError('unknown-view', 'bdf: unknown view nope');
  const flowViews = label('flow-views');
  assert.equal(flowViews.views[0].kind, 'flow', 'flow fixture is a continuous view');
  expectError('non-sheet-view', 'bdf: view ' + flowViews.views[0].id + ' is not a sheet');

  // Split sources serve the same clipboard through lazy part loading.
  assert.deepEqual(label('split-full').value, { text: fullText, html: fullHtml }, 'split source matches buffer source');
  expectError('split-part-404', new RegExp('fetch failed with 404'));
  expectError('terminated', 'render worker terminated');
  assert.deepEqual(browserErrors, [], 'no uncaught page errors');
} finally {
  await browser.close();
  await new Promise((resolve) => server.close(resolve));
}
console.log('clipboard-test: sheetClipboard worker/client scenarios passed');
