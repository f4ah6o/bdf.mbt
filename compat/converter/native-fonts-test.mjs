import assert from 'node:assert/strict';
import { createReadStream, readFileSync } from 'node:fs';
import { createServer } from 'node:http';
import { gunzipSync } from 'node:zlib';
import path from 'node:path';
import { chromium } from 'playwright';

const root = process.cwd();
const oracleWasm = process.env.BDF_UPSTREAM_WASM;
const oracleRuntime = process.env.BDF_GO_EXEC;
const fixture = JSON.parse(readFileSync('compat/fontdb/upstream.json', 'utf8'));
const files = fixture.files.map(file => ({ ...file, data:gunzipSync(Buffer.from(file.gzip, 'base64')) }));
const sample = fixture.conversions.find(x => x.group === 4 && x.scenario === 0 && x.mode === 1);
const counts = new Map();
const server = createServer((request, response) => {
  const url = new URL(request.url, 'http://localhost');
  counts.set(url.pathname, (counts.get(url.pathname) ?? 0) + 1);
  if (oracleWasm && oracleRuntime && (url.pathname === '/oracle.wasm' || url.pathname === '/wasm_exec.js')) {
    response.setHeader('Content-Type', url.pathname.endsWith('.wasm') ? 'application/wasm' : 'text/javascript');
    createReadStream(url.pathname.endsWith('.wasm') ? oracleWasm : oracleRuntime).pipe(response); return;
  }
  if (url.pathname === '/') {
    response.setHeader('Content-Type', 'text/html');
    response.end('<!doctype html><title>Converter font test</title>'); return;
  }
  if (url.pathname === '/fonts/index.json') {
    response.setHeader('Content-Type', 'application/json');
    response.end(JSON.stringify(files.map((file, i) => ({ name:file.path, size:file.data.length, ...(i % 2 ? {url:'../font-files/' + file.path} : {}) })))); return;
  }
  if (url.pathname === '/upper/index.json') {
    response.setHeader('Content-Type', 'application/json');
    response.end(JSON.stringify([null, ...files.map(file => ({Name:file.path, Size:file.data.length, URL:'../font-files/' + file.path}))])); return;
  }
  if (url.pathname === '/disconnect/index.json') { request.socket.destroy(); return; }
  if (url.pathname === '/fileflaky/index.json') {
    response.setHeader('Content-Type', 'application/json');
    response.end(JSON.stringify([{name:'00.ttf',size:files[0].data.length,url:'/fileflaky-source/00.ttf'}])); return;
  }
  if (url.pathname === '/fileflaky-source/00.ttf') {
    if (counts.get(url.pathname) === 1) { response.writeHead(503).end(); return; }
    response.setHeader('Content-Type', 'font/ttf'); response.end(files[0].data); return;
  }
  if (url.pathname === '/flaky/index.json') {
    if (counts.get(url.pathname) === 1) { response.writeHead(503).end(); return; }
    response.setHeader('Content-Type', 'application/json'); response.end('[]'); return;
  }
  if (url.pathname === '/scanvalue/index.json') {
    response.setHeader('Content-Type', 'application/json');
    response.end(JSON.stringify([{name:'fake.ttf',size:8,scan:[[0,'bad']]}])); return;
  }
  if (url.pathname === '/scanitem/index.json') {
    response.setHeader('Content-Type', 'application/json');
    response.end(JSON.stringify([{name:'fake.ttf',size:8,scan:[1]}])); return;
  }
  if (url.pathname === '/scan/index.json') {
    response.setHeader('Content-Type', 'application/json');
    response.end(JSON.stringify([{name:'fake.ttf',size:8,scan:'bad'}])); return;
  }
  if (url.pathname === '/type/index.json') {
    response.setHeader('Content-Type', 'application/json');
    response.end(JSON.stringify([{name:4,size:1}])); return;
  }
  if (url.pathname === '/bad/index.json') {
    response.setHeader('Content-Type', 'application/json');
    response.end(JSON.stringify([{name:'bad.ttf',size:1,url:'data:font/ttf;base64,AA=='}])); return;
  }
  if (url.pathname.startsWith('/fonts/') || url.pathname.startsWith('/font-files/')) {
    const file = files.find(file => file.path === path.basename(url.pathname));
    if (!file) { response.writeHead(404).end(); return; }
    response.setHeader('Content-Type', 'font/ttf'); response.end(file.data); return;
  }
  if (!url.pathname.startsWith('/_build/js/debug/build/') && !url.pathname.startsWith('/node_modules/@bdfkit/')) {
    response.writeHead(404).end(); return;
  }
  const file = path.resolve(root, '.' + decodeURIComponent(url.pathname));
  const stream = createReadStream(file);
  stream.once('error', () => { if (!response.headersSent) response.writeHead(404); response.end(); });
  response.setHeader('Content-Type', 'text/javascript'); stream.pipe(response);
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const base = `http://127.0.0.1:${server.address().port}`;
try {
  const browser = await chromium.launch({ headless:true });
  try {
    const page = await browser.newPage();
    try {
      await page.goto(base);
      const actual = await page.evaluate(async ({sample,base,oracle}) => {
        const {bdf_create_native_converter} = await import('/_build/js/debug/build/browser/browser.js');
        const {BdfDocument,BufferSource} = await import('/node_modules/@bdfkit/core/dist/index.js');
        const client = bdf_create_native_converter('/_build/js/debug/build/native_converter_worker/native_converter_worker.js');
        try {
          await client.ready;
          const data = new TextEncoder().encode(sample.input);
          const options = {fonts:base+'/fonts', format:'csv', name:'People.csv', params:{header:true}};
          const outputs = await Promise.all([client.convert(data, options), client.open(data, options), client.convert(data, {...options,fonts:'/upper'})]);
          const docs = await Promise.all(outputs.map(async output => {
            const doc = await BdfDocument.open(new BufferSource(output.bdf));
            return {warnings:output.warnings, views:doc.manifest.views, tables:doc.manifest.tables ?? [], parts:doc.manifest.parts.map(p=>({type:p.t,hash:p.h}))};
          }));
          let missing, bad, type, scan, scanitem, scanvalue, flaky, priority, disconnect;
          try { await client.convert(data, {...options,fonts:base+'/missing'}); } catch (e) { missing=e.message; }
          try { await client.convert(data, {...options,fonts:base+'/disconnect'}); } catch (e) { disconnect=e.message; }
          try { await client.convert(data, {...options,fonts:base+'/missing',format:'unknown'}); } catch (e) { priority=e.message; }
          try { await client.convert(data, {...options,fonts:base+'/bad'}); } catch (e) { bad=e.message; }
          try { await client.convert(data, {...options,fonts:base+'/type'}); } catch (e) { type=e.message; }
          try { await client.convert(data, {...options,fonts:base+'/scan'}); } catch (e) { scan=e.message; }
          try { await client.convert(data, {...options,fonts:base+'/scanitem'}); } catch (e) { scanitem=e.message; }
          try { await client.convert(data, {...options,fonts:base+'/scanvalue'}); } catch (e) { scanvalue=e.message; }
          try { await client.convert(data, {...options,fonts:base+'/flaky'}); } catch (e) { flaky=e.message; }
          const retried=await client.convert(data, {...options,fonts:base+'/flaky'});
          const fileFirst=await client.convert(data, {...options,fonts:base+'/fileflaky'});
          const fileRetry=await client.convert(data, {...options,fonts:base+'/fileflaky'});
          const fileRetryDoc=await BdfDocument.open(new BufferSource(fileRetry.bdf));
          let upstream;
          if (oracle) {
            await import('/wasm_exec.js');
            const go = new globalThis.Go();
            const wasm = await WebAssembly.instantiate(await (await fetch('/oracle.wasm')).arrayBuffer(), go.importObject);
            void go.run(wasm.instance);
            if (!globalThis.bdfConverter) await new Promise(resolve => setTimeout(resolve, 0));
            const converter = globalThis.bdfConverter;
            const out = await converter.convert(data, options);
            const doc = await BdfDocument.open(new BufferSource(out.bdf));
            let missingError, badError, typeError, scanError, scanitemError, scanvalueError, priorityError, disconnectError;
            try { await converter.convert(data, {...options,fonts:base+'/missing'}); } catch (e) { missingError=e.message; }
            try { await converter.convert(data, {...options,fonts:base+'/disconnect'}); } catch (e) { disconnectError=e.message; }
            try { await converter.convert(data, {...options,fonts:base+'/missing',format:'unknown'}); } catch (e) { priorityError=e.message; }
            try { await converter.convert(data, {...options,fonts:base+'/bad'}); } catch (e) { badError=e.message; }
            try { await converter.convert(data, {...options,fonts:base+'/type'}); } catch (e) { typeError=e.message; }
            try { await converter.convert(data, {...options,fonts:base+'/scan'}); } catch (e) { scanError=e.message; }
            try { await converter.convert(data, {...options,fonts:base+'/scanitem'}); } catch (e) { scanitemError=e.message; }
            try { await converter.convert(data, {...options,fonts:base+'/scanvalue'}); } catch (e) { scanvalueError=e.message; }
            upstream = {doc:{warnings:out.warnings,views:doc.manifest.views,tables:doc.manifest.tables ?? [],parts:doc.manifest.parts.map(p=>({type:p.t,hash:p.h}))}, missing:missingError,bad:badError,type:typeError,scan:scanError,scanitem:scanitemError,scanvalue:scanvalueError,priority:priorityError,disconnect:disconnectError};
          }
          return {docs, missing, bad, type, scan, scanitem, scanvalue, flaky, priority, disconnect, retryWarnings:retried.warnings, fileFirstWarnings:fileFirst.warnings, fileRetryHasFont:fileRetryDoc.manifest.parts.some(p=>p.t==='font'), upstream};
        } finally { client.terminate(); }
      }, {sample,base,oracle:!!(oracleWasm && oracleRuntime)});
      for (const doc of actual.docs) {
        assert.deepEqual(doc.warnings, sample.warnings ?? []);
        assert.deepEqual(doc.views, sample.views);
        assert.deepEqual(doc.tables, sample.tables ?? []);
        assert.deepEqual(doc.parts, sample.parts);
      }
      assert.equal(actual.missing, `fonts: ${base}/missing/index.json: HTTP 404`);
      assert.match(actual.bad, /font "bad.ttf" has an invalid HTTP URL/);
      assert.equal(actual.type, `fonts: ${base}/type/index.json: json: cannot unmarshal number into Go struct field .0.name of type string`);
      assert.equal(actual.scan, `fonts: ${base}/scan/index.json: json: cannot unmarshal string into Go struct field .0.scan of type [][2]int64`);
      assert.equal(actual.scanitem, `fonts: ${base}/scanitem/index.json: json: cannot unmarshal number into .0.scan.0 of type [2]int64`);
      assert.equal(actual.scanvalue, `fonts: ${base}/scanvalue/index.json: json: cannot unmarshal string into .0.scan.0.1 of type int64`);
      assert.equal(actual.flaky, `fonts: ${base}/flaky/index.json: HTTP 503`);
      assert.equal(actual.disconnect, `fonts: fetch ${base}/disconnect/index.json: JavaScript error: Failed to fetch`);
      assert.equal(actual.priority, actual.missing, 'font directory is resolved before the format');
      assert.deepEqual(actual.retryWarnings, ['no fonts found; text is laid out with estimated metrics and not embedded']);
      assert.equal(counts.get('/flaky/index.json'), 2, 'failed directory fetch is retried');
      assert.ok(actual.fileFirstWarnings.includes('no fonts found; text is laid out with estimated metrics and not embedded'));
      assert.ok(actual.fileRetryHasFont, 'a temporarily unavailable font is retried');
      assert.equal(counts.get('/fileflaky-source/00.ttf'), 2);
      if (actual.upstream) {
        assert.deepEqual(actual.docs[0], actual.upstream.doc, 'native Worker matches upstream Wasm document');
        assert.equal(actual.missing, actual.upstream.missing, 'missing directory error matches upstream Wasm');
        assert.equal(actual.bad, actual.upstream.bad, 'invalid URL error matches upstream Wasm');
        assert.equal(actual.type, actual.upstream.type, 'invalid entry type error matches upstream Wasm');
        assert.equal(actual.scan, actual.upstream.scan, 'invalid scan type error matches upstream Wasm');
        assert.equal(actual.scanitem, actual.upstream.scanitem, 'invalid scan item error matches upstream Wasm');
        assert.equal(actual.scanvalue, actual.upstream.scanvalue, 'invalid scan value error matches upstream Wasm');
        assert.equal(actual.priority, actual.upstream.priority, 'error priority matches upstream Wasm');
        assert.equal(actual.disconnect, actual.upstream.disconnect, 'network errors match upstream Wasm');
      }
      assert.equal(counts.get('/fonts/index.json'), actual.upstream ? 2 : 1, 'concurrent requests share the font directory');
      assert.equal([...counts].filter(([name]) => name.endsWith('.ttf')).length, 19);
      console.log('Native Worker font URLs, relative sources, concurrent caching, CSV output and errors match upstream.');
    } finally { await page.close(); }
  } finally { await browser.close(); }
} finally { await new Promise(resolve => server.close(resolve)); }
