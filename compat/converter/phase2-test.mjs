import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join, resolve } from 'node:path';
import { chromium } from 'playwright';

const root = resolve(import.meta.dirname, '../..');
const mime = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.idml': 'application/octet-stream', '.vsdx': 'application/octet-stream' };
const server = createServer(async (request, response) => {
  if (request.url === '/blank.html') {
    response.writeHead(200, { 'content-type': 'text/html' });
    response.end('<!doctype html><title>phase 2</title>');
    return;
  }
  try {
    const file = resolve(root, '.' + decodeURIComponent(new URL(request.url, 'http://x').pathname));
    if (!file.startsWith(root + '/')) { response.writeHead(403).end(); return; }
    const data = await readFile(file);
    response.writeHead(200, { 'content-type': mime[extname(file)] ?? 'application/octet-stream' });
    response.end(data);
  } catch { response.writeHead(404).end(); }
});
await new Promise((resolvePromise, reject) => { server.once('error', reject); server.listen(0, '127.0.0.1', resolvePromise); });
const base = `http://127.0.0.1:${server.address().port}`;
const browser = await chromium.launch({ headless: true });
try {
  const page = await browser.newPage();
  await page.goto(base + '/blank.html');
  const result = await page.evaluate(async base => {
    const { Converter } = await import('/node_modules/@bdfkit/convert/dist/index.js');
    const { BdfDocument, BufferSource } = await import('/node_modules/@bdfkit/core/dist/index.js');
    const { bdf_create_native_converter } = await import('/_build/js/debug/build/browser/browser.js');
    const upstream = new Converter(
      new Worker('/node_modules/@bdfkit/convert/dist/worker.js', { type: 'module' }),
      '/node_modules/@bdfkit/convert-all/dist/converter.wasm',
    );
    const moon = bdf_create_native_converter('/_build/js/debug/build/native_converter_worker/native_converter_worker.js');
    const formats = (await Promise.all([upstream.ready, moon.ready])).map(list => list.map(format => format.name));
    const inspect = async bdf => {
      const doc = await BdfDocument.open(new BufferSource(bdf));
      return doc.manifest.views[0].pages.map(page => ({ w: page.w, h: page.h, layers: page.layers.map(layer => layer.role) }));
    };
    const out = { formats };
    for (const [name, path] of [
      ['basic', '/compat/idml/fixtures/basic.idml'],
      ['vertical', '/compat/idml/fixtures/vertical.idml'],
      ['shapes', '/compat/visio/fixtures/shapes.vsdx'],
      ['flow', '/compat/visio/fixtures/flow.vsdx'],
    ]) {
      const extension = path.endsWith('.vsdx') ? '.vsdx' : '.idml';
      const data = new Uint8Array(await (await fetch(base + path)).arrayBuffer());
      const a = await upstream.convert(data, { name: name + extension });
      const m = await moon.convert(data, { name: name + extension });
      out[name] = {
        upstream: { summary: a.summary, warnings: a.warnings, pages: await inspect(a.bdf) },
        moon: { summary: m.summary, warnings: m.warnings, pages: await inspect(m.bdf) },
      };
    }
    {
      const data = new Uint8Array(await (await fetch(base + '/compat/idml/fixtures/basic.idml')).arrayBuffer());
      const opened = await moon.open(data, { name: 'basic.idml' });
      const first = await moon.page(opened.stream, 0);
      const doc = await BdfDocument.open(new BufferSource(first.bdf));
      out.open = { pages: opened.pages, first: doc.manifest.views[0].pages.length };
      await moon.finish(opened.stream);
      await moon.close(opened.stream);
      const selected = await moon.convert(data, { name: 'basic.idml', pages: '2' });
      const selectedDoc = await BdfDocument.open(new BufferSource(selected.bdf));
      out.selected = selectedDoc.manifest.views[0].pages.length;
    }
    upstream.terminate();
    moon.terminate();
    return out;
  }, base);
  assert.ok(result.formats[0].includes('idml'));
  assert.ok(result.formats[1].includes('idml'));
  assert.ok(result.formats[0].includes('visio'));
  assert.ok(result.formats[1].includes('visio'));
  for (const name of ['basic', 'vertical', 'shapes', 'flow']) {
    const { upstream, moon } = result[name];
    assert.equal(moon.pages.length, upstream.pages.length, `${name} page count`);
    for (let i = 0; i < moon.pages.length; i++) {
      assert.ok(Math.abs(moon.pages[i].w - upstream.pages[i].w) < 0.01, `${name} page ${i + 1} width`);
      assert.ok(Math.abs(moon.pages[i].h - upstream.pages[i].h) < 0.01, `${name} page ${i + 1} height`);
      assert.deepEqual(moon.pages[i].layers, upstream.pages[i].layers, `${name} page ${i + 1} layers`);
    }
  }
  assert.ok(result.basic.moon.warnings.some(w => w.includes('text flow between frames')), 'IDML text flow gap is warned');
  assert.deepEqual(result.open, { pages: 3, first: 1 });
  assert.equal(result.selected, 1);
  console.log('Phase 2 IDML/Visio: page count, page geometry and layer roles match upstream; IDML text flow is an approximate subset.');
} finally {
  await browser.close();
  server.close();
}
