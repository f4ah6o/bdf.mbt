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
    response.end('<!doctype html><title>phase 8 parquet</title>');
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
    const { BdfDocument, BufferSource, decodeTextIndex } = await import('/node_modules/@bdfkit/core/dist/index.js');
    const { bdf_create_native_converter } = await import('/_build/js/debug/build/browser/browser.js');
    const moon = bdf_create_native_converter('/_build/js/debug/build/native_converter_worker/native_converter_worker.js');
    await moon.ready;
    const data = new Uint8Array(await (await fetch(base + '/compat/parquet/input.parquet')).arrayBuffer());
    const converted = await moon.convert(data, { name: 'input.parquet' });
    const doc = await BdfDocument.open(new BufferSource(converted.bdf));
    const view = doc.manifest.views[0];
    const text = view.textIndex ? decodeTextIndex(await doc.part(view.textIndex)).map(run => run.text).join('\n') : '';
    moon.terminate();
    return { summary: converted.summary, warnings: converted.warnings, kind: view.kind, tiles: view.tiles.length, text, tables: doc.manifest.tables.length };
  }, base);
  assert.equal(result.kind, 'sheet', 'Parquet view is a sheet');
  assert.ok(result.text.includes('日本語') && result.text.includes('number'), 'Parquet sheet text');
  assert.equal(result.tables, 1, 'Parquet sheet attaches a typed table');
  assert.equal(result.warnings.filter(warning => !warning.includes('no fonts found')).length, 0, 'Parquet warnings');
  console.log(`Phase 8 Parquet: ${result.summary} rendered as a sheet with ${result.tables} table.`);
} finally {
  await browser.close();
  server.close();
}
