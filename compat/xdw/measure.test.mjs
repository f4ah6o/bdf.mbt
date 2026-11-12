import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, writeFileSync, symlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { PNG } from 'pngjs';
import { findPage, measurePng, scanRuns } from './measure.mjs';

function blank(width, height, colour = [255, 255, 255]) {
  const png = new PNG({ width, height });
  for (let i = 0; i < width * height; i++) {
    png.data[i * 4] = colour[0];
    png.data[i * 4 + 1] = colour[1];
    png.data[i * 4 + 2] = colour[2];
    png.data[i * 4 + 3] = 255;
  }
  return png;
}

function set(png, x, y, colour) {
  const at = (y * png.width + x) * 4;
  png.data[at] = colour[0];
  png.data[at + 1] = colour[1];
  png.data[at + 2] = colour[2];
  png.data[at + 3] = 255;
}

function fill(png, x0, y0, x1, y1, colour) {
  for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) set(png, x, y, colour);
}

// A grey workspace with a white page and a one-pixel border, like a Viewer
// screenshot. The page interior is 60x40 at (20,20); the border is 62x42.
function viewerLike() {
  const png = blank(100, 80, [128, 128, 128]);
  fill(png, 19, 19, 80, 60, [200, 200, 200]);
  fill(png, 20, 20, 79, 59, [255, 255, 255]);
  return png;
}

test('findPage returns the largest white region, not the workspace', () => {
  const page = findPage(viewerLike());
  assert.deepEqual(page, { pixels: 60 * 40, x0: 20, y0: 20, x1: 79, y1: 59 });
});

test('measurePng expands the interior by the one-pixel border and reports dpi', () => {
  const result = measurePng(PNG.sync.write(viewerLike()), { pageMm: { width: 210, height: 148 } });
  assert.deepEqual(result.page, { x0: 19, y0: 19, x1: 80, y1: 60 });
  assert.deepEqual(result.pageSize, { width: 62, height: 42 });
  assert.deepEqual(result.interiorSize, { width: 60, height: 40 });
  assert.ok(Math.abs(result.dpi.x - 62 / 210 * 25.4) < 1e-9);
  assert.ok(Math.abs(result.dpi.y - 42 / 148 * 25.4) < 1e-9);
});

test('a page-only capture is the whole image and is not expanded past it', () => {
  const png = blank(40, 30);
  const result = measurePng(PNG.sync.write(png), { pageMm: { width: 210, height: 148 } });
  assert.deepEqual(result.page, { x0: 0, y0: 0, x1: 39, y1: 29 });
  assert.deepEqual(result.pageSize, { width: 40, height: 30 });
});

test('scanRuns reports a dashed stroke as separate runs', () => {
  const png = blank(40, 10);
  fill(png, 5, 5, 9, 5, [0, 153, 204]);
  fill(png, 15, 5, 19, 5, [0, 153, 204]);
  const scan = scanRuns(png, 5, 0, 39, { stroke: { r: 0, g: 153, b: 204 }, threshold: 24 });
  assert.deepEqual(scan.runs.map(run => [run.x0, run.x1, run.length]), [[5, 9, 5], [15, 19, 5]]);
  assert.deepEqual(scan.runs[0].mean, { r: 0, g: 153, b: 204 });
});

test('scanRuns without a stroke colour reports non-dominant runs', () => {
  const png = blank(40, 10);
  fill(png, 5, 5, 9, 5, [0, 153, 204]);
  fill(png, 15, 5, 19, 5, [0, 153, 204]);
  const scan = scanRuns(png, 5, 0, 39, { threshold: 24 });
  assert.deepEqual(scan.runs.map(run => [run.x0, run.x1]), [[5, 9], [15, 19]]);
  assert.deepEqual(scan.dominant, { r: 255, g: 255, b: 255 });
});

test('a solid stroke is one run', () => {
  const png = blank(40, 10);
  fill(png, 5, 5, 19, 5, [0, 153, 204]);
  const scan = scanRuns(png, 5, 0, 39, { stroke: { r: 0, g: 153, b: 204 }, threshold: 24 });
  assert.deepEqual(scan.runs.map(run => [run.x0, run.x1, run.length]), [[5, 19, 15]]);
});

test('transparent pixels are composited on white for scans and page detection', () => {
  const png = blank(4, 4, [0, 0, 0]);
  for (let i = 3; i < png.data.length; i += 4) png.data[i] = 0;
  assert.deepEqual(scanRuns(png, 0, 0, 3).dominant, { r: 255, g: 255, b: 255 });
  assert.equal(findPage(png).pixels, 16);
});

test('a solid ellipse can produce two scan runs: no dash classification', () => {
  const png = blank(50, 40);
  for (let y = 0; y < 40; y++) for (let x = 0; x < 50; x++) {
    const d = ((x - 25) / 18) ** 2 + ((y - 20) / 12) ** 2;
    if (d >= 0.87 && d <= 1.13) set(png, x, y, [0, 153, 204]);
  }
  assert.equal(scanRuns(png, 13, 0, 49, { stroke: { r: 0, g: 153, b: 204 } }).runs.length, 2);
});

test('measurePng rejects non-PNG bytes', () => {
  assert.throws(() => measurePng(Buffer.from('not a png')), /not a PNG/);
});

test('measurement rejects oversized, duplicate-header and truncated PNGs before decoding', () => {
  const valid = PNG.sync.write(blank(4, 4));
  const oversized = Buffer.from(valid);
  oversized.writeUInt32BE(50_000, 16);
  oversized.writeUInt32BE(50_000, 20);
  assert.throws(() => measurePng(oversized), /20 million pixel/);
  const duplicate = Buffer.concat([valid.subarray(0, 33), valid.subarray(8, 33), valid.subarray(33)]);
  assert.throws(() => measurePng(duplicate), /duplicate IHDR/);
  assert.throws(() => measurePng(valid.subarray(0, -1)), /truncated PNG/);
});

test('manual bounds and reported DPI remain diagnostic and validated', () => {
  const valid = PNG.sync.write(blank(20, 20));
  assert.throws(() => measurePng(valid, { pageMm: { width: 0, height: 1 } }), /positive finite/);
  assert.throws(() => measurePng(valid, { pageRect: { x0: -1, y0: 0, x1: 1, y1: 1 } }), /invalid page rectangle/);
  assert.throws(() => scanRuns(blank(4, 4), 0, -1, 1), /outside the image/);
  const result = measurePng(valid);
  assert.equal(result.status, 'DIAGNOSTIC_ONLY');
  assert.match(result.warning, /solid curve/);
});

test('measurePng rejects an image with no white page unless a rectangle is given', () => {
  const grey = PNG.sync.write(blank(20, 20, [128, 128, 128]));
  assert.throws(() => measurePng(grey), /no near-white page region/);
  const result = measurePng(grey, { pageRect: { x0: 2, y0: 3, x1: 10, y1: 12 } });
  assert.deepEqual(result.page, { x0: 2, y0: 3, x1: 10, y1: 12 });
});

test('the CLI prints JSON for a synthetic capture', t => {
  const root = mkdtempSync(join(tmpdir(), 'xdw-measure-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const file = join(root, 'page.png');
  writeFileSync(file, PNG.sync.write(viewerLike()));
  const run = spawnSync(process.execPath, ['compat/xdw/measure.mjs', file, '--page-mm', '210x148', '--scan', '30', '--json'], { encoding: 'utf8' });
  assert.equal(run.status, 0, run.stderr);
  const result = JSON.parse(run.stdout);
  assert.deepEqual(result.pageSize, { width: 62, height: 42 });
  assert.equal(result.scan.y, 30);
});

test('the CLI exits 1 with a message on a bad image', t => {
  const root = mkdtempSync(join(tmpdir(), 'xdw-measure-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const file = join(root, 'bad.png');
  writeFileSync(file, 'not a png');
  const run = spawnSync(process.execPath, ['compat/xdw/measure.mjs', file], { encoding: 'utf8' });
  assert.equal(run.status, 1);
  assert.match(run.stderr, /not a PNG/);
});

test('CLI through a symlink with spaces still rejects a missing image', { skip: process.platform === 'win32' }, t => {
  const root = mkdtempSync(join(tmpdir(), 'xdw cli '));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const link = join(root, 'measure link.mjs');
  symlinkSync(resolve('compat/xdw/measure.mjs'), link);
  const run = spawnSync(process.execPath, [link, join(root, 'missing.png')], { encoding: 'utf8' });
  assert.equal(run.status, 1);
  assert.match(run.stderr, /ENOENT/);
});
