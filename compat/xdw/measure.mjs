// Measure a captured page image: page rectangle, implied dpi and one row's
// colour runs. This is calibration tooling, not a fidelity gate: it never
// prints PASS/FAIL and it does not compare two images.
//
// The genuine Viewer capture is a screenshot with a grey workspace around a
// white page; the candidate capture is page content only. Both are handled by
// taking the largest connected near-white region as the page interior and
// expanding it by one pixel for the page border. Pass --page-rect to override
// the detection when a capture has a different layout.
//
// Usage:
//   node compat/xdw/measure.mjs IMAGE.png [--page-mm 210x148] [--scan Y]
//        [--threshold 24] [--page-rect x0,y0,x1,y1] [--stroke R,G,B] [--json]

import { readFileSync, statSync, realpathSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { PNG } from 'pngjs';

const WHITE = 245;
const DEFAULT_THRESHOLD = 24;
const MAX_BYTES = 64 * 1024 * 1024;
const MAX_PIXELS = 20_000_000;

function dimensions(width, height) {
  if (!Number.isSafeInteger(width) || !Number.isSafeInteger(height) || width <= 0 || height <= 0 || width * height > MAX_PIXELS) fail('image exceeds bounded positive 20 million pixel dimensions');
}

function fail(message) {
  const error = new Error(message);
  error.code = 'MEASURE';
  throw error;
}

function decode(bytes) {
  if (!Buffer.isBuffer(bytes) || bytes.length < 33) fail('not a PNG');
  if (bytes.length > MAX_BYTES) fail('PNG exceeds 64 MiB limit');
  if (!bytes.subarray(0, 8).equals(Buffer.from('89504e470d0a1a0a', 'hex'))) fail('not a PNG');
  if (bytes.toString('ascii', 12, 16) !== 'IHDR') fail('not a PNG');
  if (bytes[28] !== 0) fail('interlaced PNG unsupported');
  dimensions(bytes.readUInt32BE(16), bytes.readUInt32BE(20));
  let offset = 8;
  let headers = 0;
  let ended = false;
  while (offset < bytes.length) {
    if (offset + 12 > bytes.length) fail('truncated PNG chunk');
    const length = bytes.readUInt32BE(offset);
    if (length > bytes.length - offset - 12) fail('truncated PNG data');
    const kind = bytes.toString('ascii', offset + 4, offset + 8);
    if (kind === 'IHDR' && (++headers !== 1 || offset !== 8 || length !== 13)) fail('invalid or duplicate IHDR');
    if (kind === 'IEND') {
      if (length !== 0 || offset + 12 !== bytes.length) fail('invalid IEND or trailing data');
      ended = true;
    }
    offset += length + 12;
  }
  if (headers !== 1 || !ended) fail('incomplete PNG');
  const image = PNG.sync.read(bytes);
  if (image.data.length !== image.width * image.height * 4) fail('decoded PNG size mismatch');
  return image;
}

function pixel(image, x, y) {
  const at = (y * image.width + x) * 4;
  const a = image.data[at + 3] / 255;
  const visible = channel => Math.round(255 - a * (255 - image.data[at + channel]));
  return { r: visible(0), g: visible(1), b: visible(2), a: 255 };
}

// Largest 4-connected near-white region. The page interior is the largest
// white area in a Viewer screenshot; in a page-only capture it is the whole
// image. Returns null when the image has no white pixel.
export function findPage(image) {
  const { width, height } = image;
  dimensions(width, height);
  if (image.data?.length !== width * height * 4) fail('invalid image data');
  const total = width * height;
  const white = new Uint8Array(total);
  for (let i = 0; i < total; i++) {
    const at = i * 4;
    const a = image.data[at + 3] / 255;
    white[i] = [0, 1, 2].every(c => Math.round(255 - a * (255 - image.data[at + c])) >= WHITE) ? 1 : 0;
  }
  const seen = new Uint8Array(total);
  const stack = new Int32Array(total);
  let best = null;
  for (let start = 0; start < total; start++) {
    if (!white[start] || seen[start]) continue;
    let top = 0;
    stack[top++] = start;
    seen[start] = 1;
    let count = 0;
    let x0 = width;
    let y0 = height;
    let x1 = -1;
    let y1 = -1;
    while (top > 0) {
      const at = stack[--top];
      count++;
      const x = at % width;
      const y = (at - x) / width;
      if (x < x0) x0 = x;
      if (x > x1) x1 = x;
      if (y < y0) y0 = y;
      if (y > y1) y1 = y;
      if (x > 0 && white[at - 1] && !seen[at - 1]) { seen[at - 1] = 1; stack[top++] = at - 1; }
      if (x + 1 < width && white[at + 1] && !seen[at + 1]) { seen[at + 1] = 1; stack[top++] = at + 1; }
      if (y > 0 && white[at - width] && !seen[at - width]) { seen[at - width] = 1; stack[top++] = at - width; }
      if (y + 1 < height && white[at + width] && !seen[at + width]) { seen[at + width] = 1; stack[top++] = at + width; }
    }
    if (!best || count > best.pixels) best = { pixels: count, x0, y0, x1, y1 };
  }
  return best;
}

function expand(rect, width, height) {
  return {
    x0: Math.max(0, rect.x0 - 1),
    y0: Math.max(0, rect.y0 - 1),
    x1: Math.min(width - 1, rect.x1 + 1),
    y1: Math.min(height - 1, rect.y1 + 1),
  };
}

function size(rect) {
  return { width: rect.x1 - rect.x0 + 1, height: rect.y1 - rect.y0 + 1 };
}

function parsePageMm(value) {
  if (value === undefined) return null;
  const match = /^(\d+(?:\.\d+)?)x(\d+(?:\.\d+)?)$/.exec(value);
  if (!match) fail('--page-mm must be WIDTHxHEIGHT in millimetres');
  const width = Number(match[1]);
  const height = Number(match[2]);
  if (!(width > 0) || !(height > 0)) fail('--page-mm must be positive');
  return { width, height };
}

function parseRect(value) {
  if (value === undefined) return null;
  const parts = value.split(',').map(Number);
  if (parts.length !== 4 || parts.some(n => !Number.isInteger(n) || n < 0)) fail('--page-rect must be x0,y0,x1,y1');
  const [x0, y0, x1, y1] = parts;
  if (x1 < x0 || y1 < y0) fail('--page-rect must have x1 >= x0 and y1 >= y0');
  return { x0, y0, x1, y1 };
}

function colorKey(p) {
  return `${p.r},${p.g},${p.b}`;
}

// Runs of pixels that differ from the row's most common colour, or (with
// `stroke`) runs within `threshold` of one colour. A dashed stroke against a
// fill or the page shows up as several runs; a solid stroke shows up as one
// run per crossing. The fill itself is not a run when `stroke` is given, which
// is what makes a dash pattern measurable.
export function scanRuns(image, y, x0, x1, options = {}) {
  const threshold = options.threshold === undefined ? DEFAULT_THRESHOLD : options.threshold;
  const stroke = options.stroke === undefined ? null : options.stroke;
  if (!Number.isInteger(y) || y < 0 || y >= image.height) fail('scan row outside the image');
  if (!Number.isInteger(x0) || !Number.isInteger(x1) || x0 < 0 || x1 >= image.width) fail('scan range outside the image');
  if (x1 < x0) fail('scan range is empty');
  const counts = new Map();
  for (let x = x0; x <= x1; x++) {
    const key = colorKey(pixel(image, x, y));
    counts.set(key, (counts.get(key) || 0) + 1);
  }
  let dominantKey = null;
  let dominantCount = -1;
  for (const [key, count] of counts) {
    if (count > dominantCount) { dominantKey = key; dominantCount = count; }
  }
  const [dr, dg, db] = dominantKey.split(',').map(Number);
  const runs = [];
  let run = null;
  const finish = () => {
    if (!run) return;
    const n = run.x1 - run.x0 + 1;
    runs.push({
      x0: run.x0,
      x1: run.x1,
      length: n,
      mean: {
        r: Math.round(run.r / n),
        g: Math.round(run.g / n),
        b: Math.round(run.b / n),
      },
    });
    run = null;
  };
  for (let x = x0; x <= x1; x++) {
    const p = pixel(image, x, y);
    const diff = stroke
      ? Math.max(Math.abs(p.r - stroke.r), Math.abs(p.g - stroke.g), Math.abs(p.b - stroke.b))
      : Math.max(Math.abs(p.r - dr), Math.abs(p.g - dg), Math.abs(p.b - db));
    const inside = stroke ? diff <= threshold : diff > threshold;
    if (inside) {
      if (!run) run = { x0: x, x1: x, r: 0, g: 0, b: 0 };
      run.x1 = x;
      run.r += p.r;
      run.g += p.g;
      run.b += p.b;
    } else {
      finish();
    }
  }
  finish();
  return { y, dominant: { r: dr, g: dg, b: db }, stroke, runs };
}

export function measurePng(bytes, options = {}) {
  const image = decode(bytes);
  const pageMm = options.pageMm === undefined ? null : options.pageMm;
  const threshold = options.threshold === undefined ? DEFAULT_THRESHOLD : options.threshold;
  const override = options.pageRect === undefined ? null : options.pageRect;
  if (pageMm && (![pageMm.width, pageMm.height].every(n => Number.isFinite(n) && n > 0))) fail('page dimensions must be positive finite millimetres');
  if (override && (![override.x0, override.y0, override.x1, override.y1].every(n => Number.isInteger(n) && n >= 0) || override.x1 < override.x0 || override.y1 < override.y0)) fail('invalid page rectangle');
  const found = findPage(image);
  if (!found && !override) fail('no near-white page region found; pass --page-rect');
  const interior = override ?? { x0: found.x0, y0: found.y0, x1: found.x1, y1: found.y1 };
  if (interior.x1 >= image.width || interior.y1 >= image.height) fail('page rectangle outside the image');
  const page = override ? { ...override } : expand(interior, image.width, image.height);
  const pageSize = size(page);
  const interiorSize = size(interior);
  const dpi = pageMm
    ? {
        x: pageSize.width / pageMm.width * 25.4,
        y: pageSize.height / pageMm.height * 25.4,
      }
    : null;
  const scanY = options.scanY === undefined ? Math.floor((page.y0 + page.y1) / 2) : options.scanY;
  const scan = scanRuns(image, scanY, page.x0, page.x1, { threshold, stroke: options.stroke });
  return {
    status: 'DIAGNOSTIC_ONLY',
    method: override ? 'explicit-inclusive-rectangle' : 'largest-near-white-region-plus-assumed-one-pixel-border',
    warning: 'Verify page bounds manually. Row runs do not distinguish a dashed curve from separate intersections of a solid curve. No fidelity verdict.',
    width: image.width,
    height: image.height,
    page,
    pageSize,
    interior,
    interiorSize,
    dpi,
    scan,
  };
}

function parseColor(value) {
  if (value === undefined) return undefined;
  const parts = value.split(',').map(Number);
  if (parts.length !== 3 || parts.some(n => !Number.isInteger(n) || n < 0 || n > 255)) fail('--stroke must be R,G,B');
  return { r: parts[0], g: parts[1], b: parts[2] };
}

function parseArgs(argv) {
  const options = { file: null, pageMm: undefined, scanY: undefined, threshold: undefined, pageRect: undefined, stroke: undefined, json: false };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (['--page-mm', '--scan', '--threshold', '--page-rect', '--stroke'].includes(arg) && (argv[i + 1] === undefined || argv[i + 1].startsWith('--'))) fail(`${arg} requires a value`);
    if (arg === '--json') { options.json = true; continue; }
    if (arg === '--page-mm') { options.pageMm = parsePageMm(argv[++i]); continue; }
    if (arg === '--scan') { options.scanY = Number(argv[++i]); continue; }
    if (arg === '--threshold') { options.threshold = Number(argv[++i]); continue; }
    if (arg === '--page-rect') { options.pageRect = parseRect(argv[++i]); continue; }
    if (arg === '--stroke') { options.stroke = parseColor(argv[++i]); continue; }
    if (arg.startsWith('--')) fail(`unknown option ${arg}`);
    if (options.file) fail('only one image is measured at a time');
    options.file = arg;
  }
  if (!options.file) fail('usage: node compat/xdw/measure.mjs IMAGE.png [--page-mm 210x148] [--scan Y] [--threshold 24] [--page-rect x0,y0,x1,y1] [--stroke R,G,B] [--json]');
  if (options.scanY !== undefined && !Number.isInteger(options.scanY)) fail('--scan must be an integer row');
  if (options.threshold !== undefined && !(options.threshold >= 0 && options.threshold <= 255)) fail('--threshold must be 0..255');
  return options;
}

function format(result) {
  const lines = [];
  lines.push(`${result.status}: ${result.warning}`);
  lines.push(`image ${result.width}x${result.height}`);
  lines.push(`page ${result.page.x0},${result.page.y0}..${result.page.x1},${result.page.y1} (${result.pageSize.width}x${result.pageSize.height})`);
  lines.push(`interior ${result.interior.x0},${result.interior.y0}..${result.interior.x1},${result.interior.y1} (${result.interiorSize.width}x${result.interiorSize.height})`);
  if (result.dpi) lines.push(`dpi ${result.dpi.x.toFixed(2)} x ${result.dpi.y.toFixed(2)}`);
  lines.push(`scan y=${result.scan.y} dominant ${result.scan.dominant.r},${result.scan.dominant.g},${result.scan.dominant.b}`);
  if (result.scan.stroke) lines.push(`stroke ${result.scan.stroke.r},${result.scan.stroke.g},${result.scan.stroke.b}`);
  for (const run of result.scan.runs) {
    lines.push(`  run ${run.x0}..${run.x1} length ${run.length} mean ${run.mean.r},${run.mean.g},${run.mean.b}`);
  }
  return lines.join('\n');
}

let invoked = false;
try { invoked = !!process.argv[1] && import.meta.url === pathToFileURL(realpathSync(process.argv[1])).href; } catch { /* Imported module, not an existing CLI entry. */ }
if (invoked) {
  try {
    const options = parseArgs(process.argv.slice(2));
    if (statSync(options.file).size > MAX_BYTES) fail('PNG exceeds 64 MiB limit');
    const result = measurePng(readFileSync(options.file), options);
    process.stdout.write(options.json ? `${JSON.stringify(result, null, 2)}\n` : `${format(result)}\n`);
  } catch (error) {
    process.stderr.write(`measure: ${error.message}\n`);
    process.exit(1);
  }
}
