import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join, resolve } from 'node:path';
import { chromium } from 'playwright';

const root = resolve(import.meta.dirname, '../..');
const mime = {
  '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript',
  '.wasm': 'application/wasm', '.ai': 'application/octet-stream',
  '.tif': 'application/octet-stream', '.tiff': 'application/octet-stream',
  '.psd': 'application/octet-stream', '.psb': 'application/octet-stream',
  '.emf': 'application/octet-stream', '.wmf': 'application/octet-stream',
};
const server = createServer(async (request, response) => {
  let pathname;
  try { pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname); }
  catch { response.writeHead(400).end(); return; }
  if (pathname === '/blank.html') {
    response.writeHead(200, { 'content-type': 'text/html' });
    response.end('<!doctype html><title>converter</title>');
    return;
  }
  try {
    const file = resolve(root, '.' + pathname);
    if (!file.startsWith(root + '/')) { response.writeHead(403).end(); return; }
    const data = await readFile(file);
    response.writeHead(200, { 'content-type': mime[extname(file)] ?? 'application/octet-stream' });
    response.end(data);
  } catch {
    response.writeHead(404).end();
  }
});
await new Promise((resolve, reject) => { server.once('error', reject); server.listen(0, '127.0.0.1', resolve); });
const base = `http://127.0.0.1:${server.address().port}`;
const browser = await chromium.launch({ headless: true });
try {
  const page = await browser.newPage();
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
  await page.goto(`${base}/blank.html`, { waitUntil: 'load' });
  const results = await page.evaluate(async base => {
    const { Converter } = await import('/node_modules/@bdfkit/convert/dist/index.js');
    const { BdfDocument, BufferSource } = await import('/node_modules/@bdfkit/core/dist/index.js');
    const { bdf_create_native_converter } = await import('/_build/js/debug/build/browser/browser.js');
    const upstream = new Converter(
      new Worker('/node_modules/@bdfkit/convert/dist/worker.js', { type: 'module' }),
      '/node_modules/@bdfkit/convert-all/dist/converter.wasm',
    );
    const moon = bdf_create_native_converter('/_build/js/debug/build/native_converter_worker/native_converter_worker.js');
    const formats = (await Promise.all([upstream.ready, moon.ready])).map(list => list.map(format => format.name));
    const hashPixels = async bytes => {
      const bitmap = await createImageBitmap(new Blob([bytes]));
      const canvas = new OffscreenCanvas(bitmap.width, bitmap.height);
      const context = canvas.getContext('2d');
      context.drawImage(bitmap, 0, 0);
      const pixels = context.getImageData(0, 0, bitmap.width, bitmap.height).data;
      const digest = await crypto.subtle.digest('SHA-256', pixels);
      return `${bitmap.width}x${bitmap.height}:` + [...new Uint8Array(digest)].map(value => value.toString(16).padStart(2, '0')).join('');
    };
    const inspect = async result => {
      const source = new BufferSource(result.bdf);
      const doc = await BdfDocument.open(source);
      const view = doc.manifest.views[0];
      const pages = [];
      for (const page of view.pages) {
        const images = [];
        for (const layer of page.layers) {
          const object = await doc.object(layer.obj);
          for (const hash of object.images ?? []) images.push(await hashPixels(await doc.part(hash)));
        }
        pages.push({ w: page.w, h: page.h, images });
      }
      return pages;
    };
    const cases = [
      ['ai', 'artboards.ai', 'compat/ai/fixtures/artboards.ai'],
      ['tiff', 'scan.tif', 'compat/tiff/fixtures/scan.tif'],
      ['tiff', 'fax.tif', 'compat/tiff/fixtures/fax.tif'],
      ['tiff', 'orientation.tif', 'compat/tiff/fixtures/orientation.tif'],
      ['tiff', 'bw.tif', 'compat/tiff/fixtures/internal/bw.tif'],
      ['tiff', 'gray.tif', 'compat/tiff/fixtures/internal/gray.tif'],
      ['tiff', 'pal.tif', 'compat/tiff/fixtures/internal/pal.tif'],
      ['tiff', 'rgba.tif', 'compat/tiff/fixtures/internal/rgba.tif'],
      ['tiff', 'cmyk.tif', 'compat/tiff/fixtures/internal/cmyk.tif'],
      ['tiff', 'rgb.tif', 'compat/tiff/fixtures/internal/rgb.tif'],
      ['tiff', 'rgb-be.tif', 'compat/tiff/fixtures/internal/rgb-be.tif'],
      ['tiff', 'rgb-bigtiff.tif', 'compat/tiff/fixtures/internal/rgb-bigtiff.tif'],
      ['psd', 'bitmap.psd', 'compat/psd/fixtures/bitmap.psd'],
      ['psd', 'cmyk.psd', 'compat/psd/fixtures/cmyk.psd'],
      ['psd', 'gray16.psd', 'compat/psd/fixtures/gray16.psd'],
      ['psd', 'indexed.psd', 'compat/psd/fixtures/indexed.psd'],
      ['psd', 'lab.psd', 'compat/psd/fixtures/lab.psd'],
      ['psd', 'rgb32.psd', 'compat/psd/fixtures/rgb32.psd'],
      ['psd', 'large.psb', 'compat/psd/fixtures/large.psb'],
      ['psd', 'layers.psd', 'compat/psd/fixtures/layers.psd'],
      ['psd', 'artboards.psd', 'compat/psd/fixtures/artboards.psd'],
      ['emf', 'test.emf', 'compat/emf/fixtures/test.emf'],
      ['emf', 'test.wmf', 'compat/emf/fixtures/test.wmf'],
    ];
    const out = { formats, cases: [], errors: [] };
    for (const [format, name, path] of cases) {
      const data = new Uint8Array(await (await fetch(base + '/' + path)).arrayBuffer());
      const entry = { format, name };
      try {
        const [a, m] = await Promise.all([
          upstream.convert(data, { name }),
          moon.convert(data, { name }),
        ]);
        entry.upstream = { summary: a.summary, warnings: a.warnings, format: a.format, pages: await inspect(a) };
        entry.moon = { summary: m.summary, warnings: m.warnings, format: m.format, pages: await inspect(m) };
      } catch (error) {
        entry.error = String(error?.message ?? error);
      }
      out.cases.push(entry);
    }
    for (const [name, path] of [['legacy.ai', 'compat/ai/fixtures/legacy.ai'], ['nopdf.ai', 'compat/ai/fixtures/nopdf.ai']]) {
      const data = new Uint8Array(await (await fetch(base + '/' + path)).arrayBuffer());
      const entry = { format: 'ai', name };
      try { await upstream.convert(data, { name }); entry.upstream = 'accepted'; }
      catch (error) { entry.upstream = String(error?.message ?? error); }
      try { await moon.convert(data, { name }); entry.moon = 'accepted'; }
      catch (error) { entry.moon = String(error?.message ?? error); }
      out.cases.push(entry);
    }
    out.worker = {};
    const fail = async (name, fn) => {
      try { await fn(); out.worker[name] = 'accepted'; }
      catch (error) { out.worker[name] = String(error?.message ?? error); }
    };
    {
      const data = new Uint8Array(await (await fetch(base + '/compat/tiff/fixtures/scan.tif')).arrayBuffer());
      const opened = await moon.open(data, { name: 'scan.tif' });
      out.worker.tiffOpen = { pages: opened.pages, stream: opened.stream };
      const first = await moon.page(opened.stream, 0);
      const doc = await BdfDocument.open(new BufferSource(first.bdf));
      out.worker.tiffOpenFirst = doc.manifest.views[0].pages[0].w;
      await moon.finish(opened.stream);
      await moon.close(opened.stream);
      const selected = await moon.convert(data, { name: 'scan.tif', pages: '1' });
      const selectedDoc = await BdfDocument.open(new BufferSource(selected.bdf));
      out.worker.tiffSelected = selectedDoc.manifest.views[0].pages.map(page => [page.w, page.h]);
    }
    {
      const data = new Uint8Array(await (await fetch(base + '/compat/psd/fixtures/artboards.psd')).arrayBuffer());
      const opened = await moon.open(data, { name: 'artboards.psd' });
      out.worker.psdOpen = { pages: opened.pages, stream: opened.stream };
      await moon.close(opened.stream);
      await fail('psdArtboards', () => moon.convert(data, { name: 'artboards.psd', params: { artboards: 'maybe' } }));
    }
    await fail('tiffDpi', () => moon.convert(new Uint8Array([73, 73, 42, 0]), { name: 'bad.tif', params: { dpi: 'bad' } }));
    await fail('tiffNamed', () => moon.convert(new TextEncoder().encode('not a tiff'), { name: 'bad.tif' }));
    await fail('psdNamed', () => moon.convert(new TextEncoder().encode('not a psd'), { name: 'bad.psd' }));
    await fail('emfNamed', () => moon.convert(new TextEncoder().encode('not an emf'), { name: 'bad.emf' }));
    await fail('aiBox', () => moon.convert(new TextEncoder().encode('%PDF-1.7\n'), { format: 'ai', name: 'bad.ai', params: { box: 'bad' } }));

    upstream.terminate();
    moon.terminate();
    return out;
  }, base);
  assert.deepEqual(errors, [], 'browser errors');
  for (const name of ['ai', 'tiff', 'psd', 'emf']) {
    assert.ok(results.formats[0].includes(name), `upstream has ${name}`);
    assert.ok(results.formats[1].includes(name), `moon has ${name}`);
  }
  const byName = new Map(results.cases.map(entry => [entry.name, entry]));
  const requireEntry = name => {
    const entry = byName.get(name);
    assert.ok(entry, `case ${name}`);
    assert.equal(entry.error, undefined, `${name}: ${entry.error}`);
    return entry;
  };
  for (const name of ['artboards.ai', 'scan.tif', 'fax.tif', 'orientation.tif',
    'bw.tif', 'gray.tif', 'pal.tif', 'rgba.tif', 'cmyk.tif', 'rgb.tif', 'rgb-be.tif', 'rgb-bigtiff.tif']) {
    const { upstream, moon } = requireEntry(name);
    assert.equal(moon.pages.length, upstream.pages.length, `${name} page count`);
    for (let i = 0; i < moon.pages.length; i++) {
      assert.ok(Math.abs(moon.pages[i].w - upstream.pages[i].w) < 0.01, `${name} page ${i + 1} width`);
      assert.ok(Math.abs(moon.pages[i].h - upstream.pages[i].h) < 0.01, `${name} page ${i + 1} height`);
    }
    if (name !== 'scan.tif') {
      for (let i = 0; i < moon.pages.length; i++) {
        if (name === 'cmyk.tif' && i === 2) continue; // JPEG compression is a documented gap.
        assert.deepEqual(moon.pages[i].images, upstream.pages[i].images, `${name} page ${i + 1} image`);
      }
    }
    if (name === 'cmyk.tif') {
      assert.ok(moon.warnings.some(warning => warning.includes('JPEG-compressed pages are not supported')), 'cmyk JPEG gap is warned');
    }
  }
  {
    const { moon } = requireEntry('scan.tif');
    assert.ok(moon.warnings.some(warning => warning.includes('JPEG-compressed pages are not supported')), 'scan JPEG gap is warned');
    assert.deepEqual(moon.pages[0].images, requireEntry('scan.tif').upstream.pages[0].images, 'scan G4 image');
    assert.deepEqual(moon.pages[2].images, requireEntry('scan.tif').upstream.pages[2].images, 'scan LZW image');
  }
  for (const name of ['bitmap.psd', 'cmyk.psd', 'gray16.psd', 'indexed.psd', 'lab.psd', 'rgb32.psd', 'large.psb', 'layers.psd', 'artboards.psd']) {
    const { upstream, moon } = requireEntry(name);
    assert.equal(moon.pages.length, upstream.pages.length, `${name} page count`);
    for (let i = 0; i < moon.pages.length; i++) {
      assert.ok(Math.abs(moon.pages[i].w - upstream.pages[i].w) < 0.01, `${name} page ${i + 1} width`);
      assert.ok(Math.abs(moon.pages[i].h - upstream.pages[i].h) < 0.01, `${name} page ${i + 1} height`);
      assert.deepEqual(moon.pages[i].images, upstream.pages[i].images, `${name} page ${i + 1} image`);
    }
  }
  for (const name of ['test.emf', 'test.wmf']) {
    const { upstream, moon } = requireEntry(name);
    assert.equal(moon.pages.length, upstream.pages.length, `${name} page count`);
    assert.ok(Math.abs(moon.pages[0].w - upstream.pages[0].w) < 0.01, `${name} width`);
    assert.ok(Math.abs(moon.pages[0].h - upstream.pages[0].h) < 0.01, `${name} height`);
  }
  assert.deepEqual(results.worker.tiffOpen, { pages: 3, stream: results.worker.tiffOpen.stream });
  assert.equal(results.worker.tiffOpen.stream >= 0, true);
  assert.ok(Math.abs(results.worker.tiffOpenFirst - 240) < 0.01, 'TIFF open first page width');
  assert.deepEqual(results.worker.tiffSelected, [[240, 312]]);
  assert.deepEqual(results.worker.psdOpen.pages, 3);
  assert.ok(String(results.worker.psdArtboards).includes('not a boolean'), 'PSD artboards parameter error');
  assert.ok(String(results.worker.tiffDpi).includes('not a positive number'), 'TIFF dpi parameter error');
  assert.ok(String(results.worker.tiffNamed).startsWith('tiff:'), 'TIFF extension detection');
  assert.ok(String(results.worker.psdNamed).startsWith('psd:'), 'PSD extension detection');
  assert.ok(String(results.worker.emfNamed).startsWith('emf:'), 'EMF extension detection');
  assert.ok(String(results.worker.aiBox).startsWith('ai:'), 'AI box parameter error');
  for (const name of ['legacy.ai', 'nopdf.ai']) {
    const entry = requireEntry(name);
    assert.ok(String(entry.upstream).includes('ai:'), `${name} upstream error`);
    assert.ok(String(entry.moon).includes('ai:'), `${name} moon error`);
  }
  console.log('Phase 1 converter compatibility: AI, TIFF, PSD and EMF/WMF match upstream pages and pixels (documented JPEG TIFF and metafile subset gaps).');
} finally {
  await browser.close();
  server.close();
}
