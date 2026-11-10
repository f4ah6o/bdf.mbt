// Synthetic DW03/DW06 clip replacement, rendered in a real browser canvas.
//
// The private document that motivated this test is not used: every metafile
// here is built in memory. Two disjoint clips each draw an image. A cumulative
// clip would intersect them to nothing, so the second image would be invisible.
// The test reads the actual canvas pixels, not the op count.
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
function emf(records) {
  const header = [
    ...u32(1), ...u32(88),
    ...i32(0), ...i32(0), ...i32(100), ...i32(100),
    ...i32(0), ...i32(0), ...i32(2540), ...i32(2540),
    ...u32(0x464d4520), ...u32(0x10000), ...u32(88), ...u32(1),
    ...u16(1), ...u16(0), ...u32(0), ...u32(0), ...u32(0),
    ...i32(96), ...i32(96), ...i32(25), ...i32(25),
  ];
  return Uint8Array.from([...header, ...records.flat()]);
}
function dw(a, b, payload) {
  const data = [0x44, 0x57, a, b, ...payload];
  return record(70, [...u32(data.length), ...data]);
}
function dw06(x0, y0, x1, y1) {
  return dw(48, 54, [...i32(x0), ...i32(y0), ...i32(x1), ...i32(y1)]);
}
function dw03(points) {
  const payload = [...u32(points.length / 2)];
  for (const value of points) payload.push(...u16(value));
  return dw(1, 32, payload);
}
function dw03clip() { return dw(48, 51, []); }
function intersectClip(x0, y0, x1, y1) {
  return record(30, [...i32(x0), ...i32(y0), ...i32(x1), ...i32(y1)]);
}
function eof() { return record(14, [...i32(0), ...i32(0), ...i32(0)]); }

// A 2x2 24-bit DIB, bottom-up, one colour.
function dib(r, g, b) {
  const header = [
    ...u32(40), ...i32(2), ...i32(2), ...u16(1), ...u16(24),
    ...u32(0), ...u32(16), ...i32(0), ...i32(0), ...u32(0), ...u32(0),
  ];
  const row = [b, g, r, b, g, r, 0, 0];
  return [...header, ...row, ...row];
}
function stretchDib(x, y, w, h, pixels) {
  const bmi = dib(...pixels);
  const bits = bmi.slice(40);
  const bmiOffset = 80;
  const bitsOffset = bmiOffset + 40;
  const payload = [
    ...i32(0), ...i32(0), ...i32(w), ...i32(h), // bounds
    ...i32(x), ...i32(y), ...i32(0), ...i32(0), ...i32(2), ...i32(2),
    ...u32(bmiOffset), ...u32(40), ...u32(bitsOffset), ...u32(bits.length),
    ...u32(0), ...u32(0x00cc0020), ...i32(w), ...i32(h),
  ];
  return record(81, [...payload, ...bmi, ...bits]);
}

function createBrush(handle, colour) {
  return record(39, [...u32(handle), ...u32(0), ...u32((colour[2] << 16) | (colour[1] << 8) | colour[0]), ...u32(0)]);
}
function selectObject(handle) { return record(37, [...u32(handle)]); }
function rectangle(x, y, w, h) {
  return record(43, [...i32(x), ...i32(y), ...i32(x + w), ...i32(y + h), ...i32(x), ...i32(y), ...i32(x + w), ...i32(y + h)]);
}
function solidRect(x, y, w, h, colour) {
  return [createBrush(1, colour), selectObject(1), rectangle(x, y, w, h)];
}

const red = [220, 30, 30];
const blue = [30, 60, 220];

// Two disjoint DW06 clips, each with its own image.
const dw06Emf = emf([
  dw06(0, 0, 30, 30),
  ...solidRect(0, 0, 30, 30, red),
  dw06(50, 50, 80, 80),
  ...solidRect(50, 50, 30, 30, blue),
  eof(),
]);

// The same with DW03 path clips.
const dw03Emf = emf([
  dw03([0, 0, 30, 0, 30, 30, 0, 30]),
  dw03clip(),
  ...solidRect(0, 0, 30, 30, red),
  dw03([50, 50, 80, 50, 80, 80, 50, 80]),
  dw03clip(),
  ...solidRect(50, 50, 30, 30, blue),
  eof(),
]);

// Normal GDI clipping must stay cumulative: the second image is clipped away.
const intersectEmf = emf([
  intersectClip(0, 0, 30, 30),
  ...solidRect(0, 0, 30, 30, red),
  intersectClip(50, 50, 80, 80),
  ...solidRect(50, 50, 30, 30, blue),
  eof(),
]);

const imageClipEmf = emf([
  dw06(0, 0, 30, 30),
  stretchDib(0, 0, 30, 30, red),
  dw06(50, 50, 80, 80),
  stretchDib(50, 50, 30, 30, blue),
  eof(),
]);

const imageOnlyEmf = emf([
  stretchDib(50, 50, 30, 30, blue),
  eof(),
]);

const server = createServer(async (request, response) => {
  const pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
  if (pathname === '/blank.html') {
    response.writeHead(200, { 'content-type': 'text/html' });
    response.end('<!doctype html><title>clip</title>');
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
    const { bdf_create_native_converter, mount_bdf_async, unmount_bdf } =
      await import('/_build/js/debug/build/browser/browser.js');
    const converter = bdf_create_native_converter(
      '/_build/js/debug/build/native_converter_worker/native_converter_worker.js',
    );
    await converter.ready;
    const out = {};
    for (const [name, bytes] of Object.entries(cases)) {
      const converted = await converter.convert(Uint8Array.from(bytes), { name: `${name}.emf` });
      const bdf = converted.bdf ?? converted.bytes ?? converted.data;
      if (!bdf) throw new Error(`${name}: converter returned no bytes: ${Object.keys(converted)}`);
      const host = document.createElement('div');
      document.body.append(host);
      await mount_bdf_async(host, new Uint8Array(bdf), 'single');
      const canvas = host.querySelector('canvas');
      if (!canvas) throw new Error(`${name}: no canvas`);
      const context = canvas.getContext('2d');
      const sample = (px, py) => {
        const x = Math.round(px / 96 * canvas.width);
        const y = Math.round(py / 96 * canvas.height);
        return [...context.getImageData(x, y, 1, 1).data];
      };
      out[name] = {
        size: [canvas.width, canvas.height],
        first: sample(15, 15),
        second: sample(65, 65),
        outside: sample(40, 40),
      };
      unmount_bdf(host);
      host.remove();
    }
    converter.terminate();
    return out;
  }, { cases: { dw06: [...dw06Emf], dw03: [...dw03Emf], intersect: [...intersectEmf], imageClip: [...imageClipEmf], imageOnly: [...imageOnlyEmf] } });
  assert.deepEqual(errors, [], 'browser errors');
  const near = (pixel, colour) =>
    Math.abs(pixel[0] - colour[0]) < 40 && Math.abs(pixel[1] - colour[1]) < 40 &&
    Math.abs(pixel[2] - colour[2]) < 40 && pixel[3] > 200;
  for (const name of ['dw06', 'dw03', 'imageClip']) {
    assert.ok(near(results[name].first, red), `${name}: the first image is not visible: ${results[name].first}`);
    assert.ok(near(results[name].second, blue), `${name}: the later disjoint image is not visible: ${results[name].second}`);
    assert.ok(!near(results[name].outside, red) && !near(results[name].outside, blue),
      `${name}: paint leaked outside the clips: ${results[name].outside}`);
  }
  assert.ok(near(results.imageOnly.second, blue), `imageOnly: the image is not placed at its rect: ${results.imageOnly.second}`);
  assert.ok(near(results.intersect.first, red), `intersect: the first image is not visible: ${results.intersect.first}`);
  assert.ok(!near(results.intersect.second, blue),
    `intersect: a cumulative clip must hide the disjoint image: ${results.intersect.second}`);
  console.log('EMF clip replacement: DW06 and DW03 keep both disjoint images visible; INTERSECTCLIPRECT stays cumulative.');
  console.log(JSON.stringify(results));
} finally {
  await browser.close();
  server.close();
}
