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
    response.end('<!doctype html><title>phase 9 parquet</title>');
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
    const out = [];
    for (const name of ['basic', 'codecs', 'duckdb', 'encodings', 'geo', 'legacy', 'nested', 'types', 'variant']) {
      const data = new Uint8Array(await (await fetch(base + '/compat/parquet/fixtures/' + name + '.parquet')).arrayBuffer());
      try {
        const converted = await moon.convert(data, { name: name + '.parquet' });
        const doc = await BdfDocument.open(new BufferSource(converted.bdf));
        const view = doc.manifest.views[0];
        const text = view.textIndex ? decodeTextIndex(await doc.part(view.textIndex)).map(run => run.text).join(' ') : '';
        const table = doc.manifest.tables[0];
        const tableBytes = table ? await doc.part(table.part) : null;
        out.push({ name, summary: converted.summary, warnings: converted.warnings, text, tables: doc.manifest.tables.length, tableData: tableBytes ? (tableBytes.length === data.length && tableBytes.every((value, index) => value === data[index])) : false });
      } catch (error) {
        out.push({ name, error: String(error?.message ?? error) });
      }
    }
    moon.terminate();
    return out;
  }, base);
  const expected = {
    basic: { rows: 8, cols: 11, text: ['1200.00', '2026-01-05', '["red", "blue"]'] },
    codecs: { rows: 200, cols: 6, text: ['value 1'] },
    duckdb: { rows: 5, cols: 6, text: ['red'] },
    encodings: { rows: 300, cols: 16, text: ['-50000'] },
    geo: { rows: 9, cols: 2, text: ['point'] },
    legacy: { rows: 3, cols: 2, text: ['2024-01-01'] },
    nested: { rows: 4, cols: 9, text: ['[1, 2]'] },
    types: { rows: 4, cols: 31, text: ['-128', '1970-01-01'] },
    variant: { rows: 6, cols: 3, text: ['id'] },
  };
  for (const entry of result) {
    const want = expected[entry.name];
    assert.equal(entry.error, undefined, `${entry.name}: ${entry.error}`);
    assert.match(entry.summary, new RegExp(`\\(${want.rows} rows × ${want.cols} columns\\)`), `${entry.name} shape`);
    assert.ok(entry.tables > 0, `${entry.name} table part`);
    assert.equal(entry.tableData, true, `${entry.name} stores the source file`);
    for (const text of want.text) {
      assert.ok(entry.text.includes(text), `${entry.name} text ${text}`);
    }
  }
  console.log(`Phase 9 Parquet: ${result.length} upstream fixtures decode with codecs, encodings, nested values and dates.`);
} finally {
  await browser.close();
  server.close();
}
