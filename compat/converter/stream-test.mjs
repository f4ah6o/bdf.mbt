import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, resolve } from 'node:path';
import { chromium } from 'playwright';

const root = resolve(import.meta.dirname, '../..');
const mime = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.wasm': 'application/wasm', '.pdf': 'application/pdf' };
const server = createServer(async (request, response) => {
  if (request.url === '/blank.html') {
    response.writeHead(200, { 'content-type': 'text/html' });
    response.end('<!doctype html><title>converter stream</title>');
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
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
  await page.goto(base + '/blank.html');
  const result = await page.evaluate(async base => {
    const { BdfDocument, BufferSource } = await import('/node_modules/@bdfkit/core/dist/index.js');
    const { bdf_create_native_converter } = await import('/_build/js/debug/build/browser/browser.js');
    const moon = bdf_create_native_converter('/_build/js/debug/build/native_converter_worker/native_converter_worker.js');
    await moon.ready;
    const name = 'reportlab-type1.pdf';
    const data = new Uint8Array(await (await fetch(base + '/compat/pdf/fixtures/' + name)).arrayBuffer());
    const converted = await moon.convert(data, { name });
    const convertedDoc = await BdfDocument.open(new BufferSource(converted.bdf));
    const convertedPages = convertedDoc.manifest.views[0].pages.length;
    const opened = await moon.open(data, { name });
    const first = await moon.page(opened.stream, 0);
    const firstDoc = await BdfDocument.open(new BufferSource(first.bdf));
    const finished = await moon.finish(opened.stream);
    const finishedDoc = await BdfDocument.open(new BufferSource(finished.bdf));
    const finishedAgain = await moon.finish(opened.stream);
    const finishedAgainDoc = await BdfDocument.open(new BufferSource(finishedAgain.bdf));
    const closed = await moon.close(opened.stream);
    let afterClose = '';
    try { await moon.finish(opened.stream); } catch (error) { afterClose = String(error?.message ?? error); }
    moon.terminate();
    return {
      convertedPages,
      openedPages: opened.pages,
      firstPages: firstDoc.manifest.views[0].pages.length,
      pageHasBdf: first.bdf instanceof Uint8Array,
      pageWarnings: Array.isArray(first.warnings),
      finishHasBdf: finished.bdf instanceof Uint8Array,
      finishFormat: finished.format,
      finishSummary: typeof finished.summary,
      finishWarnings: Array.isArray(finished.warnings),
      finishedPages: finishedDoc.manifest.views[0].pages.length,
      finishedAgainPages: finishedAgainDoc.manifest.views[0].pages.length,
      closed,
      afterClose,
    };
  }, base);
  assert.deepEqual(errors, [], 'page errors');
  assert.ok(result.convertedPages > 0, 'PDF has pages');
  assert.equal(result.openedPages, result.convertedPages, 'open reports the page count');
  assert.equal(result.firstPages, 1, 'page 0 is one page');
  assert.equal(result.pageHasBdf, true, 'page result carries bdf');
  assert.equal(result.pageWarnings, true, 'page result carries warnings');
  assert.equal(result.finishHasBdf, true, 'finish returns the whole document');
  assert.equal(result.finishFormat, 'pdf', 'finish keeps the format');
  assert.equal(result.finishSummary, 'string', 'finish keeps the summary');
  assert.equal(result.finishWarnings, true, 'finish keeps warnings');
  assert.equal(result.finishedPages, result.convertedPages, 'finish matches convert');
  assert.equal(result.finishedAgainPages, result.convertedPages, 'finish can be repeated');
  assert.equal(result.closed, null, 'close resolves to null');
  assert.ok(String(result.afterClose).includes('no conversion'), `finish after close fails (got ${result.afterClose})`);
  console.log('Converter stream: open/page/finish return the complete document, page warnings and stable close behavior.');
} finally {
  await browser.close();
  server.close();
}
