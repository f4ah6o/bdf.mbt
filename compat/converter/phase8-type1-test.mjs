import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, resolve } from 'node:path';

const mime = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.wasm': 'application/wasm' };
import { chromium } from 'playwright';

const root = resolve(import.meta.dirname, '../..');
const server = createServer(async (request, response) => {
  if (request.url === '/blank.html') {
    response.writeHead(200, { 'content-type': 'text/html' });
    response.end('<!doctype html><title>phase 8</title>');
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
  const out = await page.evaluate(async base => {
    const { BdfDocument, BufferSource, decodeTextIndex } = await import('/node_modules/@bdfkit/core/dist/index.js');
    const { bdf_create_native_converter } = await import('/_build/js/debug/build/browser/browser.js');
    const moon = bdf_create_native_converter('/_build/js/debug/build/native_converter_worker/native_converter_worker.js');
    await moon.ready;
    const cases = [];
    for (const name of ['cairo-type1.pdf', 'reportlab-type1.pdf']) {
      const data = new Uint8Array(await (await fetch(base + '/compat/pdf/fixtures/' + name)).arrayBuffer());
      const converted = await moon.convert(data, { name });
      const doc = await BdfDocument.open(new BufferSource(converted.bdf));
      const view = doc.manifest.views[0];
      const index = view.textIndex ? decodeTextIndex(await doc.part(view.textIndex)).map(run => run.text).join('') : '';
      cases.push({
        name,
        pages: view.pages.length,
        fonts: doc.manifest.parts.filter(part => part.t === 'font').length,
        warnings: converted.warnings,
        text: index,
      });
    }
    moon.terminate();
    return cases;
  }, base);
  for (const entry of out) {
    assert.ok(entry.pages >= 1, `${entry.name} pages`);
    assert.ok(entry.fonts > 0, `${entry.name} embeds a converted Type 1 font`);
    assert.equal(entry.warnings.length, 0, `${entry.name} warnings`);
    assert.ok(entry.text.length > 0, `${entry.name} text`);
  }
  console.log(`Phase 8 PDF Type 1: ${out.length} fixtures embed converted CFF fonts without fallback warnings.`);
} finally {
  await browser.close();
  server.close();
}
