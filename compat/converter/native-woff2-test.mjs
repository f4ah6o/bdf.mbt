import assert from 'node:assert/strict';
import { createReadStream } from 'node:fs';
import { createServer } from 'node:http';
import path from 'node:path';
import { chromium } from 'playwright';
const root = process.cwd();
const allowed = ['/compat/specimen/', '/node_modules/@bdfkit/', '/_build/js/debug/build/browser/', '/_build/js/debug/build/native_converter_worker/'];
const server = createServer((request, response) => {
  const pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
  if (pathname === '/') { response.setHeader('Content-Type', 'text/html'); response.end('<!doctype html><title>Font conversion</title>'); return; }
  const file = path.resolve(root, '.' + pathname);
  if (!allowed.some(prefix => file.startsWith(path.resolve(root, '.' + prefix) + path.sep))) { response.writeHead(403).end(); return; }
  response.setHeader('Content-Type', path.extname(file) === '.js' ? 'text/javascript' : 'application/octet-stream');
  const stream = createReadStream(file); stream.once('error', () => { if (!response.headersSent) response.writeHead(404); response.end(); }); stream.pipe(response);
});
await new Promise((resolve, reject) => { server.once('error', reject); server.listen(0, '127.0.0.1', resolve); });
const base = `http://127.0.0.1:${server.address().port}`;
try {
  const browser = await chromium.launch({headless: true});
  try {
    const page = await browser.newPage(); await page.goto(base);
    const result = await page.evaluate(async () => {
      const {bdf_create_native_converter} = await import('/_build/js/debug/build/browser/browser.js');
      const {BdfDocument, BufferSource} = await import('/node_modules/@bdfkit/core/dist/index.js');
      const unpack = async data => new Uint8Array(await new Response(new Blob([data]).stream().pipeThrough(new DecompressionStream('gzip'))).arrayBuffer());
      const from64 = value => Uint8Array.from(atob(value), c => c.charCodeAt(0));
      const fixture = JSON.parse(new TextDecoder().decode(await unpack(await (await fetch('/compat/specimen/convert.json.gz')).arrayBuffer())));
      const stable = value => Array.isArray(value) ? value.map(stable) : value && typeof value === 'object' ? Object.fromEntries(Object.keys(value).sort().map(k => [k, stable(value[k])])) : value;
      const client = bdf_create_native_converter('/_build/js/debug/build/native_converter_worker/native_converter_worker.js');
      let count = 0;
      try {
        await client.ready;
        for (const name of ['stix-ttf.woff2', 'stix-cff.woff2']) {
          const expected = fixture.cases.find(c => c.name === name && !c.system && !c.uiFont && !c.noIndex && !c.noSubset);
          const input = await unpack(from64(fixture.files[name]));
          for (const options of [{params:{examples:'5'}}, {format:'font', name, params:{examples:'5'}}]) {
            const output = await client.convert(input, options);
            if (output.format !== 'font' || output.summary !== expected.summary || JSON.stringify(output.warnings) !== JSON.stringify(expected.warnings)) throw new Error(name + ': conversion report differs');
            const doc = await BdfDocument.open(new BufferSource(output.bdf));
            if (JSON.stringify(stable(doc.manifest.views)) !== JSON.stringify(stable(expected.views))) throw new Error(name + ': views differ');
            for (const part of expected.parts) {
              const actual = new Uint8Array(await doc.part(part.hash)), bytes = from64(part.data);
              if (actual.length !== bytes.length || actual.some((v, i) => v !== bytes[i])) throw new Error(name + ': part differs');
            }
            count++;
          }
        }
      } finally { client.terminate(); }
      return count;
    });
    assert.equal(result, 4); await page.close();
    console.log('Four browser Worker WOFF2 conversions match upstream.');
  } finally { await browser.close(); }
} finally { await new Promise(resolve => server.close(resolve)); }
