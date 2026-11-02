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
    basic: {
      rows: 8,
      cols: 11,
      text: [
        '1200.00',
        '2026-01-05',
        '["red", "blue"]',
        '2026-09-27 09:30:00.000 ["red", "blue"] {"w": 1920, "h": 1080}',
        '2026-09-27 10:15:30.250 [] {"w": 1280, "h": 720}',
        '2026-09-27 11:00:00.500 4 すずき',
        '2026-04-30 ["green"] {"w": 800, "h": 600}',
        '5 空白 6 カタカナ',
        '["a", "b", "c"] {"w": 3, "h": 4}',
        '["x"] {"w": 1, "h": 1}',
        '1999-12-31 23:59:59.999 [null, "y"] {"w": 0, "h": 0}',
      ],
    },
    codecs: { rows: 200, cols: 6, text: ['value 1'] },
    duckdb: {
      rows: 5,
      cols: 6,
      text: [
        'red',
        'POINT (1 2)',
        'LINESTRING (0 0, 1 1)',
        'POLYGON ((0 0, 4 0, 4 4, 0 0))',
        'POINT EMPTY',
        '{"a": 1, "b": [true, null]}',
        '"text"',
        '[1, "two", 3.5]',
      ],
    },
    encodings: { rows: 300, cols: 16, text: ['-50000'] },
    geo: {
      rows: 9,
      cols: 2,
      text: [
        'point',
        'POINT (139.767 35.681)',
        'LINESTRING (0 0, 1.5 2, 3 0)',
        'POLYGON ((0 0, 10 0, 10 10, 0 10, 0 0), (2 2, 3 2, 3 3, 2 2))',
        'MULTIPOINT ((1 2), (3 4))',
        'MULTIPOLYGON (((0 0, 1 0, 0 1, 0 0)))',
        'GEOMETRYCOLLECTION (POINT (5 6), LINESTRING (7 8, 9 10))',
        'POINT Z (1 2 3)',
        'POINT EMPTY',
      ],
    },
    legacy: { rows: 3, cols: 2, text: ['2024-01-01'] },
    nested: { rows: 4, cols: 9, text: ['[1, 2]'] },
    types: { rows: 4, cols: 31, text: ['-128', '1970-01-01'] },
    variant: {
      rows: 6,
      cols: 3,
      text: [
        'id',
        '{"a": 1, "b": "x"}',
        '[1, 2]',
        '{"a": 2, "b": "y", "c": true}',
        '{"a": null, "b": "z"}',
        '"not a list"',
        '{"a": "text", "b": {"deep": [1.5]}}',
        '[4, null]',
      ],
    },
  };
  for (const entry of result) {
    const want = expected[entry.name];
    assert.equal(entry.error, undefined, `${entry.name}: ${entry.error}`);
    assert.match(entry.summary, new RegExp(`\\(${want.rows} rows × ${want.cols} columns`), `${entry.name} shape`);
    assert.ok(entry.tables > 0, `${entry.name} table part`);
    assert.equal(entry.tableData, true, `${entry.name} stores the source file`);
    for (const text of want.text) {
      assert.ok(entry.text.includes(text), `${entry.name} text ${text}`);
    }
  }
  console.log(`Phase 9 Parquet: ${result.length} upstream fixtures decode with codecs, encodings, nested values, WKT geometries and Variants.`);
} finally {
  await browser.close();
  server.close();
}
