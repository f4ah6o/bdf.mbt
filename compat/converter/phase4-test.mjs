import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, resolve } from 'node:path';
import { chromium } from 'playwright';

const root = resolve(import.meta.dirname, '../..');
const mime = { '.html': 'text/html', '.js': 'text/javascript', '.mp3': 'audio/mpeg', '.wav': 'audio/wav', '.flac': 'audio/flac', '.aac': 'audio/aac' };
const server = createServer(async (request, response) => {
  if (request.url === '/blank.html') {
    response.writeHead(200, { 'content-type': 'text/html' });
    response.end('<!doctype html><title>phase 4</title>');
    return;
  }
  try {
    const file = resolve(root, '.' + decodeURIComponent(new URL(request.url, 'http://x').pathname));
    if (!file.startsWith(root + '/')) { response.writeHead(403).end(); return; }
    const data = await readFile(file);
    response.writeHead(200, { 'content-type': mime[extname(file)] ?? 'application/octet-stream' });
    response.end(data);
  } catch { response.writeHead(404).end(); }
});
await new Promise((resolvePromise, reject) => { server.once('error', reject); server.listen(0, '127.0.0.1', resolvePromise); });
const base = `http://127.0.0.1:${server.address().port}`;
const browser = await chromium.launch({ headless: true });
try {
  const page = await browser.newPage();
  await page.goto(base + '/blank.html');
  const out = await page.evaluate(async base => {
    const { BdfDocument, BufferSource, decodeTextIndex } = await import('/node_modules/@bdfkit/core/dist/index.js');
    const { bdf_create_native_converter } = await import('/_build/js/debug/build/browser/browser.js');
    const moon = bdf_create_native_converter('/_build/js/debug/build/native_converter_worker/native_converter_worker.js');
    const formats = (await moon.ready).map(format => format.name);
    const result = { formats };
    for (const [name, file] of [['mp3', 'tagged.mp3'], ['wav', 'tagged.wav'], ['flac', 'tagged.flac'], ['aac', 'plain.aac']]) {
      const data = new Uint8Array(await (await fetch(base + '/compat/audio/fixtures/' + file)).arrayBuffer());
      const converted = await moon.convert(data, { name: file });
      const doc = await BdfDocument.open(new BufferSource(converted.bdf));
      const view = doc.manifest.views[0];
      const index = decodeTextIndex(await doc.part(view.textIndex));
      result[name] = {
        summary: converted.summary,
        pages: view.pages.length,
        play: !!view.play,
        text: index.map(run => run.text).join(''),
      };
    }
    {
      const data = new Uint8Array(await (await fetch(base + '/compat/audio/fixtures/tagged.mp3')).arrayBuffer());
      const converted = await moon.convert(data, { name: 'tagged.mp3', params: { play: 'false' } });
      const doc = await BdfDocument.open(new BufferSource(converted.bdf));
      result.noPlay = !!doc.manifest.views[0].play;
      try { await moon.convert(data, { name: 'tagged.mp3', params: { play: 'sometimes' } }); result.badPlay = 'accepted'; }
      catch (error) { result.badPlay = String(error?.message ?? error); }
    }
    moon.terminate();
    return result;
  }, base);
  assert.ok(out.formats.includes('audio'));
  for (const name of ['mp3', 'wav', 'flac', 'aac']) {
    assert.equal(out[name].pages, 1, `${name} pages`);
    assert.ok(out[name].summary.startsWith('1 page'), `${name} summary`);
    assert.ok(out[name].text.length > 0, `${name} text`);
  }
  assert.equal(out.mp3.play, true);
  assert.equal(out.noPlay, false);
  assert.ok(String(out.badPlay).includes('not a boolean'));
  console.log('Phase 4 audio: MP3/WAV/FLAC/AAC cards, metadata text, cover/play data and play parameter are converted.');
} finally {
  await browser.close();
  server.close();
}
