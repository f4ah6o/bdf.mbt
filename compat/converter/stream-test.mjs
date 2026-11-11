import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, resolve } from 'node:path';
import { chromium } from 'playwright';

const root = resolve(import.meta.dirname, '../..');
const mime = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.wasm': 'application/wasm', '.pdf': 'application/pdf' };
const server = createServer(async (request, response) => {
  if (request.url === '/blank.html') {
    response.writeHead(200, { 'content-type': 'text/html' });
    response.end('<!doctype html><title>converter stream</title>');
    return;
  }
  try {
    const file = resolve(root, '.' + decodeURIComponent(new URL(request.url, 'http://x').pathname));
    if (!file.startsWith(root + '/')) { response.writeHead(403).end(); return; }
    response.writeHead(200, { 'content-type': mime[extname(file)] ?? 'application/octet-stream' });
    response.end(await readFile(file));
  } catch { response.writeHead(404).end(); }
});
await new Promise((resolvePromise, reject) => { server.once('error', reject); server.listen(0, '127.0.0.1', resolvePromise); });
const base = `http://127.0.0.1:${server.address().port}`;
const browser = await chromium.launch({ headless: true });
try {
  const page = await browser.newPage();
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
  await page.goto(base + '/blank.html');
  const result = await page.evaluate(async base => {
    const { BdfDocument, BufferSource } = await import('/node_modules/@bdfkit/core/dist/index.js');
    const { bdf_create_native_converter } = await import('/_build/js/debug/build/browser/browser.js');
    const moon = bdf_create_native_converter('/_build/js/debug/build/native_converter_worker/native_converter_worker.js');
    await moon.ready;
    const name = 'reportlab-master.pdf';
    const data = new Uint8Array(await (await fetch(base + '/compat/pdf/fixtures/' + name)).arrayBuffer());
    const converted = await moon.convert(data, { name });
    const convertedDoc = await BdfDocument.open(new BufferSource(converted.bdf));
    const convertedPages = convertedDoc.manifest.views[0].pages.length;
    const opened = await moon.open(data, { name });
    const first = await moon.page(opened.stream, 0);
    const firstDoc = await BdfDocument.open(new BufferSource(first.bdf));
    const finished = await moon.finish(opened.stream);
    const finishedDoc = await BdfDocument.open(new BufferSource(finished.bdf));
    const finishedAgain = await moon.finish(opened.stream);
    const finishedAgainDoc = await BdfDocument.open(new BufferSource(finishedAgain.bdf));
    const closed = await moon.close(opened.stream);
    const closedAgain = await moon.close(opened.stream);
    let afterClose = '';
    try { await moon.finish(opened.stream); } catch (error) { afterClose = String(error?.message ?? error); }
    // A selection narrows the document before the stream is opened, so the
    // stream reports the selected page count and indexes the selected pages
    // from zero.
    const selected = await moon.open(data, { name, pages: '2' });
    const selectedDoc = await BdfDocument.open(new BufferSource(selected.bdf));
    const selectedFirst = await moon.page(selected.stream, 0);
    const selectedFirstDoc = await BdfDocument.open(new BufferSource(selectedFirst.bdf));
    const selectedFinished = await moon.finish(selected.stream);
    const selectedFinishedDoc = await BdfDocument.open(new BufferSource(selectedFinished.bdf));
    const selectedClosed = await moon.close(selected.stream);
    // A selection that names no page of the input keeps the document empty and
    // offers no stream, so `pages` and the document stay consistent.
    const empty = await moon.open(data, { name, pages: '999' });
    // Closing a stream releases it; opening again allocates a new stream id.
    const reopened = await moon.open(data, { name });
    const reopenedFirst = await moon.page(reopened.stream, 0);
    const reopenedFirstDoc = await BdfDocument.open(new BufferSource(reopenedFirst.bdf));
    const reopenedFinished = await moon.finish(reopened.stream);
    const reopenedFinishedDoc = await BdfDocument.open(new BufferSource(reopenedFinished.bdf));
    const reopenedClosed = await moon.close(reopened.stream);
    // A synthetic CSV conversion reports a warning, so the reply carries a
    // non-empty warning list across the Worker boundary.
    const csv = new TextEncoder().encode('a,b\n1,2\n');
    const csvConverted = await moon.convert(csv, { name: 'sample.csv' });
    moon.terminate();
    return {
      convertedPages,
      convertWarnings: converted.warnings,
      convertWarningsArray: Array.isArray(converted.warnings),
      openedPages: opened.pages,
      openedStream: opened.stream,
      openedWarnings: opened.warnings,
      openedWarningsArray: Array.isArray(opened.warnings),
      firstPages: firstDoc.manifest.views[0].pages.length,
      pageHasBdf: first.bdf instanceof Uint8Array,
      pageWarnings: first.warnings,
      pageWarningsArray: Array.isArray(first.warnings),
      finishHasBdf: finished.bdf instanceof Uint8Array,
      finishFormat: finished.format,
      finishSummary: typeof finished.summary,
      finishWarnings: finished.warnings,
      finishWarningsArray: Array.isArray(finished.warnings),
      finishedPages: finishedDoc.manifest.views[0].pages.length,
      finishedAgainPages: finishedAgainDoc.manifest.views[0].pages.length,
      closed,
      closedAgain,
      afterClose,
      selectedPages: selected.pages,
      selectedStream: selected.stream,
      selectedWarnings: selected.warnings,
      selectedWarningsArray: Array.isArray(selected.warnings),
      selectedDocPages: selectedDoc.manifest.views[0].pages.length,
      selectedFirstPages: selectedFirstDoc.manifest.views[0].pages.length,
      selectedFinishedPages: selectedFinishedDoc.manifest.views[0].pages.length,
      selectedClosed,
      emptyPages: empty.pages,
      emptyHasStream: empty.stream !== undefined,
      emptyWarnings: empty.warnings,
      emptyWarningsArray: Array.isArray(empty.warnings),
      reopenedStream: reopened.stream,
      reopenedPages: reopened.pages,
      reopenedFirstPages: reopenedFirstDoc.manifest.views[0].pages.length,
      reopenedFinishedPages: reopenedFinishedDoc.manifest.views[0].pages.length,
      reopenedClosed,
      csvWarnings: csvConverted.warnings,
      csvWarningsArray: Array.isArray(csvConverted.warnings),
    };
  }, base);
  assert.deepEqual(errors, [], 'page errors');
  assert.ok(result.convertedPages > 1, 'PDF has more than one page');
  assert.equal(result.convertWarningsArray, true, 'convert warnings are an array');
  assert.deepEqual(result.convertWarnings, [], 'convert warnings are empty for this PDF');
  assert.equal(result.openedPages, result.convertedPages, 'open reports the page count');
  assert.equal(result.openedStream, 0, 'the first stream is 0');
  assert.equal(result.openedWarningsArray, true, 'open warnings are an array');
  assert.deepEqual(result.openedWarnings, [], 'open warnings are empty for this PDF');
  assert.equal(result.firstPages, 1, 'page 0 is one page');
  assert.equal(result.pageHasBdf, true, 'page result carries bdf');
  assert.equal(result.pageWarningsArray, true, 'page warnings are an array');
  assert.deepEqual(result.pageWarnings, [], 'page warnings are empty');
  assert.equal(result.finishHasBdf, true, 'finish returns the whole document');
  assert.equal(result.finishFormat, 'pdf', 'finish keeps the format');
  assert.equal(result.finishSummary, 'string', 'finish keeps the summary');
  assert.equal(result.finishWarningsArray, true, 'finish warnings are an array');
  assert.deepEqual(result.finishWarnings, [], 'finish warnings are empty for this PDF');
  assert.equal(result.finishedPages, result.convertedPages, 'finish matches convert');
  assert.equal(result.finishedAgainPages, result.convertedPages, 'finish can be repeated');
  assert.equal(result.closed, null, 'close resolves to null');
  assert.equal(result.closedAgain, null, 'close can be repeated');
  assert.ok(String(result.afterClose).includes('no conversion'), `finish after close fails (got ${result.afterClose})`);
  assert.equal(result.selectedPages, 1, 'a selected open reports the selected page count');
  assert.equal(result.selectedStream, 1, 'a selected open allocates the next stream');
  assert.equal(result.selectedWarningsArray, true, 'selected open warnings are an array');
  assert.deepEqual(result.selectedWarnings, [], 'selected open warnings are empty for this PDF');
  assert.equal(result.selectedDocPages, 1, 'the selected open carries one page');
  assert.equal(result.selectedFirstPages, 1, 'the selected stream page is one page');
  assert.equal(result.selectedFinishedPages, 1, 'the selected stream finishes one page');
  assert.equal(result.selectedClosed, null, 'the selected stream closes');
  assert.equal(result.emptyPages, 0, 'an out-of-range selection reports zero pages');
  assert.equal(result.emptyHasStream, false, 'an out-of-range selection offers no stream');
  assert.equal(result.emptyWarningsArray, true, 'the empty selection warnings are an array');
  assert.deepEqual(result.emptyWarnings, [], 'the empty selection warnings are empty');
  assert.equal(result.reopenedStream, 2, 'reopening allocates a new stream');
  assert.equal(result.reopenedPages, result.convertedPages, 'reopening reports the page count');
  assert.equal(result.reopenedFirstPages, 1, 'the reopened stream pages');
  assert.equal(result.reopenedFinishedPages, result.convertedPages, 'the reopened stream finishes');
  assert.equal(result.reopenedClosed, null, 'the reopened stream closes');
  assert.equal(result.csvWarningsArray, true, 'CSV warnings are an array');
  assert.ok(result.csvWarnings.length > 0, 'CSV conversion reports a warning');
  assert.ok(result.csvWarnings.every(warning => typeof warning === 'string'), 'CSV warnings are strings');
  console.log('Converter stream: open/page/finish return the complete document, page warnings and stable close behavior.');
  console.log(`  selected open: ${result.selectedPages} page, stream ${result.selectedStream}, finished ${result.selectedFinishedPages} page`);
  console.log(`  out-of-range open: ${result.emptyPages} pages, stream ${result.emptyHasStream}`);
  console.log(`  reopened stream: ${result.reopenedStream}, ${result.reopenedPages} pages`);
  console.log(`  warnings: convert ${JSON.stringify(result.convertWarnings)}, CSV ${JSON.stringify(result.csvWarnings)}`);
} finally {
  await browser.close();
  server.close();
}
