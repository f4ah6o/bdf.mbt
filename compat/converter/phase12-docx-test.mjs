import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, resolve } from 'node:path';
import { chromium } from 'playwright';

const root = resolve(import.meta.dirname, '../..');
const mime = {
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.mjs': 'text/javascript',
  '.wasm': 'application/wasm',
  '.docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
};
const server = createServer(async (request, response) => {
  if (request.url === '/blank.html') {
    response.writeHead(200, { 'content-type': 'text/html' });
    response.end('<!doctype html><title>docx</title>');
    return;
  }
  try {
    const file = resolve(root, '.' + decodeURIComponent(new URL(request.url, 'http://x').pathname));
    if (!file.startsWith(root + '/')) {
      response.writeHead(403).end();
      return;
    }
    const data = await readFile(file);
    response.writeHead(200, { 'content-type': mime[extname(file)] ?? 'application/octet-stream' });
    response.end(data);
  } catch {
    response.writeHead(404).end();
  }
});
await new Promise((resolvePromise, reject) => {
  server.once('error', reject);
  server.listen(0, '127.0.0.1', resolvePromise);
});
const base = 'http://127.0.0.1:' + server.address().port;
const browser = await chromium.launch({ headless: true });
try {
  const page = await browser.newPage();
  await page.goto(base + '/blank.html');
  const result = await page.evaluate(async base => {
    const { Converter } = await import('/node_modules/@bdfkit/convert/dist/index.js');
    const { BdfDocument, BufferSource, decodeTextIndex } = await import('/node_modules/@bdfkit/core/dist/index.js');
    const { bdf_create_native_converter } = await import('/_build/js/debug/build/browser/browser.js');
    const upstream = new Converter(
      new Worker('/node_modules/@bdfkit/convert/dist/worker.js', { type: 'module' }),
      '/node_modules/@bdfkit/convert-all/dist/converter.wasm',
    );
    const moon = bdf_create_native_converter('/_build/js/debug/build/native_converter_worker/native_converter_worker.js');
    await Promise.all([upstream.ready, moon.ready]);
    const inspectView = async (doc, view) => {
      const text = view.textIndex
        ? decodeTextIndex(await doc.part(view.textIndex)).map(run => run.text).join(' ')
        : '';
      return {
        id: view.id,
        kind: view.kind,
        pages: view.pages.length,
        roles: view.pages.map(p => (p.layers ?? []).map(l => l.role)),
        body: view.pages[0]?.body ?? null,
        size: view.pages[0] ? [view.pages[0].w, view.pages[0].h] : null,
        text,
      };
    };
    const inspect = async bdf => {
      const doc = await BdfDocument.open(new BufferSource(bdf));
      const views = [];
      for (const view of doc.manifest.views) views.push(await inspectView(doc, view));
      return { meta: doc.manifest.meta ?? null, views };
    };
    const cases = [];
    for (const name of ['basic', 'styles', 'grid', 'vertical', 'math']) {
      const data = new Uint8Array(await (await fetch(base + '/.upstream/converter/docx/testdata/' + name + '.docx')).arrayBuffer());
      const a = await upstream.convert(data, { name: name + '.docx' });
      const m = await moon.convert(data, { name: name + '.docx' });
      cases.push({
        name,
        upstream: { summary: a.summary, warnings: a.warnings, ...(await inspect(a.bdf)) },
        moon: { summary: m.summary, warnings: m.warnings, ...(await inspect(m.bdf)) },
      });
    }
    moon.terminate();
    return cases;
  }, base);
  const normalize = value => value.replace(/\\s+/g, '');
  const lcs = (a, b) => {
    let previous = new Array(b.length + 1).fill(0);
    for (let i = 1; i <= a.length; i++) {
      const current = new Array(b.length + 1).fill(0);
      for (let j = 1; j <= b.length; j++) {
        current[j] = a[i - 1] === b[j - 1]
          ? previous[j - 1] + 1
          : Math.max(previous[j], current[j - 1]);
      }
      previous = current;
    }
    return previous[b.length];
  };
  const similarity = (a, b) => {
    const x = normalize(a);
    const y = normalize(b);
    return 2 * lcs(x, y) / (x.length + y.length);
  };
  for (const entry of result) {
    const upstreamPages = entry.upstream.views.find(view => view.id === 'pages');
    const upstreamScroll = entry.upstream.views.find(view => view.id === 'scroll');
    const moonPages = entry.moon.views.find(view => view.id === 'pages');
    const moonScroll = entry.moon.views.find(view => view.id === 'scroll');
    assert.ok(upstreamPages && upstreamScroll, entry.name + ': upstream views');
    assert.ok(moonPages, entry.name + ': moon pages view');
    assert.ok(moonScroll, entry.name + ': moon scroll view');
    assert.equal(moonPages.kind, 'flow', entry.name + ': page view kind');
    assert.equal(moonScroll.kind, 'scroll', entry.name + ': scroll view kind');
    assert.ok(moonPages.pages > 0, entry.name + ': page count');
    assert.equal(moonScroll.pages, upstreamScroll.pages, entry.name + ': scroll strip count');
    assert.ok(moonPages.body && moonPages.body.w > 0 && moonPages.body.h > 0, entry.name + ': body rectangle');
    const expectedRoles = upstreamPages.roles[0] ?? [];
    assert.deepEqual(moonPages.roles[0], expectedRoles, entry.name + ': layer roles');
    assert.ok(entry.moon.summary.includes('page'), entry.name + ': page summary');
    assert.ok(entry.moon.summary.includes('scroll strip'), entry.name + ': scroll summary');
    const pageSimilarity = similarity(upstreamPages.text, moonPages.text);
    const scrollSimilarity = similarity(upstreamScroll.text, moonScroll.text);
    assert.ok(pageSimilarity >= 0.88, entry.name + ': page text similarity ' + pageSimilarity.toFixed(3));
    assert.ok(scrollSimilarity >= 0.9, entry.name + ': scroll text similarity ' + scrollSimilarity.toFixed(3));
    if (entry.name === 'basic') {
      assert.equal(entry.moon.meta?.dc?.title, entry.upstream.meta?.dc?.title, 'basic: dc title');
      assert.ok(moonPages.text.includes('BDF test document'), 'basic: header text');
    }
  }
  console.log('Phase 12 DOCX: flow/scroll views, layer roles, body rectangles, metadata and text indexes match upstream.');
} finally {
  await browser.close();
  server.close();
}
