import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, resolve } from 'node:path';
import { chromium } from 'playwright';

const root = resolve(import.meta.dirname, '../..');
const mime = {
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.mp3': 'audio/mpeg',
  '.wav': 'audio/wav',
  '.flac': 'audio/flac',
  '.aac': 'audio/aac',
  '.aiff': 'audio/aiff',
  '.ogg': 'audio/ogg',
  '.opus': 'audio/ogg',
  '.m4a': 'audio/mp4',
};
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
const base = 'http://127.0.0.1:' + server.address().port;
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
    const fixtures = [
      ['mp3', 'tagged.mp3'],
      ['wav', 'tagged.wav'],
      ['flac', 'tagged.flac'],
      ['aac', 'plain.aac'],
      ['lrc', 'lrc.flac'],
      ['synced', 'synced.mp3'],
      ['aiff', 'tagged.aiff'],
      ['m4a', 'tagged.m4a'],
      ['ogg', 'tagged.ogg'],
      ['opus', 'tagged.opus'],
    ];
    for (const [name, file] of fixtures) {
      const data = new Uint8Array(await (await fetch(base + '/compat/audio/fixtures/' + file)).arrayBuffer());
      const converted = await moon.convert(data, { name: file });
      const doc = await BdfDocument.open(new BufferSource(converted.bdf));
      const view = doc.manifest.views[0];
      const index = decodeTextIndex(await doc.part(view.textIndex));
      result[name] = {
        summary: converted.summary,
        pages: view.pages.length,
        play: !!view.play,
        type: view.play?.type ?? '',
        text: index.map(run => run.text).join(''),
        dc: doc.manifest.meta?.dc ?? null,
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
  const dcValue = (dc, key) => Array.isArray(dc?.[key]) ? dc[key][0] : dc?.[key];
  const dcIncludes = (dc, key, wanted) => Array.isArray(dc?.[key]) ? dc[key].includes(wanted) : dc?.[key] === wanted;
  const fixtures = [
    {
      name: 'mp3', type: 'audio/mpeg',
      dc: {
        title: 'Sunny Field', creator: 'Taro Yamada', subject: 'Folk',
        description: 'A song about a field in the sun', publisher: 'Example Records',
        date: '2026-09-01', type: 'Sound', format: 'audio/mpeg',
        identifier: 'JPA012600001', language: 'en', relation: 'Four Seasons',
        rights: '© 2026 Example Records',
      },
      contributors: ['Various Artists', 'Hanako Sato'],
      text: ['Sunny Field', 'Taro Yamada', 'Four Seasons', 'Track 3 of 12', 'Lyrics',
        'Hoping it will never rain', 'Chapters', '0:00 Verse', '0:01 Chorus'],
      summary: ['4 lines of lyrics', '2 chapters'],
    },
    {
      name: 'wav', type: 'audio/wav',
      dc: {
        title: 'Sunny Field', creator: 'Taro Yamada', subject: 'Folk',
        description: 'A song about a field in the sun', date: '2026-09-01',
        type: 'Sound', format: 'audio/wav', relation: 'Four Seasons',
        rights: '© 2026 Example Records',
      },
      text: ['Sunny Field', 'Taro Yamada', 'WAV PCM', '8 kHz', 'mono'],
    },
    {
      name: 'flac', type: 'audio/flac',
      dc: {
        title: 'Sunny Field', creator: 'Taro Yamada', subject: 'Folk',
        description: 'A song about a field in the sun', contributor: 'Hanako Sato',
        date: '2026-09-01', type: 'Sound', format: 'audio/flac',
        identifier: 'JPA012600001', relation: 'Four Seasons',
        rights: '© 2026 Example Records',
      },
      text: ['Sunny Field', 'Taro Yamada', 'FLAC', '22.05 kHz', 'mono'],
    },
    {
      name: 'aac', type: 'audio/aac',
      dc: { type: 'Sound', format: 'audio/aac' },
      text: ['ADTS AAC LC', '22.05 kHz', 'mono'],
    },
    {
      name: 'lrc', type: 'audio/flac',
      dc: {
        title: '晴れた野原', creator: '山田太郎', date: '2026', type: 'Sound',
        format: 'audio/flac', relation: '四季',
      },
      text: ['Lyrics', '野原の上に太陽', '雲ひとつない夏の空'],
      summary: ['3 lines of synchronized lyrics'],
    },
    {
      name: 'synced', type: 'audio/mpeg',
      dc: {
        title: 'Sunny Field', creator: 'Taro Yamada', date: '2026-09-01',
        type: 'Sound', format: 'audio/mpeg', language: 'en',
        relation: 'Four Seasons',
      },
      text: ['Lyrics', 'Over the field the sun is high', 'Not a cloud in the summer sky',
        'Walking home along the lane', 'Hoping it will never rain'],
      summary: ['4 lines of synchronized lyrics'],
    },
    {
      name: 'aiff', type: 'audio/aiff',
      dc: {
        title: 'Sunny Field', creator: 'Taro Yamada', date: '2026', type: 'Sound',
        format: 'audio/aiff', relation: 'Four Seasons',
      },
      text: ['Sunny Field', 'Taro Yamada', 'AIFF PCM', '8 kHz', 'mono'],
    },
    {
      name: 'm4a', type: 'audio/mp4',
      dc: {
        title: 'Sunny Field', creator: 'Taro Yamada', subject: 'Folk',
        description: 'A song about a field in the sun', date: '2026-09-01',
        type: 'Sound', format: 'audio/mp4', relation: 'Four Seasons',
        rights: '© 2026 Example Records',
      },
      contributors: ['Various Artists', 'Hanako Sato'],
      text: ['Grouping: Summer', 'Track 3 of 12', 'Not a cloud in the summer sky'],
    },
    {
      name: 'ogg', type: 'audio/ogg',
      dc: {
        title: 'Sunny Field', creator: 'Taro Yamada', date: '2026', type: 'Sound',
        format: 'audio/ogg', relation: 'Four Seasons',
      },
      text: ['Sunny Field', 'Taro Yamada', 'Ogg Vorbis', 'Track 3', '22.05 kHz', 'mono'],
    },
    {
      name: 'opus', type: 'audio/ogg',
      dc: {
        title: 'Sunny Field', creator: 'Taro Yamada', date: '2026', type: 'Sound',
        format: 'audio/ogg', relation: 'Four Seasons',
      },
      text: ['Sunny Field', 'Taro Yamada', 'Ogg Opus', '48 kHz', 'mono'],
    },
  ];
  for (const fixture of fixtures) {
    const name = fixture.name;
    const got = out[name];
    assert.ok(got, name + ' was converted');
    assert.equal(got.pages, 1, name + ' pages');
    assert.ok(got.summary.startsWith('1 page'), name + ' summary: ' + got.summary);
    assert.ok(got.text.length > 0, name + ' text');
    assert.equal(got.play, true, name + ' play data');
    assert.equal(got.type, fixture.type, name + ' play type');
    assert.ok(got.dc, name + ' has Dublin Core');
    for (const [key, value] of Object.entries(fixture.dc)) {
      assert.equal(dcValue(got.dc, key), value, name + ' dc.' + key);
    }
    for (const value of fixture.contributors ?? []) {
      assert.ok(dcIncludes(got.dc, 'contributor', value), name + ' dc.contributor has ' + value);
    }
    for (const snippet of fixture.text) {
      assert.ok(got.text.includes(snippet), name + ' text lacks ' + JSON.stringify(snippet));
    }
    for (const snippet of fixture.summary ?? []) {
      assert.ok(got.summary.includes(snippet), name + ' summary lacks ' + JSON.stringify(snippet) + ': ' + got.summary);
    }
  }
  assert.equal(out.noPlay, false);
  assert.ok(String(out.badPlay).includes('not a boolean'));
  console.log('Phase 4 audio: MP3/M4A/AAC/FLAC/Ogg Vorbis/Opus/WAV/AIFF cards, Dublin Core, lyrics, chapters, cover/play data and the play parameter are converted.');
} finally {
  await browser.close();
  server.close();
}
