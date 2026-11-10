// Browser pixel check for synthetic kind 7 annotation and page bodies.
//
// Run after `moon build --target js`:
//   node convert/xdw/kind7_browser_test.mjs
//
// The fixture is built here, never read from a document: a 2x2 24-bit DIB
// whose two bands store red/green above blue/yellow, with a positive
// biHeight. The native converter worker turns it into a BDF page, and the
// page is drawn into a real Chromium canvas. The annotation object must keep
// the stored top-to-bottom order; the page content object must keep the
// generic bottom-up reading. Both are checked by their rendered pixels.
import assert from 'node:assert/strict';
import { createReadStream, existsSync } from 'node:fs';
import { createServer } from 'node:http';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { chromium } from 'playwright';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');

function concat(...parts) {
  const out = new Uint8Array(parts.reduce((n, p) => n + p.length, 0));
  let at = 0;
  for (const part of parts) { out.set(part, at); at += part.length; }
  return out;
}

function tlv(tag, value) {
  const n = value.length;
  const head = n < 0x80 ? [tag, n]
    : n < 0x100 ? [tag, 0x81, n]
    : [tag, 0x82, n >> 8, n & 0xff];
  return concat(Uint8Array.from(head), value);
}

function base128(n) {
  const out = [n & 0x7f];
  n >>= 7;
  while (n > 0) { out.unshift((n & 0x7f) | 0x80); n >>= 7; }
  return out;
}

function prop(tag, value, cls = 0x80) {
  const head = tag < 0x1f ? [cls | tag] : [cls | 0x1f, ...base128(tag)];
  const n = value.length;
  const len = n < 0x80 ? [n] : n < 0x100 ? [0x81, n] : [0x82, n >> 8, n & 0xff];
  return concat(Uint8Array.from([...head, ...len]), value);
}

function beNum(n) {
  const bytes = [];
  let v = n;
  do { bytes.unshift(v & 0xff); v = Math.floor(v / 256); } while (v > 0);
  if (bytes[0] & 0x80) bytes.unshift(0);
  return Uint8Array.from([bytes.length, ...bytes]);
}

function beRaw(n) {
  const bytes = [];
  let v = n;
  do { bytes.unshift(v & 0xff); v = Math.floor(v / 256); } while (v > 0);
  if (bytes[0] & 0x80) bytes.unshift(0);
  return Uint8Array.from(bytes);
}

function nums(values) {
  return concat(...values.map(beNum));
}

function kindBytes(kind) {
  const hi = (kind >> 8) & 0xff;
  const lo = kind & 0xff;
  return hi & 0x80 ? Uint8Array.from([0, hi, lo]) : Uint8Array.from([hi, lo]);
}

function record(depth, kind, attrs) {
  const body = concat(
    prop(0, Uint8Array.from([depth])),
    prop(2, Uint8Array.from(kind), 0x60),
    ...attrs,
  );
  return prop(2, body, 0x60);
}

function u32le(n) {
  return Uint8Array.from([n & 0xff, (n >> 8) & 0xff, (n >> 16) & 0xff, (n >> 24) & 0xff]);
}

// One LZH block whose literal table has all 256 bytes at 8 bits, so every
// output byte is its own 8-bit code. Enough for a small properties block.
function lzhLiteral(data) {
  const bits = [];
  const put = (v, n) => { for (let i = n - 1; i >= 0; i--) bits.push((v >> i) & 1); };
  put(data.length, 16);
  put(0, 5); put(10, 5); // pt: one symbol, 10 -> code length 8
  put(256, 9); // 256 literal code lengths, each read from the single pt symbol
  put(0, 4); put(0, 4); // position: one symbol
  for (const b of data) put(b, 8);
  const out = new Uint8Array(Math.ceil(bits.length / 8));
  for (let i = 0; i < bits.length; i++) if (bits[i]) out[i >> 3] |= 0x80 >> (i & 7);
  return out;
}

function bmi24(width, height) {
  const b = new Uint8Array(40);
  const dv = new DataView(b.buffer);
  dv.setUint32(0, 40, true);
  dv.setUint32(4, width, true);
  dv.setInt32(8, height, true);
  dv.setUint16(12, 1, true);
  dv.setUint16(14, 24, true);
  dv.setUint32(16, 0, true);
  dv.setUint32(20, width * height * 3, true);
  return b;
}

function kind7Body() {
  // 2x2 24-bit, stride 8: red/green on top, blue/yellow below, padded
  const row0 = Uint8Array.from([0, 0, 255, 0, 255, 0, 0, 0]);
  const row1 = Uint8Array.from([255, 0, 0, 0, 255, 255, 0, 0]);
  const band = (bytes) => concat(u32le(bytes.length), u32le(bytes.length), u32le(1), bytes);
  return concat(bmi24(2, 2), u32le(2), band(row0), band(row1));
}

function drawing(annotation) {
  return concat(
    tlv(0x80, Uint8Array.from([7])),
    ...(annotation ? [tlv(0x8d, Uint8Array.from([1]))] : []),
    tlv(0x86, kind7Body()),
  );
}

function syntheticXdw() {
  const properties = concat(
    record(0, [0x13, 0x01], [prop(5, nums([21000, 29700]))]),
    // an annotation picture at 100,200
    record(1, [0x13, 0x02], [prop(52, nums([100, 200]))]),
    record(2, kindBytes(0x803f), [prop(5, nums([300, 400])), prop(7, drawing(true))]),
    // a header/footer (non-annotation) picture at 100,700
    record(1, [0x13, 0x02], [prop(52, nums([100, 700]))]),
    record(2, kindBytes(0x802e), [prop(5, nums([300, 400])), prop(7, drawing(false))]),
  );
  const compressed = lzhLiteral(properties);
  const propsBlock = tlv(0x63, compressed);
  const fields = concat(
    tlv(0x80, Uint8Array.from([0])),
    tlv(0x82, Uint8Array.from([0])),
    tlv(0x83, beRaw(properties.length)),
    tlv(0x84, beRaw(compressed.length)),
    tlv(0x85, Uint8Array.from([0, 0, 0, 0])),
  );
  const trailerValueLen = fields.length + 6;
  const trailer = tlv(0x68, concat(fields, tlv(0x86, u32le(trailerValueLen))));
  return concat(tlv(0x60, tlv(0x82, Uint8Array.from([10]))), propsBlock, trailer);
}

const near = (p, r, g, b) => Math.abs(p[0] - r) < 60 && Math.abs(p[1] - g) < 60 && Math.abs(p[2] - b) < 60;

export async function verifyKind7Browser(browser, base) {
  const page = await browser.newPage();
  try {
    await page.goto(base + 'moon.html', { waitUntil: 'load' });
    const result = await page.evaluate(async (xdw) => {
      const worker = new Worker('/_build/js/debug/build/native_converter_worker/native_converter_worker.js', { type: 'module' });
      const reply = await new Promise((resolve, reject) => {
        worker.onmessage = (event) => {
          if (event.data.id === 0) {
            worker.postMessage({ id: 1, type: 'convert', data: xdw, options: { format: 'xdw', name: 'kind7.xdw' } });
          } else {
            resolve(event.data);
          }
        };
        worker.onerror = (event) => reject(new Error(event.message ?? 'worker error'));
        worker.postMessage({ id: 0, type: 'init' });
      });
      worker.terminate();
      if (!reply.ok) throw new Error(reply.error ?? 'conversion failed');
      const { BdfDocument, BufferSource } = await import('/node_modules/@bdfkit/core/dist/index.js');
      const { PageRenderer } = await import('/node_modules/@bdfkit/render/dist/index.js');
      const doc = await BdfDocument.open(new BufferSource(new Uint8Array(reply.result.bdf)));
      const view = doc.manifest.views[0];
      const page = view.pages[0];
      const scale = 4;
      const canvas = document.createElement('canvas');
      canvas.width = Math.ceil(page.w * scale);
      canvas.height = Math.ceil(page.h * scale);
      const ctx = canvas.getContext('2d');
      const renderer = new PageRenderer(doc);
      await renderer.renderPage(ctx, page, { scale });
      const pixel = (x, y) => Array.from(ctx.getImageData(x, y, 1, 1).data);
      const box = (y) => {
        const x0 = 100 / 100 * 72 / 25.4 * scale;
        const y0 = y / 100 * 72 / 25.4 * scale;
        const w = 300 / 100 * 72 / 25.4 * scale;
        const h = 400 / 100 * 72 / 25.4 * scale;
        return {
          topLeft: pixel(Math.round(x0 + w / 4), Math.round(y0 + h / 4)),
          topRight: pixel(Math.round(x0 + w * 3 / 4), Math.round(y0 + h / 4)),
          bottomLeft: pixel(Math.round(x0 + w / 4), Math.round(y0 + h * 3 / 4)),
          bottomRight: pixel(Math.round(x0 + w * 3 / 4), Math.round(y0 + h * 3 / 4)),
        };
      };
      return {
        page: [page.w, page.h],
        annotation: box(200),
        content: box(700),
        outside: pixel(2, 2),
      };
    }, Array.from(syntheticXdw()));
    assert.ok(Math.abs(result.page[0] - 595.2756) < 0.01 && Math.abs(result.page[1] - 841.8898) < 0.01, `page size ${result.page}`);
    // the annotation keeps the stored rows: red/green above blue/yellow
    assert.ok(near(result.annotation.topLeft, 255, 0, 0), `annotation top-left is ${result.annotation.topLeft}`);
    assert.ok(near(result.annotation.topRight, 0, 255, 0), `annotation top-right is ${result.annotation.topRight}`);
    assert.ok(near(result.annotation.bottomLeft, 0, 0, 255), `annotation bottom-left is ${result.annotation.bottomLeft}`);
    assert.ok(near(result.annotation.bottomRight, 255, 255, 0), `annotation bottom-right is ${result.annotation.bottomRight}`);
    // header/footer keeps the generic bottom-up reading: blue/yellow above red/green
    assert.ok(near(result.content.topLeft, 0, 0, 255), `content top-left is ${result.content.topLeft}`);
    assert.ok(near(result.content.topRight, 255, 255, 0), `content top-right is ${result.content.topRight}`);
    assert.ok(near(result.content.bottomLeft, 255, 0, 0), `content bottom-left is ${result.content.bottomLeft}`);
    assert.ok(near(result.content.bottomRight, 0, 255, 0), `content bottom-right is ${result.content.bottomRight}`);
    assert.ok(result.outside[0] > 240 && result.outside[1] > 240 && result.outside[2] > 240, `outside pixel is ${result.outside}`);
    return result;
  } finally {
    await page.close();
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const server = createServer((request, response) => {
    const pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
    const file = path.resolve(root, '.' + pathname);
    const allowed = [
      '/compat/visual/',
      '/node_modules/@bdfkit/',
      '/_build/js/debug/build/browser/',
      '/_build/js/debug/build/native_converter_worker/',
    ];
    if (!allowed.some((prefix) => file.startsWith(path.resolve(root, '.' + prefix) + path.sep))) {
      response.writeHead(403).end();
      return;
    }
    if (!existsSync(file)) { response.writeHead(404).end(); return; }
    response.setHeader('Content-Type', path.extname(file) === '.html' ? 'text/html' : 'text/javascript');
    createReadStream(file).pipe(response);
  });
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', resolve);
  });
  const base = `http://127.0.0.1:${server.address().port}/compat/visual/`;
  const browser = await chromium.launch({ headless: true });
  try {
    const result = await verifyKind7Browser(browser, base);
    console.log('kind 7 browser pixels:', JSON.stringify(result));
  } finally {
    await browser.close();
    server.close();
  }
}
