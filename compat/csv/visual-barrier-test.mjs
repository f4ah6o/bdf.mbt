import assert from 'node:assert/strict';
import { request } from 'node:http';
import { chromium } from 'playwright';
import { createVisualServer } from './visual-server.mjs';

const server = createVisualServer(process.cwd());
await new Promise((resolve, reject) => { server.once('error', reject); server.listen(0, '127.0.0.1', resolve); });
try {
  const origin = `http://127.0.0.1:${server.address().port}`;
  const nul = await fetch(origin + '/compat/csv/%00');
  assert.equal(nul.status, 400, 'encoded NUL path must be rejected');
  await nul.text();
  const malformed = await new Promise((resolve, reject) => {
    const req = request({ host: '127.0.0.1', port: server.address().port, path: 'http://[::1' }, response => {
      response.resume();
      resolve(response.statusCode);
    });
    req.once('error', reject);
    req.end();
  });
  assert.equal(malformed, 400, 'malformed absolute URL must be rejected');
  const browser = await chromium.launch({ headless: true });
  try {
    const url = `${origin}/compat/csv/visual-baseline.html`;
    // Simulate conversion work that outlasts networkidle's 500 ms quiet window.
    const slowJson = () => {
      const original = Response.prototype.json;
      let delayed = false;
      Response.prototype.json = async function () {
        const result = await original.call(this);
        if (!delayed) { delayed = true; await new Promise(resolve => setTimeout(resolve, 1500)); }
        return result;
      };
    };
    // Without the barrier the capture races the render: networkidle resolves
    // while the page is still blank. This is the failure the barrier prevents.
    const racing = await browser.newPage();
    try {
      await racing.addInitScript(slowJson);
      await racing.route('**/visual-wait*', route => route.fulfill({ status: 200, body: 'ready' }));
      await racing.route('**/visual-release*', route => route.fulfill({ status: 204 }));
      await racing.goto(url, { waitUntil: 'networkidle' });
      const raced = await racing.evaluate(() => ({ status: window.bdfStatus, count: document.querySelectorAll('canvas').length }));
      assert.notEqual(raced.status, 'ready', 'networkidle must not wait for rendering without the barrier');
      assert.equal(raced.count, 0, 'a raced capture must still be blank');
    } finally {
      await racing.unroute('**/visual-wait*');
      await racing.unroute('**/visual-release*');
      await racing.close();
    }
    // With the barrier the same slow render is complete before networkidle.
    const waiting = await browser.newPage();
    try {
      await waiting.addInitScript(slowJson);
      await waiting.goto(url, { waitUntil: 'networkidle' });
      const waited = await waiting.evaluate(() => ({ status: window.bdfStatus, error: window.bdfError, count: document.querySelectorAll('canvas').length }));
      assert.equal(waited.status, 'ready', waited.error ?? 'network became idle before rendering completed');
      assert.equal(waited.count, 4);
    } finally {
      await waiting.close();
    }
    // A failing barrier must abort before any capture work and must never reach
    // the server. If the barrier fetch sits outside the try/catch, bdfStatus
    // stays unset and waitForFunction times out.
    const barrierFailure = await browser.newPage();
    try {
      let intercepted = 0;
      await barrierFailure.route('**/visual-wait*', route => {
        intercepted++;
        return route.fulfill({ status: 500, body: 'unavailable' });
      });
      await barrierFailure.goto(url, { waitUntil: 'domcontentloaded' });
      await barrierFailure.waitForFunction(
        () => window.bdfStatus === 'ready' || window.bdfStatus === 'error',
        null,
        { timeout: 15000 },
      );
      const barred = await barrierFailure.evaluate(() => ({
        status: window.bdfStatus,
        error: window.bdfError,
        count: document.querySelectorAll('canvas').length,
      }));
      assert.equal(intercepted, 1, 'barrier request must be intercepted before it reaches the server');
      assert.equal(barred.status, 'error');
      assert.match(barred.error ?? '', /visual wait: HTTP 500/);
      assert.equal(barred.count, 0, 'a failed barrier must not leave capture output');
    } finally {
      await barrierFailure.unroute('**/visual-wait*');
      await barrierFailure.close();
    }
  } finally { await browser.close(); }
} finally { await new Promise(resolve => server.close(resolve)); }
console.log('CSV visual capture waits for rendering');
