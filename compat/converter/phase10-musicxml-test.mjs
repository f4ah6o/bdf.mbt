import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, resolve } from 'node:path';
import { chromium } from 'playwright';

const root = resolve(import.meta.dirname, '../..');
const mime = {
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.musicxml': 'application/vnd.recordare.musicxml+xml',
};
const server = createServer(async (request, response) => {
  if (request.url === '/blank.html') {
    response.writeHead(200, { 'content-type': 'text/html' });
    response.end('<!doctype html><title>musicxml</title>');
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
const base = 'http://127.0.0.1:' + server.address().port;
const browser = await chromium.launch({ headless: true });
try {
  const page = await browser.newPage();
  await page.goto(base + '/blank.html');
  const out = await page.evaluate(async base => {
    const { BdfDocument, BufferSource, decodeTextIndex, parseSmf } = await import('/node_modules/@bdfkit/core/dist/index.js');
    const { Converter } = await import('/node_modules/@bdfkit/convert/dist/index.js');
    const { bdf_create_native_converter } = await import('/_build/js/debug/build/browser/browser.js');
    const upstream = new Converter(
      new Worker('/node_modules/@bdfkit/convert/dist/worker.js', { type: 'module' }),
      '/node_modules/@bdfkit/convert-all/dist/converter.wasm',
    );
    const moon = bdf_create_native_converter('/_build/js/debug/build/native_converter_worker/native_converter_worker.js');
    const formats = (await Promise.all([upstream.ready, moon.ready])).map(list => list.map(format => format.name));
    const data = new Uint8Array(await (await fetch(base + '/compat/musicxml/fixtures/minuet.musicxml')).arrayBuffer());
    const inspect = async result => {
      const doc = await BdfDocument.open(new BufferSource(result.bdf));
      const views = [];
      for (const view of doc.manifest.views) {
        const index = view.textIndex ? decodeTextIndex(await doc.part(view.textIndex)) : [];
        const play = view.play ? await doc.play(view) : null;
        views.push({
          id: view.id,
          title: view.title ?? '',
          pages: view.pages?.map(p => [Math.round(p.w * 100) / 100, Math.round(p.h * 100) / 100]) ?? [],
          text: index.map(run => run.text).join('|'),
          play: !!view.play,
          ticks: play ? parseSmf(play.seq).ticks : 0,
        });
      }
      return { summary: result.summary, warnings: result.warnings, views };
    };
    const upstreamResult = await upstream.convert(data, { name: 'minuet.musicxml' });
    const moonResult = await moon.convert(data, { name: 'minuet.musicxml' });
    upstream.terminate();
    moon.terminate();
    return {
      formats,
      upstream: await inspect(upstreamResult),
      moon: await inspect(moonResult),
    };
  }, base);
  assert.ok(out.formats[0].includes('musicxml'), 'upstream advertises musicxml');
  assert.ok(out.formats[1].includes('musicxml'), 'native Worker advertises musicxml');
  assert.equal(out.moon.views.length, out.upstream.views.length, 'view count');
  for (const [i, view] of out.moon.views.entries()) {
    const expected = out.upstream.views[i];
    assert.equal(view.id, expected.id, 'view id ' + i);
    assert.equal(view.title, expected.title, 'view title ' + i);
    assert.deepEqual(view.pages, expected.pages, 'view pages ' + i);
    assert.equal(view.play, expected.play, 'view play ' + i);
    assert.equal(view.ticks, expected.ticks, 'view playback ticks ' + i);
  }
  const score = out.moon.views[0];
  for (const text of ['Minuet in G', 'Christian Petzold', '7', '1.', '2.']) {
    assert.ok(score.text.includes(text), 'score text lacks ' + JSON.stringify(text) + ': ' + score.text);
  }
  assert.deepEqual(out.moon.warnings, out.upstream.warnings, 'warnings');
  console.log('Phase 10 MusicXML: format registration, score and guitar TAB views, page geometry, text and play data match upstream.');
} finally {
  await browser.close();
  server.close();
}
