// Synthetic EMF pen widths, rendered in a real browser canvas.
//
// Every metafile is built in memory: a square device over a 25.4mm frame, so
// the page is always 72x72pt (72x72 canvas pixels) and one device unit is
// 72 / (25.4 * device / 25) page points. A pen width is a logical (device)
// width, so its page width is width * that scale.
//
// Cases:
//   geometric            40 units at 960dpi -> 2.95px
//   wide                200 units at 960dpi -> 14.76px (a legitimate wide pen)
//   cosmetic              0 units at 960dpi -> 0.75px hairline (a
//                         96dpi-inspired approximation, not one device pixel)
//   anisotropic          40 units, viewport y halved -> geometric mean 2.09px
//   pageScale2           40 units at 480dpi -> 5.91px (half the device dpi)
//   cosmeticPageScale2    0 units at 480dpi -> 0.75px (the hairline does not
//                         follow the page scale)
//   subunit               1 unit at 240dpi -> 0.30px (a positive geometric pen
//                         below one page point is scaled, not a hairline)
//   zoom                  the geometric and cosmetic cases at zoom 2 -> twice
//                         the zoom-1 ink (the hairline is a page width, so
//                         browser zoom scales it; it is not pinned to one
//                         output device pixel)
//
// The anisotropic case is an approximation, not exact GDI: the object format
// carries one isotropic width per stroke, so the geometric mean of the matrix
// axes is used. GDI would draw an elliptical pen (1.48px for this horizontal
// line, against the 2.09px the geometric mean predicts).
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, resolve } from 'node:path';
import { chromium } from 'playwright';

const root = resolve(import.meta.dirname, '../..');
const mime = {
  '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript',
  '.wasm': 'application/wasm',
};

function u16(v) { return [v & 255, (v >> 8) & 255]; }
function u32(v) { return [v & 255, (v >> 8) & 255, (v >> 16) & 255, (v >>> 24) & 255]; }
function i32(v) { return u32(v | 0); }
function record(kind, payload) {
  return [...u32(kind), ...u32(8 + payload.length), ...payload];
}
// frame 0..2540 (25.4mm) over a `device` square, 25mm of millimetres.
function emf(records, device) {
  const header = [
    ...u32(1), ...u32(88),
    ...i32(0), ...i32(0), ...i32(device), ...i32(device),
    ...i32(0), ...i32(0), ...i32(2540), ...i32(2540),
    ...u32(0x464d4520), ...u32(0x10000), ...u32(88), ...u32(1),
    ...u16(1), ...u16(0), ...u32(0), ...u32(0), ...u32(0),
    ...i32(device), ...i32(device), ...i32(25), ...i32(25),
  ];
  return Uint8Array.from([...header, ...records.flat()]);
}
function createPen(handle, width) {
  return record(38, [...u32(handle), ...u32(0), ...i32(width), ...u32(0), ...u32(0)]);
}
function selectObject(handle) { return record(37, [...u32(handle)]); }
function moveTo(x, y) { return record(27, [...i32(x), ...i32(y)]); }
function lineTo(x, y) { return record(54, [...i32(x), ...i32(y)]); }
function setMapMode(mode) { return record(17, [...i32(mode)]); }
function setWindowExt(x, y) { return record(9, [...i32(x), ...i32(y)]); }
function setViewportExt(x, y) { return record(11, [...i32(x), ...i32(y)]); }
function eof() { return record(14, [...i32(0), ...i32(0), ...i32(0)]); }

// A horizontal line through the middle of the page, so a column scan crosses
// the stroke once and its ink is the stroke's thickness.
function lineEmf(width, device, extra = []) {
  const y = Math.round(device / 2);
  return emf([
    ...extra,
    createPen(1, width),
    selectObject(1),
    moveTo(Math.round(device * 0.1), y),
    lineTo(Math.round(device * 0.9), y),
    eof(),
  ], device);
}

const anisotropic = [
  setMapMode(8),
  setWindowExt(2540, 2540),
  setViewportExt(2540, 1270),
];
const cases = {
  geometric: lineEmf(40, 960),
  wide: lineEmf(200, 960),
  cosmetic: lineEmf(0, 960),
  anisotropic: lineEmf(40, 960, anisotropic),
  pageScale2: lineEmf(40, 480),
  cosmeticPageScale2: lineEmf(0, 480),
  subunit: lineEmf(1, 240),
};

const server = createServer(async (request, response) => {
  const pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
  if (pathname === '/blank.html') {
    response.writeHead(200, { 'content-type': 'text/html' });
    response.end('<!doctype html><title>pen width</title>');
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
  const results = await page.evaluate(async ({ cases }) => {
    const { bdf_create_native_converter, bdf_create_viewer, mount_bdf_async, unmount_bdf } =
      await import('/_build/js/debug/build/browser/browser.js');
    const converter = bdf_create_native_converter(
      '/_build/js/debug/build/native_converter_worker/native_converter_worker.js',
    );
    await converter.ready;
    // Ink in a column: the alpha-weighted darkness, in canvas pixels.
    const ink = (context, x, y0, y1) => {
      const data = context.getImageData(x, y0, 1, y1 - y0).data;
      let sum = 0;
      for (let i = 0; i < data.length; i += 4) {
        const alpha = data[i + 3] / 255;
        const luminance = (0.2126 * data[i] + 0.7152 * data[i + 1] + 0.0722 * data[i + 2]) / 255;
        sum += alpha * (1 - luminance);
      }
      return sum;
    };
    const dark = (context, x, y0, y1) => {
      const data = context.getImageData(x, y0, 1, y1 - y0).data;
      let count = 0;
      for (let i = 0; i < data.length; i += 4) {
        const luminance = (0.2126 * data[i] + 0.7152 * data[i + 1] + 0.0722 * data[i + 2]) / 255;
        if (luminance < 0.5) count += 1;
      }
      return count;
    };
    const measure = (canvas) => {
      const context = canvas.getContext('2d');
      const x = Math.round(canvas.width / 2);
      return {
        size: [canvas.width, canvas.height],
        ink: ink(context, x, 0, canvas.height),
        dark: dark(context, x, 0, canvas.height),
      };
    };
    const convert = async (name, bytes) => {
      const converted = await converter.convert(Uint8Array.from(bytes), { name: `${name}.emf` });
      const bdf = converted.bdf ?? converted.bytes ?? converted.data;
      if (!bdf) throw new Error(`${name}: converter returned no bytes: ${Object.keys(converted)}`);
      return new Uint8Array(bdf);
    };
    const out = {};
    for (const [name, bytes] of Object.entries(cases)) {
      const bdf = await convert(name, bytes);
      const host = document.createElement('div');
      document.body.append(host);
      await mount_bdf_async(host, bdf, 'single');
      const canvas = host.querySelector('canvas');
      if (!canvas) throw new Error(`${name}: no canvas`);
      out[name] = measure(canvas);
      unmount_bdf(host);
      host.remove();
    }
    // Zoom: the same page through the viewer at zoom 1 and zoom 2.
    const zoomed = async (name, bytes) => {
      const bdf = await convert(name, bytes);
      const host = document.createElement('div');
      document.body.append(host);
      const viewer = bdf_create_viewer(host, {
        workerUrl: '/_build/js/debug/build/render_worker/render_worker.js',
        find: false,
      });
      await viewer.open({ kind: 'buffer', buffer: bdf.slice().buffer });
      const waitFor = async (test, label) => {
        for (let i = 0; i < 200; i += 1) {
          const canvas = host.querySelector('canvas');
          if (canvas && test(canvas)) return canvas;
          await new Promise(done => setTimeout(done, 25));
        }
        throw new Error(`${name}: ${label} did not render`);
      };
      const first = await waitFor(canvas => measure(canvas).ink > 0, 'zoom 1');
      const one = measure(first);
      viewer.setZoom(2);
      const second = await waitFor(
        canvas => canvas.width >= first.width * 2 && measure(canvas).ink > 0,
        'zoom 2',
      );
      const two = measure(second);
      viewer.destroy();
      host.remove();
      return { one, two };
    };
    const geometricZoom = await zoomed('geometric', cases.geometric);
    out.zoom1 = geometricZoom.one;
    out.zoom2 = geometricZoom.two;
    const cosmeticZoom = await zoomed('cosmetic', cases.cosmetic);
    out.cosmeticZoom1 = cosmeticZoom.one;
    out.cosmeticZoom2 = cosmeticZoom.two;
    converter.terminate();
    return out;
  }, { cases: Object.fromEntries(Object.entries(cases).map(([k, v]) => [k, [...v]])) });
  assert.deepEqual(errors, [], 'browser errors');

  // One device unit is 72 / (25.4 * device / 25) page points; the canvas is
  // one pixel per point.
  const unit = device => 72 / (25.4 * device / 25);
  const expected = {
    geometric: 40 * unit(960),
    wide: 200 * unit(960),
    cosmetic: 0.75,
    anisotropic: 40 * Math.SQRT1_2 * unit(960),
    pageScale2: 40 * unit(480),
    cosmeticPageScale2: 0.75,
    subunit: 1 * unit(240),
  };
  const near = (actual, want, tolerance) => Math.abs(actual - want) <= tolerance;
  const failures = [];
  for (const [name, want] of Object.entries(expected)) {
    const got = results[name];
    if (!near(got.ink, want, Math.max(0.12, want * 0.12))) {
      failures.push(`${name}: ink ${got.ink.toFixed(3)}px, expected ${want.toFixed(3)}px`);
    }
  }
  if (!(results.wide.ink > results.geometric.ink * 4)) {
    failures.push(`wide: a 5x wider pen must stay wider: ${results.wide.ink.toFixed(2)}px`);
  }
  if (!(results.pageScale2.ink > results.geometric.ink * 1.8)) {
    failures.push(`pageScale2: half the device dpi must double the stroke: ${results.pageScale2.ink.toFixed(2)}px`);
  }
  if (!near(results.zoom2.ink / results.zoom1.ink, 2, 0.25)) {
    failures.push(`zoom: ink must double at zoom 2: ${results.zoom1.ink.toFixed(2)} -> ${results.zoom2.ink.toFixed(2)}`);
  }
  // The hairline is a page width, so browser zoom scales it. This is the
  // documented limitation, not a cosmetic pen pinned to one device pixel.
  if (!near(results.cosmeticZoom2.ink / results.cosmeticZoom1.ink, 2, 0.3)) {
    failures.push(`cosmetic zoom: the hairline must scale with zoom: ${results.cosmeticZoom1.ink.toFixed(2)} -> ${results.cosmeticZoom2.ink.toFixed(2)}`);
  }
  assert.deepEqual(failures, [], 'pen width');
  console.log('EMF pen widths: geometric, wide, cosmetic, anisotropic, page scale, sub-unit and zoom ink measured.');
  console.log(JSON.stringify(results));
} finally {
  await browser.close();
  server.close();
}
