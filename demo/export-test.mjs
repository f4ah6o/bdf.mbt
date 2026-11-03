import assert from 'node:assert/strict';
import { createReadStream } from 'node:fs';
import { readFile, stat } from 'node:fs/promises';
import { createServer } from 'node:http';
import { resolve, extname } from 'node:path';
import { chromium } from 'playwright';

const root = resolve(import.meta.dirname, '../_build/pages');
const types = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.wasm': 'application/wasm',
  '.json': 'application/json; charset=utf-8',
  '.bdf': 'application/octet-stream',
  '.pdf': 'application/pdf',
  '.png': 'image/png',
};
const server = createServer(async (req, res) => {
  const url = new URL(req.url, 'http://localhost');
  if (!url.pathname.startsWith('/bdf.mbt/')) { res.writeHead(404).end(); return; }
  const file = resolve(root, decodeURIComponent(url.pathname.slice('/bdf.mbt/'.length)) || 'index.html');
  if (!file.startsWith(root + '/')) { res.writeHead(403).end(); return; }
  try {
    const info = await stat(file);
    if (!info.isFile()) throw new Error('not a file');
    res.writeHead(200, { 'Content-Type': types[extname(file)] ?? 'application/octet-stream', 'Content-Length': info.size });
    createReadStream(file).pipe(res);
  } catch { res.writeHead(404).end(); }
});
await new Promise((resolvePromise, reject) => { server.once('error', reject); server.listen(0, '127.0.0.1', resolvePromise); });
const url = `http://127.0.0.1:${server.address().port}/bdf.mbt/`;
const browser = await chromium.launch({ headless: true });
try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 900 }, acceptDownloads: true });
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.goto(url);
  await page.waitForFunction(() => window.bdfDemo?.bytes && !document.querySelector('#open-file').disabled, null, { timeout: 60000 });
  await page.waitForFunction(() => document.querySelector('[data-export-document]').textContent === 'upstream-demo.bdf', null, { timeout: 30000 });
  assert.match(await page.locator('#exports h2').textContent(), /BDF から描き戻す/);
  await page.waitForFunction(() => document.querySelectorAll('[data-benchmark-table] tbody tr').length >= 6, null, { timeout: 30000 });
  const benchmarkText = await page.locator('[data-benchmark-table] tbody').innerText();
  assert.match(benchmarkText, /BDF → PDF/);
  assert.match(benchmarkText, /PDF → BDF/);
  assert.match(benchmarkText, /ms/);

  await page.locator('#tab-pdf').click();
  assert.equal(await page.locator('#panel-pdf').isVisible(), true);
  await page.locator('[data-export-run="pdf"]').click();
  await page.waitForFunction(() => /20 ページ/.test(document.querySelector('#panel-pdf [data-export-status]').textContent), null, { timeout: 60000 });
  assert.match(await page.locator('[data-export-frame]').getAttribute('src'), /^blob:/);
  assert.match(await page.locator('[data-export-pdf-save]').getAttribute('download'), /^upstream-demo\.pdf$/);

  await page.locator('#tab-md').click();
  await page.locator('[data-export-run="md"]').click();
  await page.waitForFunction(() => document.querySelector('[data-export-markdown]').value.length > 1000, null, { timeout: 60000 });
  assert.equal(await page.locator('[data-export-md-save]').isVisible(), true);
  assert.match(await page.locator('[data-export-markdown]').inputValue(), /^# /m);

  await page.locator('#tab-text').click();
  await page.locator('[data-export-run="text"]').click();
  await page.waitForFunction(() => document.querySelector('[data-export-text]').textContent.length > 1000, null, { timeout: 60000 });
  const text = JSON.parse(await page.locator('[data-export-text]').textContent());
  assert.equal(text.views.length, 1);
  assert.equal(text.views[0].pages.length, 20);

  await page.locator('#tab-find').click();
  await page.locator('[data-export-find]').fill('ぶらうざ');
  await page.locator('[data-export-find-run]').click();
  await page.waitForFunction(() => document.querySelectorAll('[data-export-hits] .hit').length > 0, null, { timeout: 60000 });
  assert.ok(await page.locator('[data-export-hits] .hit').count() >= 1);
  await page.locator('[data-export-hits] .hit').first().click();
  await page.waitForTimeout(300);
  assert.equal(await page.locator('#status').evaluate(el => el.classList.contains('error')), false);

  const live = await page.locator('[data-benchmark-live]').textContent();
  assert.match(live, /PDF \d+ ms/);

  // The new tabs and benchmark cards must not create a horizontal scrollbar.
  await page.setViewportSize({ width: 375, height: 760 });
  await page.waitForTimeout(300);
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
  assert.ok(overflow <= 1, 'horizontal overflow: ' + overflow);

  const wasmPage = await browser.newPage({ viewport: { width: 1280, height: 900 }, acceptDownloads: true });
  const wasmErrors = [];
  wasmPage.on('pageerror', error => wasmErrors.push(error.message));
  await wasmPage.goto(url + 'wasm-gc.html', { waitUntil: 'networkidle', timeout: 120000 });
  await wasmPage.waitForFunction(() => window.bdfDemo?.bytes, null, { timeout: 120000 });
  await wasmPage.waitForFunction(() => /準備ができました/.test(document.querySelector('#wasm-status').textContent), null, { timeout: 120000 });
  assert.equal(await wasmPage.locator('#document-name').textContent(), 'upstream-demo.bdf');
  assert.equal(await wasmPage.locator('[data-export-document]').textContent(), 'upstream-demo.bdf');

  await wasmPage.locator('#tab-pdf').click();
  await wasmPage.locator('[data-export-run="pdf"]').click();
  await wasmPage.waitForFunction(() => /20 ページ/.test(document.querySelector('#panel-pdf [data-export-status]').textContent), null, { timeout: 120000 });
  assert.match(await wasmPage.locator('[data-export-frame]').getAttribute('src'), /^blob:/);

  await wasmPage.locator('#tab-md').click();
  await wasmPage.locator('[data-export-run="md"]').click();
  await wasmPage.waitForFunction(() => document.querySelector('[data-export-markdown]').value.length > 1000, null, { timeout: 120000 });
  await wasmPage.locator('#tab-find').click();
  await wasmPage.locator('[data-export-find]').fill('ぶらうざ');
  await wasmPage.locator('[data-export-find-run]').click();
  await wasmPage.waitForFunction(() => document.querySelectorAll('[data-export-hits] .hit').length > 0, null, { timeout: 120000 });

  await wasmPage.locator('#pdf-file').setInputFiles(resolve(root, 'samples/simple.pdf'));
  await wasmPage.locator('#pdf-convert').click();
  await wasmPage.waitForFunction(() => document.querySelector('#document-name').textContent === 'simple.bdf', null, { timeout: 120000 });
  assert.match(await wasmPage.locator('#wasm-status').textContent(), /1 ページ/);
  assert.equal(await wasmPage.locator('#page-number').textContent(), '1 / 1');

  assert.deepEqual(errors, []);
  assert.deepEqual(wasmErrors, []);
  console.log('Export UI and wasm-gc page: PDF, Markdown, text, MiniSearch, PDF conversion and mobile layout passed.');
} finally {
  await browser.close();
  await new Promise(resolvePromise => server.close(resolvePromise));
}
