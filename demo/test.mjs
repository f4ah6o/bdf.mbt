import assert from 'node:assert/strict';
import { createReadStream } from 'node:fs';
import { createHash } from 'node:crypto';
import { readFile, stat } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { BdfDocument, BufferSource } from '@bdfkit/core';
import { createServer } from 'node:http';
import { resolve, extname } from 'node:path';
import { chromium } from 'playwright';
import { PNG } from 'pngjs';

const root = resolve(import.meta.dirname, '../_build/pages');
const types = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8', '.csv': 'text/csv; charset=utf-8', '.bdf': 'application/octet-stream', '.png': 'image/png', '.svg': 'image/svg+xml', '.xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' };
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
  await page.locator('[data-sample="xlsx"]').click();
  await page.waitForFunction(() => document.querySelector('#document-name').textContent === 'sales.xlsx' && !document.querySelector('#open-file').disabled, null, { timeout: 60000 });
  assert.equal(await page.locator('#status').evaluate(el => el.classList.contains('error')), false);
  assert.deepEqual(await page.locator('#view option').evaluateAll(options => options.map(option => option.value)), ['sheet1', 'sheet2']);
  await page.waitForFunction(() => [...document.querySelectorAll('#preview canvas')].some(canvas => {
    if (!canvas.width || !canvas.height) return false;
    const pixels = canvas.getContext('2d').getImageData(0, 0, canvas.width, canvas.height).data;
    let dark = 0;
    for (let i = 0; i < pixels.length; i += 4) if (pixels[i + 3] > 0 && pixels[i] < 100 && pixels[i + 1] < 100 && pixels[i + 2] < 100 && ++dark > 100) return true;
    return false;
  }), null, { timeout: 30000 });
  await page.waitForFunction(() => {
    let teal = 0, orange = 0;
    for (const canvas of document.querySelectorAll('#preview canvas')) {
      if (!canvas.width || !canvas.height) continue;
      const pixels = canvas.getContext('2d').getImageData(0, 0, canvas.width, canvas.height).data;
      for (let i = 0; i < pixels.length; i += 4) {
        const [r, g, b, a] = pixels.subarray(i, i + 4);
        if (a && r < 55 && g > 45 && g < 130 && b > 60 && b < 150) teal++;
        if (a && r > 235 && g > 180 && g < 240 && b > 150 && b < 220) orange++;
      }
    }
    return teal > 500 && orange > 100;
  }, null, { timeout: 30000 });
  await page.locator('#search').fill('Notebook');
  await page.locator('#search-form button').click();
  await page.waitForFunction(() => /^1 \/ [1-9]/.test(document.querySelector('#search-status').textContent), null, { timeout: 30000 });
  await page.locator('#view').selectOption('sheet2');
  assert.equal(await page.locator('#search-status').textContent(), '');
  await page.locator('#search').fill('Spring');
  await page.locator('#search-form button').click();
  await page.waitForFunction(() => /^1 \/ [1-9]/.test(document.querySelector('#search-status').textContent), null, { timeout: 30000 });
  const xlsxDownload = page.waitForEvent('download');
  await page.locator('#download').click();
  const xlsxSaved = await xlsxDownload;
  assert.equal(xlsxSaved.suggestedFilename(), 'sales.bdf');
  const xlsxDoc = await BdfDocument.open(new BufferSource(await readFile(await xlsxSaved.path())));
  assert.deepEqual(xlsxDoc.manifest.views.map(view => view.id), ['sheet1', 'sheet2']);
  const samplePath = resolve(root, 'samples/sales.xlsx');
  for (let attempt = 0; attempt < 2; attempt++) {
    await page.locator('#file').setInputFiles(samplePath);
    await page.waitForFunction(() => document.querySelector('#document-name').textContent === 'sales.xlsx' && document.querySelector('#view').value === 'sheet1' && !document.querySelector('#open-file').disabled, null, { timeout: 60000 });
    assert.equal(await page.locator('#search').inputValue(), '');
    await page.locator('#view').selectOption('sheet2');
  }
  const visualCases = JSON.parse(await readFile(resolve(import.meta.dirname, '../compat/xlsx/render/001.json')));
  // Select the four-sheet workbook by content so fixture reordering cannot
  // silently narrow this end-to-end test to a different input.
  const visualCase = visualCases.find(item => createHash('sha256').update(Buffer.from(item.input, 'base64')).digest('hex') === 'd3df5666380ffefead5bafce06c6670ed26fa7fbe1b16effff85bef748af643c');
  assert.ok(visualCase, 'four-sheet XLSX visual fixture');
  assert.equal(visualCase.mode, '');
  assert.equal(visualCase.no_index, false);
  async function sheetImages(name, bytes) {
    await page.locator('#file').setInputFiles({ name, mimeType: 'application/octet-stream', buffer: Buffer.from(bytes, 'base64') });
    await page.waitForFunction(n => document.querySelector('#document-name').textContent === n && !document.querySelector('#open-file').disabled, name, { timeout: 60000 });
    assert.equal(await page.locator('#status').evaluate(el => el.classList.contains('error')), false, name);
    const ids = await page.locator('#view option').evaluateAll(options => options.map(option => option.value));
    assert.deepEqual(ids, ['sheet1', 'sheet2', 'sheet3', 'sheet4'], `${name} sheet order`);
    const images = [];
    for (const id of ids) {
      await page.locator('#view').selectOption(id);
      await page.waitForFunction(() => {
        const canvas = document.querySelector('#preview canvas');
        if (!canvas?.width || !canvas.height) return false;
        const pixels = canvas.getContext('2d').getImageData(0, 0, canvas.width, canvas.height).data;
        let dark = 0;
        for (let i = 0; i < pixels.length; i += 4) {
          if (pixels[i + 3] && pixels[i] < 100 && pixels[i + 1] < 100 && pixels[i + 2] < 100 && ++dark > 100) return true;
        }
        return false;
      }, null, { timeout: 30000 });
      const dataUrl = await page.locator('#preview canvas').first().evaluate(el => el.toDataURL('image/png'));
      images.push(PNG.sync.read(Buffer.from(dataUrl.split(',')[1], 'base64')));
    }
    return images;
  }
  const references = await sheetImages('upstream.xlsx.bdf', visualCase.bdf);
  const convertedSheets = await sheetImages('comparison.xlsx', visualCase.input);
  for (let i = 0; i < references.length; i++) {
    const reference = references[i];
    assert.deepEqual([convertedSheets[i].width, convertedSheets[i].height], [reference.width, reference.height], `XLSX sheet ${i + 1} reference dimensions`);
    assert.deepEqual(convertedSheets[i].data, reference.data, `XLSX sheet ${i + 1} browser conversion matches upstream BDF rendering`);
    for (let j = 0; j < i; j++) {
      assert.notDeepEqual(reference.data, references[j].data, `XLSX reference sheets ${j + 1} and ${i + 1} are visually distinct`);
    }
  }
  const hasIllustration = () => {
    let gold = 0, green = 0;
    for (const canvas of document.querySelectorAll('#preview canvas')) {
      if (!canvas.width || !canvas.height) continue;
      const pixels = canvas.getContext('2d').getImageData(0, 0, canvas.width, canvas.height).data;
      for (let i = 0; i < pixels.length; i += 4) {
        const r = pixels[i], g = pixels[i + 1], b = pixels[i + 2];
        if (pixels[i + 3] && r > 225 && g > 150 && g < 215 && b < 120) gold++;
        if (pixels[i + 3] && r > 80 && r < 130 && g > 140 && g < 190 && b > 130 && b < 180) green++;
      }
    }
    return gold > 50 && green > 500;
  };
  await page.locator('[data-sample="xlsx-picture"]').click();
  await page.waitForFunction(() => document.querySelector('#document-name').textContent === 'field-guide.xlsx' && !document.querySelector('#open-file').disabled, null, { timeout: 60000 });
  assert.equal(await page.locator('#status').evaluate(el => el.classList.contains('error')), false, 'illustrated workbook conversion');
  assert.deepEqual(await page.locator('#view option').evaluateAll(options => options.map(option => option.value)), ['sheet1']);
  await page.waitForFunction(hasIllustration, null, { timeout: 30000 });
  await page.locator('#search').fill('Mountain');
  await page.locator('#search-form button').click();
  await page.waitForFunction(() => /^1 \/ [1-9]/.test(document.querySelector('#search-status').textContent), null, { timeout: 30000 });
  const pictureDownload = page.waitForEvent('download');
  await page.locator('#download').click();
  const pictureSaved = await pictureDownload;
  assert.equal(pictureSaved.suggestedFilename(), 'field-guide.bdf');
  await page.locator('#file').setInputFiles({ name: 'field-guide.bdf', mimeType: 'application/octet-stream', buffer: await readFile(await pictureSaved.path()) });
  await page.waitForFunction(() => document.querySelector('#document-name').textContent === 'field-guide.bdf' && !document.querySelector('#open-file').disabled, null, { timeout: 30000 });
  assert.equal(await page.locator('#status').evaluate(el => el.classList.contains('error')), false, 'illustrated BDF reload');
  await page.waitForFunction(hasIllustration, null, { timeout: 30000 });
  const warnings = JSON.parse(await readFile(resolve(import.meta.dirname, '../compat/xlsx/render/001.json')));
  const warningCase = warnings.find(item => item.warnings?.includes('sheet "Sheet1": right-to-left sheets are drawn left to right'));
  assert.ok(warningCase, 'XLSX warning fixture');
  await page.locator('#file').setInputFiles({ name: 'rtl.xlsx', mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', buffer: Buffer.from(warningCase.input, 'base64') });
  await page.waitForFunction(() => document.querySelector('#document-name').textContent === 'rtl.xlsx' && !document.querySelector('#open-file').disabled, null, { timeout: 60000 });
  assert.match(await page.locator('#status').textContent(), /right-to-left sheets are drawn left to right/);
  const unsupported = JSON.parse(await readFile(resolve(import.meta.dirname, '../compat/xlsx/ignored-sheet-extensions-unsupported.json')));
  await page.locator('#file').setInputFiles({ name: 'unsupported.xlsx', mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', buffer: Buffer.from(unsupported[0], 'base64') });
  await page.waitForFunction(() => document.querySelector('#status').classList.contains('error'), null, { timeout: 30000 });
  assert.match(await page.locator('#status').textContent(), /extended conditional formatting/);
  assert.equal(await page.locator('#document-name').textContent(), 'rtl.xlsx');
  await page.locator('#file').setInputFiles({ name: 'picture.xlsx', mimeType: 'image/svg+xml', buffer: Buffer.from('<svg xmlns="http://www.w3.org/2000/svg" width="64" height="48"><rect width="64" height="48" fill="red"/></svg>') });
  await page.waitForFunction(() => document.querySelector('#document-name').textContent === 'picture.xlsx' && !document.querySelector('#open-file').disabled, null, { timeout: 30000 });
  assert.equal(await page.locator('#status').evaluate(el => el.classList.contains('error')), false, 'image signature takes precedence over filename');
  const explicit = await page.evaluate(async () => {
    const { bdf_create_native_converter } = await import('./browser.js');
    const client = bdf_create_native_converter(new URL('./native_converter_worker.js', location.href).href);
    try {
      await client.ready;
      const bytes = new Uint8Array(await (await fetch('./samples/sales.xlsx')).arrayBuffer());
      const result = await client.convert(bytes, { format: 'xlsx' });
      return { format: result.format, bytes: result.bdf.length };
    } finally { client.terminate(); }
  });
  assert.equal(explicit.format, 'xlsx');
  assert.ok(explicit.bytes > 0, 'explicit XLSX conversion');
  await page.locator('#csv-sample').click();
  await page.waitForFunction(() => document.querySelector('#document-name').textContent === 'people.csv' && !document.querySelector('#open-file').disabled, null, { timeout: 30000 });
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
  const converterPage = await browser.newPage({ viewport: { width: 1280, height: 900 }, acceptDownloads: true });
  converterPage.on('pageerror', error => errors.push(error.message));
  await page.getByRole('link', { name: '変換ページへ' }).click();
  assert.equal(new URL(page.url()).pathname, '/bdf.mbt/converter.html');
  await converterPage.goto(page.url());
  await converterPage.waitForFunction(() => document.querySelector('#document-name').textContent === 'people.csv' && !document.querySelector('#open-file').disabled, null, { timeout: 60000 });
  await converterPage.getByRole('button', { name: 'BDF サンプルを開く' }).click();
  await converterPage.waitForFunction(() => document.querySelector('#document-name').textContent === 'upstream-demo.bdf' && !document.querySelector('#open-file').disabled, null, { timeout: 30000 });
  for (const [sample, name] of [['csv', 'people.csv'], ['xlsx', 'sales.xlsx'], ['image', 'illustration.svg'], ['font', 'stix.ttf']]) {
    await converterPage.locator('#file').setInputFiles(resolve(root, 'samples', name));
    await converterPage.waitForFunction(n => document.querySelector('#document-name').textContent === n && !document.querySelector('#open-file').disabled, name, { timeout: 60000 });
    assert.equal(await converterPage.locator('#status').evaluate(el => el.classList.contains('error')), false, `converter ${sample}`);
    await converterPage.waitForFunction(() => [...document.querySelectorAll('#preview canvas')].some(canvas => canvas.width > 0 && canvas.height > 0), null, { timeout: 30000 });
    assert.equal(await converterPage.locator('#download').getAttribute('download'), name.replace(/\.[^.]+$/, '') + '.bdf');
  }
  await converterPage.locator('[data-sample="xlsx-picture"]').click();
  await converterPage.waitForFunction(() => document.querySelector('#document-name').textContent === 'field-guide.xlsx' && !document.querySelector('#open-file').disabled, null, { timeout: 60000 });
  await converterPage.waitForFunction(hasIllustration, null, { timeout: 30000 });
  await converterPage.locator('#search').fill('Mountain');
  await converterPage.locator('#search-form button').click();
  await converterPage.waitForFunction(() => /^1 \/ [1-9]/.test(document.querySelector('#search-status').textContent), null, { timeout: 30000 });
  const converterDownload = converterPage.waitForEvent('download');
  await converterPage.locator('#download').click();
  const converted = await converterDownload;
  assert.equal(converted.suggestedFilename(), 'field-guide.bdf');
  await converterPage.locator('#file').setInputFiles({ name: 'field-guide.bdf', mimeType: 'application/octet-stream', buffer: await readFile(await converted.path()) });
  await converterPage.waitForFunction(() => document.querySelector('#document-name').textContent === 'field-guide.bdf' && !document.querySelector('#open-file').disabled, null, { timeout: 30000 });
  await converterPage.waitForFunction(hasIllustration, null, { timeout: 30000 });
  await converterPage.locator('#file').setInputFiles({ name: 'unsupported.pdf', mimeType: 'application/pdf', buffer: Buffer.from('%PDF-1.7\n') });
  await converterPage.waitForFunction(() => document.querySelector('#status').classList.contains('error'), null, { timeout: 30000 });
  assert.match(await converterPage.locator('#status').textContent(), /unsupported\.pdf/);
  assert.equal(await converterPage.locator('#document-name').textContent(), 'field-guide.bdf');
  await converterPage.getByRole('link', { name: '← デモに戻る' }).click();
  assert.equal(new URL(converterPage.url()).pathname, '/bdf.mbt/');
  await converterPage.close();
  assert.deepEqual(errors, []);
  await page.close();
  const mobile = await browser.newPage({ viewport: { width: 375, height: 812 } });
  await mobile.goto(url);
  await mobile.waitForSelector('[data-bdf-page="0"] canvas[data-loaded="ready"]', { timeout: 30000 });
  assert.equal(await mobile.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true, 'mobile page overflow');
  await mobile.close();
  const mobileConverter = await browser.newPage({ viewport: { width: 375, height: 812 } });
  await mobileConverter.goto(new URL('converter.html', url).href);
  await mobileConverter.waitForFunction(() => document.querySelector('#document-name').textContent === 'people.csv', null, { timeout: 60000 });
  assert.equal(await mobileConverter.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true, 'mobile converter overflow');
  await mobileConverter.close();
  console.log('Demo: all 20 upstream pages, search, navigation, download, CSV, SVG, font TTF/WOFF2, XLSX conversion, sheet switching, embedded PNG, BDF save/reload, warnings, replacement, errors and mobile subpath passed.');
} finally {
  await browser.close();
  await new Promise(resolvePromise => server.close(resolvePromise));
}
