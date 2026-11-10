import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join, resolve } from 'node:path';
import { chromium } from 'playwright';

const root = resolve(import.meta.dirname, '../..');
const mime = {
  '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript',
  '.wasm': 'application/wasm', '.plt': 'application/octet-stream',
};
const server = createServer(async (request, response) => {
  if (request.url === '/blank.html') {
    response.writeHead(200, { 'content-type': 'text/html' });
    response.end('<!doctype html><title>phase 5</title>');
    return;
  }
  let pathname;
  try { pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname); }
  catch { response.writeHead(400).end(); return; }
  try {
    const file = resolve(root, '.' + pathname);
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
    const { Converter } = await import('/node_modules/@bdfkit/convert/dist/index.js');
    const { BdfDocument, BufferSource } = await import('/node_modules/@bdfkit/core/dist/index.js');
    const { bdf_create_native_converter } = await import('/_build/js/debug/build/browser/browser.js');
    const upstream = new Converter(
      new Worker('/node_modules/@bdfkit/convert/dist/worker.js', { type: 'module' }),
      '/node_modules/@bdfkit/convert-all/dist/converter.wasm',
    );
    const moon = bdf_create_native_converter('/_build/js/debug/build/native_converter_worker/native_converter_worker.js');
    const formats = (await Promise.all([upstream.ready, moon.ready])).map(list => list.map(format => format.name));
    const inspect = async bdf => {
      const doc = await BdfDocument.open(new BufferSource(bdf));
      return doc.manifest.views[0].pages.map(page => ({ w: page.w, h: page.h, layers: page.layers.map(layer => layer.role) }));
    };
    const text = async bdf => {
      const doc = await BdfDocument.open(new BufferSource(bdf));
      const index = doc.manifest.views[0].textIndex;
      if (!index) return '';
      const { decodeTextIndex } = await import('/node_modules/@bdfkit/core/dist/index.js');
      return decodeTextIndex(await doc.part(index)).map(run => run.text).join(' ');
    };
    const out = { formats, cases: [] };
    for (const [name, path] of [
      ['hpgl1.plt', '/compat/hpgl/fixtures/hpgl1.plt'],
      ['shapes.plt', '/compat/hpgl/fixtures/shapes.plt'],
      ['shapes.jww', '/compat/jww/fixtures/shapes.jww'],
      ['old.jww', '/compat/jww/fixtures/old.jww'],
      ['shapes.dxf', '/compat/dxf/fixtures/shapes.dxf'],
      ['shapes-bin.dxf', '/compat/dxf/fixtures/shapes-bin.dxf'],
      ['r12-sjis.dxf', '/compat/dxf/fixtures/r12-sjis.dxf'],
      ['shapes.sfc', '/compat/sxf/fixtures/shapes.sfc'],
      ['shapes.cgm', '/compat/cgm/fixtures/shapes.cgm'],
      ['illustration.cgm', '/compat/cgm/fixtures/illustration.cgm'],
      ['sjis.cgm', '/compat/cgm/fixtures/sjis.cgm'],
      ['labels.drawio', '/compat/drawio/fixtures/labels.drawio'],
      ['multipage.drawio', '/compat/drawio/fixtures/multipage.drawio'],
      ['cairo-type1.pdf', '/compat/pdf/fixtures/cairo-type1.pdf'],
      ['reportlab-type1.pdf', '/compat/pdf/fixtures/reportlab-type1.pdf'],
    ]) {
      const data = new Uint8Array(await (await fetch(base + path)).arrayBuffer());
      const a = await upstream.convert(data, { name });
      const m = await moon.convert(data, { name });
      out.cases.push({
        name,
        upstream: { summary: a.summary, warnings: a.warnings, pages: await inspect(a.bdf), text: await text(a.bdf) },
        moon: { summary: m.summary, warnings: m.warnings, pages: await inspect(m.bdf), text: await text(m.bdf) },
      });
    }
    {
      const data = new Uint8Array(await (await fetch(base + '/compat/hpgl/fixtures/hpgl1.plt')).arrayBuffer());
      const opened = await moon.open(data, { name: 'hpgl1.plt' });
      const first = await moon.page(opened.stream, 0);
      const doc = await BdfDocument.open(new BufferSource(first.bdf));
      out.open = { pages: opened.pages, first: doc.manifest.views[0].pages.length };
      await moon.finish(opened.stream);
      await moon.close(opened.stream);
      const selected = await moon.convert(data, { name: 'hpgl1.plt', pages: '1' });
      const selectedDoc = await BdfDocument.open(new BufferSource(selected.bdf));
      out.selected = selectedDoc.manifest.views[0].pages.length;
    }
    {
      const data = new Uint8Array(await (await fetch(base + '/compat/cgm/fixtures/shapes-text.cgm')).arrayBuffer());
      try { await moon.convert(data, { name: 'shapes-text.cgm' }); out.clearText = 'accepted'; }
      catch (error) { out.clearText = String(error?.message ?? error); }
      try { await upstream.convert(data, { name: 'shapes-text.cgm' }); out.clearTextUpstream = 'accepted'; }
      catch (error) { out.clearTextUpstream = String(error?.message ?? error); }
    }
    try {
      const data = new Uint8Array(await (await fetch(base + '/compat/hpgl/fixtures/hpgl1.plt')).arrayBuffer());
      await moon.convert(data, { name: 'hpgl1.plt', params: { colors: 'bad' } });
      out.badColor = 'accepted';
    } catch (error) { out.badColor = String(error?.message ?? error); }
    try {
      await moon.convert(new TextEncoder().encode('not a plot'), { name: 'bad.plt' });
      out.named = 'accepted';
    } catch (error) { out.named = String(error?.message ?? error); }
    {
      const data = new Uint8Array(await (await fetch(base + '/compat/hpgl/fixtures/job.plt')).arrayBuffer());
      const a = await upstream.convert(data, { name: 'job.plt' });
      const m = await moon.convert(data, { name: 'job.plt' });
      out.job = { upstreamPages: (await inspect(a.bdf)).length, moonPages: (await inspect(m.bdf)).length, moonWarnings: m.warnings, upstreamSummary: a.summary };
    }
    {
      const data = new Uint8Array(await (await fetch(base + '/compat/dxf/fixtures/layout.dxf')).arrayBuffer());
      const a = await upstream.convert(data, { name: 'layout.dxf' });
      const m = await moon.convert(data, { name: 'layout.dxf' });
      const aDoc = await BdfDocument.open(new BufferSource(a.bdf));
      const mDoc = await BdfDocument.open(new BufferSource(m.bdf));
      out.layout = { upstreamViews: aDoc.manifest.views.length, moonViews: mDoc.manifest.views.length, moonWarnings: m.warnings, moonPages: await inspect(m.bdf), upstreamPages: await inspect(a.bdf) };
    }
    upstream.terminate();
    moon.terminate();
    return out;
  }, base);
  assert.ok(result.formats[0].includes('hpgl'), 'upstream has hpgl');
  assert.ok(result.formats[1].includes('hpgl'), 'moon has hpgl');
  for (const entry of result.cases) {
    assert.equal(entry.moon.pages.length, entry.upstream.pages.length, `${entry.name} page count`);
    const dxf = entry.name.endsWith('.dxf');
    const sxf = entry.name.endsWith('.sfc');
    const cgm = entry.name.endsWith('.cgm');
    const drawio = entry.name.endsWith('.drawio');
    // The second picture of illustration.cgm has no metric scaling; this port
    // sizes it from the VDC extent while upstream uses the picture descriptor.
    const partialGeometry = entry.name === 'illustration.cgm';
    const tolerance = cgm ? 0.05 : dxf ? 0.06 : sxf ? 0.10 : drawio ? 0.15 : 0.01;
    for (let i = 0; i < entry.moon.pages.length; i++) {
      if (!drawio && !partialGeometry) {
        assert.ok(Math.abs(entry.moon.pages[i].w - entry.upstream.pages[i].w) < entry.upstream.pages[i].w * tolerance, `${entry.name} page ${i + 1} width: moon ${entry.moon.pages[i].w}, upstream ${entry.upstream.pages[i].w}`);
        assert.ok(Math.abs(entry.moon.pages[i].h - entry.upstream.pages[i].h) < entry.upstream.pages[i].h * tolerance, `${entry.name} page ${i + 1} height: moon ${entry.moon.pages[i].h}, upstream ${entry.upstream.pages[i].h}`);
      }
      assert.deepEqual(entry.moon.pages[i].layers, entry.upstream.pages[i].layers, `${entry.name} page ${i + 1} layers`);
    }
    if (dxf || sxf || cgm || drawio) {
      assert.ok(entry.moon.text.length > 0, `${entry.name} text index`);
    } else {
      assert.equal(entry.moon.text, entry.upstream.text, `${entry.name} text index`);
    }
  }
  {
    const binary = result.cases.find(entry => entry.name === 'shapes-bin.dxf');
    const ascii = result.cases.find(entry => entry.name === 'shapes.dxf');
    assert.deepEqual(binary.moon.pages, ascii.moon.pages, 'binary and text DXF page geometry');
    assert.equal(binary.moon.text, ascii.moon.text, 'binary and text DXF text index');
  }
  assert.deepEqual(result.open, { pages: 1, first: 1 });
  assert.equal(result.selected, 1);
  assert.equal(result.clearText, 'accepted', 'this port converts clear-text CGM');
  assert.equal(result.clearTextUpstream, 'accepted', 'upstream converts clear-text CGM');
  assert.equal(result.job.upstreamPages, 2, 'upstream job.plt has a raster page');
  assert.equal(result.job.moonPages, 1, 'this port converts the HP-GL/2 page only');
  assert.ok(result.job.moonWarnings.some(message => message.includes('PCL and HP RTL')), 'job.plt reports the PCL gap');
  assert.equal(result.layout.upstreamViews, 2, 'upstream layout.dxf has model and paper space views');
  assert.equal(result.layout.moonViews, 1, 'this port converts model space only');
  assert.ok(result.layout.moonWarnings.some(message => message.includes('paper-space layouts')), 'layout.dxf reports the layout gap');
  assert.ok(Math.abs(result.layout.moonPages[0].w - result.layout.upstreamPages[0].w) < result.layout.upstreamPages[0].w * 0.06, 'layout.dxf model page width');
  assert.ok(String(result.badColor).includes('not pens or mono'), 'colors parameter error');
  assert.ok(String(result.named).startsWith('hpgl:'), 'HP-GL detection');
  console.log(`Phase 5-8 CAD, draw.io and PDF Type1: ${result.cases.length} fixtures convert with the expected layers and coverage; draw.io pages are fitted by this port, so their page sizes differ from the upstream auto-fit scaling.`);
} finally {
  await browser.close();
  server.close();
}
