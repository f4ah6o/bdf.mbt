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
  '.pdf': 'application/pdf',
};
const server = createServer(async (request, response) => {
  if (request.url === '/blank.html') {
    response.writeHead(200, { 'content-type': 'text/html' });
    response.end('<!doctype html><title>pdf</title>');
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
    const inspect = async bdf => {
      const doc = await BdfDocument.open(new BufferSource(bdf));
      const views = [];
      for (const view of doc.manifest.views) {
        const text = view.textIndex
          ? decodeTextIndex(await doc.part(view.textIndex)).map(run => run.text).join(' ')
          : '';
        views.push({
          id: view.id,
          kind: view.kind,
          pages: view.pages?.length ?? 0,
          sizes: (view.pages ?? []).map(p => [p.w, p.h]),
          body: view.pages?.[0]?.body ?? null,
          text,
        });
      }
      return views;
    };
    const cases = [];
    for (const name of [
      'cairo-cff.pdf', 'cairo-type1.pdf', 'chrome-doc.pdf', 'chrome-masks.pdf',
      'chrome-slides.pdf', 'cjk-cmaps.pdf', 'reportlab-master.pdf',
      'reportlab-mixed.pdf', 'reportlab-type1.pdf', 'weasyprint-webfonts.pdf',
    ]) {
      const data = new Uint8Array(await (await fetch(base + '/compat/pdf/fixtures/' + name)).arrayBuffer());
      const a = await upstream.convert(data, { name });
      const m = await moon.convert(data, { name });
      cases.push({
        name,
        upstream: { summary: a.summary, warnings: a.warnings, views: await inspect(a.bdf) },
        moon: { summary: m.summary, warnings: m.warnings, views: await inspect(m.bdf) },
      });
    }
    const flowData = new Uint8Array(await (await fetch(base + '/compat/pdf/fixtures/reportlab-master.pdf')).arrayBuffer());
    const flowUpstream = await upstream.convert(flowData, { name: 'reportlab-master.pdf', params: { kind: 'flow' } });
    const flowMoon = await moon.convert(flowData, { name: 'reportlab-master.pdf', params: { kind: 'flow' } });
    const flow = {
      upstream: await inspect(flowUpstream.bdf),
      moon: await inspect(flowMoon.bdf),
    };
    let invalidKind = '';
    try { await moon.convert(flowData, { name: 'reportlab-master.pdf', params: { kind: 'wrong' } }); }
    catch (error) { invalidKind = String(error?.message ?? error); }
    let selected = 0;
    try {
      const one = await moon.convert(flowData, { name: 'reportlab-master.pdf', pages: '2' });
      selected = (await inspect(one.bdf))[0].pages;
    } catch {}
    moon.terminate();
    return { cases, flow, invalidKind, selected };
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
  for (const entry of result.cases) {
    const a = entry.upstream.views[0];
    const m = entry.moon.views[0];
    assert.equal(m.id, a.id, entry.name + ': view id');
    assert.equal(m.kind, a.kind, entry.name + ': view kind');
    assert.equal(m.pages, a.pages, entry.name + ': page count');
    assert.deepEqual(m.sizes, a.sizes, entry.name + ': page sizes');
    const ratio = similarity(a.text, m.text);
    assert.ok(ratio >= 0.95, entry.name + ': text similarity ' + ratio.toFixed(3));
  }
  const flowUpstream = result.flow.upstream[0];
  const flowMoon = result.flow.moon[0];
  assert.equal(flowMoon.kind, 'flow', 'flow: kind');
  assert.equal(flowMoon.kind, flowUpstream.kind, 'flow: upstream kind');
  assert.deepEqual(flowMoon.body, flowUpstream.body, 'flow: body rectangle');
  assert.equal(flowMoon.pages, flowUpstream.pages, 'flow: page count');
  assert.match(result.invalidKind, /view kind/, 'invalid kind error');
  assert.equal(result.selected, 1, 'page selection');
  console.log('Phase 13 PDF: page geometry, text indexes, flow views, page selection and kind validation match upstream.');
} finally {
  await browser.close();
  server.close();
}
