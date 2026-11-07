// Render a sample to a card preview with the MoonBit JavaScript build.
//
//   npm run build:demo            # builds _build/pages
//   node demo/make-previews.mjs   # rewrites demo/previews/*.png
//   node demo/make-previews.mjs --only bdf,csv
//   node demo/make-previews.mjs --check   # render, compare, do not write
//   node demo/make-previews.mjs --out demo/previews
//
// The cards in demo/index.html are the single source of truth: for each
// `<article class="format-card">` the preview file comes from the card's
// `<img src="./previews/NAME.png">` and the sample from the card's first
// `<a data-sample="ID">` link that carries `data-preview`, resolved through
// the data-sample map parsed from demo/app.js. A card whose links open
// several documents marks the one its image shows; without the attribute the
// first link is used. The converter and the viewer run the same public API
// the demo runs, served from the built site, so the previews are the demo's
// own output.
import { createServer } from 'node:http';
import { createReadStream, readFileSync } from 'node:fs';
import { stat, writeFile, mkdir } from 'node:fs/promises';
import { extname, resolve } from 'node:path';
import { PNG } from 'pngjs';
import { chromium } from 'playwright';

const root = resolve(import.meta.dirname, '..');
const demo = resolve(root, 'demo');
const pages = resolve(root, '_build/pages');
const WIDTH = 640;
const HEIGHT = 400;
const SETTLE_MS = 400;

function fail(message) {
  console.error('make-previews: ' + message);
  process.exit(1);
}

// --- CLI --------------------------------------------------------------------
const args = process.argv.slice(2);
function readOption(flag) {
  const index = args.indexOf(flag);
  if (index < 0) return undefined;
  const value = index + 1 < args.length ? args[index + 1] : '';
  args.splice(index, 2);
  return value;
}
const outDir = resolve(demo, readOption('--out') ?? 'previews');
const check = args.includes('--check');
const only = readOption('--only')?.split(',').map(name => name.trim()).filter(Boolean);
if (only && !only.length) fail('--only needs at least one preview name');
const unknownOptions = args.filter(arg => arg !== '--check');
if (unknownOptions.length) fail(`unknown options: ${unknownOptions.join(' ')} (usage: node demo/make-previews.mjs [--only name[,name]] [--check] [--out DIR])`);

// --- cards (single source of truth) -----------------------------------------
function sampleFile(id) {
  if (!/^[\w-]+$/.test(id)) fail(`unexpected data-sample id "${id}" in demo/index.html`);
  const source = readFileSync(resolve(demo, 'app.js'), 'utf8');
  const entry = new RegExp(`(?:'${id}'|\\b${id}):\\s*\\['([^']+)'`).exec(source);
  if (!entry) fail(`no sample file for data-sample="${id}" in demo/app.js`);
  return entry[1].replace('./', '');
}
const cards = [...readFileSync(resolve(demo, 'index.html'), 'utf8').matchAll(/<article class="format-card">[\s\S]*?<\/article>/g)].map(match => {
  const source = match[0];
  const image = /src="\.\/previews\/([^"/]+)\.png"/.exec(source);
  if (!image) fail('a gallery card has no <img src="./previews/NAME.png"> in demo/index.html');
  const links = [...source.matchAll(/<a\b[^>]*>/g)].map(link => link[0]);
  const samples = links
    .map(link => /data-sample="([^"]+)"/.exec(link)?.[1])
    .filter(Boolean);
  if (!samples.length) fail(`card previews/${image[1]}.png has no <a data-sample="ID"> link in demo/index.html`);
  const marked = links.filter(link => /\bdata-sample="[^"]+"[^>]*\bdata-preview\b/.test(link));
  if (marked.length > 1) fail(`card previews/${image[1]}.png marks more than one data-preview link`);
  const sample = marked.length ? /data-sample="([^"]+)"/.exec(marked[0])[1] : samples[0];
  return { name: image[1], sample };
});
if (!cards.length) fail('no <article class="format-card"> elements found in demo/index.html');
// A preview file must belong to exactly one sample: if two cards that open
// different samples share a preview name, either image would leave one card
// showing the wrong document, so refuse instead of guessing.
for (const a of cards) {
  for (const b of cards) {
    if (a !== b && a.name === b.name && a.sample !== b.sample) {
      fail(`previews/${a.name}.png is referenced by cards that open different samples (${a.sample} and ${b.sample}); give each card its own preview file in demo/index.html`);
    }
  }
}
const targets = cards.filter((card, index) => cards.slice(0, index).every(other => other.name !== card.name));
if (only) {
  const known = targets.map(card => card.name);
  const missing = only.filter(name => !known.includes(name));
  if (missing.length) fail(`unknown preview name(s): ${missing.join(', ')} (known: ${known.join(', ')})`);
}
const selected = only ? targets.filter(card => only.includes(card.name)) : targets;

if (!await fileExists(resolve(pages, 'browser.js'))) {
  fail('_build/pages/browser.js is missing; run `npm run build:demo` first');
}

// --- static server (temporary port) -----------------------------------------
const types = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.json': 'application/json',
};
const server = createServer(async (request, response) => {
  const url = new URL(request.url, 'http://localhost');
  // A blank document on the served origin: same-origin access to /browser.js
  // without the demo page's own viewer competing for the Workers.
  if (url.pathname === '/__previews') {
    response.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    response.end('<!doctype html><title>bdf previews</title>');
    return;
  }
  const file = resolve(pages, decodeURIComponent(url.pathname.slice(1)) || 'index.html');
  if (!file.startsWith(pages + '/')) { response.writeHead(403).end(); return; }
  try {
    const info = await stat(file);
    if (!info.isFile()) throw new Error('not a file');
    response.writeHead(200, { 'Content-Type': types[extname(file)] ?? 'application/octet-stream', 'Content-Length': info.size });
    createReadStream(file).pipe(response);
  } catch {
    response.writeHead(404).end();
  }
});
await new Promise((done, fail) => { server.once('error', fail); server.listen(0, '127.0.0.1', done); });
const base = 'http://127.0.0.1:' + server.address().port + '/';

// --- rendering --------------------------------------------------------------
// The page opens on a blank document on the served origin (the Workers and
// samples are same-origin there) so the demo's own viewer stays out of the
// way. The evaluated function is self-contained: module scope is not shipped
// to the browser.
async function renderPreview({ url, name, width, height, sheetWidth, sheetHeight, settleMs }) {
  const { bdf_create_native_converter, bdf_create_viewer } = await import('/browser.js');
  // One converter for the whole run, like the demo keeps one.
  if (!window.__bdfConverter) window.__bdfConverter = bdf_create_native_converter('/native_converter_worker.js');
  const converter = window.__bdfConverter;
  await converter.ready;
  const response = await fetch(url);
  if (!response.ok) throw new Error(url + ': HTTP ' + response.status);
  const input = await response.arrayBuffer();
  // .bdf inputs are opened as-is; everything else converts first.
  const bytes = name.toLowerCase().endsWith('.bdf')
    ? new Uint8Array(input)
    : new Uint8Array((await converter.convert(input, { name })).bdf);
  // A sheet viewport is derived from the stage's scroll position and client
  // box at zoom 1, so size the host to the sheet region we want; the size is
  // harmless for page views, which fill the stage with page frames instead.
  const host = document.createElement('div');
  host.style.cssText = `position:absolute;left:0;top:0;width:${sheetWidth}px;height:${sheetHeight}px;overflow:hidden;`;
  document.body.append(host);
  const viewer = bdf_create_viewer(host, { workerUrl: '/render_worker.js', layout: 'single', find: false });
  const errors = [];
  viewer.addEventListener('error', event => errors.push(String(event.detail?.message ?? event.detail)));
  try {
    await viewer.open({ kind: 'buffer', buffer: bytes.slice().buffer });
    const view = viewer.view;
    // Asynchronous image/font preparation runs inside the render Worker's
    // draw loop; once the first canvas is drawn, give the bitmap time to
    // settle before reading pixels.
    const settle = async extra => {
      await new Promise(done => setTimeout(done, extra));
      await new Promise(done => requestAnimationFrame(() => requestAnimationFrame(done)));
    };
    let canvas;
    if (view.kind === 'sheet') {
      // The sheet canvas exists (300x150) before its first draw; only a
      // finished draw sets style.width.
      canvas = await new Promise((done, failAfter) => {
        const attempts = 240;
        const tick = left => {
          const canvas = host.querySelector('canvas');
          if (canvas && canvas.style.width) done(canvas);
          else if (left <= 0) failAfter(new Error('the sheet canvas never got a viewport'));
          else setTimeout(() => tick(left - 1), 100);
        };
        tick(attempts);
      });
      await settle(settleMs);
    } else if (view.kind === 'scroll') {
      // A scroll view (Markdown, font specimen) is one continuous document:
      // draw the top of it through the same renderer the viewer holds, via
      // the continuous request with an explicit viewport.
      const bitmap = await viewer.renderer.continuous(view.id, { x: 0, y: 0, w: 900, h: 1200 }, 1);
      canvas = document.createElement('canvas');
      canvas.width = bitmap.width;
      canvas.height = bitmap.height;
      canvas.getContext('2d').drawImage(bitmap, 0, 0);
      bitmap.close();
      await settle(0);
    } else {
      // fixed and flow views list pages and are drawn like pages.
      canvas = await new Promise((done, failAfter) => {
        const attempts = 240;
        const tick = left => {
          const canvas = host.querySelector('[data-bdf-page="0"] canvas[data-loaded="ready"]');
          if (canvas) done(canvas);
          else if (left <= 0) failAfter(new Error('the first page canvas never became ready'));
          else setTimeout(() => tick(left - 1), 100);
        };
        tick(attempts);
      });
      await settle(settleMs);
    }
    if (errors.length) throw new Error(errors[0]);
    // Compose the card image: light grey background, the page or sheet band
    // centred and scaled to fit, white paper behind it.
    const card = document.createElement('canvas');
    card.width = width;
    card.height = height;
    const context = card.getContext('2d');
    context.fillStyle = '#e9ecef';
    context.fillRect(0, 0, width, height);
    const fit = Math.min(width / canvas.width, height / canvas.height);
    const drawWidth = canvas.width * fit;
    const drawHeight = canvas.height * fit;
    context.fillStyle = '#ffffff';
    context.fillRect((width - drawWidth) / 2, (height - drawHeight) / 2, drawWidth, drawHeight);
    context.imageSmoothingQuality = 'high';
    context.drawImage(canvas, (width - drawWidth) / 2, (height - drawHeight) / 2, drawWidth, drawHeight);
    // Never write a blank image: something must be drawn on the paper. Count
    // pixels that are neither the fixed #e9ecef background nor near-white.
    const pixels = context.getImageData(0, 0, width, height).data;
    let content = 0;
    let ink = 0;
    for (let index = 0; index < pixels.length; index += 4) {
      const red = pixels[index];
      const green = pixels[index + 1];
      const blue = pixels[index + 2];
      if (red === 233 && green === 236 && blue === 239) continue;
      content++;
      if (red < 248 || green < 248 || blue < 248) ink++;
    }
    if (ink === 0) throw new Error('the rendered preview is blank (nothing drawn on the paper)');
    const blob = await new Promise(done => card.toBlob(done, 'image/png'));
    return { kind: view.kind, content, bytes: new Uint8Array(await blob.arrayBuffer()) };
  } finally {
    viewer.destroy();
    host.remove();
  }
}

function contentPixels(png) {
  let count = 0;
  for (let index = 0; index < png.data.length; index += 4) {
    if (png.data[index] !== 233 || png.data[index + 1] !== 236 || png.data[index + 2] !== 239) count++;
  }
  return count;
}

async function fileExists(file) {
  try { return (await stat(file)).isFile(); } catch { return false; }
}

// --- run --------------------------------------------------------------------
const browser = await chromium.launch({ headless: true });
try {
  const page = await browser.newPage();
  page.setDefaultTimeout(0);
  // Keep the page's console errors around for failure messages.
  const pageErrors = [];
  page.on('pageerror', error => pageErrors.push(error.message));
  page.on('console', message => { if (message.type() === 'error') pageErrors.push(message.text()); });
  await page.goto(base + '__previews');
  await mkdir(outDir, { recursive: true });
  const stale = [];
  for (const { name, sample } of selected) {
    const file = sampleFile(sample);
    pageErrors.length = 0;
    let rendered;
    try {
      rendered = await page.evaluate(renderPreview, {
        url: '/' + file,
        name: file.split('/').pop(),
        width: WIDTH,
        height: HEIGHT,
        sheetWidth: 900,
        sheetHeight: 560,
        settleMs: SETTLE_MS,
      });
    } catch (error) {
      const detail = [error.message?.split('\n')[0] ?? String(error), ...pageErrors].join(' | ');
      fail(`previews/${name}.png: ${file} could not be rendered${detail ? ' (' + detail + ')' : ''}`);
    }
    const png = PNG.sync.read(Buffer.from(rendered.bytes));
    const content = contentPixels(png);
    const path = resolve(outDir, name + '.png');
    if (!check) {
      await writeFile(path, Buffer.from(rendered.bytes));
      console.log(`wrote previews/${name}.png from ${file} (${rendered.kind} view, ${content} content pixels)`);
    } else {
      let existing = null;
      try { existing = PNG.sync.read(readFileSync(path)); } catch { /* missing or unreadable */ }
      const same = existing
        && existing.width === png.width && existing.height === png.height
        && Buffer.compare(existing.data, png.data) === 0;
      if (same) {
        console.log(`ok previews/${name}.png from ${file} (${rendered.kind} view, ${content} content pixels)`);
      } else {
        console.error(`stale previews/${name}.png (${rendered.kind} view, differs from the rendered content of ${file})`);
        stale.push(name);
      }
    }
  }
  if (check && stale.length) {
    fail(`stale previews: ${stale.join(', ')} — re-run node demo/make-previews.mjs to regenerate`);
  }
} finally {
  await browser.close();
  server.close();
}
