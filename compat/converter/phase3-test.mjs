import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, resolve } from 'node:path';
import { chromium } from 'playwright';

const root = resolve(import.meta.dirname, '../..');
const mime = { '.html': 'text/html', '.js': 'text/javascript', '.md': 'text/markdown', '.html': 'text/html', '.epub': 'application/epub+zip' };
const server = createServer(async (request, response) => {
  if (request.url === '/blank.html') {
    response.writeHead(200, { 'content-type': 'text/html' });
    response.end('<!doctype html><title>phase 3</title>');
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
  const result = await page.evaluate(async base => {
    const { BdfDocument, BufferSource, decodeTextIndex } = await import('/node_modules/@bdfkit/core/dist/index.js');
    const { bdf_create_native_converter } = await import('/_build/js/debug/build/browser/browser.js');
    const moon = bdf_create_native_converter('/_build/js/debug/build/native_converter_worker/native_converter_worker.js');
    await moon.ready;
    const out = { formats: (await moon.ready).map(format => format.name) };
    const data = new Uint8Array(await (await fetch(base + '/compat/markdown/fixtures/basic.md')).arrayBuffer());
    const converted = await moon.convert(data, { name: 'basic.md' });
    const doc = await BdfDocument.open(new BufferSource(converted.bdf));
    const view = doc.manifest.views[0];
    const bytes = await doc.part(view.textIndex);
    const index = decodeTextIndex(bytes);
    out.markdown = {
      summary: converted.summary,
      pages: view.pages.length,
      kind: view.kind,
      text: index.map(run => run.text).join(''),
    };
    my: {
      const opened = await moon.open(data, { name: 'basic.md' });
      const first = await moon.page(opened.stream, 0);
      const firstDoc = await BdfDocument.open(new BufferSource(first.bdf));
      out.open = { pages: opened.pages, first: firstDoc.manifest.views[0].pages.length };
      await moon.close(opened.stream);
    }
    {
      const bytes = new Uint8Array(await (await fetch(base + '/compat/html/fixtures/article.html')).arrayBuffer());
      const converted = await moon.convert(bytes, { name: 'html.html' });
      const doc = await BdfDocument.open(new BufferSource(converted.bdf));
      const view = doc.manifest.views[0];
      const index = decodeTextIndex(await doc.part(view.textIndex));
      out.html = { summary: converted.summary, pages: view.pages.length, text: index.map(run => run.text).join(''), warnings: converted.warnings };
    }
    moon.terminate();
    return out;
  }, base);
  assert.ok(result.formats.includes('markdown'));
  assert.ok(result.formats.includes('html'));
  assert.equal(result.markdown.summary.includes('scroll strip(s)'), true);
  assert.equal(result.markdown.pages, 1);
  assert.equal(result.markdown.kind, 'scroll');
  for (const want of ['Markdown のテスト文書', 'リスト', 'func main()', '完了したタスク', 'リンク']) {
    assert.ok(result.markdown.text.includes(want), `Markdown text lacks ${want}`);
  }
  assert.deepEqual(result.open, { pages: result.markdown.pages, first: 1 });
  assert.ok(result.html.pages > 0);
  assert.ok(result.html.text.includes('How Canvas Documents Load Quickly'));
  assert.ok(!result.formats.includes('epub'), 'EPUB is out of the maintained porting scope');
  console.log('Phase 3 HTML/Markdown: reader pages, metadata, text indexes and streamed pages are converted.');
} finally {
  await browser.close();
  server.close();
}
