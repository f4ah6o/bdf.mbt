import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFileSync } from 'node:fs';
import { PNG } from 'pngjs';

// A real HTTP server lets the test inspect the requests made inside each Worker.
export async function verifyRangeWorker(browser, visualBase) {
  const fixtures = {
    plain: readFileSync('compat/visual/fixture.bdf'),
    encrypted: readFileSync('compat/visual/encrypted-fixture/password.bdf'),
  };
  const requests = new Map();
  const server = createServer((req, res) => {
    const u = new URL(req.url, 'http://localhost');
    const key = u.searchParams.get('id'), mode = u.searchParams.get('mode');
    if (u.pathname === '/stats') {
      res.setHeader('Access-Control-Allow-Origin', '*');
      res.end(String((requests.get(key) ?? []).length));
      return;
    }
    const data = fixtures[u.pathname.slice(1)];
    if (!data) { res.writeHead(404).end(); return; }
    const log = requests.get(key) ?? []; requests.set(key, log);
    log.push(req.headers.range ?? null);
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Expose-Headers', 'Content-Range');
    if (mode === 'status') { res.writeHead(503).end(); return; }
    if (mode === 'fallback') { res.writeHead(200, { 'Content-Length': data.length }); res.end(data); return; }
    const match = /^bytes=(\d+)-(\d+)$/.exec(req.headers.range ?? '');
    if (!match) { res.writeHead(400).end(); return; }
    const start = Number(match[1]), end = Number(match[2]);
    if (start >= data.length || end >= data.length) { res.writeHead(416).end(); return; }
    const bytes = data.subarray(start, mode === 'short' ? end : mode === 'oversize' ? end + 2 : end + 1);
    const headers = { 'Content-Length': bytes.length };
    if (mode !== 'no-header') headers['Content-Range'] = 'bytes ' + (mode === 'mismatch' ? start + 1 : start) + '-' + end + '/' + data.length;
    res.writeHead(206, headers); res.end(bytes);
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const port = server.address().port;
  const page = await browser.newPage();
  try {
    await page.goto(visualBase + 'moon.html', { waitUntil: 'networkidle' });
    const cases = await page.evaluate(async port => {
      const { BdfWorkerClient } = await import('/node_modules/@bdfkit/render/dist/client.js');
      const moon = await import('/_build/js/debug/build/browser/browser.js');
      const out = [];
      for (const [kind, workerUrl] of [['upstream','/node_modules/@bdfkit/render/dist/worker.js'],['moon','/_build/js/debug/build/render_worker/render_worker.js']]) {
        for (const [fixture, mode] of [['plain','range'],['plain','no-header'],['plain','fallback'],['encrypted','range'],['encrypted','fallback'],['plain','mismatch'],['plain','short'],['plain','oversize'],['plain','status']]) {
          const id = kind + '-' + fixture + '-' + mode;
          const worker = new Worker(workerUrl, { type: 'module' });
          const client = kind === 'upstream' ? new BdfWorkerClient(worker) : moon.bdf_render_worker_client(worker);
          const source = {kind:'single',url:'http://127.0.0.1:' + port + '/' + fixture + '?id=' + id + '&mode=' + mode,range:true};
          const item = {id, fixture, mode};
          try {
            let manifest;
            if (fixture === 'encrypted') {
              try { await client.open(source); } catch (e) { item.locked = {name:e.name,code:e.code}; }
              manifest = await client.unlock('pass');
            } else manifest = await client.open(source);
            item.manifest = manifest;
            item.requestsAtOpen = Number(await (await fetch('http://127.0.0.1:' + port + '/stats?id=' + id)).text());
            const bitmap = await client.page(manifest.views[0].id, 0, 1);
            const canvas = document.createElement('canvas'); canvas.width = bitmap.width; canvas.height = bitmap.height;
            canvas.getContext('2d').drawImage(bitmap, 0, 0); bitmap.close(); item.image = canvas.toDataURL();
            const again = await client.page(manifest.views[0].id, 0, 1); again.close();
          } catch (e) { item.error = {name:e.name,code:e.code}; }
          finally { client.terminate(); }
          out.push(item);
        }
      }
      return out;
    }, port);
    const upstream = cases.filter(c => c.id.startsWith('upstream-'));
    const moon = cases.filter(c => c.id.startsWith('moon-'));
    for (let i = 0; i < upstream.length; i++) {
      const a = upstream[i], b = moon[i], {id: _idA, image: imageA, ...dataA} = a, {id: _idB, image: imageB, ...dataB} = b;
      assert.deepEqual(dataB, dataA, b.id + ': protocol result');
      if (imageA) {
        const x = PNG.sync.read(Buffer.from(imageA.split(',')[1], 'base64'));
        const y = PNG.sync.read(Buffer.from(imageB.split(',')[1], 'base64'));
        assert.deepEqual([y.width, y.height], [x.width, x.height]);
        let changed = 0; for (let j=0;j<x.data.length;j+=4) if (x.data[j]!==y.data[j]||x.data[j+1]!==y.data[j+1]||x.data[j+2]!==y.data[j+2]||x.data[j+3]!==y.data[j+3]) changed++;
        assert.ok(changed/(x.width*x.height)<=0.0005, b.id + ': bitmap differs');
      }
      for (const item of [a,b]) {
        const log = requests.get(item.id);
        assert.ok(log?.length, item.id + ': no HTTP request');
        assert.equal(log[0], 'bytes=0-31', item.id + ': header range');
        if (item.mode === 'fallback') assert.equal(log.length, 1, item.id + ': full response should be cached');
        if (['range','no-header'].includes(item.mode)) {
          assert.equal(item.requestsAtOpen, item.fixture === 'encrypted' ? 3 : 2, item.id + ': parts should be loaded only when needed');
          assert.ok(log.length > 2, item.id + ': manifest and parts must be fetched separately');
          assert.ok(log.every(r => /^bytes=\d+-\d+$/.test(r)), item.id + ': missing Range header');
          assert.equal(new Set(log).size, log.length, item.id + ': repeated range was fetched again');
        }
        if (['mismatch','short','oversize','status'].includes(item.mode)) assert.ok(item.error, item.id + ': invalid response accepted');
        else assert.ok(item.image, item.id + ': page was not drawn');
      }
    }
  } finally { await page.close(); await new Promise(resolve => server.close(resolve)); }
}
