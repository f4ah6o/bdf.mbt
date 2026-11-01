import assert from 'node:assert/strict';
import { request } from 'node:http';
import { chromium } from 'playwright';
import { createVisualServer } from './visual-server.mjs';

const server = createVisualServer(process.cwd());
await new Promise((resolve, reject) => { server.once('error', reject); server.listen(0, '127.0.0.1', resolve); });
try {
  const origin = `http://127.0.0.1:${server.address().port}`;
  const nul = await fetch(origin + '/compat/xlsx/%00');
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
    const page = await browser.newPage();
    // Simulate conversion work that outlasts networkidle's 500 ms quiet window.
    await page.addInitScript(() => {
      const original = Response.prototype.json;
      let delayed = false;
      Response.prototype.json = async function () {
        const result = await original.call(this);
        if (!delayed) { delayed = true; await new Promise(resolve => setTimeout(resolve, 1500)); }
        return result;
      };
    });
    const url = `http://127.0.0.1:${server.address().port}/compat/xlsx/visual-baseline.html`;
    await page.goto(url, { waitUntil: 'networkidle' });
    const result = await page.evaluate(() => ({ status: window.bdfStatus, error: window.bdfError, count: document.querySelectorAll('canvas').length }));
    assert.equal(result.status, 'ready', result.error ?? 'network became idle before rendering completed');
    assert.equal(result.count, 5);
    await page.close();
    const failing = await browser.newPage();
    await failing.addInitScript(() => {
      const original = Response.prototype.json;
      let count = 0;
      Response.prototype.json = async function () {
        if (++count === 5) throw new Error('simulated render failure');
        return original.call(this);
      };
    });
    await failing.goto(url, { waitUntil: 'networkidle' });
    const failed = await failing.evaluate(() => ({ status: window.bdfStatus, count: document.querySelectorAll('canvas').length }));
    assert.equal(failed.status, 'error');
    assert.equal(failed.count, 0, 'a failed capture must not retain partial colored output');
    await failing.close();
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
console.log('XLSX visual capture waits for rendering');
