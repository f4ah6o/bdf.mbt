import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, resolve } from 'node:path';
import { chromium } from 'playwright';

const root = resolve(import.meta.dirname, '../..');
const mime = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.wasm': 'application/wasm' };
const server = createServer(async (request, response) => {
  if (request.url === '/blank.html') {
    response.writeHead(200, { 'content-type': 'text/html' });
    response.end('<!doctype html><title>phase 9 drawio</title>');
    return;
  }
  try {
    const file = resolve(root, '.' + decodeURIComponent(new URL(request.url, 'http://x').pathname));
    if (!file.startsWith(root + '/')) { response.writeHead(403).end(); return; }
    response.writeHead(200, { 'content-type': mime[extname(file)] ?? 'application/octet-stream' });
    response.end(await readFile(file));
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
    const { BdfDocument, BufferSource, decodeTextIndex } = await import('/node_modules/@bdfkit/core/dist/index.js');
    const { bdf_create_native_converter } = await import('/_build/js/debug/build/browser/browser.js');
    const upstream = new Converter(
      new Worker('/node_modules/@bdfkit/convert/dist/worker.js', { type: 'module' }),
      '/node_modules/@bdfkit/convert-all/dist/converter.wasm',
    );
    const moon = bdf_create_native_converter('/_build/js/debug/build/native_converter_worker/native_converter_worker.js');
    await Promise.all([upstream.ready, moon.ready]);
    const summarize = async bdf => {
      const doc = await BdfDocument.open(new BufferSource(bdf));
      const views = [];
      for (const view of doc.manifest.views) {
        let text = '';
        if (view.textIndex) text = decodeTextIndex(await doc.part(view.textIndex)).map(run => run.text).join(' ');
        views.push({
          title: view.title ?? '',
          pages: (view.pages ?? []).map(page => ({ w: page.w, h: page.h, layers: page.layers.map(layer => layer.role) })),
          text,
        });
      }
      return views;
    };
    const out = [];
    for (const name of [
      'labels.drawio', 'math.drawio', 'multipage.drawio', 'showcase.drawio',
      'aws.drawio', 'embedded.drawio.svg', 'embedded.drawio.png', 'compressed.drawio',
    ]) {
      const data = new Uint8Array(await (await fetch(base + '/compat/drawio/fixtures/' + name)).arrayBuffer());
      const upstreamResult = await upstream.convert(data, { name });
      const moonResult = await moon.convert(data, { name });
      out.push({
        name,
        upstream: { summary: upstreamResult.summary, warnings: upstreamResult.warnings, views: await summarize(upstreamResult.bdf) },
        moon: { summary: moonResult.summary, warnings: moonResult.warnings, views: await summarize(moonResult.bdf) },
      });
    }
    upstream.terminate();
    moon.terminate();
    return out;
  }, base);
  for (const entry of result) {
    assert.equal(entry.moon.views.length, entry.upstream.views.length, `${entry.name} view count`);
    for (let i = 0; i < entry.moon.views.length; i++) {
      const moon = entry.moon.views[i];
      const upstream = entry.upstream.views[i];
      assert.equal(moon.pages.length, upstream.pages.length, `${entry.name} view ${i + 1} page count`);
      for (let j = 0; j < moon.pages.length; j++) {
        assert.deepEqual(moon.pages[j].layers, upstream.pages[j].layers, `${entry.name} view ${i + 1} page ${j + 1} layers`);
        assert.ok(Math.abs(moon.pages[j].w - upstream.pages[j].w) <= upstream.pages[j].w * 0.08, `${entry.name} view ${i + 1} page ${j + 1} width`);
        assert.ok(Math.abs(moon.pages[j].h - upstream.pages[j].h) <= upstream.pages[j].h * 0.08, `${entry.name} view ${i + 1} page ${j + 1} height`);
      }
      assert.ok(moon.text.length > 0, `${entry.name} view ${i + 1} text`);
    }
    if (entry.name === 'embedded.drawio.svg' || entry.name === 'embedded.drawio.png') {
      assert.ok(entry.moon.views[0].text.includes('Hello World'), `${entry.name} embedded label`);
    }
    assert.ok(entry.moon.warnings.every(warning => !warning.startsWith('drawio: invalid')), `${entry.name} no invalid warnings`);
  }
  console.log(`Phase 9 draw.io: ${result.length} fixtures match view/page/layer structure and text.`);
} finally {
  await browser.close();
  server.close();
}
