import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, resolve } from 'node:path';
import { chromium } from 'playwright';

const root = resolve(import.meta.dirname, '../..');
const mime = {
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.mjs': 'text/javascript',
  '.wasm': 'application/wasm',
  '.md': 'text/markdown',
};
const server = createServer(async (request, response) => {
  if (request.url === '/blank.html') {
    response.writeHead(200, { 'content-type': 'text/html' });
    response.end('<!doctype html><title>markdown</title>');
    return;
  }
  try {
    const file = resolve(root, '.' + decodeURIComponent(new URL(request.url, 'http://x').pathname));
    if (!file.startsWith(root + '/')) {
      response.writeHead(403).end();
      return;
    }
    const data = await readFile(file);
    response.writeHead(200, { 'content-type': mime[extname(file)] ?? 'application/octet-stream' });
    response.end(data);
  } catch {
    response.writeHead(404).end();
  }
});
await new Promise((resolvePromise, reject) => {
  server.once('error', reject);
  server.listen(0, '127.0.0.1', resolvePromise);
});
const base = 'http://127.0.0.1:' + server.address().port;
const browser = await chromium.launch({ headless: true });
try {
  const page = await browser.newPage();
  await page.goto(base + '/blank.html');
  const result = await page.evaluate(async base => {
    const { Converter } = await import('/node_modules/@bdfkit/convert/dist/index.js');
    const { BdfDocument, BufferSource, decodeTextIndex } = await import('/node_modules/@bdfkit/core/dist/index.js');
    const { bdf_create_native_converter } = await import('/_build/js/debug/build/browser/browser.js');
    const upstream = new Converter(
      new Worker('/node_modules/@bdfkit/convert/dist/worker.js', { type: 'module' }),
      '/node_modules/@bdfkit/convert-all/dist/converter.wasm',
    );
    const moon = bdf_create_native_converter('/_build/js/debug/build/native_converter_worker/native_converter_worker.js');
    await Promise.all([upstream.ready, moon.ready]);
    const inspect = async bdf => {
      const doc = await BdfDocument.open(new BufferSource(bdf));
      const view = doc.manifest.views[0];
      const text = view.textIndex
        ? decodeTextIndex(await doc.part(view.textIndex)).map(run => run.text).join(' ')
        : '';
      return {
        id: view.id,
        kind: view.kind,
        pages: view.pages.length,
        width: view.pages[0]?.w,
        height: view.pages[0]?.h,
        images: doc.manifest.parts.filter(part => part.t === 'img').length,
        text,
      };
    };
    const cases = [];
    for (const name of ['basic.md', 'math.md', 'svg.md']) {
      const data = new Uint8Array(await (await fetch(base + '/compat/markdown/fixtures/' + name)).arrayBuffer());
      const a = await upstream.convert(data, { name });
      const m = await moon.convert(data, { name });
      cases.push({
        name,
        upstream: { summary: a.summary, warnings: a.warnings, ...(await inspect(a.bdf)) },
        moon: { summary: m.summary, warnings: m.warnings, ...(await inspect(m.bdf)) },
      });
    }
    moon.terminate();
    return cases;
  }, base);
  const normalize = value => value.replace(/\\s+/g, '');
  const lcs = (a, b) => {
    let previous = new Array(b.length + 1).fill(0);
    for (let i = 1; i <= a.length; i++) {
      const current = new Array(b.length + 1).fill(0);
      for (let j = 1; j <= b.length; j++) {
        current[j] = a[i - 1] === b[j - 1]
          ? previous[j - 1] + 1
          : Math.max(previous[j], current[j - 1]);
      }
      previous = current;
    }
    return previous[b.length];
  };
  const expectations = {
    'basic.md': ['Markdown のテスト文書', '太字', '入れ子の項目', '番号付き', '完了したタスク', '引用の段落です。', 'func main()', 'Long cell text that wraps in its column', 'グラデーションの画像', '脚注の本文です。'],
    'math.md': ['e^(iπ)+1=0', '√2≈1.414', 'x=(−b±√(b^2−4ac))/(2a)', '∑_(k=1)^n k=(n(n+1))/2', '∇⋅E=ρ/(ε_0)', 'A=(1, 2; 3, 4)'],
    'svg.md': ['Passing', 'Done', 'SVG images', 'sprite sheet'],
  };
  // The inline svg chart and the symbol of the sprite sheet are stored as
  // image parts; the two relative SVG files keep their alternative text and
  // a warning, as upstream does when it has no directory to resolve them in.
  const expectedImages = { 'basic.md': 0, 'math.md': 0, 'svg.md': 2 };
  const expectedWarnings = { 'basic.md': 2, 'math.md': 0, 'svg.md': 2 };
  for (const entry of result) {
    assert.equal(entry.upstream.kind, 'scroll', `${entry.name}: upstream kind`);
    assert.equal(entry.moon.kind, 'scroll', `${entry.name}: moon kind`);
    assert.equal(entry.moon.id, 'scroll', `${entry.name}: moon view id`);
    assert.equal(entry.moon.pages, 1, `${entry.name}: moon page count`);
    assert.equal(entry.moon.width, 504, `${entry.name}: scroll width`);
    assert.ok(entry.moon.summary.includes('scroll strip(s)'), `${entry.name}: summary`);
    assert.equal(entry.moon.images, expectedImages[entry.name], `${entry.name}: image parts`);
    assert.equal(entry.moon.warnings.length, expectedWarnings[entry.name], `${entry.name}: warnings`);
    if (entry.name === 'svg.md') {
      assert.ok(entry.moon.summary.includes('2 image(s)'), 'svg.md: summary images');
      assert.ok(entry.moon.warnings.some(warning => warning.includes('images/badge.svg')), 'svg.md: badge warning');
      assert.ok(entry.moon.warnings.some(warning => warning.includes('images/check.svg')), 'svg.md: check warning');
    }
    for (const want of expectations[entry.name]) {
      assert.ok(normalize(entry.moon.text).includes(normalize(want)), `${entry.name}: text lacks ${want}`);
    }
    const a = normalize(entry.upstream.text);
    const b = normalize(entry.moon.text);
    const similarity = 2 * lcs(a, b) / (a.length + b.length);
    assert.ok(similarity >= 0.88, `${entry.name}: text similarity ${similarity.toFixed(3)}`);
  }
  console.log('Phase 11 Markdown: scroll views, inline SVG image parts, GFM structure, math linearization and text indexes match upstream.');
} finally {
  await browser.close();
  server.close();
}
