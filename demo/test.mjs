import assert from 'node:assert/strict';
import { createReadStream } from 'node:fs';
import { readFile, stat } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { BdfDocument, BufferSource } from '@bdfkit/core';
import { createServer } from 'node:http';
import { resolve, extname } from 'node:path';
import { chromium } from 'playwright';

const root = resolve(import.meta.dirname, '../_build/pages');
const types = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8', '.csv': 'text/csv; charset=utf-8', '.bdf': 'application/octet-stream', '.png': 'image/png', '.svg': 'image/svg+xml' };
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
  await page.waitForFunction(() => !document.querySelector('#open-file').disabled, null, { timeout: 30000 });
  // Headless platforms do not consistently report native file chooser events.
  // Check that keyboard activation invokes the input; uploads are exercised below.
  await page.evaluate(() => {
    const input = document.querySelector('#file');
    window.originalFileClick = input.click;
    input.click = () => { window.pickerTriggered = true; };
  });
  await page.locator('#open-file').press('Enter');
  await page.waitForFunction(() => window.pickerTriggered === true, null, { timeout: 5000 });
  await page.evaluate(() => { document.querySelector('#file').click = window.originalFileClick; });
  assert.equal(await page.locator('[data-bdf-page]').count(), 20);
  for (let i = 0; i < 20; i++) {
    await page.locator(`[data-bdf-page="${i}"]`).scrollIntoViewIfNeeded();
    await page.waitForFunction(n => document.querySelector(`[data-bdf-page="${n}"] canvas`)?.dataset.loaded === 'ready', i, { timeout: 15000 });
    assert.equal(await page.locator('#status').evaluate(el => el.classList.contains('error')), false, `page ${i + 1}`);
  }
  await page.waitForFunction(() => document.querySelector('#page-number').textContent === '20 / 20', null, { timeout: 15000 });
  await page.locator('#layout').selectOption('spread');
  await page.waitForFunction(() => Number(document.querySelector('#page-number').textContent.split(' / ')[0]) >= 19, null, { timeout: 15000 });
  await page.locator('#layout').selectOption('single');
  await page.locator('#search').fill('BDF');
  await page.locator('#search-form button').click();
  await page.waitForFunction(() => /\d+ \/ \d+/.test(document.querySelector('#search-status').textContent), null, { timeout: 15000 });
  await page.locator('[data-bdf-page="0"]').scrollIntoViewIfNeeded();
  await page.waitForFunction(() => document.querySelector('#page-number').textContent === '1 / 20', null, { timeout: 15000 });
  await page.locator('#zoom').selectOption('0.75');
  await page.locator('#layout').selectOption('spread');
  await page.locator('#layout').selectOption('single');
  await page.locator('#next').press('Enter');
  await page.waitForFunction(() => document.querySelector('#page-number').textContent === '2 / 20', null, { timeout: 15000 });
  await page.locator('#previous').press('Enter');
  await page.waitForFunction(() => document.querySelector('#page-number').textContent === '1 / 20', null, { timeout: 15000 });
  const downloaded = page.waitForEvent('download');
  await page.locator('#download').click();
  assert.equal((await downloaded).suggestedFilename(), 'upstream-demo.bdf');
  await page.locator('#csv-sample').click();
  await page.waitForFunction(() => document.querySelector('#document-name').textContent === 'people.csv' && !document.querySelector('#open-file').disabled, null, { timeout: 30000 });
  await page.waitForFunction(() => [...document.querySelectorAll('#preview canvas')].some(c => c.width > 0 && c.height > 0), null, { timeout: 15000 });
  assert.equal(await page.locator('#view').inputValue(), 'sheet1');
  await page.locator('#file').setInputFiles({ name: 'picture.svg', mimeType: 'image/svg+xml', buffer: Buffer.from('<svg xmlns="http://www.w3.org/2000/svg" width="64" height="48"><rect width="64" height="48" fill="red"/></svg>') });
  await page.waitForFunction(() => document.querySelector('#document-name').textContent === 'picture.svg' && !document.querySelector('#open-file').disabled, null, { timeout: 30000 });
  await page.waitForSelector('[data-bdf-page="0"] canvas[data-loaded="ready"]', { timeout: 15000 });
  await page.locator('#file').setInputFiles({ name: 'unsupported.pdf', mimeType: 'application/pdf', buffer: Buffer.from('%PDF-1.7\n') });
  await page.waitForFunction(() => document.querySelector('#status').classList.contains('error'), null, { timeout: 15000 });
  assert.match(await page.locator('#status').textContent(), /unsupported\.pdf/);
  await page.locator('#sample').press('Enter');
  await page.waitForFunction(() => document.querySelector('#document-name').textContent === 'upstream-demo.bdf' && !document.querySelector('#status').classList.contains('error'), null, { timeout: 30000 });
  for (const [kind, name] of [['csv', 'people.csv'], ['image', 'illustration.svg'], ['bdf', 'upstream-demo.bdf'], ['font', 'stix.ttf']]) {
    await page.locator(`[data-sample="${kind}"]`).click();
    await page.waitForFunction(n => document.querySelector('#document-name').textContent === n && !document.querySelector('#open-file').disabled, name, { timeout: 30000 });
    assert.equal(await page.locator('#status').evaluate(el => el.classList.contains('error')), false, `${kind} sample`);
  }
  const fontViews = await page.locator('#view option').evaluateAll(options => options.map(option => option.value));
  assert.deepEqual(fontViews, ['overview', 'characters', 'glyphs', 'features']);
  await page.waitForFunction(() => [...document.querySelectorAll('#preview canvas')].some(c => c.width > 0 && c.height > 0), null, { timeout: 30000 });
  await page.locator('#view').selectOption('glyphs');
  await page.waitForFunction(() => document.querySelectorAll('#preview [data-bdf-page]').length === 7, null, { timeout: 30000 });
  await page.locator('#view').selectOption('overview');
  await page.waitForFunction(() => document.querySelectorAll('#preview [data-bdf-page]').length === 2, null, { timeout: 30000 });
  await page.locator('#search').fill('STIX');
  await page.locator('#search-form button').click();
  await page.waitForFunction(() => /\d+ \/ \d+/.test(document.querySelector('#search-status').textContent), null, { timeout: 30000 });
  const fontDownload = page.waitForEvent('download');
  await page.locator('#download').click();
  const saved = await fontDownload;
  assert.equal(saved.suggestedFilename(), 'stix.bdf');
  const savedBytes = await readFile(await saved.path());
  const savedDoc = await BdfDocument.open(new BufferSource(savedBytes));
  assert.deepEqual(savedDoc.manifest.views.map(view => view.id), fontViews);
  const fixture = JSON.parse(gunzipSync(await readFile(resolve(import.meta.dirname, '../compat/specimen/convert.json.gz'))));
  const woff2 = gunzipSync(Buffer.from(fixture.files['stix-ttf.woff2'], 'base64'));
  await page.locator('#file').setInputFiles({ name: 'stix.woff2', mimeType: 'font/woff2', buffer: woff2 });
  await page.waitForFunction(() => document.querySelector('#document-name').textContent === 'stix.woff2' && !document.querySelector('#open-file').disabled, null, { timeout: 60000 });
  assert.equal(await page.locator('#status').evaluate(el => el.classList.contains('error')), false, 'WOFF2 input');
  assert.deepEqual(await page.locator('#view option').evaluateAll(options => options.map(option => option.value)), fontViews);
  await page.waitForFunction(() => [...document.querySelectorAll('#preview canvas')].some(c => c.width > 0 && c.height > 0), null, { timeout: 30000 });
  await page.waitForFunction(() => [...document.querySelectorAll('#preview canvas')].some(canvas => {
    const ctx = canvas.getContext('2d');
    if (!ctx || !canvas.width || !canvas.height) return false;
    const pixels = ctx.getImageData(0, 0, canvas.width, canvas.height).data;
    let dark = 0;
    for (let i = 0; i < pixels.length; i += 4) {
      if (pixels[i + 3] > 0 && pixels[i] < 160 && pixels[i + 1] < 160 && pixels[i + 2] < 160 && ++dark > 100) return true;
    }
    return false;
  }), null, { timeout: 30000 });
  await page.locator('#search').fill('STIX');
  await page.locator('#search-form button').click();
  await page.waitForFunction(() => /\d+ \/ \d+/.test(document.querySelector('#search-status').textContent), null, { timeout: 30000 });
  for (const card of await page.locator('.format-card').all()) {
    assert.equal(await card.locator('img').evaluate(img => img.complete && img.naturalWidth > 1), true, 'card preview');
    const href = await card.getByRole('link', { name: '形式の説明' }).getAttribute('href');
    const response = await page.request.get(new URL(href, url).href);
    assert.equal(response.status(), 200, href);
    const section = href.split('#')[1];
    const description = await browser.newPage();
    await description.goto(new URL(href, url).href);
    assert.equal(await description.locator(`#${section}`).count(), 1, href);
    await description.close();
  }
  const coverage = await browser.newPage();
  await coverage.goto(new URL('coverage.html', url).href);
  assert.equal(await coverage.getByRole('heading', { name: 'Porting coverage' }).count(), 1);
  await coverage.getByRole('link', { name: '← デモに戻る' }).click();
  assert.equal(new URL(coverage.url()).pathname, '/bdf.mbt/');
  await coverage.close();
  assert.deepEqual(errors, []);
  await page.close();
  const mobile = await browser.newPage({ viewport: { width: 375, height: 812 } });
  await mobile.goto(url);
  await mobile.waitForSelector('[data-bdf-page="0"] canvas[data-loaded="ready"]', { timeout: 30000 });
  assert.equal(await mobile.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true, 'mobile page overflow');
  await mobile.close();
  console.log('Demo: all 20 upstream pages, search, navigation, download, CSV, SVG, font TTF/WOFF2, views, search, saving, errors and mobile subpath passed.');
} finally {
  await browser.close();
  await new Promise(resolvePromise => server.close(resolvePromise));
}
