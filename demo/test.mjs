import assert from 'node:assert/strict';
import { createReadStream } from 'node:fs';
import { stat } from 'node:fs/promises';
import { createServer } from 'node:http';
import { resolve, extname } from 'node:path';
import { chromium } from 'playwright';

const root = resolve(import.meta.dirname, '../_build/pages');
const types = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8', '.csv': 'text/csv; charset=utf-8', '.bdf': 'application/octet-stream' };
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
  await page.waitForSelector('[data-bdf-page="0"] canvas[data-loaded="ready"]', { timeout: 30000 });
  assert.equal(await page.locator('#page-number').textContent(), '1 / 20');
  await page.locator('#open-file').focus();
  const chooser = page.waitForEvent('filechooser');
  await page.keyboard.press('Enter');
  await chooser;
  assert.equal(await page.locator('[data-bdf-page]').count(), 20);
  for (let i = 0; i < 20; i++) {
    await page.locator(`[data-bdf-page="${i}"]`).scrollIntoViewIfNeeded();
    await page.waitForFunction(n => document.querySelector(`[data-bdf-page="${n}"] canvas`)?.dataset.loaded === 'ready', i, { timeout: 15000 });
    assert.equal(await page.locator('#status').evaluate(el => el.classList.contains('error')), false, `page ${i + 1}`);
  }
  await page.locator('#search').fill('BDF');
  await page.locator('#search-form button').click();
  await page.waitForFunction(() => /\d+ \/ \d+/.test(document.querySelector('#search-status').textContent), null, { timeout: 15000 });
  await page.locator('#zoom').selectOption('0.75');
  await page.locator('#layout').selectOption('spread');
  await page.locator('#next').focus();
  await page.keyboard.press('Enter');
  assert.equal(await page.locator('#page-number').textContent(), '2 / 20');
  await page.locator('#previous').focus();
  await page.keyboard.press('Enter');
  assert.equal(await page.locator('#page-number').textContent(), '1 / 20');
  const downloaded = page.waitForEvent('download');
  await page.locator('#download').click();
  assert.equal((await downloaded).suggestedFilename(), 'upstream-demo.bdf');
  await page.locator('#csv-sample').click();
  await page.waitForFunction(() => document.querySelector('#document-name').textContent === 'people.csv', null, { timeout: 30000 });
  await page.waitForFunction(() => [...document.querySelectorAll('#preview canvas')].some(c => c.width > 0 && c.height > 0), null, { timeout: 15000 });
  assert.equal(await page.locator('#view').inputValue(), 'sheet1');
  await page.locator('#file').setInputFiles({ name: 'picture.svg', mimeType: 'image/svg+xml', buffer: Buffer.from('<svg xmlns="http://www.w3.org/2000/svg" width="64" height="48"><rect width="64" height="48" fill="red"/></svg>') });
  await page.waitForFunction(() => document.querySelector('#document-name').textContent === 'picture.svg', null, { timeout: 30000 });
  await page.waitForSelector('[data-bdf-page="0"] canvas[data-loaded="ready"]', { timeout: 15000 });
  await page.locator('#file').setInputFiles({ name: 'unsupported.pdf', mimeType: 'application/pdf', buffer: Buffer.from('%PDF-1.7\n') });
  await page.waitForFunction(() => document.querySelector('#status').classList.contains('error'), null, { timeout: 15000 });
  assert.match(await page.locator('#status').textContent(), /unsupported\.pdf/);
  await page.locator('#sample').focus();
  await page.keyboard.press('Enter');
  await page.waitForFunction(() => document.querySelector('#document-name').textContent === 'upstream-demo.bdf' && !document.querySelector('#status').classList.contains('error'), null, { timeout: 30000 });
  assert.deepEqual(errors, []);
  await page.close();
  const mobile = await browser.newPage({ viewport: { width: 375, height: 812 } });
  await mobile.goto(url);
  await mobile.waitForSelector('[data-bdf-page="0"] canvas[data-loaded="ready"]', { timeout: 30000 });
  assert.equal(await mobile.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true, 'mobile page overflow');
  await mobile.close();
  console.log('Demo: all 20 upstream pages, search, navigation, download, CSV, SVG, errors and mobile subpath passed.');
} finally {
  await browser.close();
  await new Promise(resolvePromise => server.close(resolvePromise));
}
